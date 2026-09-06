import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'place_search_service.dart';

class NominatimPlaceSearchService implements PlaceSearchService {
  static final NominatimPlaceSearchService _instance =
      NominatimPlaceSearchService._internal();
  factory NominatimPlaceSearchService() => _instance;
  NominatimPlaceSearchService._internal();

  static DateTime? _lastRequestTime;
  static final Map<String, List<PlaceSearchResult>> _cache = {};

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://nominatim.openstreetmap.org',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'HappyWayApp/1.0',
        'Accept': 'application/json',
      },
    ),
  );

  @override
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final cacheKey = cleanQuery.toLowerCase();
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      const minInterval = Duration(milliseconds: 1000);
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();

    try {
      final response = await _dio.get(
        '/search',
        queryParameters: {
          'q': cleanQuery,
          'countrycodes': 'my',
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '8',
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List;
        final results = <PlaceSearchResult>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            try {
              results.add(PlaceSearchResult.fromNominatimJson(item));
            } catch (e) {
              debugPrint('[NominatimPlaceSearchService] Parsing item error: $e');
            }
          }
        }
        _cache[cacheKey] = results;
        return results;
      }
      return [];
    } catch (e) {
      debugPrint('[NominatimPlaceSearchService] Search failed: $e');
      return [];
    }
  }

  static void clearCache() {
    _cache.clear();
  }
}
