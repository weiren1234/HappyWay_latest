import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planned_trip.dart';
import '../models/trip_stop.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../services/trip_service.dart';
import '../services/trip_stop_service.dart';
import '../services/weather_service.dart';
import '../services/route_service.dart';
import '../services/itinerary_analyzer.dart';
import '../services/trip_day_setting_service.dart';
import '../models/itinerary_analysis.dart';
import '../utils/travel_score_calculator.dart';
import '../utils/itinerary_top_score_deriver.dart';

enum TripForecastStatus {
  pending,
  loading,
  available,
  unavailable,
  error,
}

class TripProvider extends ChangeNotifier {
  final TripService _tripService = TripService();
  final TripStopService _tripStopService = TripStopService();
  final TripDaySettingService _tripDaySettingService = TripDaySettingService();
  final WeatherService _weatherService = WeatherService();
  final RouteService _routeService = RouteService();
  final ItineraryAnalyzer _itineraryAnalyzer = ItineraryAnalyzer();

  StreamSubscription<AuthState>? _authSub;

  List<PlannedTrip> _trips = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _remindersEnabled = true;

  final Map<int, List<TripStop>> _stopsByTrip = {};
  final Map<int, bool> _stopsLoading = {};

  final Map<int, WeatherInfo?> _tripForecasts = {};
  final Map<int, TravelRoute?> _tripRoutes = {};
  final Map<int, TravelScore?> _tripScores = {};
  final Map<int, TripForecastStatus> _tripForecastStatuses = {};
  final Map<int, bool> _tripScoreLoading = {};

  final Map<int, Future<TravelScore?>> _inFlightTripCalculations = {};

  final Map<int, ItineraryAnalysis?> _itineraryAnalyses = {};
  final Map<int, bool> _itineraryAnalysisLoading = {};
  final Map<String, ({String name, double lat, double lng, String? address})> _dayStartingPoints = {};
  final Map<int, Future<ItineraryAnalysis?>> _inFlightAnalyses = {};
  final Map<int, bool> _pendingReanalysis = {};

  WeatherInfo? weatherForTrip(int tripId) => _tripForecasts[tripId];
  TravelRoute? routeForTrip(int tripId) => _tripRoutes[tripId];
  TravelScore? scoreForTrip(int tripId) => _tripScores[tripId];
  TripForecastStatus forecastStatusForTrip(int tripId) =>
      _tripForecastStatuses[tripId] ?? TripForecastStatus.pending;
  bool isScoreLoadingForTrip(int tripId) => _tripScoreLoading[tripId] ?? false;

  List<TripStop> getStopsForTrip(int tripId) => _stopsByTrip[tripId] ?? [];
  bool isStopsLoading(int tripId) => _stopsLoading[tripId] ?? false;

  ItineraryAnalysis? getItineraryAnalysis(int tripId) => _itineraryAnalyses[tripId];
  bool isItineraryAnalysisLoading(int tripId) => _itineraryAnalysisLoading[tripId] ?? false;

  static String _dayKey(int tripId, DateTime date) =>
      '${tripId}_${date.year}_${date.month}_${date.day}';

  Future<void> loadDaySettingsForTrip(int tripId, {bool force = false}) async {
    final settings = await _tripDaySettingService.getSettingsForTrip(tripId);
    for (final s in settings) {
      _dayStartingPoints[_dayKey(tripId, s.visitDate)] = (
        name: s.startLocationName,
        lat: s.startLatitude,
        lng: s.startLongitude,
        address: s.address,
      );
    }
    notifyListeners();
  }

  Future<void> setDayStartingPoint(
    int tripId,
    DateTime dayDate,
    String name,
    double lat,
    double lng, {
    String? locationId,
    String? sourceType,
    String? address,
  }) async {
    _dayStartingPoints[_dayKey(tripId, dayDate)] = (
      name: name,
      lat: lat,
      lng: lng,
      address: address,
    );
    notifyListeners();
    _invalidateAndReanalyze(tripId);

    await _tripDaySettingService.saveDayStartOverride(
      tripId: tripId,
      visitDate: dayDate,
      locationName: name,
      latitude: lat,
      longitude: lng,
      locationId: locationId,
      sourceType: sourceType,
      address: address,
    );
  }

