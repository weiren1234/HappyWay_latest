import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/destination_image_info.dart';

class DestinationImageService {
  static final DestinationImageService _instance = DestinationImageService._internal();
  factory DestinationImageService() => _instance;
  DestinationImageService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  final Map<String, DestinationImageInfo?> _memoryCache = {};
  final Map<String, Future<DestinationImageInfo?>> _inFlightRequests = {};

  static const Map<String, String> _verifiedLocalAssets = {
    'cameron highlands': 'assets/destinations/cameron_highlands.jpg',
    'cameron': 'assets/destinations/cameron_highlands.jpg',
    'location:314': 'assets/destinations/cameron_highlands.jpg',
    'dest_cameron': 'assets/destinations/cameron_highlands.jpg',

    'langkawi': 'assets/destinations/langkawi_island.jpg',
    'langkawi island': 'assets/destinations/langkawi_island.jpg',
    'pulau langkawi': 'assets/destinations/langkawi_island.jpg',
    'location:323': 'assets/destinations/langkawi_island.jpg',
    'dest_langkawi': 'assets/destinations/langkawi_island.jpg',

    'genting highlands': 'assets/destinations/genting_highlands.jpg',
    'genting': 'assets/destinations/genting_highlands.jpg',
    'location:317': 'assets/destinations/genting_highlands.jpg',
    'dest_genting': 'assets/destinations/genting_highlands.jpg',

    'kundasang': 'assets/destinations/kundasang.jpg',
    'kundasang & mt kinabalu': 'assets/destinations/kundasang.jpg',
    'mount kinabalu': 'assets/destinations/kundasang.jpg',
    'location:829': 'assets/destinations/kundasang.jpg',
    'dest_kundasang': 'assets/destinations/kundasang.jpg',

    'taman negara': 'assets/destinations/taman_negara.jpg',
    'taman negara rainforest': 'assets/destinations/taman_negara.jpg',
    'location:331': 'assets/destinations/taman_negara.jpg',
    'dest_taman_negara': 'assets/destinations/taman_negara.jpg',

    'melaka': 'assets/destinations/melaka_city.jpg',
    'melaka historic city': 'assets/destinations/melaka_city.jpg',
    'melaka city': 'assets/destinations/melaka_city.jpg',
    'bandar melaka': 'assets/destinations/melaka_city.jpg',
    'location:174': 'assets/destinations/melaka_city.jpg',
    'dest_melaka': 'assets/destinations/melaka_city.jpg',
  };

  static const Map<String, String> _curatedSearchAliases = {

    'pulau redang': 'Redang Island',
    'redang island': 'Redang Island',
    'redang': 'Redang Island',

    'pulau perhentian': 'Perhentian Islands',
    'perhentian islands': 'Perhentian Islands',
    'perhentian island': 'Perhentian Islands',
    'perhentian': 'Perhentian Islands',

    'pulau tioman': 'Tioman Island',
    'tioman island': 'Tioman Island',
    'tioman': 'Tioman Island',

    'pulau pangkor': 'Pangkor Island',
    'pangkor island': 'Pangkor Island',
    'pangkor': 'Pangkor Island',

    'pulau langkawi': 'Langkawi',
    'langkawi island': 'Langkawi',
    'langkawi': 'Langkawi',

    'pulau kapas': 'Kapas Island',
    'pulau rawa': 'Rawa Island',
    'pulau sipadan': 'Sipadan Island',
    'pulau mabul': 'Mabul Island',
    'pulau tenggol': 'Tenggol Island',
    'pulau besar': 'Pulau Besar Melaka',

    'batu ferringhi': 'Batu Ferringhi Penang',
    'desaru coast': 'Desaru Beach',
    'desaru': 'Desaru Beach',
    'cherating beach': 'Cherating',
    'cherating': 'Cherating',
    'port dickson': 'Port Dickson',
    'teluk cempedak': 'Teluk Cempedak Kuantan',

    'cameron highlands': 'Cameron Highlands',
    'genting highlands': 'Genting Highlands',
    'genting': 'Genting Highlands',
    'kundasang & mt kinabalu': 'Mount Kinabalu Sabah',
    'kundasang': 'Kundasang Mount Kinabalu',
    'mount kinabalu': 'Mount Kinabalu',
    'taman negara rainforest': 'Taman Negara National Park',
    'taman negara': 'Taman Negara National Park',
    'fraser\'s hill': 'Frasers Hill',
    'frasers hill': 'Frasers Hill',
    'tasik kenyir': 'Lake Kenyir',
    'bukit tinggi': 'Bukit Tinggi Pahang',

    'melaka historic city': 'Melaka City',
    'melaka city': 'Melaka City',
    'bandar melaka': 'Melaka City',
    'melaka': 'Melaka City',
    'george town': 'George Town Penang',
    'georgetown': 'George Town Penang',
    'kuala lumpur': 'Kuala Lumpur',
    'putrajaya': 'Putrajaya',
    'batu caves': 'Batu Caves',
    'taman danau kota': 'Danau Kota Lake Kuala Lumpur',
    'danau kota': 'Danau Kota Lake Kuala Lumpur',
    'taman tasik titiwangsa': 'Titiwangsa Lake Kuala Lumpur',
    'titiwangsa': 'Titiwangsa Lake Kuala Lumpur',
    'perdana botanical garden': 'Perdana Botanical Garden Kuala Lumpur',
    'lake gardens': 'Perdana Botanical Garden Kuala Lumpur',
    'kota kinabalu': 'Kota Kinabalu',
    'kuching': 'Kuching Sarawak',
    'ipoh': 'Ipoh Perak',
    'taiping': 'Taiping Perak',
  };

