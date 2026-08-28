import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/weather_info.dart';
import 'api_client.dart';

/// WeatherService fetches daily general forecasts from the MET Malaysia API
/// (`https://api.met.gov.my/v2.1/data`) and maps the response directly to [WeatherInfo].
///
/// ## Data Integrity & Caching Rules:
/// - If official MET Malaysia API returns data -> parse, cache, and return it.
/// - Caches successful official forecasts locally with a timestamp (TTL: 1 hour).
/// - If API returns no data, location has no MET ID, or request fails without valid cache -> return `null`.
/// - NO mock, static, estimated, derived, or fallback weather values are generated.
class WeatherService {
  static const Duration _cacheTtl = Duration(hours: 1);
  static final Map<String, _CachedForecast> _memoryCache = {};

  /// Mapping of destination name keyword -> MET Malaysia location ID.
  static const Map<String, String> _locationIds = {
    'genting': 'LOCATION:317',
    'cameron': 'LOCATION:314',
    'langkawi': 'LOCATION:323',
    'taman negara': 'LOCATION:331',
    'kundasang': 'LOCATION:829',
    'desaru': 'LOCATION:316',
    'batu feringgi': 'LOCATION:310',
    'batu ferringhi': 'LOCATION:310',
    'redang': 'LOCATION:326',
    'pangkor': 'LOCATION:324',
    'tioman': 'LOCATION:329',
    'perhentian': 'LOCATION:325',
    'port dickson': 'LOCATION:186',
    'fraser': 'LOCATION:313',
    'melaka': 'LOCATION:174',
    'kenyir': 'LOCATION:337',
    'cherating': 'LOCATION:315',
  };

  /// Fetches official MET Malaysia forecast data for [locationName].
  Future<WeatherInfo?> fetchWeatherForLocation(String locationName, String state, {bool forceRefresh = false}) async {
    final locationId = _resolveLocationId(locationName);
    if (locationId == null) {
      return null;
    }
    return fetchWeatherForLocationId(locationId, forceRefresh: forceRefresh);
  }

