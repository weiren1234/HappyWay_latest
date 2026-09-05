import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/met_location.dart';
import 'api_client.dart';

class MetLocationService {
  static const String _cacheKey = 'met_locations_cache_v1';
  static const String _cacheTimeKey = 'met_locations_cache_timestamp_v1';
  static const Duration _cacheTtl = Duration(days: 7);
  static const double _earthRadiusKm = 6371.0;

  static List<MetLocation>? _cachedLocations;

  static Future<List<MetLocation>> getLocations() async {
    if (_cachedLocations != null && _cachedLocations!.isNotEmpty) {
      return _cachedLocations!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cacheTimestamp = prefs.getInt(_cacheTimeKey);

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cachedJson) as List<dynamic>;
        _cachedLocations = list.map((item) => MetLocation.fromJson(item as Map<String, dynamic>)).toList();
        

        if (cacheTimestamp == null ||
            DateTime.now().millisecondsSinceEpoch - cacheTimestamp > _cacheTtl.inMilliseconds) {
          _refreshLocationsFromApiInBackground();
        }
        return _cachedLocations!;
      }
    } catch (_) {

    }

    try {
      final raw = await rootBundle.loadString('assets/data/met_locations.json');
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _cachedLocations = list.map((item) => MetLocation.fromJson(item as Map<String, dynamic>)).toList();
      

      _saveToCache(_cachedLocations!);
    } catch (_) {
      _cachedLocations = [];
    }

    return _cachedLocations ?? [];
  }

  static double calculateHaversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static Future<MetLocation?> findNearestWeatherLocation(
    double latitude,
    double longitude, {
    String? preferredState,
    double maxDistanceKm = 100.0,
  }) async {
    final all = await getLocations();

    final landLocations = all.where((loc) {
      if (loc.latitude == null || loc.longitude == null) return false;
      final cat = loc.locationCategoryId.toUpperCase();
      return cat == 'TOWN' || cat == 'TOURISTDEST' || cat == 'DISTRICT';
    }).toList();

    if (landLocations.isEmpty) return null;

    MetLocation? bestMatch;
    double lowestWeightedDistance = double.infinity;
    double bestActualDistance = double.infinity;

    final cleanPreferredState = preferredState?.trim().toLowerCase();

    for (final loc in landLocations) {
      final actualDistance = calculateHaversineDistanceKm(
        latitude,
        longitude,
        loc.latitude!,
        loc.longitude!,
      );

      if (actualDistance > maxDistanceKm) continue;

      double categoryMultiplier = 1.0;
      final cat = loc.locationCategoryId.toUpperCase();
      if (cat == 'TOURISTDEST' || cat == 'TOWN') {
        categoryMultiplier = 0.88;
      }

      double stateMultiplier = 1.0;
      if (cleanPreferredState != null &&
          cleanPreferredState.isNotEmpty &&
          loc.state.toLowerCase().contains(cleanPreferredState)) {
        stateMultiplier = 0.90;
      }

      final weightedDistance = actualDistance * categoryMultiplier * stateMultiplier;

      if (weightedDistance < lowestWeightedDistance) {
        lowestWeightedDistance = weightedDistance;
        bestActualDistance = actualDistance;
        bestMatch = loc;
      }
    }

    if (bestMatch != null && bestActualDistance <= maxDistanceKm) {
      return bestMatch;
    }

    return null;
  }

  static Future<List<MetLocation>> searchLocations(String query) async {
    final all = await getLocations();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;

    final startsWith = <MetLocation>[];
    final contains = <MetLocation>[];

    for (final loc in all) {
      final name = loc.name.toLowerCase();
      final formattedName = loc.formattedName.toLowerCase();
      final state = loc.state.toLowerCase();
      final cat = loc.categoryLabel.toLowerCase();

      if (name.startsWith(q) || formattedName.startsWith(q)) {
        startsWith.add(loc);
      } else if (name.contains(q) || formattedName.contains(q) || state.contains(q) || cat.contains(q)) {
        contains.add(loc);
      }
    }

    return [...startsWith, ...contains];
  }

  static Future<MetLocation?> getLocationById(String id) async {
    final all = await getLocations();
    for (final loc in all) {
      if (loc.id == id) return loc;
    }
    return null;
  }

  static Future<void> _saveToCache(List<MetLocation> locations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(locations.map((e) => e.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<void> _refreshLocationsFromApiInBackground() async {
    try {
      final token = await AppConfig.getMetToken();
      if (token == null || token.isEmpty) return;

      final dio = ApiClient.createMetDio(token);

      final states = <String, String>{};
      final stateRes = await dio.get('locations', queryParameters: {'locationcategoryid': 'STATE'});
      final stateResults = stateRes.data['results'] as List<dynamic>? ?? [];
      for (final s in stateResults) {
        final id = s['id'] as String?;
        final name = s['name'] as String?;
        if (id != null && name != null) {
          states[id] = name;
        }
      }

      final freshLocations = <MetLocation>[];
      final categories = ['TOURISTDEST', 'TOWN', 'DISTRICT'];

      for (final cat in categories) {
        int offset = 0;
        const int limit = 50;
        int total = 999;

        while (offset < total) {
          final res = await dio.get(
            'locations',
            queryParameters: {
              'locationcategoryid': cat,
              'limit': limit,
              'offset': offset,
            },
          );

          final metadata = res.data['metadata'] as Map<String, dynamic>?;
          final resultset = metadata?['resultset'] as Map<String, dynamic>?;
          total = resultset?['count'] as int? ?? 0;

          final results = res.data['results'] as List<dynamic>? ?? [];
          if (results.isEmpty) break;

          for (final r in results) {
            final rootId = r['locationrootid'] as String?;
            final stateName = rootId != null ? (states[rootId] ?? '') : '';
            freshLocations.add(MetLocation(
              id: r['id'] as String? ?? '',
              name: r['name'] as String? ?? '',
              locationCategoryId: r['locationcategoryid'] as String? ?? cat,
              locationRootId: rootId,
              state: stateName,
              latitude: (r['latitude'] as num?)?.toDouble(),
              longitude: (r['longitude'] as num?)?.toDouble(),
            ));
          }
          offset += limit;
        }
      }

      if (freshLocations.isNotEmpty) {
        _cachedLocations = freshLocations;
        await _saveToCache(freshLocations);
      }
    } catch (_) {

    }
  }
}