  static String normalizeSearchTerm(String name) {
    final clean = name.trim().toLowerCase();
    if (_curatedSearchAliases.containsKey(clean)) {
      return _curatedSearchAliases[clean]!;
    }

    if (clean.startsWith('pulau ') && name.trim().length > 6) {
      final islandName = name.trim().substring(6).trim();
      return '$islandName Island';
    }

    if (clean.startsWith('tasik ') && name.trim().length > 6) {
      final lakeName = name.trim().substring(6).trim();
      return 'Lake $lakeName';
    }
    return name.trim();
  }

  static List<String> buildFallbackQueries({
    required String name,
    String? state,
    bool isCurated = false,
  }) {
    final normalized = normalizeSearchTerm(name);
    final cleanState = (state ?? '').trim();
    final queries = <String>[];

    void addQuery(String q) {
      final trimmed = q.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (trimmed.isNotEmpty && !queries.contains(trimmed)) {
        queries.add(trimmed);
      }
    }

    if (cleanState.isNotEmpty && !normalized.toLowerCase().contains(cleanState.toLowerCase())) {
      addQuery('$normalized $cleanState Malaysia');
    }

    if (!normalized.toLowerCase().contains('malaysia')) {
      addQuery('$normalized Malaysia');
    }

    addQuery(normalized);

    if (isCurated && cleanState.isNotEmpty && !cleanState.toLowerCase().contains('malaysia')) {
      addQuery('$cleanState Malaysia');
    }

    return queries;
  }

  static bool isCuratedLocation(String name, String? locationId) {
    final cleanName = name.trim().toLowerCase();
    final cleanId = (locationId ?? '').trim().toLowerCase();
    if (_curatedSearchAliases.containsKey(cleanName) || _verifiedLocalAssets.containsKey(cleanName)) {
      return true;
    }
    if (_verifiedLocalAssets.containsKey(cleanId) || cleanId.startsWith('dest_')) {
      return true;
    }
    return false;
  }

  static String _cacheKey({String? locationId, required String name, String? state}) {
    final sanitizedName = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final sanitizedState = (state ?? '').trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return 'img_${sanitizedName}_$sanitizedState';
  }

  Future<DestinationImageInfo?> resolveImage({
    required String name,
    String? state,
    String? locationId,
    String? explicitImageUrl,
  }) async {

    if (explicitImageUrl != null && explicitImageUrl.startsWith('assets/')) {
      return DestinationImageInfo(
        imageUrl: explicitImageUrl,
        cachedAt: DateTime.now(),
        isLocalAsset: true,
        isVerified: true,
      );
    }

    final keyName = name.trim().toLowerCase();
    final keyId = (locationId ?? '').trim().toLowerCase();
    if (_verifiedLocalAssets.containsKey(keyName)) {
      final asset = _verifiedLocalAssets[keyName]!;
      return DestinationImageInfo(
        imageUrl: asset,
        cachedAt: DateTime.now(),
        isLocalAsset: true,
        isVerified: true,
      );
    }
    if (_verifiedLocalAssets.containsKey(keyId)) {
      final asset = _verifiedLocalAssets[keyId]!;
      return DestinationImageInfo(
        imageUrl: asset,
        cachedAt: DateTime.now(),
        isLocalAsset: true,
        isVerified: true,
      );
    }

    final key = _cacheKey(locationId: locationId, name: name, state: state);

    if (_memoryCache.containsKey(key)) {
      final mem = _memoryCache[key];
      if (mem != null && mem.isValid()) {
        return mem;
      }
    }

    if (_inFlightRequests.containsKey(key)) {
      return await _inFlightRequests[key]!;
    }

    final future = _fetchAndCache(
      key: key,
      name: name,
      state: state,
      locationId: locationId,
    );
    _inFlightRequests[key] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  Future<DestinationImageInfo?> _fetchAndCache({
    required String key,
    required String name,
    String? state,
    String? locationId,
  }) async {

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('dest_img_v1_$key');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final info = DestinationImageInfo.fromJson(data);
        if (info.isValid()) {
          _memoryCache[key] = info;
          return info;
        }
      }
    } catch (_) {}

