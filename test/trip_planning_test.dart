import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:happyway/models/planned_trip.dart';
import 'package:happyway/models/travel_location.dart';
import 'package:happyway/models/weather_info.dart';
import 'package:happyway/models/travel_route.dart';
import 'package:happyway/providers/trip_provider.dart';
import 'package:happyway/services/weather_service.dart';
import 'package:happyway/models/travel_score.dart';
import 'package:happyway/screens/trip_detail_screen.dart';
import 'package:happyway/utils/travel_score_calculator.dart';
import 'package:happyway/widgets/trip_reminder_card.dart';

void main() {
  group('PlannedTrip Model Tests', () {
    test('Correctly serializes and deserializes PlannedTrip JSON with integer ID & tripCode', () {
      final trip = PlannedTrip(
        id: 7,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        destinationLatitude: 4.4700,
        destinationLongitude: 101.3800,
        destinationImageUrl: 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07',
        travelDate: DateTime(2026, 8, 24),
        originName: 'Kuala Lumpur',
        originLatitude: 3.1390,
        originLongitude: 101.6869,
        preferredPeriod: 'Morning',
        notes: 'Visit BOH tea estate and strawberry farm',
        createdAt: DateTime(2026, 8, 21, 10, 0),
      );

      expect(trip.tripCode, 'T0007');

      final json = trip.toJson();
      final reconstructed = PlannedTrip.fromJson(json);

      expect(reconstructed.id, 7);
      expect(reconstructed.tripCode, 'T0007');
      expect(reconstructed.destinationLocationId, 'LOCATION:314');
      expect(reconstructed.destinationName, 'Cameron Highlands');
      expect(reconstructed.destinationState, 'Pahang');
      expect(reconstructed.destinationLatitude, 4.4700);
      expect(reconstructed.destinationLongitude, 101.3800);
      expect(reconstructed.originName, 'Kuala Lumpur');
      expect(reconstructed.preferredPeriod, 'Morning');
      expect(reconstructed.notes, 'Visit BOH tea estate and strawberry farm');
    });

    test('Supabase mapping creates valid payload with userId', () {
      final trip = PlannedTrip(
        id: null,
        destinationLocationId: 'LOCATION:323',
        destinationName: 'Langkawi Island',
        destinationState: 'Kedah',
        destinationCategory: 'Island',
        travelDate: DateTime(2026, 9, 1),
        originName: 'George Town',
        createdAt: DateTime(2026, 8, 21),
      );

      expect(trip.tripCode, 'New Trip');

      final payload = trip.toSupabase(userId: 'usr_abc_123');
      expect(payload['user_id'], 'usr_abc_123');
      expect(payload['destination_location_id'], 'LOCATION:323');
      expect(payload['destination_name'], 'Langkawi Island');
      expect(payload['travel_date'], '2026-09-01');
    });

    test('Computes date relative getters, weekdays and forecast eligibility correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTrip = PlannedTrip(
        id: 1,
        destinationLocationId: 'LOCATION:317',
        destinationName: 'Genting Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: today,
        originName: 'Kuala Lumpur',
        createdAt: now,
      );
      expect(todayTrip.isToday, isTrue);
      expect(todayTrip.isPast, isFalse);
      expect(todayTrip.isUpcoming, isTrue);
      expect(todayTrip.daysUntil, 0);
      expect(todayTrip.relativeDateLabel, 'Today');
      expect(todayTrip.tripCode, 'T0001');
      expect(todayTrip.isWithinForecastRange, isTrue);
      expect(todayTrip.formattedWeekday.isNotEmpty, isTrue);

      final nearTrip = PlannedTrip(
        id: 2,
        destinationLocationId: 'LOCATION:323',
        destinationName: 'Langkawi Island',
        destinationState: 'Kedah',
        destinationCategory: 'Island',
        travelDate: today.add(const Duration(days: 3)),
        originName: 'George Town',
        createdAt: now,
      );
      expect(nearTrip.isToday, isFalse);
      expect(nearTrip.isPast, isFalse);
      expect(nearTrip.isUpcoming, isTrue);
      expect(nearTrip.daysUntil, 3);
      expect(nearTrip.relativeDateLabel, 'In 3 days');
      expect(nearTrip.tripCode, 'T0002');
      expect(nearTrip.isWithinForecastRange, isTrue);

      final farTrip = PlannedTrip(
        id: 3,
        destinationLocationId: 'LOCATION:829',
        destinationName: 'Kundasang',
        destinationState: 'Sabah',
        destinationCategory: 'Highlands',
        travelDate: today.add(const Duration(days: 60)),
        originName: 'Kota Kinabalu',
        createdAt: now,
      );
      expect(farTrip.isToday, isFalse);
      expect(farTrip.isPast, isFalse);
      expect(farTrip.isUpcoming, isTrue);
      expect(farTrip.daysUntil, 60);
      expect(farTrip.relativeDateLabel, 'In 60 days');
      expect(farTrip.tripCode, 'T0003');

      expect(farTrip.isWithinForecastRange, isFalse);

      final pastTrip = PlannedTrip(
        id: 4,
        destinationLocationId: 'LOCATION:174',
        destinationName: 'Melaka',
        destinationState: 'Melaka',
        destinationCategory: 'Town',
        travelDate: today.subtract(const Duration(days: 5)),
        originName: 'Kuala Lumpur',
        createdAt: now.subtract(const Duration(days: 10)),
      );
      expect(pastTrip.isToday, isFalse);
      expect(pastTrip.isPast, isTrue);
      expect(pastTrip.isUpcoming, isFalse);
      expect(pastTrip.relativeDateLabel, 'Completed');
      expect(pastTrip.tripCode, 'T0004');
      expect(pastTrip.isWithinForecastRange, isFalse);
    });
  });

  group('Weather Forecast Horizon Data Integrity Tests', () {
    test('Rejects forecast queries beyond official MET 7-day horizon', () async {
      final weatherService = WeatherService();
      final farFutureDate = DateTime.now().add(const Duration(days: 30));

      final result = await weatherService.fetchWeatherForLocationAndDate(
        'LOCATION:314',
        farFutureDate,
      );

      expect(result, isNull,
          reason: 'Dates outside MET 7-day forecast horizon must return null to preserve official data integrity');
    });
  });

  group('Trip Forecast Status & Travel Score Tests', () {
    test('TripForecastStatus enum defines expected states', () {
      expect(TripForecastStatus.values, contains(TripForecastStatus.pending));
      expect(TripForecastStatus.values, contains(TripForecastStatus.loading));
      expect(TripForecastStatus.values, contains(TripForecastStatus.available));
      expect(TripForecastStatus.values, contains(TripForecastStatus.unavailable));
      expect(TripForecastStatus.values, contains(TripForecastStatus.error));
    });

    test('Consistent Travel Score calculation with WeatherInfo', () {
      const weather = WeatherInfo(
        condition: 'Sunny',
        iconCode: 'sunny',
        alertLevel: 'None',
        maxTemperature: 32.0,
        minTemperature: 24.0,
        morningCondition: 'No Rain',
        afternoonCondition: 'No Rain',
        nightCondition: 'No Rain',
      );

      final score = TravelScoreCalculator.calculateScore(weather: weather);
      expect(score.score, greaterThanOrEqualTo(80));

      expect(['Excellent', 'Very Good', 'Good', 'Moderate', 'Less Ideal'], contains(score.levelName));
    });
  });

  group('Destination Selection & Coordinates Separation Tests', () {
    test('Official MET TravelLocation retains exact coords and MET location ID', () {
      final loc = TravelLocation(
        id: 'met:LOCATION:314',
        name: 'Cameron Highlands',
        latitude: 4.472123,
        longitude: 101.380456,
        state: 'Pahang',
        category: 'Highlands',
        source: TravelLocationSource.metLocation,
        metLocationId: 'LOCATION:314',
        metLocationName: 'Cameron Highlands',
      );

      expect(loc.latitude, 4.472123);
      expect(loc.longitude, 101.380456);
      expect(loc.metLocationId, 'LOCATION:314');
      expect(loc.isMetLocation, isTrue);
    });

    test('Geocoded Place TravelLocation retains exact coordinates without using geo: ID as MET location', () {
      final geoLoc = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang Utara, Kuala Lumpur',
        formattedAddress: 'Jalan Jinjang Utara, 52000 Kuala Lumpur',
        latitude: 3.209400,
        longitude: 101.668200,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      expect(geoLoc.id, startsWith('geo:'));
      expect(geoLoc.latitude, 3.209400);
      expect(geoLoc.longitude, 101.668200);
      expect(geoLoc.metLocationId, 'LOCATION:234');
      expect(geoLoc.isMetLocation, isFalse);

      final String effectiveMetId = geoLoc.metLocationId ?? '';
      expect(effectiveMetId, 'LOCATION:234');
      expect(effectiveMetId.startsWith('geo:'), isFalse);
    });

    test('Geocoded Place without MET match has empty MET ID and does not send geo: to weather API', () {
      final unmappedLoc = TravelLocation.fromGeocodedPlace(
        name: 'Remote Offshore Spot',
        latitude: 2.500000,
        longitude: 105.000000,
        state: 'Unknown',
        metLocationId: null,
      );

      expect(unmappedLoc.metLocationId, isNull);
      String effectiveMetId = unmappedLoc.metLocationId ?? '';
      if (effectiveMetId.startsWith('geo:')) effectiveMetId = '';
      expect(effectiveMetId, isEmpty);
    });
  });

  group('Trip Reminder Prioritization Tests', () {
    test('PlannedTrip isTomorrow and relativeDateLabel work accurately', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final tomorrowTrip = PlannedTrip(
        id: 10,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: tomorrow,
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      expect(tomorrowTrip.isToday, isFalse);
      expect(tomorrowTrip.isTomorrow, isTrue);
      expect(tomorrowTrip.daysUntil, 1);
      expect(tomorrowTrip.relativeDateLabel, 'Tomorrow');
    });

    test('resolveTopReminder prioritizes Today trip over Tomorrow and upcoming trips', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTrip = PlannedTrip(
        id: 1,
        destinationLocationId: 'LOCATION:317',
        destinationName: 'Genting Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: today,
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final tomorrowTrip = PlannedTrip(
        id: 2,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: today.add(const Duration(days: 1)),
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final upcomingTrip = PlannedTrip(
        id: 3,
        destinationLocationId: 'LOCATION:323',
        destinationName: 'Langkawi Island',
        destinationState: 'Kedah',
        destinationCategory: 'Island',
        travelDate: today.add(const Duration(days: 4)),
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final tripProvider = TripProvider();

      final top = TripReminderCard.resolveTopReminder(
        [upcomingTrip, tomorrowTrip, todayTrip],
        tripProvider,
      );

      expect(top, isNotNull);
      expect(top!.id, todayTrip.id);
      expect(top.destinationName, 'Genting Highlands');
    });

    test('resolveTopReminder prioritizes Tomorrow trip over future upcoming trips when no today trip', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tomorrowTrip = PlannedTrip(
        id: 2,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: today.add(const Duration(days: 1)),
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final upcomingTrip = PlannedTrip(
        id: 3,
        destinationLocationId: 'LOCATION:323',
        destinationName: 'Langkawi Island',
        destinationState: 'Kedah',
        destinationCategory: 'Island',
        travelDate: today.add(const Duration(days: 5)),
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final tripProvider = TripProvider();

      final top = TripReminderCard.resolveTopReminder(
        [upcomingTrip, tomorrowTrip],
        tripProvider,
      );

      expect(top, isNotNull);
      expect(top!.id, tomorrowTrip.id);
      expect(top.destinationName, 'Cameron Highlands');
    });

    test('resolveTopReminder returns null for empty trips or past-only trips', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final pastTrip = PlannedTrip(
        id: 4,
        destinationLocationId: 'LOCATION:174',
        destinationName: 'Melaka',
        destinationState: 'Melaka',
        destinationCategory: 'Town',
        travelDate: today.subtract(const Duration(days: 2)),
        originName: 'Kuala Lumpur',
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final tripProvider = TripProvider();

      expect(TripReminderCard.resolveTopReminder([], tripProvider), isNull);
      expect(TripReminderCard.resolveTopReminder([pastTrip], tripProvider), isNull);
    });
  });

  group('MET Rain Condition & TravelScoreCalculator Tests', () {
    test('Correctly scores MET Rain condition and categorizes as rain penalty', () {
      final weather = WeatherInfo(
        condition: 'Rain',
        iconCode: 'rain',
        alertLevel: 'None',
        morningCondition: 'Tiada hujan',
        afternoonCondition: 'Rain',
        nightCondition: 'Tiada hujan',
        maxTemperature: 28.0,
        minTemperature: 20.0,
      );

      final score = TravelScoreCalculator.calculateScore(weather: weather);
      expect(score.score, isNotNull);
      expect(score.score, greaterThan(0));
      expect(score.score, lessThan(100));
      expect(score.reasons, isNotEmpty);
    });
  });

  group('TravelScore Consumer Summary & Consistency Tests', () {
    test('consumerSummary returns user-friendly phrases according to levelName', () {
      final excellentScore = TravelScore(
        score: 95,
        suitability: TravelSuitability.ideal,
        levelName: 'Excellent',
        bestTravelPeriod: 'Morning',
        recommendation: 'Technical recommendation string',
        highlights: [],
      );
      expect(excellentScore.consumerSummary, 'Great conditions expected for your trip.');

      final goodScore = TravelScore(
        score: 75,
        suitability: TravelSuitability.moderate,
        levelName: 'Good',
        bestTravelPeriod: 'Morning',
        recommendation: 'Technical recommendation string',
        highlights: [],
      );
      expect(goodScore.consumerSummary, 'Good conditions expected for your trip.');

      final moderateScore = TravelScore(
        score: 65,
        suitability: TravelSuitability.moderate,
        levelName: 'Moderate',
        bestTravelPeriod: 'Morning',
        recommendation: 'Technical recommendation string',
        highlights: [],
      );
      expect(moderateScore.consumerSummary, 'Conditions are generally suitable for your trip.');

      final challengingScore = TravelScore(
        score: 45,
        suitability: TravelSuitability.challenging,
        levelName: 'Less Ideal',
        bestTravelPeriod: 'Morning',
        recommendation: 'Technical recommendation string',
        highlights: [],
      );
      expect(challengingScore.consumerSummary, 'Less favorable conditions expected for your trip.');
    });

    test('TripProvider calculateScoreForPlannedTrip skips past trips and out-of-range trips', () async {
      final tripProvider = TripProvider();
      final now = DateTime.now();

      final pastTrip = PlannedTrip(
        id: 991,
        destinationLocationId: 'LOCATION:174',
        destinationName: 'Melaka',
        destinationState: 'Melaka',
        destinationCategory: 'Town',
        travelDate: now.subtract(const Duration(days: 3)),
        originName: 'Kuala Lumpur',
        createdAt: now.subtract(const Duration(days: 5)),
      );

      final pastScore = await tripProvider.calculateScoreForPlannedTrip(pastTrip);
      expect(pastScore, isNull);
      expect(tripProvider.isScoreLoadingForTrip(991), isFalse);

      final futureTrip = PlannedTrip(
        id: 992,
        destinationLocationId: 'LOCATION:174',
        destinationName: 'Melaka',
        destinationState: 'Melaka',
        destinationCategory: 'Town',
        travelDate: now.add(const Duration(days: 20)),
        originName: 'Kuala Lumpur',
        createdAt: now,
      );

      final futureScore = await tripProvider.calculateScoreForPlannedTrip(futureTrip);
      expect(futureScore, isNull);
      expect(tripProvider.forecastStatusForTrip(992), TripForecastStatus.pending);
      expect(tripProvider.isScoreLoadingForTrip(992), isFalse);
    });
  });

  group('TripDetailScreen Responsive Layout Tests', () {
    testWidgets('Renders on Samsung A52s dimensions (411x915) without RenderFlex overflow (Light & Dark)', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final trip = PlannedTrip(
          id: 501,
          destinationLocationId: 'LOCATION:314',
          destinationName: 'Cameron Highlands',
          destinationState: 'Pahang',
          destinationCategory: 'Highlands',
          travelDate: DateTime.now().add(const Duration(days: 2)),
          originName: 'Kuala Lumpur',
          originLatitude: 3.139,
          originLongitude: 101.686,
          destinationLatitude: 4.47,
          destinationLongitude: 101.38,
          preferredPeriod: 'Morning',
          createdAt: DateTime.now(),
        );

        final score = TravelScore(
          score: 96,
          suitability: TravelSuitability.ideal,
          levelName: 'Excellent',
          bestTravelPeriod: 'Morning',
          recommendedPeriod: 'Morning',
          bestWeatherWindow: '8:00 AM – 11:00 AM',
          recommendedDeparture: 'Around 8:00 AM',
          departureReason: 'Clear morning skies on 26 Aug at 10:45 AM',
          recommendation: 'Conditions are great.',
          highlights: ['Clear morning skies'],
        );

        final tripProvider = TripProvider();
        tripProvider.setTripScoreForTesting(
          tripId: 501,
          score: score,
          route: TravelRoute(
            originName: 'Kuala Lumpur',
            originLatitude: 3.139,
            originLongitude: 101.686,
            destinationName: 'Cameron Highlands',
            destinationLatitude: 4.47,
            destinationLongitude: 101.38,
            distanceMeters: 200000,
            distanceKm: 200.0,
            durationSeconds: 7200,
            fetchedAt: DateTime.now(),
          ),
          weather: WeatherInfo(
            condition: 'Fair',
            iconCode: 'clear',
            alertLevel: 'None',
            morningCondition: 'Tiada hujan',
            afternoonCondition: 'Tiada hujan',
            nightCondition: 'Tiada hujan',
            maxTemperature: 24.0,
            minTemperature: 16.0,
          ),
          status: TripForecastStatus.available,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light ? ThemeData.light() : ThemeData.dark(),
            home: ChangeNotifierProvider<TripProvider>.value(
              value: tripProvider,
              child: TripDetailScreen(trip: trip),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Recommended Period'), findsOneWidget);
        expect(find.text('Best Window'), findsOneWidget);
        expect(find.text('Morning'), findsWidgets);
        expect(find.text('8:00 AM – 11:00 AM'), findsOneWidget);
      }
    });

    testWidgets('Renders long Best Departure Window on narrow screen (360x800) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final trip = PlannedTrip(
        id: 502,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: DateTime.now().add(const Duration(days: 2)),
        originName: 'Kuala Lumpur',
        preferredPeriod: 'Morning',
        createdAt: DateTime.now(),
      );

      final score = TravelScore(
        score: 96,
        suitability: TravelSuitability.ideal,
        levelName: 'Excellent',
        bestTravelPeriod: 'Morning',
        recommendedPeriod: 'Morning',
        bestWeatherWindow: '6:30 AM – 10:30 AM (Extended Window)',
        recommendedDeparture: 'Around 6:30 AM',
        recommendation: 'Conditions are great.',
        highlights: ['Clear morning skies'],
      );

      final tripProvider = TripProvider();
      tripProvider.setTripScoreForTesting(
        tripId: 502,
        score: score,
        weather: WeatherInfo(
          condition: 'Fair',
          iconCode: 'clear',
          alertLevel: 'None',
          morningCondition: 'Tiada hujan',
          afternoonCondition: 'Tiada hujan',
          nightCondition: 'Tiada hujan',
          maxTemperature: 24.0,
          minTemperature: 16.0,
        ),
        status: TripForecastStatus.available,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TripProvider>.value(
            value: tripProvider,
            child: TripDetailScreen(trip: trip),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Recommended Period'), findsOneWidget);
      expect(find.text('Best Window'), findsOneWidget);
      expect(find.text('6:30 AM – 10:30 AM (Extended Window)'), findsOneWidget);
    });
  });
}
