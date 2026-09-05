import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/weather_info.dart';
import 'package:happyway/models/travel_route.dart';
import 'package:happyway/models/user_location.dart';
import 'package:happyway/models/travel_score.dart';
import 'package:happyway/utils/travel_score_calculator.dart';

void main() {
  group('TravelRoute Model Tests', () {
    test('Correctly parses OSRM JSON and formats distance and duration', () {
      final mockOsrmJson = {
        'code': 'Ok',
        'routes': [
          {
            'distance': 206300.0,
            'duration': 11880.0,
          }
        ]
      };

      final route = TravelRoute.fromOsrmJson(
        json: mockOsrmJson,
        originName: 'Kuala Lumpur',
        originLat: 3.1390,
        originLng: 101.6869,
        destName: 'Cameron Highlands',
        destLat: 4.4700,
        destLng: 101.3800,
      );

      expect(route.distanceKm, 206.3);
      expect(route.durationMinutes, 198);
      expect(route.distanceFormatted, '206 km');
      expect(route.durationFormatted, '3 hr 18 min');
      expect(route.originName, 'Kuala Lumpur');
      expect(route.destinationName, 'Cameron Highlands');
    });

    test('Formats short duration correctly (< 1 hour)', () {
      final mockShortRoute = {
        'code': 'Ok',
        'routes': [
          {
            'distance': 15200.0,
            'duration': 1500.0,
          }
        ]
      };

      final route = TravelRoute.fromOsrmJson(
        json: mockShortRoute,
        originName: 'Petaling Jaya',
        originLat: 3.1073,
        originLng: 101.6067,
        destName: 'Kuala Lumpur',
        destLat: 3.1390,
        destLng: 101.6869,
      );

      expect(route.distanceFormatted, '15.2 km');
      expect(route.durationFormatted, '25 min');
    });
  });

  group('UserLocation Model Tests', () {
    test('GPS user location attributes', () {
      final gpsLoc = UserLocation.fromGps(
        latitude: 5.4141,
        longitude: 100.3288,
        accuracy: 10.0,
        reverseGeocodedAddress: 'George Town, Penang',
      );

      expect(gpsLoc.isGps, isTrue);
      expect(gpsLoc.name, 'Current Location');
      expect(gpsLoc.subtitle, 'Device GPS (±10m)');
      expect(gpsLoc.reverseGeocodedAddress, 'George Town, Penang');
    });

    test('Manual user location attributes', () {
      const manualLoc = UserLocation(
        name: 'Ipoh',
        latitude: 4.5975,
        longitude: 101.0901,
        subtitle: 'Perak (Manually Selected)',
        type: UserLocationType.selectedPlace,
      );

      expect(manualLoc.isGps, isFalse);
      expect(manualLoc.name, 'Ipoh');
      expect(manualLoc.subtitle, contains('Manually Selected'));
    });
  });

  group('TravelScoreCalculator Data Integrity & Missing Weather Tests', () {
    test('Missing / null conditions do NOT automatically behave like dry weather or score 100', () {

      const incompleteWeather = WeatherInfo(
        condition: 'Unknown',
        morningCondition: null,
        afternoonCondition: null,
        nightCondition: null,
        alertLevel: 'None',
        iconCode: 'cloudy',
      );

      final score = TravelScoreCalculator.calculateScore(weather: incompleteWeather, route: null);

      expect(score.weatherSubscore, isNot(100));
      expect(score.score, isNot(100));
      expect(score.bestTravelPeriod, 'Not available');
      expect(score.breakdown.isWeatherComplete, isFalse);
    });

    test('Empty condition strings do NOT automatically behave like dry weather or score 100', () {
      const emptyStringWeather = WeatherInfo(
        condition: '',
        morningCondition: '',
        afternoonCondition: '',
        nightCondition: '',
        alertLevel: 'None',
        iconCode: 'cloudy',
      );

      final score = TravelScoreCalculator.calculateScore(weather: emptyStringWeather, route: null);

      expect(score.weatherSubscore, isNot(100));
      expect(score.score, isNot(100));
      expect(score.bestTravelPeriod, 'Not available');
    });

    test('Explicit positive MET dry keywords yield full weather suitability', () {
      const perfectDryWeather = WeatherInfo(
        condition: 'Cerah',
        morningCondition: 'Tiada hujan',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
        minTemperature: 22.0,
        maxTemperature: 31.0,
      );

      final score = TravelScoreCalculator.calculateScore(weather: perfectDryWeather, route: null);

      expect(score.weatherSubscore, 100);
      expect(score.bestTravelPeriod, 'All Day (Dry & Clear)');
      expect(score.levelName, 'Excellent');
    });

    test('Unknown MET condition strings use neutral scoring without crashing or awarding 100', () {
      const unusualWeather = WeatherInfo(
        condition: 'Fenomena Cuaca Luar Biasa',
        morningCondition: 'Fenomena Cuaca Luar Biasa',
        afternoonCondition: 'Tiada hujan',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'cloudy',
      );

      final score = TravelScoreCalculator.calculateScore(weather: unusualWeather, route: null);

      expect(score.weatherSubscore, inInclusiveRange(70, 97));
      expect(score.weatherSubscore, isNot(100));
    });
  });

  group('TravelScoreCalculator Rule-Based Scoring & Route Integration Tests', () {
    test('Calculates high score for clear weather with short driving time', () {
      const weather = WeatherInfo(
        condition: 'Sunny',
        morningCondition: 'Cerah / Clear',
        afternoonCondition: 'Tiada Hujan / No Rain',
        nightCondition: 'Tiada Hujan / No Rain',
        alertLevel: 'None',
        iconCode: 'sunny',
        minTemperature: 25.0,
        maxTemperature: 33.0,
      );

      final route = TravelRoute(
        originName: 'Kuah',
        originLatitude: 6.3265,
        originLongitude: 99.8432,
        destinationName: 'Pantai Cenang',
        destinationLatitude: 6.2925,
        destinationLongitude: 99.7291,
        distanceMeters: 18500.0,
        distanceKm: 18.5,
        durationSeconds: 1500.0,
        fetchedAt: DateTime.now(),
      );

      final score = TravelScoreCalculator.calculateScore(weather: weather, route: route);

      expect(score.score, greaterThanOrEqualTo(85));
      expect(score.suitability, TravelSuitability.ideal);
      expect(score.weatherSubscore, 100);
      expect(score.journeySubscore, 95);
      expect(score.isRouteAvailable, isTrue);
      expect(score.analysisLimitation, isNull);
    });

    test('No-route destination does NOT receive Journey 100 or fake route score', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
      );

      final score = TravelScoreCalculator.calculateScore(weather: weather, route: null);

      expect(score.journeySubscore, isNull);
      expect(score.breakdown.journeyScore, isNull);
      expect(score.isRouteAvailable, isFalse);
      expect(score.analysisLimitation, contains('driving route unavailable'));
    });

    test('Generates curated activity recommendations only when activityTags are provided', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Ribut petir di satu dua tempat',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'thunderstorm',
      );

      final curatedScore = TravelScoreCalculator.calculateScore(
        weather: weather,
        activityTags: ['Highlands', 'Nature'],
      );
      expect(curatedScore.recommendedActivities, isNotEmpty);

      final geocodedScore = TravelScoreCalculator.calculateScore(
        weather: weather,
        activityTags: null,
      );
      expect(geocodedScore.recommendedActivities, isEmpty);
    });

    test('Compares preferred travel period against recommended best period', () {
      const weather = WeatherInfo(
        condition: 'Rain in afternoon',
        morningCondition: 'Cerah',
        afternoonCondition: 'Ribut petir',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'thunderstorm',
      );

      final scoreMismatch = TravelScoreCalculator.calculateScore(
        weather: weather,
        preferredPeriod: 'Afternoon',
      );
      expect(scoreMismatch.reasons, contains(TravelRecommendationReason.preferredPeriodMismatch));
      expect(scoreMismatch.preferredPeriodComparison, contains('more favourable'));

      final scoreMatch = TravelScoreCalculator.calculateScore(
        weather: weather,
        preferredPeriod: 'Morning',
      );
      expect(scoreMatch.reasons, contains(TravelRecommendationReason.preferredPeriodMatch));
      expect(scoreMatch.preferredPeriodComparison, contains('matches'));
    });

    test('Current Location -> Genting Highlands full route calculation and score combination', () {
      const weather = WeatherInfo(
        condition: 'Partly Cloudy',
        morningCondition: 'Cerah',
        afternoonCondition: 'Berawan',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'partly_cloudy',
      );

      final gentingRoute = TravelRoute(
        originName: 'Current Location',
        originLatitude: 3.1970,
        originLongitude: 101.7130,
        destinationName: 'Genting Highlands',
        destinationLatitude: 3.39545,
        destinationLongitude: 101.77915,
        distanceMeters: 37977.5,
        distanceKm: 37.9775,
        durationSeconds: 2750.0,
        fetchedAt: DateTime.now(),
      );

      expect(gentingRoute.distanceFormatted, '38.0 km');
      expect(gentingRoute.durationFormatted, '46 min');

      final score = TravelScoreCalculator.calculateScore(
        weather: weather,
        route: gentingRoute,
        activityTags: ['Highlands', 'Sightseeing', 'Relaxing'],
      );

      expect(score.isRouteAvailable, isTrue);
      expect(score.journeySubscore, 95);
      expect(score.weatherSubscore, 98);

      expect(score.score, 97);
      expect(score.analysisLimitation, isNull);
    });

    test('Current Location -> Cameron Highlands route calculation and score combination', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
      );

      final cameronRoute = TravelRoute(
        originName: 'Current Location',
        originLatitude: 3.1390,
        originLongitude: 101.6869,
        destinationName: 'Cameron Highlands',
        destinationLatitude: 4.4700,
        destinationLongitude: 101.3800,
        distanceMeters: 206300.0,
        distanceKm: 206.3,
        durationSeconds: 11880.0,
        fetchedAt: DateTime.now(),
      );

      expect(cameronRoute.distanceFormatted, '206 km');
      expect(cameronRoute.durationFormatted, '3 hr 18 min');

      final score = TravelScoreCalculator.calculateScore(
        weather: weather,
        route: cameronRoute,
        activityTags: ['Highlands', 'Nature', 'Hiking'],
      );

      expect(score.isRouteAvailable, isTrue);
      expect(score.journeySubscore, 78);
      expect(score.weatherSubscore, 100);

      expect(score.score, 91);
      expect(score.analysisLimitation, isNull);
    });

    test('Peninsular -> Sabah / Sarawak (cross-sea) receives weather-only analysis without fake route', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
      );

      final score = TravelScoreCalculator.calculateScore(
        weather: weather,
        route: null,
        activityTags: ['Highlands', 'Nature'],
      );

      expect(score.isRouteAvailable, isFalse);
      expect(score.journeySubscore, isNull);
      expect(score.weatherSubscore, 100);
      expect(score.score, 100);
      expect(score.analysisLimitation, contains('driving route unavailable'));
    });

    test('Current Location -> Nearby KL destination calculates short distance and high journey score', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
      );

      final nearbyRoute = TravelRoute(
        originName: 'Current Location',
        originLatitude: 3.1970,
        originLongitude: 101.7130,
        destinationName: 'Batu Caves',
        destinationLatitude: 3.2379,
        destinationLongitude: 101.6840,
        distanceMeters: 8500.0,
        distanceKm: 8.5,
        durationSeconds: 900.0,
        fetchedAt: DateTime.now(),
      );

      expect(nearbyRoute.distanceFormatted, '8.5 km');
      expect(nearbyRoute.durationFormatted, '15 min');

      final score = TravelScoreCalculator.calculateScore(
        weather: weather,
        route: nearbyRoute,
        activityTags: ['Sightseeing'],
      );

      expect(score.isRouteAvailable, isTrue);
      expect(score.journeySubscore, 95);
      expect(score.weatherSubscore, 100);
      expect(score.score, 98);
    });

    test('Live OSRM response JSON for Genting Highlands parses distance 38.0 km and 46 min duration', () {
      final liveGentingOsrmJson = {
        'code': 'Ok',
        'routes': [
          {
            'legs': [],
            'weight_name': 'routability',
            'weight': 2750.0,
            'duration': 2750.0,
            'distance': 37977.5,
          }
        ],
        'waypoints': [
          {
            'hint': 'test_hint_1',
            'distance': 1.2,
            'name': 'Jalan Genting Kelang',
            'location': [101.7130, 3.1970],
          },
          {
            'hint': 'test_hint_2',
            'distance': 2.5,
            'name': 'Genting Highlands Resort',
            'location': [101.77915, 3.39545],
          }
        ]
      };

      final route = TravelRoute.fromOsrmJson(
        json: liveGentingOsrmJson,
        originName: 'Current Location',
        originLat: 3.1970,
        originLng: 101.7130,
        destName: 'Genting Highlands',
        destLat: 3.39545,
        destLng: 101.77915,
      );

      expect(route.distanceKm, closeTo(37.98, 0.01));
      expect(route.distanceFormatted, '38.0 km');
      expect(route.durationMinutes, 46);
      expect(route.durationFormatted, '46 min');
      expect(route.originLatitude, 3.1970);
      expect(route.originLongitude, 101.7130);
      expect(route.destinationLatitude, 3.39545);
      expect(route.destinationLongitude, 101.77915);
    });

    test('Kuala Lumpur -> Kundasang (Sabah) / Kuching (Sarawak) cross-region has no direct road route', () {
      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah',
        afternoonCondition: 'Cerah',
        nightCondition: 'Tiada hujan',
        alertLevel: 'None',
        iconCode: 'sunny',
      );

      final kundasangScore = TravelScoreCalculator.calculateScore(
        weather: weather,
        route: null,
      );

      expect(kundasangScore.isRouteAvailable, isFalse);
      expect(kundasangScore.journeySubscore, isNull);
      expect(kundasangScore.score, 100);
      expect(kundasangScore.analysisLimitation, contains('driving route unavailable'));
    });
  });
}