    final apiKey = await AppConfig.getPexelsApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[DestinationImageService] Diagnostic: Pexels API key is not configured. Falling back to neutral placeholder for "$name".');
      return null;
    }

    final isCurated = isCuratedLocation(name, locationId);
    final fallbackQueries = buildFallbackQueries(
      name: name,
      state: state,
      isCurated: isCurated,
    );

    debugPrint('[DestinationImageService] ────────────────────────────────────────────────────────');
    debugPrint('[DestinationImageService] Resolving image for: "$name"');
    debugPrint('[DestinationImageService]   Location ID: ${locationId ?? 'none'} | State: ${state ?? 'none'} | Curated: $isCurated');
    debugPrint('[DestinationImageService]   Fallback Query Cascade (${fallbackQueries.length}): $fallbackQueries');

    for (int i = 0; i < fallbackQueries.length; i++) {
      final query = fallbackQueries[i];

      try {
        debugPrint('[DestinationImageService]   Step ${i + 1}/${fallbackQueries.length} Querying Pexels: "$query"');
        final response = await _dio.get(
          'https://api.pexels.com/v1/search',
          queryParameters: {
            'query': query,
            'orientation': 'landscape',
            'per_page': 5,
          },
          options: Options(
            headers: {
              'Authorization': apiKey,
            },
          ),
        );

        final statusCode = response.statusCode ?? 0;
        final photos = response.data is Map ? (response.data['photos'] as List<dynamic>?) : null;
        final count = photos?.length ?? 0;

        debugPrint('[DestinationImageService]   Step ${i + 1} Response: HTTP $statusCode | Results Count: $count');

        if (statusCode == 200 && photos != null && photos.isNotEmpty) {
          final first = photos.first as Map<String, dynamic>;
          final src = first['src'] as Map<String, dynamic>?;
          final largeUrl = src?['large'] as String? ??
              src?['landscape'] as String? ??
              src?['medium'] as String?;

          if (largeUrl != null && largeUrl.isNotEmpty) {
            final info = DestinationImageInfo(
              imageUrl: largeUrl,
              photographer: first['photographer'] as String?,
              photographerUrl: first['photographer_url'] as String?,
              pexelsUrl: first['url'] as String?,
              altText: first['alt'] as String?,
              cachedAt: DateTime.now(),
              isLocalAsset: false,
              isVerified: false,
            );

            debugPrint('[DestinationImageService]   ✓ Image resolved successfully on step ${i + 1} ("$query")');
            debugPrint('[DestinationImageService]     URL: ${info.imageUrl}');
            debugPrint('[DestinationImageService]     Photographer: ${info.photographer}');
            debugPrint('[DestinationImageService] ────────────────────────────────────────────────────────');

            _memoryCache[key] = info;
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('dest_img_v1_$key', jsonEncode(info.toJson()));
            } catch (_) {}

            return info;
          }
        }
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) {
          debugPrint('[DestinationImageService]   ⚠ Pexels API Rate Limited (HTTP 429). Halting query cascade.');
          debugPrint('[DestinationImageService] ────────────────────────────────────────────────────────');
          _memoryCache[key] = null;
          return null;
        } else {
          debugPrint('[DestinationImageService]   ✗ Pexels query "$query" failed (HTTP $statusCode): ${e.message}');
        }
      } catch (e) {
        debugPrint('[DestinationImageService]   ✗ Unexpected error querying "$query": $e');
      }
    }

    debugPrint('[DestinationImageService]   ✗ All ${fallbackQueries.length} fallback queries returned zero results for "$name".');
    debugPrint('[DestinationImageService]   Reason: No suitable photos found on Pexels.');
    debugPrint('[DestinationImageService]   Result: Displaying clean neutral placeholder (no wrong images).');
    debugPrint('[DestinationImageService] ────────────────────────────────────────────────────────');

    _memoryCache[key] = null;
    return null;
  }

  Future<void> clearCache() async {
    _memoryCache.clear();
    _inFlightRequests.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('dest_img_v1_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
