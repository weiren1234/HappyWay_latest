import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../models/saved_location.dart';
import '../models/weather_info.dart';
import '../models/destination_recommendation.dart';
import '../models/user_location.dart';
import '../services/destination_data_service.dart';
import '../services/met_location_service.dart';
import '../services/weather_service.dart';
import '../services/recommendation_service.dart';
import '../services/saved_destination_service.dart';
import '../services/geocoding_service.dart';
import '../utils/travel_score_calculator.dart';
import '../utils/canonical_destination_id.dart';

/// DestinationProvider manages state for travel destinations:
/// - 16 Curated Featured Destinations with rich travel metadata & verified MET IDs
/// - Smart Destination Recommendations based on user activity preference & official MET Malaysia forecasts
/// - Searchable Catalogue of ~448 official MET Malaysia locations (TOURISTDEST, TOWN, DISTRICT)
/// - Geocoded Detailed Places with independent official MET weather location matching
/// - On-demand official MET weather forecasts (with rate-limiting protection & zero mock data)
/// - Cloud-persisted Saved Destinations via Supabase `saved_destinations` (RLS-backed)
/// - Local device cache for Recently Analysed locations & MET location catalogue
class DestinationProvider extends ChangeNotifier {
  static const String _recentAnalysedKey = 'happyway_recent_analysed_v1';

  final WeatherService _weatherService = WeatherService();
  final SavedDestinationService _savedDestinationService = SavedDestinationService();
  late final RecommendationService _recommendationService;

  List<TravelDestination> _featuredDestinations = [];
  List<MetLocation> _searchableLocations = [];
  List<MetLocation> _searchResults = [];
  List<SavedLocation> _savedLocations = [];
  List<MetLocation> _recentlyAnalysed = [];

  // Recommendations State
  String _selectedRecommendationTag = 'Nature';
  List<DestinationRecommendation> _recommendations = [];
  bool _isLoadingRecommendations = false;
  double _maxDistanceKm = 300; // default 300 km radius

  // Filter / Search State
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  bool _isLoadingSaved = false;
  String? _errorMessage;

  UserLocation? _currentUserOrigin;

  List<TravelDestination> get allDestinations => _featuredDestinations;
  List<TravelDestination> get featuredDestinations => _featuredDestinations;
  List<MetLocation> get searchableLocations => _searchableLocations;
  List<MetLocation> get searchResults => _searchResults;
  List<SavedLocation> get savedLocations => _savedLocations;
  List<MetLocation> get recentlyAnalysed => _recentlyAnalysed;

  String get selectedRecommendationTag => _selectedRecommendationTag;
  List<DestinationRecommendation> get recommendations => _recommendations;
  double get maxDistanceKm => _maxDistanceKm;
  UserLocation? get currentUserOrigin => _currentUserOrigin;
  
  /// All road-accessible recs strictly within targetDistance ± 50 km (or 0-100km if target is 50km),
  /// sorted strictly by road distance ascending. Shows all matching destinations without a 5-item cap.
  List<DestinationRecommendation> get roadAccessibleRecommendations {
    final roadRecs = _recommendations.where((r) => r.isRoadAccessible).toList();
    if (roadRecs.isEmpty) return [];

    // Strictly target distance ± 50 km window (or 0 to 100km if <= 50km)
    final double minKm = _maxDistanceKm <= 50 ? 0.0 : (_maxDistanceKm - 50.0).clamp(0.0, double.infinity);
    final double maxKm = _maxDistanceKm + 50.0;

    // Filter strictly within [target - 50, target + 50] km
    final matched = roadRecs.where((r) {
      final d = _getRoadDistanceKm(r);
      return d >= minKm && d <= maxKm;
    }).toList();

    // Sort all matching items strictly in ascending order of road distance
    matched.sort((a, b) {
      final distA = _getRoadDistanceKm(a);
      final distB = _getRoadDistanceKm(b);
      return distA.compareTo(distB);
    });

    return matched;
  }

