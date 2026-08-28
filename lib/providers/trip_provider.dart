import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planned_trip.dart';
import '../models/weather_info.dart';
import '../models/travel_score.dart';
import '../services/trip_service.dart';
import '../services/weather_service.dart';
import '../utils/travel_score_calculator.dart';

/// Forecast availability state for a specific planned trip.
enum TripForecastStatus {
  /// Trip date is outside the official MET Malaysia 7-day window.
  pending,

  /// Forecast is currently being fetched.
  loading,

  /// Official MET forecast was retrieved successfully.
  available,

  /// Trip is within the forecast window but MET returned no data.
  unavailable,

  /// A network or API error occurred while fetching.
  error,
}

/// TripProvider manages state for trips the user has explicitly planned.
/// Cloud-persisted in Supabase `planned_trips` table with integer database IDs (bigint)
/// and isolated via Row Level Security (RLS).
///
/// Forecast loading is centralised here to:
/// - Avoid individual card-level duplicate MET requests.
/// - Deduplicate requests by (locationId, travelDate).
/// - Reuse the existing WeatherService cache (1-hour TTL).
/// - Keep PlannedTripCard purely presentational.
class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();
  final WeatherService _weatherService = WeatherService();

  StreamSubscription<AuthState>? _authSub;

  List<PlannedTrip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _remindersEnabled = true;

  // Keyed by trip.id (int). Null id trips are ignored for forecast loading.
  final Map<int, WeatherInfo?> _tripForecasts = {};
  final Map<int, TripForecastStatus> _tripForecastStatuses = {};
  final Map<int, TravelScore> _tripScores = {};

  // Deduplication: track in-flight forecast requests by (locationId_dateStr)
  final Set<String> _inFlightForecastKeys = {};

  List<PlannedTrip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get remindersEnabled => _remindersEnabled;

  /// Sets whether in-app trip reminders are enabled.
  void setRemindersEnabled(bool enabled) {
    _remindersEnabled = enabled;
    notifyListeners();
  }

  /// Today's trips.
  List<PlannedTrip> get todayTrips {
    final list = _trips.where((t) => t.isToday).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  /// Tomorrow's trips.
  List<PlannedTrip> get tomorrowTrips {
    final list = _trips.where((t) => t.isTomorrow).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  /// Future upcoming trips (excluding today), sorted with nearest travel date first.
  List<PlannedTrip> get upcomingTrips {
    final list = _trips.where((t) => t.isUpcoming && !t.isToday).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  /// Next upcoming trip (including today), sorted nearest first.
  PlannedTrip? get nextUpcomingTrip {
    final upcoming = _trips.where((t) => t.isUpcoming).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return upcoming.first;
  }

  /// True if user has any trip today.
  bool get hasTodayTrip => todayTrips.isNotEmpty;

  /// True if user has any trip tomorrow.
  bool get hasTomorrowTrip => tomorrowTrips.isNotEmpty;

  /// Past / Completed trips, sorted with most recent first.
  List<PlannedTrip> get pastTrips {
    final list = _trips.where((t) => t.isPast).toList();
    list.sort((a, b) => b.travelDate.compareTo(a.travelDate));
    return list;
  }

  TripProvider({bool autoLoad = true, bool listenToAuth = true}) {
    if (listenToAuth) {
      _initAuthListener();
    }
    if (autoLoad) {
      loadTrips();
    }
  }

  /// Listens to Supabase auth events to reload or clear trips automatically.
  void _initAuthListener() {
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {
          // Reload trips when a real authenticated session becomes available.
          loadTrips();
        } else if (event == AuthChangeEvent.signedOut) {
          clearUserData();
        }
      });
    } catch (_) {
      // Supabase instance may not be initialized in unit/widget test environments
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // ─── Forecast Accessors ────────────────────────────────────────────────────

  /// Returns the forecast status for a trip by its database ID.
  /// Defaults to [TripForecastStatus.pending] if the status is not yet set.
  TripForecastStatus forecastStatusForTrip(int tripId) {
    return _tripForecastStatuses[tripId] ?? TripForecastStatus.pending;
  }

  /// Returns the loaded [WeatherInfo] for a trip, or null if unavailable/pending.
  WeatherInfo? weatherForTrip(int tripId) => _tripForecasts[tripId];

  /// Returns the computed [TravelScore] for a trip, or null if forecast is pending/unavailable.
  TravelScore? scoreForTrip(int tripId) => _tripScores[tripId];

  // ─── Data Loading ──────────────────────────────────────────────────────────

  /// Loads all saved planned trips for the current authenticated user from Supabase.
  Future<void> loadTrips() async {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id ??
          Supabase.instance.client.auth.currentSession?.user.id;
    } catch (_) {
      userId = null;
    }

    if (userId == null) {
      _trips = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _trips = await _tripService.getTrips(userId);
      debugPrint('[TripProvider] ========================================');
      debugPrint('[TripProvider] TOTAL PROVIDER TRIPS: ${_trips.length}');
      debugPrint('[TripProvider] TODAY COUNT: ${todayTrips.length}');
      debugPrint('[TripProvider] UPCOMING COUNT: ${upcomingTrips.length}');
      debugPrint('[TripProvider] PAST COUNT: ${pastTrips.length}');
      debugPrint('[TripProvider] ========================================');

      // Load forecasts after trips are available (non-blocking)
      _loadForecastsForEligibleTrips();
    } catch (e, stack) {
      debugPrint('[TripProvider] Error loading trips: $e\n$stack');
      _errorMessage = 'Unable to load your trips. Please try again.';
      _trips = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads MET Malaysia forecasts for all trips within the official forecast window.
  ///
  /// Rules:
  /// 1. Only trips where [PlannedTrip.isWithinForecastRange] is true are queried.
  /// 2. Requests are deduplicated by (locationId + travelDate) — multiple trips to
  ///    the same destination on the same date share one MET API call.
  /// 3. The existing [WeatherService] 1-hour cache is honoured automatically.
  /// 4. Trips with no usable MET location ID are marked [TripForecastStatus.unavailable].
  Future<void> _loadForecastsForEligibleTrips() async {
    final eligible = _trips.where((t) => t.id != null).toList();

    // Mark non-eligible trips as pending immediately
    for (final trip in eligible) {
      if (!trip.isWithinForecastRange) {
        if (_tripForecastStatuses[trip.id!] != TripForecastStatus.pending) {
          _tripForecastStatuses[trip.id!] = TripForecastStatus.pending;
        }
      }
    }

    // Gather unique (locationId, date) pairs to deduplicate
    final Map<String, List<PlannedTrip>> byKey = {};
    for (final trip in eligible) {
      if (!trip.isWithinForecastRange) continue;

      final locationId = _effectiveMETLocationId(trip);
      if (locationId == null) {
        _tripForecastStatuses[trip.id!] = TripForecastStatus.unavailable;
        continue;
      }

      final dateStr = _dateKey(trip.travelDate);
      final key = '${locationId}__$dateStr';
      byKey.putIfAbsent(key, () => []).add(trip);
      _tripForecastStatuses[trip.id!] = TripForecastStatus.loading;
    }

    notifyListeners();

    // One MET fetch per unique (locationId, date)
    for (final entry in byKey.entries) {
      final key = entry.key;
      final tripsForKey = entry.value;
      final parts = key.split('__');
      if (parts.length < 2) continue;
      final locationId = parts[0];
      final trip = tripsForKey.first; // All share the same date

      if (_inFlightForecastKeys.contains(key)) continue;
      _inFlightForecastKeys.add(key);

      try {
        final weather = await _weatherService.fetchWeatherForLocationAndDate(
          locationId,
          trip.travelDate,
        );

        for (final t in tripsForKey) {
          if (t.id == null) continue;
          _tripForecasts[t.id!] = weather;
          _tripForecastStatuses[t.id!] =
              weather != null ? TripForecastStatus.available : TripForecastStatus.unavailable;

          if (weather != null) {
            _tripScores[t.id!] = TravelScoreCalculator.calculateScore(
              weather: weather,
              preferredPeriod: t.preferredPeriod,
            );
          }
        }
      } catch (_) {
        for (final t in tripsForKey) {
          if (t.id == null) continue;
          _tripForecastStatuses[t.id!] = TripForecastStatus.error;
        }
      } finally {
        _inFlightForecastKeys.remove(key);
      }

      notifyListeners();
    }
  }

  /// Refreshes forecasts for all eligible trips (e.g. on pull-to-refresh).
  Future<void> refreshForecasts() async {
    _inFlightForecastKeys.clear();
    await _loadForecastsForEligibleTrips();
  }

  // ─── Trip Mutations ────────────────────────────────────────────────────────

  /// Adds a new planned trip to Supabase and updates in-memory list.
  Future<PlannedTrip?> addTrip(PlannedTrip trip) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final createdTrip = await _tripService.saveTrip(userId, trip);
      _trips.removeWhere((t) => t.id == createdTrip.id);
      _trips.insert(0, createdTrip);
      notifyListeners();

      // Load forecast for this new trip immediately
      _loadForecastsForEligibleTrips();
      return createdTrip;
    } catch (_) {
      _errorMessage = 'Failed to create trip. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Updates an existing planned trip in Supabase.
  Future<bool> updateTrip(PlannedTrip trip) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || trip.id == null) return false;

    try {
      await _tripService.updateTrip(userId, trip);
      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index != -1) {
        _trips[index] = trip;
      } else {
        _trips.insert(0, trip);
      }
      // Invalidate cached forecast/score for this trip so it re-fetches
      _tripForecasts.remove(trip.id);
      _tripScores.remove(trip.id);
      _tripForecastStatuses.remove(trip.id);
      notifyListeners();

      _loadForecastsForEligibleTrips();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update trip. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a planned trip by its integer database ID.
  Future<bool> deleteTrip(int tripId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _tripService.deleteTrip(userId, tripId);
      _trips.removeWhere((t) => t.id == tripId);
      _tripForecasts.remove(tripId);
      _tripScores.remove(tripId);
      _tripForecastStatuses.remove(tripId);
      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Finds a specific trip by its integer database ID.
  PlannedTrip? getTripById(int tripId) {
    for (final t in _trips) {
      if (t.id == tripId) return t;
    }
    return null;
  }

  /// Clears in-memory trip data on logout.
  void clearUserData() {
    _trips = [];
    _tripForecasts.clear();
    _tripScores.clear();
    _tripForecastStatuses.clear();
    _inFlightForecastKeys.clear();
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Resolves the effective MET Malaysia location ID for weather fetching.
  ///
  /// - If [PlannedTrip.destinationLocationId] starts with `LOCATION:`, use it directly.
  /// - If it starts with `geo:`, we cannot infer the MET location from the stored model
  ///   alone (the matched MET location should have been stored as the ID at planning time
  ///   via TravelInsightsScreen). In this case return null so the trip shows "unavailable".
  /// - Any other unexpected format returns null.
  static String? _effectiveMETLocationId(PlannedTrip trip) {
    final id = trip.destinationLocationId;
    if (id.startsWith('LOCATION:')) return id;
    // met: prefix is used internally in TravelLocation but should not appear in stored trips
    // (TravelInsightsScreen passes _metLocationId ?? _locationId which resolves to LOCATION:xxx)
    if (id.startsWith('met:')) return id.substring(4); // strip internal prefix if ever stored
    // geo: IDs cannot be used directly with the MET API
    return null;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