  Future<void> clearDayStartingPoint(int tripId, DateTime dayDate) async {
    _dayStartingPoints.remove(_dayKey(tripId, dayDate));
    notifyListeners();
    _invalidateAndReanalyze(tripId);

    await _tripDaySettingService.deleteDayStartOverride(tripId, dayDate);
  }

  ({String name, double lat, double lng, String? address})? getDayStartingPoint(int tripId, DateTime dayDate) {
    return _dayStartingPoints[_dayKey(tripId, dayDate)];
  }

  void setTripScore(int tripId, TravelScore score) {
    _tripScores[tripId] = score;
    unawaited(_persistTripScore(tripId, score));
    notifyListeners();
  }

  Future<void> _persistTripScore(int tripId, TravelScore score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('canonical_trip_score_$tripId', jsonEncode(score.toJson()));
    } catch (_) {}
  }

  Future<TravelScore?> _loadPersistedTripScore(int tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('canonical_trip_score_$tripId');
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return TravelScore.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _removePersistedTripScore(int tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('canonical_trip_score_$tripId');
    } catch (_) {}
  }

  ({String name, double lat, double lng, String? address}) getEffectiveDayStart(
    int tripId,
    DateTime dayDate,
    List<TripStop> allStops,
    PlannedTrip trip,
  ) {
    final override = _dayStartingPoints[_dayKey(tripId, dayDate)];
    if (override != null) return override;

    final tripStartDate = trip.effectiveStartDate;
    final isFirstDay = dayDate.year == tripStartDate.year &&
        dayDate.month == tripStartDate.month &&
        dayDate.day == tripStartDate.day;

    if (isFirstDay) {
      return (
        name: trip.originName.isNotEmpty ? trip.originName : 'Current Location',
        lat: trip.originLatitude ?? 0.0,
        lng: trip.originLongitude ?? 0.0,
        address: null,
      );
    }

    final priorStops = allStops.where((s) {
      final sDate = DateTime(s.visitDate.year, s.visitDate.month, s.visitDate.day);
      final targetDate = DateTime(dayDate.year, dayDate.month, dayDate.day);
      return sDate.isBefore(targetDate);
    }).toList();

    if (priorStops.isNotEmpty) {
      priorStops.sort((a, b) {
        final dateCmp = a.visitDate.compareTo(b.visitDate);
        if (dateCmp != 0) return dateCmp;
        return a.stopOrder.compareTo(b.stopOrder);
      });
      final lastPrior = priorStops.last;
      return (
        name: lastPrior.locationName,
        lat: lastPrior.latitude,
        lng: lastPrior.longitude,
        address: lastPrior.address,
      );
    }

    return (
      name: trip.originName.isNotEmpty ? trip.originName : 'Current Location',
      lat: trip.originLatitude ?? 0.0,
      lng: trip.originLongitude ?? 0.0,
      address: null,
    );
  }

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

  @visibleForTesting
  void setTripStopsForTesting(int tripId, List<TripStop> stops) {
    _stopsByTrip[tripId] = stops;
    notifyListeners();
  }

  @visibleForTesting
  void setItineraryAnalysisForTesting(int tripId, ItineraryAnalysis analysis) {
    _itineraryAnalyses[tripId] = analysis;
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
    } catch (_) {}
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
      debugPrint('[TripProvider] TOTAL PROVIDER TRIPS: ${_trips.length}');
      for (final trip in _trips) {
        if (trip.id != null && !trip.isPast && trip.isWithinForecastRange) {
          final persisted = await _loadPersistedTripScore(trip.id!);
          if (persisted != null && !persisted.isInitial) {
            _tripScores[trip.id!] = persisted;
            _tripForecastStatuses[trip.id!] = TripForecastStatus.available;
          }
        }
      }
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

  Future<List<TripStop>> loadStopsForTrip(int tripId, {bool force = false}) async {
    if (!force && _stopsByTrip.containsKey(tripId)) {
      return _stopsByTrip[tripId]!;
    }

    final userId = _tripStopService.currentUserId;
    if (userId == null) {
      _stopsByTrip[tripId] = [];
      notifyListeners();
      return [];
    }

    _stopsLoading[tripId] = true;
    notifyListeners();

    try {
      final stops = await _tripStopService.getStopsForTrip(tripId);
      if (stops.isEmpty) {
        final trip = getTripById(tripId);
        if (trip != null &&
            trip.destinationName.trim().isNotEmpty &&
            trip.destinationLocationId.trim().isNotEmpty) {
          await _migrateLegacyTripDestination(userId, trip);
          final reloaded = await _tripStopService.getStopsForTrip(tripId);
          _stopsByTrip[tripId] = reloaded;
          return reloaded;
        }
      }
      _stopsByTrip[tripId] = stops;
      return stops;
    } catch (e) {
      debugPrint('[TripProvider] Error loading stops for trip $tripId: $e');
      _stopsByTrip[tripId] = [];
      return [];
    } finally {
      _stopsLoading[tripId] = false;
      notifyListeners();
    }
  }

  Future<void> _migrateLegacyTripDestination(String userId, PlannedTrip trip) async {
    if (trip.id == null) return;
    try {
      final existing = await _tripStopService.getStopsForTrip(trip.id!);
      if (existing.isNotEmpty) return;

      String plannedArrival = '09:00:00';
      if (trip.preferredPeriod == 'Afternoon') plannedArrival = '14:00:00';
      if (trip.preferredPeriod == 'Night') plannedArrival = '19:00:00';

      final legacyStop = TripStop(
        tripId: trip.id!,
        userId: userId,
        stopOrder: 1,
        locationId: trip.destinationLocationId,
        locationName: trip.destinationName,
        state: trip.destinationState,
        category: trip.destinationCategory,
        latitude: trip.destinationLatitude ?? 0.0,
        longitude: trip.destinationLongitude ?? 0.0,
        metLocationId: _effectiveMETLocationId(trip),
        metLocationName: trip.destinationName,
        address: '${trip.destinationName}, ${trip.destinationState}',
        visitDate: trip.travelDate,
        timeMode: 'exact',
        preferredPeriod: trip.preferredPeriod,
        plannedArrivalTime: plannedArrival,
        stayDurationMinutes: null,
        note: trip.notes,
        createdAt: DateTime.now(),
      );

      await _tripStopService.createStop(legacyStop);
    } catch (e) {
      debugPrint('[TripProvider] Legacy migration error for trip ${trip.id}: $e');
    }
  }

  Future<TripStop?> addStop(int tripId, TripStop stop) async {
    final userId = _tripStopService.currentUserId;
    if (userId == null) {
      debugPrint('[TripProvider] ❌ addStop BLOCKED: currentUserId is null');
      _errorMessage = 'You must be signed in to add a stop.';
      notifyListeners();
      return null;
    }

    try {
      final created = await _tripStopService.createStop(stop);
      final currentList = List<TripStop>.from(_stopsByTrip[tripId] ?? []);
      currentList.removeWhere((s) => s.id == created.id);
      currentList.add(created);

      final sameDayStops = currentList.where((s) =>
          s.visitDate.year == created.visitDate.year &&
          s.visitDate.month == created.visitDate.month &&
          s.visitDate.day == created.visitDate.day).toList();
      sameDayStops.sort(_compareStopsChronologically);

      bool orderChanged = false;
      for (int i = 0; i < sameDayStops.length; i++) {
        if (sameDayStops[i].stopOrder != i + 1) {
          orderChanged = true;
          break;
        }
      }

      if (orderChanged) {
        await _tripStopService.reorderStops(userId, tripId, created.visitDate, sameDayStops);
        final reloaded = await _tripStopService.getStopsForTrip(tripId);
        _stopsByTrip[tripId] = reloaded;
      } else {
        _sortStops(currentList);
        _stopsByTrip[tripId] = currentList;
      }

      _invalidateTripCaches(tripId);
      _errorMessage = null;
      notifyListeners();
      _invalidateAndReanalyze(tripId);
      return created;
    } catch (e) {
      debugPrint('[TripProvider] ❌ addStop caught error: $e');
      if (e is PostgrestException) {
        _errorMessage = 'Database error (${e.code}): ${e.message}';
      } else {
        _errorMessage = 'Failed to add stop: $e';
      }
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateStop(TripStop stop) async {
    final userId = _tripStopService.currentUserId;
    if (userId == null || stop.id == null) return false;

    try {
      final updated = await _tripStopService.updateStop(stop);
      final currentList = List<TripStop>.from(_stopsByTrip[stop.tripId] ?? []);
      final idx = currentList.indexWhere((s) => s.id == updated.id);
      final prevStop = idx != -1 ? currentList[idx] : null;

      if (idx != -1) {
        currentList[idx] = updated;
      } else {
        currentList.add(updated);
      }

      final timingChanged = prevStop == null ||
          prevStop.visitDate.year != updated.visitDate.year ||
          prevStop.visitDate.month != updated.visitDate.month ||
          prevStop.visitDate.day != updated.visitDate.day ||
          prevStop.timeMode != updated.timeMode ||
          prevStop.plannedArrivalTime != updated.plannedArrivalTime ||
          prevStop.preferredPeriod != updated.preferredPeriod;

      if (timingChanged) {
        final sameDayStops = currentList.where((s) =>
            s.visitDate.year == updated.visitDate.year &&
            s.visitDate.month == updated.visitDate.month &&
            s.visitDate.day == updated.visitDate.day).toList();
        sameDayStops.sort(_compareStopsChronologically);

        await _tripStopService.reorderStops(userId, stop.tripId, updated.visitDate, sameDayStops);

        if (prevStop != null &&
            (prevStop.visitDate.year != updated.visitDate.year ||
             prevStop.visitDate.month != updated.visitDate.month ||
             prevStop.visitDate.day != updated.visitDate.day)) {
          final oldDayStops = currentList.where((s) =>
              s.id != updated.id &&
              s.visitDate.year == prevStop.visitDate.year &&
              s.visitDate.month == prevStop.visitDate.month &&
              s.visitDate.day == prevStop.visitDate.day).toList();
          oldDayStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
          await _tripStopService.reorderStops(userId, stop.tripId, prevStop.visitDate, oldDayStops);
        }

        final reloaded = await _tripStopService.getStopsForTrip(stop.tripId);
        _stopsByTrip[stop.tripId] = reloaded;
      } else {
        _sortStops(currentList);
        _stopsByTrip[stop.tripId] = currentList;
      }

      _invalidateTripCaches(stop.tripId);
      notifyListeners();
      _invalidateAndReanalyze(stop.tripId);
      return true;
    } catch (e) {
      debugPrint('[TripProvider] Error updateStop: $e');
      return false;
    }
  }

  Future<bool> deleteStop(int tripId, int stopId) async {
    final userId = _tripStopService.currentUserId;
    if (userId == null) return false;

    try {
      await _tripStopService.deleteStop(userId, stopId);
      final currentList = List<TripStop>.from(_stopsByTrip[tripId] ?? []);
      final removedIndex = currentList.indexWhere((s) => s.id == stopId);
      if (removedIndex != -1) {
        final removedStop = currentList[removedIndex];
        currentList.removeAt(removedIndex);

        final sameDayStops = currentList.where((s) =>
            s.visitDate.year == removedStop.visitDate.year &&
            s.visitDate.month == removedStop.visitDate.month &&
            s.visitDate.day == removedStop.visitDate.day).toList();
        sameDayStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

        await _tripStopService.reorderStops(userId, tripId, removedStop.visitDate, sameDayStops);
        final reloaded = await _tripStopService.getStopsForTrip(tripId);
        _stopsByTrip[tripId] = reloaded;
      } else {
        _stopsByTrip[tripId] = currentList;
      }

      _invalidateTripCaches(tripId);
      notifyListeners();
      _invalidateAndReanalyze(tripId);
      return true;
    } catch (e) {
      debugPrint('[TripProvider] Error deleteStop: $e');
      return false;
    }
  }

  Future<bool> reorderStopsForDay(int tripId, DateTime visitDate, List<TripStop> dayStops) async {
    final userId = _tripStopService.currentUserId;
    if (userId == null) return false;

    try {
      await _tripStopService.reorderStops(userId, tripId, visitDate, dayStops);
      final reloaded = await _tripStopService.getStopsForTrip(tripId);
      _stopsByTrip[tripId] = reloaded;
      _invalidateTripCaches(tripId);
      notifyListeners();
      _invalidateAndReanalyze(tripId);
      return true;
    } catch (e) {
      debugPrint('[TripProvider] Error reorderStopsForDay: $e');
      return false;
    }
  }

  void _sortStops(List<TripStop> list) {
    list.sort((a, b) {
      final dateCmp = a.visitDate.compareTo(b.visitDate);
      if (dateCmp != 0) return dateCmp;
      return a.stopOrder.compareTo(b.stopOrder);
    });
  }

  int _compareStopsChronologically(TripStop a, TripStop b) {
    final dateCmp = a.visitDate.compareTo(b.visitDate);
    if (dateCmp != 0) return dateCmp;

    final aMinutes = _stopSortMinutes(a);
    final bMinutes = _stopSortMinutes(b);

    final minCmp = aMinutes.compareTo(bMinutes);
    if (minCmp != 0) return minCmp;

    return a.stopOrder.compareTo(b.stopOrder);
  }

  int _stopSortMinutes(TripStop stop) {
    if (stop.isExactTime && stop.arrivalTimeOfDay != null) {
      final tod = stop.arrivalTimeOfDay!;
      return tod.hour * 60 + tod.minute;
    }
    final period = (stop.preferredPeriod ?? 'morning').trim().toLowerCase();
    if (period.startsWith('morning')) return 9 * 60;
    if (period.startsWith('afternoon')) return 14 * 60;
    if (period.startsWith('night')) return 19 * 60;
    return 12 * 60;
  }

  void _invalidateTripCaches(int tripId) {
    _tripForecasts.remove(tripId);
    _tripRoutes.remove(tripId);
    _tripScores.remove(tripId);
    _tripForecastStatuses.remove(tripId);
    _tripScoreLoading.remove(tripId);
    _inFlightTripCalculations.remove(tripId);
    unawaited(_removePersistedTripScore(tripId));
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
          preferredPeriod: null,
          travelDate: trip.travelDate,
        );
        _tripScores[tripId] = score;
        unawaited(_persistTripScore(tripId, score));
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
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id;
    if (currentUser == null || userId == null) {
      debugPrint('[TripProvider] ❌ addTrip BLOCKED: currentUser is null (guest or unauthenticated)');
      _errorMessage = 'You must be signed in to create a trip.';
      notifyListeners();
      return null;
    }

    try {
      final createdTrip = await _tripService.saveTrip(userId, trip);
      _trips.removeWhere((t) => t.id == createdTrip.id);
      _trips.insert(0, createdTrip);
      _errorMessage = null;
      notifyListeners();

      _loadForecastsForEligibleTrips();
      return createdTrip;
    } catch (e) {
      debugPrint('[TripProvider] ❌ addTrip caught error: $e');
      if (e is PostgrestException) {
        _errorMessage = 'Database error (${e.code}): ${e.message}';
      } else {
        _errorMessage = 'Failed to create trip: $e';
      }
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
      _stopsByTrip.remove(tripId);
      _stopsLoading.remove(tripId);
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
    _stopsByTrip.clear();
    _stopsLoading.clear();
    _tripForecasts.clear();
    _tripRoutes.clear();
    _tripScores.clear();
    _tripForecastStatuses.clear();
    _tripScoreLoading.clear();
    _inFlightTripCalculations.clear();
    _itineraryAnalyses.clear();
    _itineraryAnalysisLoading.clear();
    _dayStartingPoints.clear();
    _inFlightAnalyses.clear();
    _pendingReanalysis.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<ItineraryAnalysis?> analyzeItineraryForTrip(
    int tripId, {
    bool forceRefresh = false,
    DateTime? currentTimeOverride,
  }) async {
    if (!forceRefresh &&
        _itineraryAnalyses.containsKey(tripId) &&
        _itineraryAnalyses[tripId] != null) {
      return _itineraryAnalyses[tripId];
    }

    if (_inFlightAnalyses.containsKey(tripId)) {
      return _inFlightAnalyses[tripId]!;
    }

    final future = _runItineraryAnalysis(
      tripId,
      forceRefresh: forceRefresh,
      currentTimeOverride: currentTimeOverride,
    );
    _inFlightAnalyses[tripId] = future;
    try {
      return await future;
    } finally {
      _inFlightAnalyses.remove(tripId);
    }
  }

  Future<ItineraryAnalysis?> _runItineraryAnalysis(
    int tripId, {
    bool forceRefresh = false,
    DateTime? currentTimeOverride,
  }) async {
    final trip = getTripById(tripId);
    if (trip == null) return null;

    final stops = await loadStopsForTrip(tripId, force: forceRefresh);
    if (stops.isEmpty) {
      return null;
    }

    _itineraryAnalysisLoading[tripId] = true;
    notifyListeners();

    try {
      final tripOverrides = <DateTime, ({String name, double lat, double lng})>{};
      for (final entry in _dayStartingPoints.entries) {
        if (entry.key.startsWith('${tripId}_')) {
          final parts = entry.key.split('_');
          if (parts.length == 4) {
            final y = int.tryParse(parts[1]);
            final m = int.tryParse(parts[2]);
            final d = int.tryParse(parts[3]);
            if (y != null && m != null && d != null) {
              tripOverrides[DateTime(y, m, d)] = (
                name: entry.value.name,
                lat: entry.value.lat,
                lng: entry.value.lng,
              );
            }
          }
        }
      }

      final analysis = await _itineraryAnalyzer.analyzeTrip(
        trip: trip,
        stops: stops,
        forceRefresh: forceRefresh,
        currentTimeOverride: currentTimeOverride,
        dayStartOverrides: tripOverrides.isNotEmpty ? tripOverrides : null,
      );
      _itineraryAnalyses[tripId] = analysis;

      if (analysis.days.isNotEmpty) {
        final allStopAnalyses = analysis.days.expand((d) => d.stops).toList();
        if (allStopAnalyses.isNotEmpty) {
          final derivedScore = ItineraryTopScoreDeriver.derive(
            trip: trip,
            firstStopAnalysis: allStopAnalyses.first,
            totalStops: allStopAnalyses.length,
            fallbackScore: _tripScores[tripId],
          );
          _tripScores[tripId] = derivedScore;
          _tripForecastStatuses[tripId] = TripForecastStatus.available;
          unawaited(_persistTripScore(tripId, derivedScore));
        }
      }

      return analysis;
    } catch (e) {
      debugPrint('[TripProvider] Error analyzing itinerary for trip $tripId: $e');
      return null;
    } finally {
      _itineraryAnalysisLoading[tripId] = false;
      notifyListeners();
    }
  }

  void _invalidateAndReanalyze(int tripId) {
    _itineraryAnalysisLoading[tripId] = true;
    notifyListeners();
    unawaited(_queueReanalysis(tripId));
  }

  Future<void> _queueReanalysis(int tripId) async {
    if (_inFlightAnalyses.containsKey(tripId)) {
      _pendingReanalysis[tripId] = true;
      return;
    }

    do {
      _pendingReanalysis[tripId] = false;
      final future = _runItineraryAnalysis(tripId, forceRefresh: true);
      _inFlightAnalyses[tripId] = future;
      try {
        await future;
      } finally {
        _inFlightAnalyses.remove(tripId);
      }
    } while (_pendingReanalysis[tripId] == true);
  }

  static String? _effectiveMETLocationId(PlannedTrip trip) {
    final id = trip.destinationLocationId;
    if (id.startsWith('LOCATION:')) return id;
    if (id.startsWith('met:')) return id.substring(4);
    return null;
  }
}
