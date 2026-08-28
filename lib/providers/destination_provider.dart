import 'dart:convert';
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
  
  /// Recommendations that have a direct driving road route feasible from current location.
  List<DestinationRecommendation> get roadAccessibleRecommendations =>
      _recommendations.where((r) => r.isRoadAccessible).toList();

  /// Recommendations requiring water/air transport (e.g. Sabah, Sarawak, offshore islands).
  List<DestinationRecommendation> get getawayRecommendations =>
      _recommendations.where((r) => !r.isRoadAccessible).toList();

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

  /// Loads curated featured destinations and initialises smart recommendations.
  Future<void> loadDestinations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _featuredDestinations = DestinationDataService.getDestinations();

      // Sync saved status from persistent storage
      final savedIds = _savedLocations.map((s) => s.id).toSet();
      _featuredDestinations = _featuredDestinations.map((dest) {
        final isSaved = savedIds.contains(dest.id) ||
            savedIds.contains('met:${dest.metLocationId}') ||
            savedIds.contains('met:${dest.id}');
        return dest.copyWith(isSaved: isSaved);
      }).toList();

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

  /// Generates recommendations for the current preference tag (queries max candidate pool).
  Future<void> _refreshRecommendations() async {
    try {
      final recs = await _recommendationService.getRecommendations(
        preference: _selectedRecommendationTag,
        allDestinations: _featuredDestinations,
        userOrigin: _currentUserOrigin,
      );
      _recommendations = recs;

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

  /// Fetches official MET forecast on-demand for a [TravelLocation] using its matched MET location ID.
  Future<WeatherInfo?> fetchForecastForTravelLocation(TravelLocation location, {bool forceRefresh = false}) async {
    if (!location.hasWeatherLocation) return null;
    try {
      final weather = await _weatherService.fetchWeatherForLocationId(
        location.metLocationId!,
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

  /// Fetches official MET forecast for a [TravelDestination] on-demand.
  Future<WeatherInfo?> fetchForecastForDestination(TravelDestination dest, {bool forceRefresh = false}) async {
    try {
      final weather = await _weatherService.fetchWeatherForLocationId(
        dest.metLocationId,
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
    final cleanId = id.startsWith('met:') || id.startsWith('geo:') ? id : 'met:$id';
    return _savedLocations.any((s) => s.id == cleanId || s.id == id || s.metLocationId == id);
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

  /// Saves or unsaves any [TravelLocation] (official MET or geocoded detailed place).
  Future<void> toggleSaveTravelLocation(TravelLocation location) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final existingIndex = _savedLocations.indexWhere((s) => s.id == location.id);
    if (existingIndex != -1) {
      _savedLocations.removeAt(existingIndex);
      _syncFeaturedSavedState();
      notifyListeners();
      try {
        await _savedDestinationService.unsaveDestination(currentUserId, location.id);
      } catch (_) {}
    } else {
      final savedLoc = SavedLocation.fromTravelLocation(location);
      _savedLocations.insert(0, savedLoc);
      _syncFeaturedSavedState();
      notifyListeners();
      try {
        await _savedDestinationService.saveDestination(currentUserId, savedLoc);
      } catch (_) {}
    }
  }

  Future<void> toggleSaveFeaturedDestination(String id) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final index = _featuredDestinations.indexWhere((item) => item.id == id);
    if (index != -1) {
      final current = _featuredDestinations[index];
      final newSaved = !current.isSaved;
      _featuredDestinations[index] = current.copyWith(isSaved: newSaved);

      final locationId = 'met:${current.metLocationId.isNotEmpty ? current.metLocationId : current.id}';

      if (newSaved) {
        final savedLoc = SavedLocation.fromFeaturedDestination(_featuredDestinations[index]);
        _savedLocations.removeWhere((s) => s.id == locationId || s.id == id);
        _savedLocations.insert(0, savedLoc);
        notifyListeners();
        try {
          await _savedDestinationService.saveDestination(currentUserId, savedLoc);
        } catch (_) {}
      } else {
        _savedLocations.removeWhere((s) => s.id == locationId || s.id == id);
        notifyListeners();
        try {
          await _savedDestinationService.unsaveDestination(currentUserId, locationId);
        } catch (_) {}
      }
    }
  }

  Future<void> toggleSaveDestination(String id) async {
    await toggleSaveFeaturedDestination(id);
  }

  Future<void> toggleSaveMetLocation(MetLocation location) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final locationId = 'met:${location.id}';
    final existingIndex = _savedLocations.indexWhere((s) => s.id == locationId || s.id == location.id);
    if (existingIndex != -1) {
      _savedLocations.removeAt(existingIndex);
      notifyListeners();
      try {
        await _savedDestinationService.unsaveDestination(currentUserId, locationId);
      } catch (_) {}
    } else {
      final savedLoc = SavedLocation.fromMetLocation(location);
      _savedLocations.insert(0, savedLoc);
      notifyListeners();
      try {
        await _savedDestinationService.saveDestination(currentUserId, savedLoc);
      } catch (_) {}
    }
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
    final savedIds = _savedLocations.map((s) => s.id).toSet();
    _featuredDestinations = _featuredDestinations.map((dest) {
      final isSaved = savedIds.contains(dest.id) ||
          savedIds.contains('met:${dest.metLocationId}') ||
          savedIds.contains('met:${dest.id}');
      return dest.copyWith(isSaved: isSaved);
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