  double _getRoadDistanceKm(DestinationRecommendation r) {
    if (r.route?.distanceKm != null) {
      return r.route!.distanceKm;
    }
    final originLat = _currentUserOrigin?.latitude ?? 3.1950;
    final originLng = _currentUserOrigin?.longitude ?? 101.7100;
    if (r.destination.latitude != null && r.destination.longitude != null) {
      final straightKm = _haversineKm(
        originLat, originLng,
        r.destination.latitude!, r.destination.longitude!,
      );
      return straightKm * 1.3;
    }
    return double.infinity;
  }

  /// Getaway recs (islands / cross-region) — top 4 by score, no distance filter.
  List<DestinationRecommendation> get getawayRecommendations =>
      _recommendations.where((r) => !r.isRoadAccessible).take(4).toList();

  bool get isLoadingRecommendations => _isLoadingRecommendations;

  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingSaved => _isLoadingSaved;
  String? get errorMessage => _errorMessage;

  List<String> get preferenceTags => DestinationDataService.preferenceCategories;

  List<String> get categories => [
        'All',
        'Highlands',
        'Island & Beach',
        'Beach',
        'Island',
        'Nature',
        'Sightseeing',
      ];

  DestinationProvider() {
    _recommendationService = RecommendationService(weatherService: _weatherService);
    loadDestinations();
    _loadLocationCatalogue();
    loadSavedLocations();
    _loadRecentlyAnalysed();
  }

  /// Updates the user's current origin to evaluate reachability in recommendations.
  void updateUserOrigin(UserLocation? origin) {
    if (_currentUserOrigin?.latitude == origin?.latitude &&
        _currentUserOrigin?.longitude == origin?.longitude &&
        _currentUserOrigin?.state == origin?.state) {
      return;
    }
    _currentUserOrigin = origin;
    _refreshRecommendations();
  }

  /// Updates the target distance for road-accessible recommendations and refreshes options.
  void setMaxDistanceKm(double km) {
    if (_maxDistanceKm == km) return;
    _maxDistanceKm = km;
    notifyListeners();
    _refreshRecommendations();
  }

  // Haversine for the provider-level distance filter fallback.
  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final a = sinDLat * sinDLat +
        math.cos(lat1 * math.pi / 180.0) *
        math.cos(lat2 * math.pi / 180.0) *
        sinDLng * sinDLng;
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Loads curated featured destinations and initialises smart recommendations.
  Future<void> loadDestinations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _featuredDestinations = DestinationDataService.getDestinations();

      _syncFeaturedSavedState();

