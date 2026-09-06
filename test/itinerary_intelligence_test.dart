import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/planned_trip.dart';
import 'package:happyway/models/trip_stop.dart';
import 'package:happyway/models/weather_info.dart';
import 'package:happyway/models/travel_route.dart';
import 'package:happyway/models/itinerary_analysis.dart';
import 'package:happyway/services/route_service.dart';
import 'package:happyway/services/weather_service.dart';
import 'package:happyway/services/itinerary_analyzer.dart';
import 'package:happyway/providers/trip_provider.dart';
import 'package:happyway/utils/itinerary_top_score_deriver.dart';
import 'package:happyway/models/travel_score.dart';
import 'package:happyway/widgets/hourly_weather_sheet.dart';

class FakeRouteService implements RouteService {
  final Map<String, TravelRoute> routes = {};
  bool shouldFail = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<RouteCalculationResult> calculateRouteDetails({
    required String originName,
    required double originLat,
    required double originLng,
    required String destName,
    required double destLat,
    required double destLng,
    bool forceRefresh = false,
  }) async {
    if (shouldFail) {
      return const RouteCalculationResult.failure(
        failureReason: RouteFailureReason.networkError,
        errorMessage: 'Route unavailable',
      );
    }

    final key = '$originName->$destName';
    if (routes.containsKey(key)) {
      return RouteCalculationResult.success(routes[key]!);
    }

    return RouteCalculationResult.success(TravelRoute(
      originName: originName,
      originLatitude: originLat,
      originLongitude: originLng,
      destinationName: destName,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      distanceMeters: 8400,
      distanceKm: 8.4,
      durationSeconds: 1080,
      fetchedAt: DateTime.now(),
    ));
  }
}

class FakeWeatherService implements WeatherService {
  final Map<String, WeatherInfo> weatherMap = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<WeatherInfo?> fetchWeatherForCoordinates({
    required double latitude,
    required double longitude,
    DateTime? targetDate,
    String? locationId,
    bool forceRefresh = false,
  }) async {
    final key = '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
    return weatherMap[key];
  }
}

WeatherInfo createMockWeather(DateTime baseDate, {int baseSuitabilityWeatherCode = 0}) {
  final items = <HourlyWeatherItem>[];
  for (int h = 0; h < 48; h++) {
    final itemTime = DateTime(baseDate.year, baseDate.month, baseDate.day).add(Duration(hours: h));
    int wCode = baseSuitabilityWeatherCode;
    int precip = 10;
    if (h >= 14 && h <= 16) {
      wCode = 61;
      precip = 75;
    }
    items.add(HourlyWeatherItem(
      time: itemTime,
      timeLabel: '${itemTime.hour}:00',
      temperature: 29.0,
      condition: wCode == 61 ? 'Rain' : 'Partly Cloudy',
      iconCode: wCode == 61 ? 'rain' : 'partly_cloudy',
      precipitationProbability: precip,
      weatherCode: wCode,
    ));
  }

  return WeatherInfo(
    condition: 'Partly Cloudy',
    iconCode: 'partly_cloudy',
    alertLevel: 'none',
    hourlyForecast: items,
  );
}