  /// Fetches official MET Malaysia forecast data by exact MET [locationId].
  /// Uses cached official response if still valid within TTL, unless [forceRefresh] is true.
  Future<WeatherInfo?> fetchWeatherForLocationId(String locationId, {bool forceRefresh = false}) async {
    if (locationId.isEmpty) return null;

    // 1. Check in-memory cache
    final now = DateTime.now();
    if (!forceRefresh && _memoryCache.containsKey(locationId)) {
      final cached = _memoryCache[locationId]!;
      if (now.difference(cached.fetchedAt) < _cacheTtl) {
        return cached.weatherInfo;
      }
    }

    // 2. Check SharedPreferences local cache
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('met_fc_$locationId');
        final ts = prefs.getInt('met_fc_ts_$locationId');
        if (raw != null && ts != null) {
          final fetchedAt = DateTime.fromMillisecondsSinceEpoch(ts);
          if (now.difference(fetchedAt) < _cacheTtl) {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            final info = WeatherInfo.fromJson(json);
            _memoryCache[locationId] = _CachedForecast(info, fetchedAt);
            return info;
          }
        }
      } catch (_) {}
    }

    // 3. Request fresh official MET Malaysia forecast
    try {
      final token = await AppConfig.getMetToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final dio = ApiClient.createMetDio(token);
      final today = _dateString(now);
      final tomorrow = _dateString(now.add(const Duration(days: 1)));

      final response = await dio.get(
        'data',
        queryParameters: {
          'datasetid': 'FORECAST',
          'datacategoryid': 'GENERAL',
          'locationid': locationId,
          'start_date': today,
          'end_date': tomorrow,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        return null;
      }

      // Filter to today's results
      final todayResults = results
          .cast<Map<String, dynamic>>()
          .where((r) => (r['date'] as String? ?? '').startsWith(today))
          .toList();

      if (todayResults.isEmpty) {
        return null;
      }

      final weatherInfo = _parseResults(todayResults);

      // Save to caches
      _memoryCache[locationId] = _CachedForecast(weatherInfo, now);
      _persistToCache(locationId, weatherInfo, now);

      return weatherInfo;
    } catch (_) {
      // If network fails, return cached forecast if available, else null (never mock data)
      if (_memoryCache.containsKey(locationId)) {
        return _memoryCache[locationId]!.weatherInfo;
      }
      return null;
    }
  }

  /// Fetches official MET forecast for a specific [targetDate].
  /// Returns `null` if the date is beyond the official MET forecast horizon (usually > 6 days from today).
  Future<WeatherInfo?> fetchWeatherForLocationAndDate(
    String locationId,
    DateTime targetDate, {
    bool forceRefresh = false,
  }) async {
    if (locationId.isEmpty) return null;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final daysDiff = targetMidnight.difference(todayMidnight).inDays;

    // MET Malaysia official general forecasts only cover up to 7 days ahead (days 0 through 6)
    if (daysDiff < 0 || daysDiff > 6) {
      return null;
    }

    if (daysDiff == 0) {
      return fetchWeatherForLocationId(locationId, forceRefresh: forceRefresh);
    }

    final dateStr = _dateString(targetDate);
    final cacheKey = '${locationId}_$dateStr';

    // 1. In-memory cache check
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.fetchedAt) < _cacheTtl) {
        return cached.weatherInfo;
      }
    }

    // 2. SharedPreferences cache check
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('met_fc_$cacheKey');
        final ts = prefs.getInt('met_fc_ts_$cacheKey');
        if (raw != null && ts != null) {
          final fetchedAt = DateTime.fromMillisecondsSinceEpoch(ts);
          if (now.difference(fetchedAt) < _cacheTtl) {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            final info = WeatherInfo.fromJson(json);
            _memoryCache[cacheKey] = _CachedForecast(info, fetchedAt);
            return info;
          }
        }
      } catch (_) {}
    }

    // 3. Request fresh forecast for that date
    try {
      final token = await AppConfig.getMetToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final dio = ApiClient.createMetDio(token);
      final nextDay = _dateString(targetDate.add(const Duration(days: 1)));

      final response = await dio.get(
        'data',
        queryParameters: {
          'datasetid': 'FORECAST',
          'datacategoryid': 'GENERAL',
          'locationid': locationId,
          'start_date': dateStr,
          'end_date': nextDay,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        return null;
      }

      final targetResults = results
          .cast<Map<String, dynamic>>()
          .where((r) => (r['date'] as String? ?? '').startsWith(dateStr))
          .toList();

      if (targetResults.isEmpty) {
        return null;
      }

      final weatherInfo = _parseResults(targetResults);

      // Save to caches
      _memoryCache[cacheKey] = _CachedForecast(weatherInfo, now);
      _persistToCache(cacheKey, weatherInfo, now);

      return weatherInfo;
    } catch (_) {
      if (_memoryCache.containsKey(cacheKey)) {
        return _memoryCache[cacheKey]!.weatherInfo;
      }
      return null;
    }
  }

  static Future<void> _persistToCache(String locationId, WeatherInfo info, DateTime fetchedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('met_fc_$locationId', jsonEncode(info.toJson()));
      await prefs.setInt('met_fc_ts_$locationId', fetchedAt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  String? _resolveLocationId(String locationName) {
    final name = locationName.toLowerCase();
    for (final entry in _locationIds.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  WeatherInfo _parseResults(List<Map<String, dynamic>> results) {
    double? maxT;
    double? minT;
    String? morningCond;
    String? afternoonCond;
    String? nightCond;
    String? sigWeather;
    String? sigWhen;
    String alertLevel = 'None';

    for (final r in results) {
      final datatype = r['datatype'] as String? ?? '';
      final value = r['value'];
      final attrs = r['attributes'] as Map<String, dynamic>? ?? {};

      switch (datatype) {
        case 'FMAXT':
          maxT = (value as num?)?.toDouble();
          break;
        case 'FMINT':
          minT = (value as num?)?.toDouble();
          break;
        case 'FGM':
          if (value is String) {
            morningCond = _humaniseCondition(value);
          }
          break;
        case 'FGA':
          if (value is String) {
            afternoonCond = _humaniseCondition(value);
          }
          break;
        case 'FGN':
          if (value is String) {
            nightCond = _humaniseCondition(value);
          }
          break;
        case 'FSIGW':
          if (value is String) {
            sigWeather = _humaniseCondition(value);
            sigWhen = attrs['when'] as String?;
            alertLevel = _alertFromSigw(value, sigWhen ?? '');
          }
          break;
      }
    }

    // Primary condition: Afternoon condition (FGA) or Significant weather (FSIGW) or Morning (FGM)
    final condition = afternoonCond ?? sigWeather ?? morningCond ?? 'Unavailable';
    final iconCode = _iconFromCondition(sigWeather ?? afternoonCond ?? morningCond ?? '');

    return WeatherInfo(
      maxTemperature: maxT,
      minTemperature: minT,
      condition: condition,
      iconCode: iconCode,
      alertLevel: alertLevel,
      morningCondition: morningCond,
      afternoonCondition: afternoonCond,
      nightCondition: nightCond,
      significantWeather: sigWeather,
      significantWhen: sigWhen,
    );
  }

  String _humaniseCondition(String metValue) {
    final v = metValue.toLowerCase();
    if (v.contains('thunder')) return 'Thunderstorms';
    if (v.contains('heavy rain') || v.contains('heavy shower')) return 'Heavy Rain';
    if (v.contains('rain') || v.contains('shower')) return 'Rain';
    if (v.contains('fog') || v.contains('mist')) return 'Foggy';
    if (v.contains('haze')) return 'Hazy';
    if (v.contains('overcast') || v.contains('cloudy')) return 'Cloudy';
    if (v.contains('partly cloudy') || v.contains('partly')) return 'Partly Cloudy';
    if (v.contains('sunny') || v.contains('fine') || v.contains('fair')) return 'Sunny';
    if (v.contains('no rain')) return 'No Rain';
    return metValue;
  }

  String _iconFromCondition(String metValue) {
    final v = metValue.toLowerCase();
    if (v.contains('thunder')) return 'thunderstorm';
    if (v.contains('heavy rain') || v.contains('heavy shower')) return 'rain';
    if (v.contains('rain') || v.contains('shower')) return 'rain';
    if (v.contains('fog') || v.contains('mist')) return 'foggy';
    if (v.contains('haze')) return 'hazy';
    if (v.contains('overcast')) return 'cloudy';
    if (v.contains('partly cloudy') || v.contains('partly')) return 'partly_cloudy';
    if (v.contains('sunny') || v.contains('fine') || v.contains('fair')) return 'sunny';
    if (v.contains('no rain')) return 'partly_cloudy';
    return 'cloudy';
  }

  String _alertFromSigw(String value, String when) {
    final v = value.toLowerCase();
    if (v.contains('thunder')) {
      return when.isNotEmpty
          ? 'Yellow Alert — Thunderstorms ($when)'
          : 'Yellow Alert — Thunderstorms';
    }
    if (v.contains('heavy rain')) return 'Yellow Alert — Heavy Rain';
    if (v.contains('haze')) return 'Orange Alert — Haze';
    if (v.contains('fog') || v.contains('mist')) return 'Yellow Alert — Low Visibility';
    return 'None';
  }
}

class _CachedForecast {
  final WeatherInfo weatherInfo;
  final DateTime fetchedAt;

  _CachedForecast(this.weatherInfo, this.fetchedAt);
}
