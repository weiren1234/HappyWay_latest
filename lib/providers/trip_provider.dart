import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planned_trip.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../services/trip_service.dart';
import '../services/weather_service.dart';
import '../services/route_service.dart';
import '../utils/travel_score_calculator.dart';

enum TripForecastStatus {

  pending,

  loading,

  available,

  unavailable,

  error,
}

class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();
  final WeatherService _weatherService = WeatherService();
  final RouteService _routeService = RouteService();

  StreamSubscription<AuthState>? _authSub;

  List<PlannedTrip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _remindersEnabled = true;

  final Map<int, WeatherInfo?> _tripForecasts = {};
  final Map<int, TravelRoute?> _tripRoutes = {};
  final Map<int, TravelScore?> _tripScores = {};
  final Map<int, TripForecastStatus> _tripForecastStatuses = {};
  final Map<int, bool> _tripScoreLoading = {};

  final Map<int, Future<TravelScore?>> _inFlightTripCalculations = {};

  WeatherInfo? weatherForTrip(int tripId) => _tripForecasts[tripId];
  TravelRoute? routeForTrip(int tripId) => _tripRoutes[tripId];
  TravelScore? scoreForTrip(int tripId) => _tripScores[tripId];
  TripForecastStatus forecastStatusForTrip(int tripId) =>
      _tripForecastStatuses[tripId] ?? TripForecastStatus.pending;
  bool isScoreLoadingForTrip(int tripId) => _tripScoreLoading[tripId] ?? false;

  @visibleForTesting
  void setTripScoreForTesting({
    required int tripId,
    TravelScore? score,
    WeatherInfo? weather,
    TravelRoute? route,
    TripForecastStatus status = TripForecastStatus.available,
  }) {
    if (score != null) _tripScores[tripId] = score;
    if (weather != null) _tripForecasts[tripId] = weather;
    if (route != null) _tripRoutes[tripId] = route;
    _tripForecastStatuses[tripId] = status;
    notifyListeners();
  }

  List<PlannedTrip> get trips => _trips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get remindersEnabled => _remindersEnabled;

  void setRemindersEnabled(bool enabled) {
    _remindersEnabled = enabled;
    notifyListeners();
  }

  List<PlannedTrip> get todayTrips {
    final list = _trips.where((t) => t.isToday).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  List<PlannedTrip> get tomorrowTrips {
    final list = _trips.where((t) => t.isTomorrow).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  List<PlannedTrip> get upcomingTrips {
    final list = _trips.where((t) => t.isUpcoming && !t.isToday).toList();
    list.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return list;
  }

  PlannedTrip? get nextUpcomingTrip {
    final upcoming = _trips.where((t) => t.isUpcoming).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return upcoming.first;
  }

  bool get hasTodayTrip => todayTrips.isNotEmpty;

  bool get hasTomorrowTrip => tomorrowTrips.isNotEmpty;

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

  void _initAuthListener() {
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {

          loadTrips();
        } else if (event == AuthChangeEvent.signedOut) {
          clearUserData();
        }
      });
    } catch (_) {

    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

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

  Future<TravelScore?> calculateScoreForPlannedTrip(
    PlannedTrip trip, {
    bool forceRefresh = false,
    String sourceScreen = 'MyTrips',
  }) async {
    final tripId = trip.id;
    if (tripId == null) return null;

    if (trip.isPast) {
      _tripForecastStatuses[tripId] = TripForecastStatus.unavailable;
      _tripScores.remove(tripId);
      _tripScoreLoading[tripId] = false;
      return null;
    }

    if (!trip.isWithinForecastRange) {
      _tripForecastStatuses[tripId] = TripForecastStatus.pending;
      _tripScores.remove(tripId);
      _tripScoreLoading[tripId] = false;
      return null;
    }

    if (!forceRefresh && _inFlightTripCalculations.containsKey(tripId)) {
      return await _inFlightTripCalculations[tripId]!;
    }

    if (!forceRefresh &&
        _tripScores.containsKey(tripId) &&
        _tripScores[tripId] != null) {
      final cachedScore = _tripScores[tripId]!;
      _logScoreDebug(
        trip: trip,
        weather: _tripForecasts[tripId],
        route: _tripRoutes[tripId],
        score: cachedScore,
        sourceScreen: sourceScreen,
      );
      return cachedScore;
    }

    final future = _doCalculateScoreForTrip(
      trip,
      forceRefresh: forceRefresh,
      sourceScreen: sourceScreen,
    );
    _inFlightTripCalculations[tripId] = future;
    try {
      return await future;
    } finally {
      _inFlightTripCalculations.remove(tripId);
    }
  }

  Future<TravelScore?> _doCalculateScoreForTrip(
    PlannedTrip trip, {
    required bool forceRefresh,
    required String sourceScreen,
  }) async {
    final tripId = trip.id!;
    _tripScoreLoading[tripId] = true;
    _tripForecastStatuses[tripId] = TripForecastStatus.loading;
    notifyListeners();

    try {

      TravelRoute? route = forceRefresh ? null : _tripRoutes[tripId];
      final origLat = trip.originLatitude;
      final origLng = trip.originLongitude;
      final destLat = trip.destinationLatitude;
      final destLng = trip.destinationLongitude;

      if (route == null &&
          origLat != null && origLng != null && origLat != 0.0 && origLng != 0.0 &&
          destLat != null && destLng != null && destLat != 0.0 && destLng != 0.0) {
        try {
          final routeResult = await _routeService.calculateRouteDetails(
            originName: trip.originName,
            originLat: origLat,
            originLng: origLng,
            destName: trip.destinationName,
            destLat: destLat,
            destLng: destLng,
            forceRefresh: forceRefresh,
          );
          route = routeResult.route;
        } catch (e) {
          debugPrint('[TripProvider] Route calculation error for trip $tripId: $e');
        }
      }
      _tripRoutes[tripId] = route;

      final metId = _effectiveMETLocationId(trip) ?? '';
      WeatherInfo? weather;
      if (metId.isNotEmpty || (destLat != null && destLng != null && destLat != 0.0 && destLng != 0.0)) {
        try {
          weather = await _weatherService.fetchWeatherForLocationAndDate(
            metId,
            trip.travelDate,
            latitude: destLat,
            longitude: destLng,
            forceRefresh: forceRefresh,
          );
        } catch (e) {
          debugPrint('[TripProvider] Weather fetch error for trip $tripId: $e');
        }
      }

      _tripForecasts[tripId] = weather;
      _tripForecastStatuses[tripId] = weather != null
          ? TripForecastStatus.available
          : TripForecastStatus.unavailable;

      TravelScore? score;
      if (weather != null) {
        score = TravelScoreCalculator.calculateScore(
          weather: weather,
          route: route,
          preferredPeriod: trip.preferredPeriod,
          travelDate: trip.travelDate,
        );
        _tripScores[tripId] = score;
      } else {
        _tripScores.remove(tripId);
      }

      _logScoreDebug(
        trip: trip,
        weather: weather,
        route: route,
        score: score,
        sourceScreen: sourceScreen,
      );

      return score;
    } catch (e) {
      debugPrint('[TripProvider] Error calculating score for trip $tripId: $e');
      _tripForecastStatuses[tripId] = TripForecastStatus.error;
      _tripScores.remove(tripId);
      return null;
    } finally {
      _tripScoreLoading[tripId] = false;
      notifyListeners();
    }
  }

  void _logScoreDebug({
    required PlannedTrip trip,
    required WeatherInfo? weather,
    required TravelRoute? route,
    required TravelScore? score,
    required String sourceScreen,
  }) {
    debugPrint('[TRIP SCORE DEBUG]');
    debugPrint('tripId = ${trip.id}');
    debugPrint('destination = ${trip.destinationName}');
    debugPrint('origin = ${trip.originName}');
    debugPrint('travelDate = ${DateFormat('yyyy-MM-dd').format(trip.travelDate)}');
    debugPrint('preferredPeriod = ${trip.preferredPeriod}');
    debugPrint('hourlyForecastDate = ${weather?.hourlyForecast?.isNotEmpty == true ? DateFormat('yyyy-MM-dd').format(weather!.hourlyForecast!.first.time) : "none"}');
    debugPrint('routeDuration = ${route?.durationFormatted ?? "none"}');
    debugPrint('weatherSuitability = ${score?.weatherSubscore ?? "none"}');
    debugPrint('journeyPracticality = ${score?.journeySubscore ?? "none"}');
    debugPrint('finalScore = ${score?.score ?? "none"}');
    debugPrint('sourceScreen = $sourceScreen');
  }

  Future<void> _loadForecastsForEligibleTrips() async {
    final eligible = _trips.where((t) => t.id != null && !t.isPast && t.isWithinForecastRange).toList();

    for (final trip in _trips) {
      if (trip.id == null) continue;
      if (trip.isPast) {
        _tripForecastStatuses[trip.id!] = TripForecastStatus.unavailable;
        _tripScores.remove(trip.id!);
      } else if (!trip.isWithinForecastRange) {
        _tripForecastStatuses[trip.id!] = TripForecastStatus.pending;
        _tripScores.remove(trip.id!);
      }
    }

    if (eligible.isEmpty) {
      notifyListeners();
      return;
    }

    for (final trip in eligible) {
      await calculateScoreForPlannedTrip(trip, sourceScreen: 'MyTrips');
    }
  }

  Future<void> refreshForecasts() async {
    final eligible = _trips.where((t) => t.id != null && !t.isPast && t.isWithinForecastRange).toList();
    for (final trip in eligible) {
      await calculateScoreForPlannedTrip(trip, forceRefresh: true, sourceScreen: 'MyTrips');
    }
  }

  Future<PlannedTrip?> addTrip(PlannedTrip trip) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final createdTrip = await _tripService.saveTrip(userId, trip);
      _trips.removeWhere((t) => t.id == createdTrip.id);
      _trips.insert(0, createdTrip);
      notifyListeners();

      _loadForecastsForEligibleTrips();
      return createdTrip;
    } catch (_) {
      _errorMessage = 'Failed to create trip. Please try again.';
      notifyListeners();
      return null;
    }
  }

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

      _tripForecasts.remove(trip.id);
      _tripRoutes.remove(trip.id);
      _tripScores.remove(trip.id);
      _tripForecastStatuses.remove(trip.id);
      _tripScoreLoading.remove(trip.id);
      _inFlightTripCalculations.remove(trip.id);
      notifyListeners();

      _loadForecastsForEligibleTrips();
      return true;
    } catch (_) {
      _errorMessage = 'Failed to update trip. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTrip(int tripId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _tripService.deleteTrip(userId, tripId);
      _trips.removeWhere((t) => t.id == tripId);
      _tripForecasts.remove(tripId);
      _tripRoutes.remove(tripId);
      _tripScores.remove(tripId);
      _tripForecastStatuses.remove(tripId);
      _tripScoreLoading.remove(tripId);
      _inFlightTripCalculations.remove(tripId);
      notifyListeners();

      return true;
    } catch (_) {
      return false;
    }
  }

  PlannedTrip? getTripById(int tripId) {
    for (final t in _trips) {
      if (t.id == tripId) return t;
    }
    return null;
  }

  void clearUserData() {
    _trips = [];
    _tripForecasts.clear();
    _tripRoutes.clear();
    _tripScores.clear();
    _tripForecastStatuses.clear();
    _tripScoreLoading.clear();
    _inFlightTripCalculations.clear();
    _errorMessage = null;
    notifyListeners();
  }

  static String? _effectiveMETLocationId(PlannedTrip trip) {
    final id = trip.destinationLocationId;
    if (id.startsWith('LOCATION:')) return id;

    if (id.startsWith('met:')) return id.substring(4);

    return null;
  }
}