      // Generate initial recommendations for default preference
      await _refreshRecommendations();
    } catch (e) {
      _errorMessage = 'Failed to load travel destinations. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Changes the user's active recommendation preference and updates recommended candidates.
  Future<void> setRecommendationPreference(String tag) async {
    if (_selectedRecommendationTag == tag && _recommendations.isNotEmpty) return;
    _selectedRecommendationTag = tag;
    _isLoadingRecommendations = true;
    notifyListeners();

    await _refreshRecommendations();

    _isLoadingRecommendations = false;
    notifyListeners();
  }

  /// Generates recommendations for the current preference tag (queries full nationwide candidate pool).
  Future<void> _refreshRecommendations() async {
    try {
      if (_searchableLocations.isEmpty) {
        _searchableLocations = await MetLocationService.getLocations();
      }

      // Build comprehensive candidate pool from curated destinations + all official MET locations
      final candidatePool = <TravelDestination>[..._featuredDestinations];
      final seenMetIds = _featuredDestinations.map((d) => d.metLocationId).toSet();
      final seenNames = _featuredDestinations.map((d) => d.name.toLowerCase()).toSet();

      for (final loc in _searchableLocations) {
        if (loc.latitude != null &&
            loc.longitude != null &&
            loc.latitude != 0.0 &&
            loc.longitude != 0.0) {
          final formattedLower = loc.formattedName.toLowerCase();
          if (!seenMetIds.contains(loc.id) && !seenNames.contains(formattedLower)) {
            candidatePool.add(TravelDestination.fromMetLocation(loc));
            seenMetIds.add(loc.id);
            seenNames.add(formattedLower);
          }
        }
      }

      final recs = await _recommendationService.getRecommendations(
        preference: _selectedRecommendationTag,
        allDestinations: candidatePool,
        userOrigin: _currentUserOrigin,
        targetDistanceKm: _maxDistanceKm,
      );
      _recommendations = recs;
      notifyListeners();

      // Update destination forecast in memory if retrieved
      for (final rec in recs) {
        if (rec.weather != null) {
          final idx = _featuredDestinations.indexWhere((d) => d.id == rec.destination.id);
          if (idx != -1) {
            _featuredDestinations[idx] = _featuredDestinations[idx].copyWith(
              weather: rec.weather,
              travelScore: TravelScoreCalculator.calculateScore(weather: rec.weather),
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Loads the official MET location catalogue for searching (~448 locations).
  Future<void> _loadLocationCatalogue() async {
    try {
      _searchableLocations = await MetLocationService.getLocations();
      _searchResults = _searchableLocations;
      notifyListeners();
    } catch (_) {}
  }

  /// Searches across the official MET location catalogue (~448 locations)
  /// with case-insensitivity and prefix-first ranking.
  Future<void> searchLocations(String query) async {
    _searchQuery = query;
    if (_searchableLocations.isEmpty) {
      _searchableLocations = await MetLocationService.getLocations();
    }

    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _searchResults = _searchableLocations;
      notifyListeners();
      return;
    }

    final exactMatches = <MetLocation>[];
    final prefixMatches = <MetLocation>[];
    final containsMatches = <MetLocation>[];

    for (final loc in _searchableLocations) {
      final name = loc.name.toLowerCase();
      final formattedName = loc.formattedName.toLowerCase();
      final state = loc.state.toLowerCase();
      final cat = loc.categoryLabel.toLowerCase();

      if (name == q || formattedName == q) {
        exactMatches.add(loc);
      } else if (name.startsWith(q) || formattedName.startsWith(q)) {
        prefixMatches.add(loc);
      } else if (name.contains(q) ||
          formattedName.contains(q) ||
          state.contains(q) ||
          cat.contains(q)) {
        containsMatches.add(loc);
      }
    }

    _searchResults = [...exactMatches, ...prefixMatches, ...containsMatches];
    notifyListeners();
  }

  /// Resolves user-entered places/addresses via device geocoder into [TravelLocation] items.
  Future<GeocodingResult> searchDetailedPlaces(String query) async {
    return await GeocodingService.searchPlaces(query);
  }

  /// Fetches official MET forecast on-demand for any valid [MetLocation].
  Future<WeatherInfo?> fetchForecastForMetLocation(MetLocation location, {bool forceRefresh = false}) async {
    try {
      final weather = await _weatherService.fetchWeatherForLocationId(
        location.id,
        forceRefresh: forceRefresh,
      );

      if (weather != null) {
        _addToRecentlyAnalysed(location);
      }

      return weather;
    } catch (_) {
      return null;
    }
  }

  /// Fetches official forecast on-demand for a [TravelLocation].
  Future<WeatherInfo?> fetchForecastForTravelLocation(TravelLocation location, {bool forceRefresh = false}) async {
    try {
      final weather = await _weatherService.fetchWeatherForLocationId(
        location.metLocationId ?? '',
        latitude: location.latitude != 0.0 ? location.latitude : null,
        longitude: location.longitude != 0.0 ? location.longitude : null,
        forceRefresh: forceRefresh,
      );

      if (weather != null && location.isMetLocation && location.metLocationId != null) {
        final metLoc = await MetLocationService.getLocationById(location.metLocationId!);
        if (metLoc != null) {
          _addToRecentlyAnalysed(metLoc);
        }
      }

      return weather;
    } catch (_) {
      return null;
    }
  }

  /// Fetches official forecast for a [TravelDestination] on-demand.
  Future<WeatherInfo?> fetchForecastForDestination(TravelDestination dest, {bool forceRefresh = false}) async {
    try {
      final weather = await _weatherService.fetchWeatherForLocationId(
        dest.metLocationId,
        latitude: dest.latitude,
        longitude: dest.longitude,
        forceRefresh: forceRefresh,
      );

      if (weather != null) {
        final idx = _featuredDestinations.indexWhere((d) => d.id == dest.id);
        if (idx != -1) {
          final updatedScore = TravelScoreCalculator.calculateScore(weather: weather);
          _featuredDestinations[idx] = _featuredDestinations[idx].copyWith(
            weather: weather,
            travelScore: updatedScore,
          );
          notifyListeners();
        }
        final recIdx = _recommendations.indexWhere(
          (r) => CanonicalDestinationId.fromDestination(r.destination) == CanonicalDestinationId.fromDestination(dest),
        );
        if (recIdx != -1) {
          final currentRec = _recommendations[recIdx];
          _recommendations[recIdx] = currentRec.copyWith(
            destination: currentRec.destination.copyWith(weather: weather),
            weather: weather,
          );
          notifyListeners();
        }
      }

      return weather;
    } catch (_) {
      return null;
    }
  }

  /// Returns filtered list of featured destinations based on search query and category chip.
  List<TravelDestination> get filteredDestinations {
    return _featuredDestinations.where((dest) {
      final matchesSearch = _searchQuery.isEmpty ||
          dest.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          dest.state.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          dest.activityTags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesCategory = _selectedCategory == 'All' ||
          dest.category == _selectedCategory ||
          dest.activityTags.contains(_selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ─── Cloud-Backed Saved Locations (Supabase `saved_destinations`) ─────────

  bool isLocationSaved(String id) {
    final target = CanonicalDestinationId.fromString(id);
    return _savedLocations.any((s) => CanonicalDestinationId.fromSavedLocation(s) == target);
  }

  bool isDestinationSaved(TravelDestination dest) {
    final target = CanonicalDestinationId.fromDestination(dest);
    return _savedLocations.any((s) => CanonicalDestinationId.fromSavedLocation(s) == target);
  }

  /// Loads saved destinations for the authenticated user from Supabase.
  Future<void> loadSavedLocations() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) {
      _savedLocations = [];
      _syncFeaturedSavedState();
      notifyListeners();
      return;
    }

    _isLoadingSaved = true;
    notifyListeners();

    try {
      _savedLocations = await _savedDestinationService.getSavedDestinations(currentUserId);
      _syncFeaturedSavedState();
    } catch (_) {
      _savedLocations = [];
    } finally {
      _isLoadingSaved = false;
      notifyListeners();
    }
  }

  /// Universal method to toggle saving any [TravelDestination] (curated or dynamic recommendation).
  ///
  /// Optimistically updates UI immediately. If Supabase persistence fails,
  /// automatically rolls back to the previous state and returns false.
  Future<bool> toggleSaveAnyDestination(TravelDestination destination) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final canonicalId = CanonicalDestinationId.fromDestination(destination);
    final wasSaved = isDestinationSaved(destination);
    final previousSavedLocations = List<SavedLocation>.from(_savedLocations);

    debugPrint('[SAVE DEBUG] toggleSaveAnyDestination: destination="${destination.name}" canonical="$canonicalId" wasSaved=$wasSaved');

    // 1. Build SavedLocation object BEFORE optimistic update so we can reference it later
    final SavedLocation? newSavedLoc = wasSaved ? null : SavedLocation.fromAnyDestination(destination);

    // 2. Optimistic update
    if (wasSaved) {
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
      debugPrint('[SAVE DEBUG] Optimistic remove: canonical="$canonicalId"');
    } else {
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
      _savedLocations.insert(0, newSavedLoc!);
      debugPrint('[SAVE DEBUG] Optimistic insert: location_id="${newSavedLoc.id}" name="${newSavedLoc.name}"');
    }
    _syncFeaturedSavedState();
    notifyListeners();

    // 3. Persist to Supabase
    try {
      if (wasSaved) {
        debugPrint('[SAVE DEBUG] Calling unsaveDestination: userId=$currentUserId canonical="$canonicalId"');
        await _savedDestinationService.unsaveDestination(currentUserId, canonicalId);
        debugPrint('[SAVE DEBUG] unsaveDestination succeeded');
      } else {
        debugPrint('[SAVE DEBUG] Calling saveDestination: userId=$currentUserId location_id="${newSavedLoc!.id}"');
        await _savedDestinationService.saveDestination(currentUserId, newSavedLoc);
        debugPrint('[SAVE DEBUG] saveDestination succeeded');
      }
      return true;
    } catch (e, st) {
      debugPrint('[SAVE DEBUG] Supabase error: $e\n$st');
      // 4. Rollback on failure
      _savedLocations = previousSavedLocations;
      _syncFeaturedSavedState();
      notifyListeners();
      return false;
    }
  }

  /// Saves or unsaves any [TravelLocation] with optimistic update and rollback.
  Future<bool> toggleSaveTravelLocation(TravelLocation location) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final canonicalId = CanonicalDestinationId.fromTravelLocation(location);
    final wasSaved = _savedLocations.any((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
    final previousSavedLocations = List<SavedLocation>.from(_savedLocations);

    if (wasSaved) {
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
    } else {
      final savedLoc = SavedLocation.fromTravelLocation(location);
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
      _savedLocations.insert(0, savedLoc);
    }
    _syncFeaturedSavedState();
    notifyListeners();

    try {
      if (wasSaved) {
        await _savedDestinationService.unsaveDestination(currentUserId, canonicalId);
      } else {
        final savedLoc = _savedLocations.firstWhere(
          (s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId,
        );
        await _savedDestinationService.saveDestination(currentUserId, savedLoc);
      }
      return true;
    } catch (_) {
      _savedLocations = previousSavedLocations;
      _syncFeaturedSavedState();
      notifyListeners();
      return false;
    }
  }

  /// Saves or unsaves an official [MetLocation] with optimistic update and rollback.
  Future<bool> toggleSaveMetLocation(MetLocation location) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final canonicalId = CanonicalDestinationId.fromMetLocation(location);
    final wasSaved = _savedLocations.any((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
    final previousSavedLocations = List<SavedLocation>.from(_savedLocations);

    if (wasSaved) {
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
    } else {
      final savedLoc = SavedLocation.fromMetLocation(location);
      _savedLocations.removeWhere((s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId);
      _savedLocations.insert(0, savedLoc);
    }
    _syncFeaturedSavedState();
    notifyListeners();

    try {
      if (wasSaved) {
        await _savedDestinationService.unsaveDestination(currentUserId, canonicalId);
      } else {
        final savedLoc = _savedLocations.firstWhere(
          (s) => CanonicalDestinationId.fromSavedLocation(s) == canonicalId,
        );
        await _savedDestinationService.saveDestination(currentUserId, savedLoc);
      }
      return true;
    } catch (_) {
      _savedLocations = previousSavedLocations;
      _syncFeaturedSavedState();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleSaveFeaturedDestination(String id) async {
    final canonicalId = CanonicalDestinationId.fromString(id);
    final matchingFeatured = _featuredDestinations.where(
      (d) => CanonicalDestinationId.fromDestination(d) == canonicalId || d.id == id,
    ).firstOrNull;

    if (matchingFeatured != null) {
      return await toggleSaveAnyDestination(matchingFeatured);
    }

    final matchingRec = _recommendations.where(
      (r) => CanonicalDestinationId.fromDestination(r.destination) == canonicalId || r.destination.id == id,
    ).firstOrNull;

    if (matchingRec != null) {
      return await toggleSaveAnyDestination(matchingRec.destination);
    }

    final matchingMet = _searchableLocations.where(
      (m) => CanonicalDestinationId.fromMetLocation(m) == canonicalId || m.id == id,
    ).firstOrNull;

    if (matchingMet != null) {
      return await toggleSaveMetLocation(matchingMet);
    }

    return false;
  }

  Future<bool> toggleSaveDestination(String id) async {
    return await toggleSaveFeaturedDestination(id);
  }

  /// Removes a saved location from Supabase with optimistic UI update.
  ///
  /// Returns `null` on success, or an error string if the Supabase DELETE failed
  /// (in which case the item is restored in the UI automatically).
  Future<String?> removeSavedLocationWithUndo(String id) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Optimistic UI: remove from list immediately
    final index = _savedLocations.indexWhere((s) => s.id == id);
    if (index == -1) return null;

    final removed = _savedLocations[index];
    _savedLocations.removeAt(index);
    final featuredIndex = _featuredDestinations.indexWhere(
      (d) => d.id == id || 'met:${d.metLocationId}' == id,
    );
    if (featuredIndex != -1) {
      _featuredDestinations[featuredIndex] =
          _featuredDestinations[featuredIndex].copyWith(isSaved: false);
    }
    notifyListeners();

    if (currentUserId != null) {
      try {
        await _savedDestinationService.unsaveDestination(currentUserId, id);
        return null; // success
      } catch (_) {
        // Supabase DELETE failed — restore UI
        _savedLocations.insert(index, removed);
        if (featuredIndex != -1) {
          _featuredDestinations[featuredIndex] =
              _featuredDestinations[featuredIndex].copyWith(isSaved: true);
        }
        notifyListeners();
        return 'Unable to remove destination. Please try again.';
      }
    }
    return null;
  }

  /// Restores a previously removed SavedLocation (used by Undo).
  ///
  /// Returns `null` on success, or an error string if the Supabase INSERT failed.
  Future<String?> restoreSavedLocation(SavedLocation location) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    // Optimistic UI: re-insert at top
    _savedLocations.insert(0, location);
    final featuredIndex = _featuredDestinations.indexWhere(
      (d) => d.id == location.id || 'met:${d.metLocationId}' == location.id,
    );
    if (featuredIndex != -1) {
      _featuredDestinations[featuredIndex] =
          _featuredDestinations[featuredIndex].copyWith(isSaved: true);
    }
    notifyListeners();

    if (currentUserId != null) {
      try {
        await _savedDestinationService.saveDestination(currentUserId, location);
        return null; // success
      } catch (_) {
        // Supabase INSERT failed — revert UI
        _savedLocations.removeWhere((s) => s.id == location.id);
        if (featuredIndex != -1) {
          _featuredDestinations[featuredIndex] =
              _featuredDestinations[featuredIndex].copyWith(isSaved: false);
        }
        notifyListeners();
        return 'Unable to restore destination. Please save it again.';
      }
    }
    return null;
  }

  Future<void> removeSavedLocation(String id) async {
    await removeSavedLocationWithUndo(id);
  }

  void _syncFeaturedSavedState() {
    final savedCanonicals = _savedLocations
        .map(CanonicalDestinationId.fromSavedLocation)
        .toSet();

    _featuredDestinations = _featuredDestinations.map((dest) {
      final canonical = CanonicalDestinationId.fromDestination(dest);
      return dest.copyWith(isSaved: savedCanonicals.contains(canonical));
    }).toList();

    _recommendations = _recommendations.map((rec) {
      final canonical = CanonicalDestinationId.fromDestination(rec.destination);
      final isSaved = savedCanonicals.contains(canonical);
      if (rec.destination.isSaved != isSaved) {
        return rec.copyWith(
          destination: rec.destination.copyWith(isSaved: isSaved),
        );
      }
      return rec;
    }).toList();
  }

  /// Clears user-specific saved data on logout.
  void clearUserData() {
    _savedLocations = [];
    _syncFeaturedSavedState();
    notifyListeners();
  }

  // ─── Recently Analysed Management (Device Local Cache) ───────────────────

  void _addToRecentlyAnalysed(MetLocation location) {
    _recentlyAnalysed.removeWhere((item) => item.id == location.id);
    _recentlyAnalysed.insert(0, location);
    if (_recentlyAnalysed.length > 8) {
      _recentlyAnalysed = _recentlyAnalysed.take(8).toList();
    }
    _persistRecentlyAnalysed();
    notifyListeners();
  }

  Future<void> _loadRecentlyAnalysed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recentAnalysedKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        _recentlyAnalysed = list.map((item) => MetLocation.fromJson(item as Map<String, dynamic>)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistRecentlyAnalysed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_recentlyAnalysed.map((item) => item.toJson()).toList());
      await prefs.setString(_recentAnalysedKey, raw);
    } catch (_) {}
  }
}
