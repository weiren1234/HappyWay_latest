import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/weather_info.dart';
import 'api_client.dart';

class WeatherService {
  static const Duration _cacheTtl = Duration(hours: 1);
  static final Map<String, _CachedForecast> _memoryCache = {};

  static final Dio _openMeteoDio = Dio(
    BaseOptions(
      baseUrl: 'https://api.open-meteo.com/v1/',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

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
    'kuala lumpur': 'LOCATION:237',
    'kl': 'LOCATION:237',
  };

  static const Map<String, (double, double)> _locationCoords = {
    'LOCATION:317': (3.424, 101.794),
    'LOCATION:314': (4.471, 101.380),
    'LOCATION:323': (6.350, 99.800),
    'LOCATION:331': (4.383, 102.400),
    'LOCATION:829': (5.980, 116.580),
    'LOCATION:316': (1.560, 104.267),
    'LOCATION:310': (5.474, 100.250),
    'LOCATION:326': (5.770, 103.007),
    'LOCATION:324': (4.222, 100.558),
    'LOCATION:329': (2.815, 104.162),
    'LOCATION:325': (5.908, 102.738),
    'LOCATION:186': (2.522, 101.795),
    'LOCATION:313': (3.712, 101.741),
    'LOCATION:174': (2.189, 102.250),
    'LOCATION:337': (5.000, 102.800),
    'LOCATION:315': (4.125, 103.392),
    'LOCATION:237': (3.139, 101.686),
    'LOCATION:241': (3.073, 101.518),
    'LOCATION:244': (2.926, 101.696),
    'LOCATION:240': (2.993, 101.790),
    'LOCATION:242': (3.125, 101.593),
    'LOCATION:239': (3.308, 101.272),
    'LOCATION:243': (2.813, 101.696),
    'LOCATION:238': (3.044, 101.445),
    'LOCATION:245': (3.033, 101.717),
    'LOCATION:334': (3.195, 101.710),
  };

  Future<WeatherInfo?> fetchWeatherForLocation(
    String locationName,
    String state, {
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final locationId = _resolveLocationId(locationName);
    if (latitude != null && longitude != null) {
      return fetchWeatherForCoordinates(
        latitude: latitude,
        longitude: longitude,
        locationId: locationId,
        forceRefresh: forceRefresh,
      );
    }
    if (locationId != null) {
      return fetchWeatherForLocationId(locationId, forceRefresh: forceRefresh);
    }
    return null;
  }

  Future<WeatherInfo?> fetchWeatherForLocationId(
    String locationId, {
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    if (locationId.isEmpty && (latitude == null || longitude == null)) return null;

    final targetLat = latitude ?? _locationCoords[locationId]?.$1;
    final targetLng = longitude ?? _locationCoords[locationId]?.$2;

    if (targetLat != null && targetLng != null) {
      return fetchWeatherForCoordinates(
        latitude: targetLat,
        longitude: targetLng,
        locationId: locationId,
        forceRefresh: forceRefresh,
      );
    }

    return _fetchMetForecastDirect(locationId, DateTime.now(), forceRefresh: forceRefresh);
  }

  Future<WeatherInfo?> fetchWeatherForLocationAndDate(
    String locationId,
    DateTime targetDate, {
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    final targetLat = latitude ?? _locationCoords[locationId]?.$1;
    final targetLng = longitude ?? _locationCoords[locationId]?.$2;

    if (targetLat != null && targetLng != null) {
      return fetchWeatherForCoordinates(
        latitude: targetLat,
        longitude: targetLng,
        targetDate: targetDate,
        locationId: locationId,
        forceRefresh: forceRefresh,
      );
    }

    return _fetchMetForecastDirect(locationId, targetDate, forceRefresh: forceRefresh);
  }

  Future<WeatherInfo?> fetchWeatherForCoordinates({
    required double latitude,
    required double longitude,
    DateTime? targetDate,
    String? locationId,
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final date = targetDate ?? now;
    final dateStr = _dateString(date);
    final nextDateStr = _dateString(date.add(const Duration(days: 1)));
    final cacheKey = 'coord_${latitude.toStringAsFixed(3)}_${longitude.toStringAsFixed(3)}_${dateStr}_2d';

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.fetchedAt) < _cacheTtl) {
        return cached.weatherInfo;
      }
    }

    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('om_fc_$cacheKey');
        final ts = prefs.getInt('om_fc_ts_$cacheKey');
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

    try {
      dynamic responseData;
      try {
        final response = await _openMeteoDio.get(
          'forecast',
          queryParameters: {
            'latitude': latitude,
            'longitude': longitude,
            'hourly': 'temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,apparent_temperature,wind_speed_10m,uv_index,visibility',
            'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max',
            'timezone': 'Asia/Kuala_Lumpur',
            'start_date': dateStr,
            'end_date': nextDateStr,
          },
        );
        if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
          responseData = response.data;
        }
      } catch (_) {

        final fallbackResp = await _openMeteoDio.get(
          'forecast',
          queryParameters: {
            'latitude': latitude,
            'longitude': longitude,
            'hourly': 'temperature_2m,relative_humidity_2m,precipitation_probability,weather_code,apparent_temperature,wind_speed_10m,uv_index,visibility',
            'daily': 'weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max',
            'timezone': 'Asia/Kuala_Lumpur',
            'start_date': dateStr,
            'end_date': dateStr,
          },
        );
        if (fallbackResp.statusCode == 200 && fallbackResp.data is Map<String, dynamic>) {
          responseData = fallbackResp.data;
        }
      }

      if (responseData is Map<String, dynamic>) {
        final weatherInfo = _parseOpenMeteoResponse(responseData, date);

        _memoryCache[cacheKey] = _CachedForecast(weatherInfo, now);
        _persistToCache(cacheKey, weatherInfo, now);
        return weatherInfo;
      }
    } catch (_) {

      if (locationId != null && locationId.isNotEmpty) {
        return _fetchMetForecastDirect(locationId, date, forceRefresh: forceRefresh);
      }
    }

    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey]!.weatherInfo;
    }
    return null;
  }

  WeatherInfo _parseOpenMeteoResponse(Map<String, dynamic> data, DateTime targetDate) {
    final hourly = data['hourly'] as Map<String, dynamic>? ?? {};
    final daily = data['daily'] as Map<String, dynamic>? ?? {};

    final times = (hourly['time'] as List<dynamic>? ?? []).cast<String>();
    final temps = (hourly['temperature_2m'] as List<dynamic>? ?? []).cast<num>();
    final humids = (hourly['relative_humidity_2m'] as List<dynamic>? ?? []).cast<num>();
    final precips = (hourly['precipitation_probability'] as List<dynamic>? ?? []).cast<num>();
    final codes = (hourly['weather_code'] as List<dynamic>? ?? []).cast<num>();
    final feels = (hourly['apparent_temperature'] as List<dynamic>? ?? []).cast<num>();
    final winds = (hourly['wind_speed_10m'] as List<dynamic>? ?? []).cast<num>();
    final uvs = (hourly['uv_index'] as List<dynamic>? ?? []).cast<num>();
    final visibilities = (hourly['visibility'] as List<dynamic>? ?? []).cast<num>();

    final now = DateTime.now();
    final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;

    final items = <HourlyWeatherItem>[];

    for (int i = 0; i < times.length; i++) {
      final dt = DateTime.tryParse(times[i]);
      if (dt == null) continue;

      final temp = i < temps.length ? temps[i].toDouble() : 28.0;
      final humid = i < humids.length ? humids[i].toInt() : null;
      final precip = i < precips.length ? precips[i].toInt() : null;
      final wCode = i < codes.length ? codes[i].toInt() : 0;
      final feel = i < feels.length ? feels[i].toDouble() : null;
      final wind = i < winds.length ? winds[i].toDouble() : null;
      final uv = i < uvs.length ? uvs[i].toDouble() : null;
      final vis = i < visibilities.length ? visibilities[i].toDouble() : null;

      final isCurrentHour = isToday && dt.day == now.day && dt.hour == now.hour;
      final timeLabel = isCurrentHour
          ? 'Now'
          : DateFormat('h a').format(dt).replaceAll(' ', '');

      items.add(HourlyWeatherItem(
        time: dt,
        timeLabel: timeLabel,
        temperature: temp,
        condition: _conditionFromWmo(wCode),
        iconCode: _iconFromWmo(wCode),
        precipitationProbability: precip,
        humidity: humid,
        weatherCode: wCode,
        apparentTemperature: feel,
        uvIndex: uv,
        visibility: vis,
        windSpeed: wind,
      ));
    }

    final maxT = (daily['temperature_2m_max'] as List<dynamic>?)?.firstOrNull as num?;
    final minT = (daily['temperature_2m_min'] as List<dynamic>?)?.firstOrNull as num?;
    final uv = (daily['uv_index_max'] as List<dynamic>?)?.firstOrNull as num?;

    String? sunriseFormatted;
    String? sunsetFormatted;

    final sunriseList = (daily['sunrise'] as List<dynamic>?)?.cast<String>();
    if (sunriseList != null && sunriseList.isNotEmpty) {
      final sDt = DateTime.tryParse(sunriseList.first);
      if (sDt != null) {
        sunriseFormatted = DateFormat('hh:mm a').format(sDt);
        items.add(HourlyWeatherItem(
          time: sDt,
          timeLabel: DateFormat('h:mm a').format(sDt).replaceAll(' ', ''),
          temperature: null,
          condition: 'Sunrise',
          iconCode: 'sunrise',
          isSunrise: true,
          specialLabel: 'Sunrise',
        ));
      }
    }

    final sunsetList = (daily['sunset'] as List<dynamic>?)?.cast<String>();
    if (sunsetList != null && sunsetList.isNotEmpty) {
      final sDt = DateTime.tryParse(sunsetList.first);
      if (sDt != null) {
        sunsetFormatted = DateFormat('hh:mm a').format(sDt);
        items.add(HourlyWeatherItem(
          time: sDt,
          timeLabel: DateFormat('h:mm a').format(sDt).replaceAll(' ', ''),
          temperature: null,
          condition: 'Sunset',
          iconCode: 'sunset',
          isSunset: true,
          specialLabel: 'Sunset',
        ));
      }
    }

    items.sort((a, b) => a.time.compareTo(b.time));

    final targetDayItems = items.where((i) =>
        i.time.year == targetDate.year &&
        i.time.month == targetDate.month &&
        i.time.day == targetDate.day &&
        !i.isSunset &&
        !i.isSunrise).toList();

    String? morningCond;
    String? afternoonCond;
    String? nightCond;

    for (final item in targetDayItems) {
      final h = item.time.hour;
      if (h >= 7 && h <= 11 && morningCond == null) morningCond = item.condition;
      if (h >= 12 && h <= 17 && afternoonCond == null) afternoonCond = item.condition;
      if (h >= 18 && h <= 23 && nightCond == null) nightCond = item.condition;
    }

    final dailyWCode = (daily['weather_code'] as List<dynamic>?)?.firstOrNull as num? ?? 0;
    final primaryCondition = _conditionFromWmo(dailyWCode.toInt());
    final primaryIcon = _iconFromWmo(dailyWCode.toInt());

    final targetFeels = targetDayItems.map((i) => i.apparentTemperature ?? i.temperature).whereType<double>().toList();
    final targetHumids = targetDayItems.map((i) => i.humidity).whereType<int>().toList();
    final targetPrecips = targetDayItems.map((i) => i.precipitationProbability).whereType<int>().toList();
    final targetWinds = targetDayItems.map((i) => i.windSpeed).whereType<double>().toList();

    final avgFeels = targetFeels.isNotEmpty
        ? (isToday && now.hour < targetFeels.length ? targetFeels[now.hour] : targetFeels.reduce((a, b) => a + b) / targetFeels.length)
        : null;
    final avgHumidity = targetHumids.isNotEmpty
        ? (isToday && now.hour < targetHumids.length ? targetHumids[now.hour] : (targetHumids.reduce((a, b) => a + b) / targetHumids.length).round())
        : null;
    final maxPrecip = targetPrecips.isNotEmpty ? targetPrecips.reduce((a, b) => a > b ? a : b) : null;
    final maxWind = targetWinds.isNotEmpty ? targetWinds.reduce((a, b) => a > b ? a : b) : null;

    return WeatherInfo(
      maxTemperature: maxT?.toDouble(),
      minTemperature: minT?.toDouble(),
      condition: primaryCondition,
      iconCode: primaryIcon,
      alertLevel: 'None',
      morningCondition: morningCond ?? primaryCondition,
      afternoonCondition: afternoonCond ?? primaryCondition,
      nightCondition: nightCond ?? primaryCondition,
      hourlyForecast: items,
      sunriseTime: sunriseFormatted,
      sunsetTime: sunsetFormatted,
      uvIndex: uv?.toDouble(),
      precipitationProbability: maxPrecip,
      humidity: avgHumidity,
      feelsLike: avgFeels,
      windSpeed: maxWind,
    );
  }

  static String _conditionFromWmo(int code) {
    switch (code) {
      case 0: return 'Sunny';
      case 1: return 'Mainly Clear';
      case 2: return 'Partly Cloudy';
      case 3: return 'Cloudy';
      case 45:
      case 48: return 'Foggy';
      case 51:
      case 53:
      case 55: return 'Drizzle';
      case 61:
      case 63: return 'Rain';
      case 65: return 'Heavy Rain';
      case 80:
      case 81: return 'Rain Showers';
      case 82: return 'Heavy Rain Showers';
      case 95: return 'Thunderstorms';
      case 96:
      case 99: return 'Severe Thunderstorms';
      default: return 'Partly Cloudy';
    }
  }

  static String _iconFromWmo(int code) {
    switch (code) {
      case 0: return 'sunny';
      case 1:
      case 2: return 'partly_cloudy';
      case 3: return 'cloudy';
      case 45:
      case 48: return 'foggy';
      case 51:
      case 53:
      case 55: return 'drizzle';
      case 61:
      case 63: return 'rain';
      case 65: return 'heavy_rain';
      case 80:
      case 81: return 'showers';
      case 82: return 'heavy_showers';
      case 95: return 'thunderstorm';
      case 96:
      case 99: return 'severe_thunderstorm';
      default: return 'cloudy';
    }
  }

  Future<WeatherInfo?> _fetchMetForecastDirect(String locationId, DateTime targetDate, {bool forceRefresh = false}) async {
    final now = DateTime.now();
    final dateStr = _dateString(targetDate);
    final cacheKey = '${locationId}_$dateStr';

    try {
      final token = await AppConfig.getMetToken();
      if (token == null || token.isEmpty) return null;

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
      if (results.isEmpty) return null;

      final targetResults = results
          .cast<Map<String, dynamic>>()
          .where((r) => (r['date'] as String? ?? '').startsWith(dateStr))
          .toList();

      if (targetResults.isEmpty) return null;

      final weatherInfo = _parseMetResults(targetResults);
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

  WeatherInfo _parseMetResults(List<Map<String, dynamic>> results) {
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
          if (value is String) morningCond = _humaniseCondition(value);
          break;
        case 'FGA':
          if (value is String) afternoonCond = _humaniseCondition(value);
          break;
        case 'FGN':
          if (value is String) nightCond = _humaniseCondition(value);
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

  static Future<void> _persistToCache(String key, WeatherInfo info, DateTime fetchedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('om_fc_$key', jsonEncode(info.toJson()));
      await prefs.setInt('om_fc_ts_$key', fetchedAt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  String _dateString(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String? _resolveLocationId(String locationName) {
    final name = locationName.toLowerCase();
    for (final entry in _locationIds.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return null;
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
    if (v.contains('severe') || v.contains('ribut petir teruk')) return 'severe_thunderstorm';
    if (v.contains('thunder') || v.contains('ribut petir')) return 'thunderstorm';
    if (v.contains('heavy rain') || v.contains('heavy shower') || v.contains('lebat')) return 'heavy_rain';
    if (v.contains('shower') || v.contains('sekejap')) return 'showers';
    if (v.contains('drizzle') || v.contains('gerimis') || v.contains('light rain')) return 'drizzle';
    if (v.contains('rain') || v.contains('hujan')) return 'rain';
    if (v.contains('fog') || v.contains('mist') || v.contains('kabut')) return 'foggy';
    if (v.contains('haze') || v.contains('jerebu')) return 'hazy';
    if (v.contains('overcast') || v.contains('mendung')) return 'cloudy';
    if (v.contains('partly cloudy') || v.contains('partly') || v.contains('sebahagian')) return 'partly_cloudy';
    if (v.contains('sunny') || v.contains('fine') || v.contains('fair') || v.contains('cerah')) return 'sunny';
    if (v.contains('no rain')) return 'partly_cloudy';
    return 'cloudy';
  }

  String _alertFromSigw(String value, String when) {
    final v = value.toLowerCase();
    if (v.contains('thunder')) {
      return when.isNotEmpty ? 'Thunderstorm Expected in $when' : 'Thunderstorms Expected';
    }
    if (v.contains('heavy rain')) {
      return when.isNotEmpty ? 'Heavy Rain Expected in $when' : 'Heavy Rain Expected';
    }
    if (v.contains('strong wind') || v.contains('angin kencang')) {
      return 'Strong Winds Advisory';
    }
    return 'Active Weather Advisory';
  }
}

class _CachedForecast {
  final WeatherInfo weatherInfo;
  final DateTime fetchedAt;

  _CachedForecast(this.weatherInfo, this.fetchedAt);
}
