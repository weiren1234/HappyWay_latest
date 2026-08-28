import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/travel_route.dart';

/// Categories of route calculation failure.
enum RouteFailureReason {
  /// Invalid or missing coordinates (0.0, NaN, or out of range).
  invalidCoordinates,

  /// OSRM returned NoRoute, NoSegment, or destination is not road-accessible.
  noDirectRoute,

  /// Network error, timeout, DNS resolution failure, or server unreachable.
  networkError,

  /// OSRM server error (HTTP 5xx).
  serverError,
}

/// Detailed result of a route calculation.
class RouteCalculationResult {
  final TravelRoute? route;
  final RouteFailureReason? failureReason;
  final String? errorMessage;
  final int? httpStatusCode;
  final String? osrmCode;

  const RouteCalculationResult.success(TravelRoute this.route)
      : failureReason = null,
        errorMessage = null,
        httpStatusCode = 200,
        osrmCode = 'Ok';

  const RouteCalculationResult.failure({
    required this.failureReason,
    required this.errorMessage,
    this.httpStatusCode,
    this.osrmCode,
  }) : route = null;

  bool get isSuccess => route != null;
}

/// RouteService queries the Open Source Routing Machine (OSRM) driving API
/// to calculate real road distance and estimated driving duration.
///
/// NOTE: The duration returned represents normal estimated driving duration,
/// NOT live traffic data.
class RouteService {
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      validateStatus: (status) => status != null && status < 500, // Handle 2xx, 3xx, 4xx without throwing
      headers: {
        'User-Agent': 'HappyWay-App/1.0 (Malaysia Travel Planning)',
        'Accept': 'application/json',
      },
    ),
  );

  static const String _cachePrefix = 'happyway_osrm_route_v1_';
  static const Duration _cacheTtl = Duration(hours: 1);

  final Map<String, (TravelRoute, DateTime)> _memoryCache = {};

  RouteService._internal();

  /// Calculates driving route distance and duration between origin and destination.
  /// Returns a detailed [RouteCalculationResult] with typed failure reasons and messages.
  Future<RouteCalculationResult> calculateRouteDetails({
    required String originName,
    required double originLat,
    required double originLng,
    required String destName,
    required double destLat,
    required double destLng,
    bool forceRefresh = false,
  }) async {
    // 1. Validate coordinates
    if (originLat == 0.0 ||
        originLng == 0.0 ||
        destLat == 0.0 ||
        destLng == 0.0 ||
        originLat.isNaN ||
        originLng.isNaN ||
        destLat.isNaN ||
        destLng.isNaN) {
      debugPrint('[RouteService] Invalid coordinates: origin=($originLat, $originLng), dest=($destLat, $destLng)');
      return const RouteCalculationResult.failure(
        failureReason: RouteFailureReason.invalidCoordinates,
        errorMessage: 'Route unavailable — destination coordinates missing.',
      );
    }

    final cacheKey = _generateCacheKey(originLat, originLng, destLat, destLng);

    // 2. In-memory cache check
    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final (cachedRoute, timestamp) = _memoryCache[cacheKey]!;
      if (DateTime.now().difference(timestamp) < _cacheTtl) {
        debugPrint('[RouteService] Cache HIT (Memory): ${cachedRoute.originName} -> ${cachedRoute.destinationName} (${cachedRoute.distanceFormatted})');
        return RouteCalculationResult.success(cachedRoute);
      }
    }

    // 3. SharedPreferences cache check
    if (!forceRefresh) {
      final diskRoute = await _readDiskCache(cacheKey);
      if (diskRoute != null) {
        _memoryCache[cacheKey] = (diskRoute, diskRoute.fetchedAt);
        debugPrint('[RouteService] Cache HIT (Disk): ${diskRoute.originName} -> ${diskRoute.destinationName} (${diskRoute.distanceFormatted})');
        return RouteCalculationResult.success(diskRoute);
      }
    }

    // 4. Live OSRM REST Request
    // OSRM requires: /route/v1/driving/{longitude},{latitude};{longitude},{latitude}?overview=false
    final url =
        'https://router.project-osrm.org/route/v1/driving/$originLng,$originLat;$destLng,$destLat?overview=false';

    debugPrint('[RouteService] ════════════════════════════════════════════════════');
    debugPrint('[RouteService] OSRM Route Request:');
    debugPrint('[RouteService]   Origin Name: $originName');
    debugPrint('[RouteService]   Origin Lat: $originLat');
    debugPrint('[RouteService]   Origin Lng: $originLng');
    debugPrint('[RouteService]   Destination Name: $destName');
    debugPrint('[RouteService]   Destination Lat: $destLat');
    debugPrint('[RouteService]   Destination Lng: $destLng');
    debugPrint('[RouteService]   Final OSRM URL: $url');

    try {
      final response = await _dio.get(url);
      final statusCode = response.statusCode ?? 0;

      Map<String, dynamic> data;
      if (response.data is Map<String, dynamic>) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String && (response.data as String).isNotEmpty) {
        try {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
        } catch (_) {
          data = {'code': 'InvalidJson'};
        }
      } else {
        data = {'code': 'EmptyResponse'};
      }

      final osrmCode = data['code'] as String? ?? 'Unknown';

      debugPrint('[RouteService] OSRM Response:');
      debugPrint('[RouteService]   HTTP Status Code: $statusCode');
      debugPrint('[RouteService]   OSRM Code: $osrmCode');
      debugPrint('[RouteService]   Response Summary: ${data.containsKey('message') ? data['message'] : (data.containsKey('routes') ? 'Found ${(data['routes'] as List).length} route(s)' : data)}');
      debugPrint('[RouteService] ════════════════════════════════════════════════════');

      if (statusCode == 200 && osrmCode == 'Ok') {
        final routesList = data['routes'] as List<dynamic>?;
        if (routesList != null && routesList.isNotEmpty) {
          final route = TravelRoute.fromOsrmJson(
            json: data,
            originName: originName,
            originLat: originLat,
            originLng: originLng,
            destName: destName,
            destLat: destLat,
            destLng: destLng,
          );

          debugPrint('[RouteService] Route calculated successfully: ${route.distanceFormatted}, ${route.durationFormatted}');

          // Save to memory and disk cache
          _memoryCache[cacheKey] = (route, DateTime.now());
          await _writeDiskCache(cacheKey, route);

          return RouteCalculationResult.success(route);
        }
      }

      // Handle specific OSRM NoRoute / NoSegment responses
      if (osrmCode == 'NoRoute' || osrmCode == 'NoSegment') {
        return RouteCalculationResult.failure(
          failureReason: RouteFailureReason.noDirectRoute,
          errorMessage: 'Direct driving route unavailable.',
          httpStatusCode: statusCode,
          osrmCode: osrmCode,
        );
      }

      if (statusCode >= 500) {
        return RouteCalculationResult.failure(
          failureReason: RouteFailureReason.serverError,
          errorMessage: 'Unable to load route. Please try again.',
          httpStatusCode: statusCode,
          osrmCode: osrmCode,
        );
      }

      return RouteCalculationResult.failure(
        failureReason: RouteFailureReason.noDirectRoute,
        errorMessage: 'Direct driving route unavailable.',
        httpStatusCode: statusCode,
        osrmCode: osrmCode,
      );
    } on DioException catch (e) {
      debugPrint('[RouteService] OSRM DioException: ${e.type} - ${e.message}');
      return const RouteCalculationResult.failure(
        failureReason: RouteFailureReason.networkError,
        errorMessage: 'Unable to load route. Please try again.',
      );
    } catch (e) {
      debugPrint('[RouteService] OSRM unexpected error: $e');
      return const RouteCalculationResult.failure(
        failureReason: RouteFailureReason.networkError,
        errorMessage: 'Unable to load route. Please try again.',
      );
    }
  }

  /// Calculates driving route distance and duration between origin and destination.
  /// Returns `null` if the route calculation fails (no fake fallback data).
  Future<TravelRoute?> calculateDrivingRoute({
    required String originName,
    required double originLat,
    required double originLng,
    required String destName,
    required double destLat,
    required double destLng,
    bool forceRefresh = false,
  }) async {
    final result = await calculateRouteDetails(
      originName: originName,
      originLat: originLat,
      originLng: originLng,
      destName: destName,
      destLat: destLat,
      destLng: destLng,
      forceRefresh: forceRefresh,
    );
    return result.route;
  }

  String _generateCacheKey(double lat1, double lng1, double lat2, double lng2) {
    return '$_cachePrefix${lat1.toStringAsFixed(3)}_${lng1.toStringAsFixed(3)}_${lat2.toStringAsFixed(3)}_${lng2.toStringAsFixed(3)}';
  }

  Future<TravelRoute?> _readDiskCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final route = TravelRoute.fromJson(json);
        if (DateTime.now().difference(route.fetchedAt) < _cacheTtl) {
          return route;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeDiskCache(String key, TravelRoute route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(route.toJson()));
    } catch (_) {}
  }
}