void main() {
  group('Itinerary Analysis Models', () {
    test('ItinerarySegmentAnalysis formats distance and duration correctly', () {
      const segment = ItinerarySegmentAnalysis(
        fromName: 'Origin Point',
        fromLatitude: 5.4141,
        fromLongitude: 100.3288,
        toName: 'Kek Lok Si',
        toLatitude: 5.3995,
        toLongitude: 100.2737,
        distanceKm: 8.4,
        durationMinutes: 18,
        isRouteAvailable: true,
      );

      expect(segment.distanceFormatted, '8.4 km');
      expect(segment.durationFormatted, '18 min');
      expect(segment.summaryText, '8.4 km · 18 min drive');
    });

    test('ItinerarySegmentAnalysis handles unavailable route', () {
      const segment = ItinerarySegmentAnalysis(
        fromName: 'Island A',
        fromLatitude: 0.0,
        fromLongitude: 0.0,
        toName: 'Island B',
        toLatitude: 0.0,
        toLongitude: 0.0,
        isRouteAvailable: false,
      );

      expect(segment.distanceFormatted, 'Distance unavailable');
      expect(segment.durationFormatted, 'Drive time unavailable');
      expect(segment.summaryText, 'Route unavailable');
    });

    test('ItineraryStopAnalysis rounds suggested departure to nearest 5 minutes', () {
      final stop = TripStop(
        tripId: 1,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.4,
        longitude: 100.3,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = ItineraryStopAnalysis(
        stop: stop,
        isWeatherAvailable: true,
        suggestedDepartureDateTime: DateTime(2026, 11, 4, 13, 27),
      );

      expect(analysis.suggestedDepartureFormatted, 'Around 1:25 PM');

      final analysis2 = ItineraryStopAnalysis(
        stop: stop,
        isWeatherAvailable: true,
        suggestedDepartureDateTime: DateTime(2026, 11, 4, 13, 28),
      );

      expect(analysis2.suggestedDepartureFormatted, 'Around 1:30 PM');
    });

    test('ItineraryStopAnalysis displays date on estimated arrival when crossing midnight', () {
      final stop = TripStop(
        tripId: 1,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.4,
        longitude: 100.3,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = ItineraryStopAnalysis(
        stop: stop,
        isWeatherAvailable: true,
        estimatedArrivalDateTime: DateTime(2026, 11, 5, 0, 40),
      );

      expect(analysis.estimatedArrivalFormatted, '5 Nov · 12:40 AM');
    });
  });

  group('ItineraryAnalyzer Route Chaining', () {
    late FakeRouteService fakeRouteService;
    late FakeWeatherService fakeWeatherService;
    late ItineraryAnalyzer analyzer;

    setUp(() {
      fakeRouteService = FakeRouteService();
      fakeWeatherService = FakeWeatherService();
      analyzer = ItineraryAnalyzer(
        routeService: fakeRouteService,
        weatherService: fakeWeatherService,
      );
    });

    test('Day 1 first stop routes from Trip origin, later stop routes from previous stop', () async {
      final trip = PlannedTrip(
        id: 10,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'George Town Hotel',
        originLatitude: 5.4164,
        originLongitude: 100.3327,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop1 = TripStop(
        id: 1,
        tripId: 10,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kek Lok Si Temple',
        latitude: 5.3995,
        longitude: 100.2737,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '09:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final stop2 = TripStop(
        id: 2,
        tripId: 10,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Penang Hill Lower Station',
        latitude: 5.4085,
        longitude: 100.2771,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '11:45:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1, stop2],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      expect(analysis.days.length, 1);
      final day1 = analysis.days.first;
      expect(day1.stops.length, 2);

      expect(day1.segments[0].fromName, 'George Town Hotel');
      expect(day1.segments[0].toName, 'Kek Lok Si Temple');
      expect(day1.segments[0].isRouteAvailable, isTrue);

      expect(day1.segments[1].fromName, 'Kek Lok Si Temple');
      expect(day1.segments[1].toName, 'Penang Hill Lower Station');
      expect(day1.segments[1].isRouteAvailable, isTrue);
    });

    test('Later days first stop routes from previous day last stop', () async {
      final trip = PlannedTrip(
        id: 20,
        startDate: DateTime(2026, 11, 4),
        endDate: DateTime(2026, 11, 5),
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Penang Airport',
        originLatitude: 5.2971,
        originLongitude: 100.2768,
        createdAt: DateTime(2026, 10, 1),
      );

      final day1Stop = TripStop(
        id: 101,
        tripId: 20,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Batu Ferringhi Resort',
        latitude: 5.4740,
        longitude: 100.2500,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '15:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final day2Stop = TripStop(
        id: 102,
        tripId: 20,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Escape Theme Park',
        latitude: 5.4490,
        longitude: 100.2150,
        visitDate: DateTime(2026, 11, 5),
        timeMode: 'exact',
        plannedArrivalTime: '10:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [day1Stop, day2Stop],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      expect(analysis.days.length, 2);
      final day1 = analysis.days[0];
      final day2 = analysis.days[1];

      expect(day1.segments[0].fromName, 'Penang Airport');
      expect(day1.segments[0].toName, 'Batu Ferringhi Resort');

      expect(day2.segments[0].fromName, 'Batu Ferringhi Resort');
      expect(day2.segments[0].toName, 'Escape Theme Park');
    });

    test('Route failure marks segment as unavailable without throwing', () async {
      fakeRouteService.shouldFail = true;

      final trip = PlannedTrip(
        id: 30,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'George Town',
        originLatitude: 5.4164,
        originLongitude: 100.3327,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop = TripStop(
        id: 201,
        tripId: 30,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Remote Island',
        latitude: 5.8000,
        longitude: 100.5000,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '10:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      expect(analysis.days.first.segments.first.isRouteAvailable, isFalse);
      expect(analysis.days.first.stops.first.plannedArrivalFormatted, '10:00 AM');
    });
  });

  group('ItineraryAnalyzer Timing & Conflicts', () {
    late FakeRouteService fakeRouteService;
    late FakeWeatherService fakeWeatherService;
    late ItineraryAnalyzer analyzer;

    setUp(() {
      fakeRouteService = FakeRouteService();
      fakeWeatherService = FakeWeatherService();
      analyzer = ItineraryAnalyzer(
        routeService: fakeRouteService,
        weatherService: fakeWeatherService,
      );
    });

    test('Exact time stop calculates suggested departure with 5 min buffer', () async {
      final trip = PlannedTrip(
        id: 40,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Origin',
        originLatitude: 5.41,
        originLongitude: 100.33,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop = TripStop(
        id: 301,
        tripId: 40,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Meeting Spot',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '14:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      final stopAnalysis = analysis.days.first.stops.first;
      expect(stopAnalysis.plannedArrivalFormatted, '2:00 PM');
      expect(stopAnalysis.suggestedDepartureFormatted, 'Around 1:35 PM');
    });

    test('Timing conflict detected when previous stop departure prevents on-time arrival', () async {
      fakeRouteService.routes['Stop 1->Stop 2'] = TravelRoute(
        originName: 'Stop 1',
        originLatitude: 5.41,
        originLongitude: 100.33,
        destinationName: 'Stop 2',
        destinationLatitude: 5.42,
        destinationLongitude: 100.34,
        distanceMeters: 25000,
        distanceKm: 25.0,
        durationSeconds: 3300,
        fetchedAt: DateTime.now(),
      );

      final trip = PlannedTrip(
        id: 50,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Origin',
        originLatitude: 5.40,
        originLongitude: 100.30,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop1 = TripStop(
        id: 401,
        tripId: 50,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.41,
        longitude: 100.33,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '13:00:00',
        plannedDepartureTime: '14:30:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final stop2 = TripStop(
        id: 402,
        tripId: 50,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Stop 2',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '15:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1, stop2],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      final stop2Analysis = analysis.days.first.stops[1];
      expect(stop2Analysis.hasTimingConflict, isTrue);
      expect(stop2Analysis.timingConflictText, contains('You may arrive around 3:25 PM'));
    });

    test('No timing conflict fabricated when previous stop has no planned departure time', () async {
      fakeRouteService.routes['Stop 1->Stop 2'] = TravelRoute(
        originName: 'Stop 1',
        originLatitude: 5.41,
        originLongitude: 100.33,
        destinationName: 'Stop 2',
        destinationLatitude: 5.42,
        destinationLongitude: 100.34,
        distanceMeters: 25000,
        distanceKm: 25.0,
        durationSeconds: 3300,
        fetchedAt: DateTime.now(),
      );

      final trip = PlannedTrip(
        id: 51,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Origin',
        originLatitude: 5.40,
        originLongitude: 100.30,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop1 = TripStop(
        id: 411,
        tripId: 51,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.41,
        longitude: 100.33,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '13:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final stop2 = TripStop(
        id: 412,
        tripId: 51,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Stop 2',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '15:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1, stop2],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      final stop2Analysis = analysis.days.first.stops[1];
      expect(stop2Analysis.hasTimingConflict, isFalse);
    });

    test('Flexible stop chooses best weather window within preferred period', () async {
      final visitDate = DateTime(2026, 11, 4);
      final weather = createMockWeather(visitDate);
      fakeWeatherService.weatherMap['5.42,100.34'] = weather;

      final trip = PlannedTrip(
        id: 60,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: visitDate,
        originName: 'Origin',
        originLatitude: 5.40,
        originLongitude: 100.30,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop = TripStop(
        id: 501,
        tripId: 60,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Botanical Gardens',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: visitDate,
        timeMode: 'flexible',
        preferredPeriod: 'Afternoon',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      final stopAnalysis = analysis.days.first.stops.first;
      expect(stopAnalysis.recommendedArrivalDateTime, isNotNull);
      expect(stopAnalysis.recommendedArrivalDateTime!.hour >= 12, isTrue);
      expect(stopAnalysis.recommendedArrivalDateTime!.hour <= 17, isTrue);
      expect(stopAnalysis.weatherSuitability, isNotNull);
    });

    test('Auto preferred period compares morning, afternoon, and night', () async {
      final visitDate = DateTime(2026, 11, 4);
      final weather = createMockWeather(visitDate);
      fakeWeatherService.weatherMap['5.42,100.34'] = weather;

      final trip = PlannedTrip(
        id: 70,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: visitDate,
        originName: 'Origin',
        originLatitude: 5.40,
        originLongitude: 100.30,
        createdAt: DateTime(2026, 10, 1),
      );

      final stop = TripStop(
        id: 601,
        tripId: 70,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Penang National Park',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: visitDate,
        timeMode: 'flexible',
        preferredPeriod: 'Auto',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop],
        currentTimeOverride: DateTime(2026, 11, 1, 8, 0),
      );

      final stopAnalysis = analysis.days.first.stops.first;
      expect(stopAnalysis.recommendedArrivalDateTime, isNotNull);
      expect(stopAnalysis.recommendedArrivalDateTime!.hour != 14, isTrue);
    });

    test('Today past-time rule does not recommend elapsed hours', () async {
      final today = DateTime(2026, 9, 6);
      final now = DateTime(2026, 9, 6, 15, 0);

      final trip = PlannedTrip(
        id: 80,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: today,
        originName: 'Origin',
        originLatitude: 5.40,
        originLongitude: 100.30,
        createdAt: DateTime(2026, 9, 1),
      );

      final stop = TripStop(
        id: 701,
        tripId: 80,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Cafe Stop',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: today,
        timeMode: 'flexible',
        preferredPeriod: 'Afternoon',
        createdAt: DateTime(2026, 9, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop],
        currentTimeOverride: now,
      );

      final stopAnalysis = analysis.days.first.stops.first;
      expect(stopAnalysis.recommendedArrivalDateTime!.isAfter(now), isTrue);
    });
  });

  group('TripProvider Itinerary Analysis Integration', () {
    test('Provider stores and invalidates itinerary analysis', () {
      final provider = TripProvider(autoLoad: false, listenToAuth: false);

      final mockAnalysis = ItineraryAnalysis(
        tripId: 99,
        days: const [],
        analyzedAt: DateTime(2026, 11, 4),
      );

      provider.setItineraryAnalysisForTesting(99, mockAnalysis);
      expect(provider.getItineraryAnalysis(99), equals(mockAnalysis));

      provider.clearUserData();
      expect(provider.getItineraryAnalysis(99), isNull);
    });

    test('Provider manages per-day starting points and defaults', () {
      final provider = TripProvider(autoLoad: false, listenToAuth: false);
      final trip = PlannedTrip(
        id: 99,
        startDate: DateTime(2026, 11, 4),
        endDate: DateTime(2026, 11, 6),
        originName: 'Home',
        originLatitude: 3.14,
        originLongitude: 101.69,
        travelDate: DateTime(2026, 11, 4),
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        createdAt: DateTime.now(),
      );

      final day1Stop = TripStop(
        id: 1,
        tripId: 99,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Maritime Suites',
        latitude: 5.39,
        longitude: 100.32,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      );

      final day1Start = provider.getEffectiveDayStart(99, DateTime(2026, 11, 4), [day1Stop], trip);
      expect(day1Start.name, 'Home');

      final day2Default = provider.getEffectiveDayStart(99, DateTime(2026, 11, 5), [day1Stop], trip);
      expect(day2Default.name, 'Maritime Suites');

      provider.setDayStartingPoint(99, DateTime(2026, 11, 5), 'Penang Airport', 5.29, 100.27);
      expect(provider.getDayStartingPoint(99, DateTime(2026, 11, 5))?.name, 'Penang Airport');

      final day2Overridden = provider.getEffectiveDayStart(99, DateTime(2026, 11, 5), [day1Stop], trip);
      expect(day2Overridden.name, 'Penang Airport');

      provider.clearDayStartingPoint(99, DateTime(2026, 11, 5));
      expect(provider.getDayStartingPoint(99, DateTime(2026, 11, 5)), isNull);

      final day2Reverted = provider.getEffectiveDayStart(99, DateTime(2026, 11, 5), [day1Stop], trip);
      expect(day2Reverted.name, 'Maritime Suites');
    });
  });

  group('Per-Day Starting Point Route Analysis', () {
    late FakeRouteService fakeRouteService;
    late FakeWeatherService fakeWeatherService;
    late ItineraryAnalyzer analyzer;

    setUp(() {
      fakeRouteService = FakeRouteService();
      fakeWeatherService = FakeWeatherService();
      analyzer = ItineraryAnalyzer(
        routeService: fakeRouteService,
        weatherService: fakeWeatherService,
      );
    });

    test('Custom starting point override is used for first stop of day', () async {
      final trip = PlannedTrip(
        id: 200,
        startDate: DateTime(2026, 11, 4),
        endDate: DateTime(2026, 11, 5),
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Home',
        originLatitude: 3.14,
        originLongitude: 101.69,
        createdAt: DateTime(2026, 10, 1),
      );

      final day1Stop = TripStop(
        id: 201,
        tripId: 200,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Maritime Suites',
        latitude: 5.39,
        longitude: 100.32,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '18:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final day2Stop = TripStop(
        id: 202,
        tripId: 200,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kek Lok Si',
        latitude: 5.40,
        longitude: 100.27,
        visitDate: DateTime(2026, 11, 5),
        timeMode: 'exact',
        plannedArrivalTime: '10:00:00',
        createdAt: DateTime(2026, 10, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [day1Stop, day2Stop],
        dayStartOverrides: {
          DateTime(2026, 11, 5): (name: 'Penang Airport', lat: 5.29, lng: 100.27),
        },
      );

      expect(analysis.days.length, 2);
      final day2 = analysis.days[1];
      expect(day2.segments.first.fromName, 'Penang Airport');
      expect(day2.segments.first.toName, 'Kek Lok Si');
      expect(day2.stops.first.suggestedDepartureDateTime, isNotNull);
      expect(day2.stops.first.estimatedArrivalDateTime, isNotNull);
    });

    test('3-day override scenario preserves custom starting points and handles reset', () {
      final provider = TripProvider(autoLoad: false, listenToAuth: false);
      final trip = PlannedTrip(
        id: 300,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 3),
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 11, 1),
        originName: 'Home',
        originLatitude: 3.14,
        originLongitude: 101.69,
        createdAt: DateTime(2026, 10, 1),
      );

      final stopDay1 = TripStop(
        id: 301,
        tripId: 300,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kedai Kopi Kong Lean',
        latitude: 5.41,
        longitude: 100.33,
        visitDate: DateTime(2026, 11, 1),
        createdAt: DateTime(2026, 10, 1),
      );

      final stopDay2 = TripStop(
        id: 302,
        tripId: 300,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kek Lok Si Temple',
        latitude: 5.40,
        longitude: 100.27,
        visitDate: DateTime(2026, 11, 2),
        createdAt: DateTime(2026, 10, 1),
      );

      final allStops = [stopDay1, stopDay2];

      provider.setDayStartingPoint(
        300,
        DateTime(2026, 11, 1),
        'Current Location',
        3.15,
        101.70,
        address: 'Jalan Genting Kelang, KL',
      );
      provider.setDayStartingPoint(
        300,
        DateTime(2026, 11, 2),
        'Maritime Suites',
        5.39,
        100.32,
        address: 'Persiaran Karpal Singh',
      );
      provider.setDayStartingPoint(
        300,
        DateTime(2026, 11, 3),
        stopDay1.locationName,
        stopDay1.latitude,
        stopDay1.longitude,
        locationId: stopDay1.locationId,
        sourceType: stopDay1.sourceType,
        address: stopDay1.address,
      );

      final day1 = provider.getEffectiveDayStart(300, DateTime(2026, 11, 1), allStops, trip);
      final day2 = provider.getEffectiveDayStart(300, DateTime(2026, 11, 2), allStops, trip);
      final day3 = provider.getEffectiveDayStart(300, DateTime(2026, 11, 3), allStops, trip);

      expect(day1.name, 'Current Location');
      expect(day1.address, 'Jalan Genting Kelang, KL');
      expect(day2.name, 'Maritime Suites');
      expect(day2.address, 'Persiaran Karpal Singh');
      expect(day3.name, 'Kedai Kopi Kong Lean');

      provider.clearDayStartingPoint(300, DateTime(2026, 11, 2));

      final day2Reset = provider.getEffectiveDayStart(300, DateTime(2026, 11, 2), allStops, trip);
      expect(day2Reset.name, 'Kedai Kopi Kong Lean');

      final day3StillOverridden = provider.getEffectiveDayStart(300, DateTime(2026, 11, 3), allStops, trip);
      expect(day3StillOverridden.name, 'Kedai Kopi Kong Lean');
    });

    test('single-stop trip top score independently calculated from trip context', () {
      final trip = PlannedTrip(
        id: 400,
        userId: 'u1',
        tripName: 'Cameron Single Stop',
        originName: 'Kuala Lumpur',
        destinationName: 'Cameron Highlands',
        destinationLocationId: 'loc_cameron',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: DateTime(2026, 9, 7),
        startDate: DateTime(2026, 9, 7),
        endDate: DateTime(2026, 9, 7),
        createdAt: DateTime(2026, 9, 1),
      );

      final stop1 = TripStop(
        id: 401,
        tripId: 400,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Boh Tea Centre',
        latitude: 4.51,
        longitude: 101.41,
        visitDate: DateTime(2026, 9, 7),
        plannedArrivalTime: '06:00',
        timeMode: 'exact',
        createdAt: DateTime(2026, 9, 1),
      );

      final segment = ItinerarySegmentAnalysis(
        fromName: 'Kuala Lumpur',
        fromLatitude: 3.14,
        fromLongitude: 101.69,
        toName: 'Boh Tea Centre',
        toLatitude: 4.51,
        toLongitude: 101.41,
        distanceKm: 205.0,
        durationMinutes: 125,
        isRouteAvailable: true,
      );

      final stopAnalysis = ItineraryStopAnalysis(
        stop: stop1,
        isWeatherAvailable: true,
        weatherSuitability: 88,
        routeFromPrevious: segment,
        plannedArrivalDateTime: DateTime(2026, 9, 7, 6, 0),
        recommendedArrivalDateTime: DateTime(2026, 9, 7, 6, 0),
        suggestedDepartureDateTime: DateTime(2026, 9, 7, 3, 55),
        estimatedArrivalDateTime: DateTime(2026, 9, 7, 6, 0),
        weatherAtArrival: HourlyWeatherItem(
          time: DateTime(2026, 9, 7, 6, 0),
          timeLabel: '06:00',
          temperature: 18.0,
          condition: 'Clear',
          iconCode: 'clear',
          precipitationProbability: 0,
        ),
      );

      final topScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: stopAnalysis,
        totalStops: 1,
      );

      expect(topScore.score, 88);
      expect(topScore.recommendedDeparture, 'Around 6:00 AM');
      expect(topScore.bestWeatherWindow, 'Around 8:00 AM');
      expect(topScore.recommendedPeriod, 'Morning');
      expect(topScore.explanationBullets.any((b) => b.contains('205 km') || b.contains('drive')), isTrue);
    });

    test('multi-stop trip top score calculated independently from Stop 1 timing', () {
      final trip = PlannedTrip(
        id: 500,
        userId: 'u1',
        tripName: 'Penang Multi Stop',
        originName: 'Kuala Lumpur',
        destinationName: 'George Town',
        destinationLocationId: 'loc_georgetown',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 9, 7),
        startDate: DateTime(2026, 9, 7),
        endDate: DateTime(2026, 9, 8),
        createdAt: DateTime(2026, 9, 1),
      );

      final stop1 = TripStop(
        id: 501,
        tripId: 500,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Ipoh Old Town',
        latitude: 4.59,
        longitude: 101.07,
        visitDate: DateTime(2026, 9, 7),
        preferredPeriod: 'afternoon',
        timeMode: 'flexible',
        createdAt: DateTime(2026, 9, 1),
      );

      final segment = ItinerarySegmentAnalysis(
        fromName: 'Kuala Lumpur',
        fromLatitude: 3.14,
        fromLongitude: 101.69,
        toName: 'Ipoh Old Town',
        toLatitude: 4.59,
        toLongitude: 101.07,
        distanceKm: 200.0,
        durationMinutes: 120,
        isRouteAvailable: true,
      );

      final stopAnalysis = ItineraryStopAnalysis(
        stop: stop1,
        isWeatherAvailable: true,
        weatherSuitability: 82,
        routeFromPrevious: segment,
        recommendedArrivalDateTime: DateTime(2026, 9, 7, 14, 0),
        suggestedDepartureDateTime: DateTime(2026, 9, 7, 11, 55),
        estimatedArrivalDateTime: DateTime(2026, 9, 7, 14, 0),
        betterWeatherWindow: '2:00 PM - 4:00 PM',
      );

      final topScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: stopAnalysis,
        totalStops: 3,
      );

      expect(topScore.score, 82);
      expect(topScore.recommendedDeparture, 'Around 6:00 AM');
      expect(topScore.bestWeatherWindow, 'Around 8:00 AM');
      expect(topScore.recommendedPeriod, 'Morning');
      expect(topScore.explanationBullets.any((b) => b.contains('3 stops')), isTrue);
      expect(topScore.explanationBullets.any((b) => b.contains('Leg 1')), isTrue);
    });

    test('editing Stop 1 preferredPeriod recalculates itinerary while top Travel Suitability remains independent', () async {
      final fakeRouteService = FakeRouteService();
      final fakeWeatherService = FakeWeatherService();
      final analyzer = ItineraryAnalyzer(
        routeService: fakeRouteService,
        weatherService: fakeWeatherService,
      );

      final tripDate = DateTime(2026, 9, 8);
      final weather = createMockWeather(tripDate);
      fakeWeatherService.weatherMap['4.51,101.41'] = weather;

      final trip = PlannedTrip(
        id: 700,
        userId: 'u1',
        tripName: 'Cameron Independent Test',
        originName: 'Kuala Lumpur',
        originLatitude: 3.14,
        originLongitude: 101.69,
        destinationName: 'Cameron Highlands',
        destinationLocationId: 'loc_cameron',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: tripDate,
        startDate: tripDate,
        endDate: tripDate,
        createdAt: DateTime(2026, 9, 1),
      );

      final stop1Morning = TripStop(
        id: 701,
        tripId: 700,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Boh Tea Centre',
        latitude: 4.51,
        longitude: 101.41,
        visitDate: tripDate,
        preferredPeriod: 'morning',
        timeMode: 'flexible',
        createdAt: DateTime(2026, 9, 1),
      );

      final initialAnalysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1Morning],
        currentTimeOverride: DateTime(2026, 9, 1, 8, 0),
      );

      final initialStop1 = initialAnalysis.days.first.stops.first;
      final initialTopScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: initialStop1,
        totalStops: 1,
      );

      final stop1Afternoon = stop1Morning.copyWith(preferredPeriod: 'afternoon');

      final updatedAnalysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1Afternoon],
        currentTimeOverride: DateTime(2026, 9, 1, 8, 0),
      );

      final updatedStop1 = updatedAnalysis.days.first.stops.first;
      final updatedTopScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: updatedStop1,
        totalStops: 1,
      );

      expect(updatedTopScore.recommendedPeriod, initialTopScore.recommendedPeriod);
      expect(updatedTopScore.bestWeatherWindow, initialTopScore.bestWeatherWindow);
      expect(updatedTopScore.recommendedDeparture, initialTopScore.recommendedDeparture);
      expect(updatedTopScore.score, initialTopScore.score);

      expect(updatedStop1.stop.preferredPeriod, 'afternoon');
      expect(updatedStop1.recommendedArrivalDateTime, isNot(initialStop1.recommendedArrivalDateTime));
      expect(updatedStop1.suggestedDepartureDateTime, isNot(initialStop1.suggestedDepartureDateTime));
      expect(updatedStop1.suggestedDepartureFormatted, isNot(initialStop1.suggestedDepartureFormatted));
    });

    testWidgets('Hourly weather sheet displays correct stop name, date, and items', (tester) async {
      final visit = DateTime(2026, 9, 8);
      final stop = TripStop(
        id: 1,
        tripId: 10,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kek Lok Si Temple',
        latitude: 5.3995,
        longitude: 100.2737,
        visitDate: visit,
        timeMode: 'exact',
        plannedArrivalTime: '10:00:00',
        createdAt: DateTime(2026, 9, 1),
      );

      final weather = createMockWeather(visit);
      final analysis = ItineraryStopAnalysis(
        stop: stop,
        weather: weather,
        isWeatherAvailable: true,
        plannedArrivalDateTime: DateTime(2026, 9, 8, 10, 0),
        recommendedArrivalDateTime: DateTime(2026, 9, 8, 10, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourlyWeatherSheet(stop: stop, analysis: analysis),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hourly Weather'), findsOneWidget);
      expect(find.text('Kek Lok Si Temple'), findsOneWidget);
      expect(find.textContaining('8 Sep 2026'), findsOneWidget);
      expect(find.text('Planned'), findsOneWidget);
    });

    testWidgets('Hourly weather sheet displays empty state when forecast unavailable', (tester) async {
      final visit = DateTime(2026, 9, 8);
      final stop = TripStop(
        id: 2,
        tripId: 10,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Remote Viewpoint',
        latitude: 5.4,
        longitude: 100.3,
        visitDate: visit,
        timeMode: 'flexible',
        createdAt: DateTime(2026, 9, 1),
      );

      final analysis = ItineraryStopAnalysis(
        stop: stop,
        weather: null,
        isWeatherAvailable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HourlyWeatherSheet(stop: stop, analysis: analysis),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hourly forecast is not available yet.'), findsOneWidget);
    });

    test('Estimated arrival calculated consistently for multi-stop itinerary without previous departure', () async {
      final analyzer = ItineraryAnalyzer(
        routeService: fakeRouteService,
        weatherService: fakeWeatherService,
      );

      final trip = PlannedTrip(
        id: 99,
        destinationLocationId: 'met:1',
        destinationName: 'Penang',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 9, 8),
        originName: 'Hotel',
        originLatitude: 5.41,
        originLongitude: 100.33,
        createdAt: DateTime(2026, 9, 1),
      );

      final stop1 = TripStop(
        id: 1,
        tripId: 99,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.41,
        longitude: 100.33,
        visitDate: DateTime(2026, 9, 8),
        timeMode: 'exact',
        plannedArrivalTime: '10:00:00',
        createdAt: DateTime(2026, 9, 1),
      );

      final stop2 = TripStop(
        id: 2,
        tripId: 99,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Stop 2',
        latitude: 5.42,
        longitude: 100.34,
        visitDate: DateTime(2026, 9, 8),
        timeMode: 'exact',
        plannedArrivalTime: '13:00:00',
        createdAt: DateTime(2026, 9, 1),
      );

      final analysis = await analyzer.analyzeTrip(
        trip: trip,
        stops: [stop1, stop2],
        currentTimeOverride: DateTime(2026, 9, 1, 8, 0),
      );

      final stop2Analysis = analysis.days.first.stops[1];
      expect(stop2Analysis.suggestedDepartureDateTime, isNotNull);
      expect(stop2Analysis.estimatedArrivalDateTime, isNotNull);
      expect(
        stop2Analysis.estimatedArrivalDateTime,
        stop2Analysis.suggestedDepartureDateTime!.add(
          Duration(minutes: stop2Analysis.routeFromPrevious!.durationMinutes!),
        ),
      );
    });

    test('ItineraryTopScoreDeriver uses centralized TravelScoreCalculator and is not defaulting to 100', () {
      final trip = PlannedTrip(
        id: 77,
        userId: 'u1',
        tripName: 'Trip Test',
        originName: 'KL',
        destinationName: 'Penang',
        destinationLocationId: 'met:1',
        destinationState: 'Penang',
        destinationCategory: 'Town',
        travelDate: DateTime(2026, 9, 8),
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 8),
        createdAt: DateTime(2026, 9, 1),
      );

      final stop = TripStop(
        id: 1,
        tripId: 77,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Stop 1',
        latitude: 5.41,
        longitude: 100.33,
        visitDate: DateTime(2026, 9, 8),
        preferredPeriod: 'afternoon',
        timeMode: 'flexible',
        createdAt: DateTime(2026, 9, 1),
      );

      final weather = createMockWeather(DateTime(2026, 9, 8), baseSuitabilityWeatherCode: 61);
      final route = TravelRoute(
        originName: 'KL',
        originLatitude: 3.14,
        originLongitude: 101.69,
        destinationName: 'Penang',
        destinationLatitude: 5.41,
        destinationLongitude: 100.33,
        distanceMeters: 350000,
        distanceKm: 350.0,
        durationSeconds: 14400,
        fetchedAt: DateTime.now(),
      );

      final segment = ItinerarySegmentAnalysis(
        fromName: 'KL',
        fromLatitude: 3.14,
        fromLongitude: 101.69,
        toName: 'Stop 1',
        toLatitude: 5.41,
        toLongitude: 100.33,
        distanceKm: 350.0,
        durationMinutes: 240,
        route: route,
        isRouteAvailable: true,
      );

      final stopAnalysis = ItineraryStopAnalysis(
        stop: stop,
        weather: weather,
        isWeatherAvailable: true,
        weatherSuitability: 100,
        routeFromPrevious: segment,
        recommendedArrivalDateTime: DateTime(2026, 9, 8, 14, 0),
        suggestedDepartureDateTime: DateTime(2026, 9, 8, 9, 55),
      );

      final topScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: stopAnalysis,
        totalStops: 1,
      );

      expect(topScore.score, isNot(100));
      expect(topScore.score, lessThan(90));
      expect(topScore.weatherSubscore, isNotNull);
      expect(topScore.journeySubscore, isNotNull);
    });

    test('ItineraryTopScoreDeriver strictly preserves canonical trip score when fallbackScore is provided', () {
      final trip = PlannedTrip(
        id: 77,
        userId: 'u1',
        tripName: 'Trip Test',
        originName: 'KL',
        destinationName: 'Cameron Highlands',
        destinationLocationId: 'met:1',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: DateTime(2026, 9, 8),
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 8),
        createdAt: DateTime(2026, 9, 1),
      );

      final stop = TripStop(
        id: 1,
        tripId: 77,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Boh Tea Centre',
        latitude: 4.51,
        longitude: 101.41,
        visitDate: DateTime(2026, 9, 8),
        preferredPeriod: 'morning',
        timeMode: 'flexible',
        createdAt: DateTime(2026, 9, 1),
      );

      final weather = createMockWeather(DateTime(2026, 9, 8), baseSuitabilityWeatherCode: 0);
      final segment = ItinerarySegmentAnalysis(
        fromName: 'KL',
        fromLatitude: 3.14,
        fromLongitude: 101.69,
        toName: 'Boh Tea Centre',
        toLatitude: 4.51,
        toLongitude: 101.41,
        distanceKm: 210.0,
        durationMinutes: 180,
        isRouteAvailable: true,
      );

      final stopAnalysis = ItineraryStopAnalysis(
        stop: stop,
        weather: weather,
        isWeatherAvailable: true,
        weatherSuitability: 95,
        routeFromPrevious: segment,
      );

      final canonicalTripScore = TravelScore(
        score: 79,
        weatherSubscore: 82,
        journeySubscore: 74,
        suitability: TravelSuitability.moderate,
        levelName: 'Good',
        bestTravelPeriod: 'Morning',
        recommendation: 'Good conditions planned for your trip.',
        highlights: const ['Destination forecast stable.'],
      );

      final topScore = ItineraryTopScoreDeriver.derive(
        trip: trip,
        firstStopAnalysis: stopAnalysis,
        totalStops: 1,
        fallbackScore: canonicalTripScore,
      );

      expect(topScore.score, 79);
      expect(topScore.weatherSubscore, 82);
      expect(topScore.journeySubscore, 74);
      expect(topScore.levelName, 'Good');
      expect(topScore.bestTravelPeriod, 'Morning');
    });
  });
}
