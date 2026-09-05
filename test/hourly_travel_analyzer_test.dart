import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/weather_info.dart';
import 'package:happyway/models/travel_route.dart';
import 'package:happyway/utils/hourly_travel_analyzer.dart';

void main() {
  group('HourlyTravelAnalyzer - Feasibility & Time-Awareness', () {
    test('Today: past hours are filtered out, past period is not recommended', () {
      final now = DateTime(2026, 9, 5, 16, 0); // 4:00 PM today
      final targetDate = DateTime(2026, 9, 5); // Today

      // Generate 24 hourly items: Morning is great (95), Afternoon is moderate (72), Night is good (84)
      final items = List.generate(24, (hour) {
        final time = DateTime(2026, 9, 5, hour);
        if (hour >= 6 && hour <= 11) {
          // Morning: Clear, pleasant
          return HourlyWeatherItem(
            time: time,
            timeLabel: '$hour:00',
            temperature: 25,
            condition: 'Clear',
            iconCode: 'clear',
            weatherCode: 0,
            precipitationProbability: 0,
          );
        } else if (hour >= 12 && hour <= 17) {
          // Afternoon: Cloudy, moderate
          return HourlyWeatherItem(
            time: time,
            timeLabel: '$hour:00',
            temperature: 32,
            condition: 'Cloudy',
            iconCode: 'cloudy',
            weatherCode: 2,
            precipitationProbability: 25,
          );
        } else {
          // Night: Fair
          return HourlyWeatherItem(
            time: time,
            timeLabel: '$hour:00',
            temperature: 27,
            condition: 'Clear',
            iconCode: 'clear',
            weatherCode: 0,
            precipitationProbability: 10,
          );
        }
      });

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        currentTimeOverride: now,
        preferredPeriod: 'Auto',
      );

      // Morning has passed (hours 6-11 < 16), so its actionable score is 0 and is not feasible
      expect(result.periodEvaluations?[TravelPeriod.morning]?.score, 0);
      expect(result.periodEvaluations?[TravelPeriod.morning]?.isFeasible, isFalse);
      // Auto must NOT recommend Morning because it has already passed!
      expect(result.recommendedPeriod, isNot('Morning'));
      expect(result.recommendedPeriod, anyOf('Afternoon', 'Night'));
      // Morning fullScore should be preserved internally
      expect(result.periodEvaluations?[TravelPeriod.morning]?.fullScore, greaterThan(80));
    });

    test('Future date: all periods are evaluated normally regardless of current hour', () {
      final now = DateTime(2026, 9, 5, 16, 0); // 4:00 PM today
      final futureDate = DateTime(2026, 9, 7); // 2 days in future

      final items = List.generate(24, (hour) {
        final time = DateTime(2026, 9, 7, hour);
        return HourlyWeatherItem(
          time: time,
          timeLabel: '$hour:00',
          temperature: hour < 12 ? 24 : 32,
          condition: hour < 12 ? 'Clear' : 'Rain',
          iconCode: hour < 12 ? 'clear' : 'rain',
          weatherCode: hour < 12 ? 0 : 61,
          precipitationProbability: hour < 12 ? 0 : 60,
        );
      });

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: futureDate,
        currentTimeOverride: now,
        preferredPeriod: 'Auto',
      );

      // Morning is fully evaluated and feasible for future trip
      expect(result.periodEvaluations?[TravelPeriod.morning]?.isFeasible, isTrue);
      expect(result.morningSuitability, greaterThan(80));
      expect(result.recommendedPeriod, 'Morning');
    });
  });

  group('HourlyTravelAnalyzer - Weather-Derived Tie Breaking', () {
    test('Equal average score resolves to period with higher minimum hourly suitability', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      // We craft Morning and Afternoon to have the SAME average score,
      // but Morning has a severe dip (e.g. 100, 100, 100, 100, 100, 40)
      // while Afternoon has stable consistent hours (e.g. 90, 90, 90, 90, 90, 90)
      final items = <HourlyWeatherItem>[];

      // Morning: hours 6-11
      // 5 sunny hours (code 0) and 1 hour with heavy rain (code 65)
      for (int h = 6; h <= 11; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 25,
          condition: h == 11 ? 'Heavy Rain' : 'Sunny',
          iconCode: h == 11 ? 'heavy_rain' : 'sunny',
          weatherCode: h == 11 ? 65 : 0,
          precipitationProbability: 10,
        ));
      }

      // Afternoon: hours 12-17
      // 6 mildly overcast hours (code 1), no extreme rain
      for (int h = 12; h <= 17; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 27,
          condition: 'Partly Cloudy',
          iconCode: 'cloudy',
          weatherCode: 1,
          precipitationProbability: 10,
        ));
      }

      // Night: hours 18-23 (lower score)
      for (int h = 18; h <= 23; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 26,
          condition: 'Thunderstorm',
          iconCode: 'tstorm',
          weatherCode: 95,
          precipitationProbability: 80,
        ));
      }

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        currentTimeOverride: now,
        preferredPeriod: 'Auto',
      );

      // Afternoon should win over Morning due to higher floor / no heavy rain!
      expect(result.recommendedPeriod, 'Afternoon');
    });

    test('Equal average score resolves to period with lower precipitation probability', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      final items = <HourlyWeatherItem>[];

      // Morning: hours 6-11 (Code 1, precip 40%)
      for (int h = 6; h <= 11; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 27,
          condition: 'Partly Cloudy',
          iconCode: 'partly_cloudy',
          weatherCode: 1,
          precipitationProbability: 40,
        ));
      }

      // Afternoon: hours 12-17 (Code 1, precip 5%)
      for (int h = 12; h <= 17; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 27,
          condition: 'Partly Cloudy',
          iconCode: 'partly_cloudy',
          weatherCode: 1,
          precipitationProbability: 5,
        ));
      }

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        currentTimeOverride: now,
        preferredPeriod: 'Auto',
      );

      // Afternoon has much lower precip probability (5% vs 40%), so Afternoon wins
      expect(result.recommendedPeriod, 'Afternoon');
    });
  });

  group('HourlyTravelAnalyzer - Best Weather Window & Suggested Departure', () {
    test('Calculates 3-hour sliding window correctly', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      // Make 7:00 to 10:00 AM the clearest consecutive 3 hours
      final items = List.generate(24, (h) {
        final isBestWindow = h >= 7 && h <= 9;
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 24,
          condition: isBestWindow ? 'Clear' : 'Overcast',
          iconCode: isBestWindow ? 'clear' : 'cloudy',
          weatherCode: isBestWindow ? 0 : 3,
          precipitationProbability: isBestWindow ? 0 : 50,
        );
      });

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        currentTimeOverride: now,
        preferredPeriod: 'Morning',
      );

      expect(result.bestWeatherWindow, contains('7:00 AM – 10:00 AM'));
    });

    test('Suggests departure accounting for drive duration and target window', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      final items = List.generate(24, (h) {
        final isBestWindow = h >= 8 && h <= 10;
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 24,
          condition: isBestWindow ? 'Clear' : 'Rain',
          iconCode: isBestWindow ? 'clear' : 'rain',
          weatherCode: isBestWindow ? 0 : 61,
          precipitationProbability: isBestWindow ? 0 : 60,
        );
      });

      // Route taking 2 hours (7200 seconds)
      final route = TravelRoute(
        originName: 'Kuala Lumpur',
        originLatitude: 3.139,
        originLongitude: 101.686,
        destinationName: 'Cameron Highlands',
        destinationLatitude: 4.470,
        destinationLongitude: 101.378,
        distanceMeters: 120000,
        distanceKm: 120,
        durationSeconds: 7200,
        fetchedAt: DateTime.now(),
      );

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Morning',
      );

      // In forward-projected departure, departures between 6:00 AM and 8:00 AM arrive in the 8-10 AM optimal window
      expect(result.suggestedDeparture, isNotNull);
      expect(result.suggestedDeparture, anyOf(contains('6:00 AM'), contains('6:30 AM'), contains('7:00 AM'), contains('7:30 AM'), contains('8:00 AM')));
      expect(result.bestWeatherWindow, isNotNull);
      expect(result.bestWeatherWindow, anyOf(contains('6:00 AM'), contains('7:00 AM')));
    });

    test('Returns null departure if route is null, but provides window explanation', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      final items = List.generate(24, (h) {
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 25,
          condition: 'Clear',
          iconCode: 'clear',
          weatherCode: 0,
        );
      });

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: null,
        currentTimeOverride: now,
      );

      expect(result.suggestedDeparture, isNull);
      expect(result.departureReason, contains('Direct driving route unavailable'));
    });

    test('Does not recommend past departure for today', () {
      final now = DateTime(2026, 9, 5, 18, 0); // 6:00 PM today
      final targetDate = DateTime(2026, 9, 5); // Today

      final items = List.generate(24, (h) {
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 5, h),
          timeLabel: '$h:00',
          temperature: 25,
          condition: 'Clear',
          iconCode: 'clear',
          weatherCode: 0,
        );
      });

      final route = TravelRoute(
        originName: 'Kuala Lumpur',
        originLatitude: 3.139,
        originLongitude: 101.686,
        destinationName: 'Melaka',
        destinationLatitude: 2.189,
        destinationLongitude: 102.250,
        distanceMeters: 150000,
        distanceKm: 150,
        durationSeconds: 7200,
        fetchedAt: DateTime.now(),
      );

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Afternoon', // Afternoon (12:00-17:59) has passed by 18:00
      );

      expect(result.suggestedDeparture, isNull);
      expect(result.departureReason, contains('No suitable departure window remaining today'));
    });

    test('Overnight arrival evaluates next day forecast across midnight', () {
      final targetDate = DateTime(2026, 9, 6);
      final now = DateTime(2026, 9, 5, 10, 0);

      // 48 hourly items across 6 Sep and 7 Sep
      final items = <HourlyWeatherItem>[];
      for (int h = 0; h < 24; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 6, h),
          timeLabel: '$h:00',
          temperature: 28,
          condition: 'Cloudy',
          iconCode: 'cloudy',
          weatherCode: 3,
        ));
      }
      for (int h = 0; h < 24; h++) {
        final isOptimalOvernightArrival = h == 2; // 2:00 AM on 7 Sep is clear
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 7, h),
          timeLabel: '$h:00',
          temperature: 24,
          condition: isOptimalOvernightArrival ? 'Clear' : 'Rain',
          iconCode: isOptimalOvernightArrival ? 'clear' : 'rain',
          weatherCode: isOptimalOvernightArrival ? 0 : 61,
        ));
      }

      // 3 hours drive (10800 seconds)
      final route = TravelRoute(
        originName: 'Kuala Lumpur',
        originLatitude: 3.139,
        originLongitude: 101.686,
        destinationName: 'Penang',
        destinationLatitude: 5.414,
        destinationLongitude: 100.329,
        distanceMeters: 350000,
        distanceKm: 350,
        durationSeconds: 10800,
        fetchedAt: DateTime.now(),
      );

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Night', // Night departure: 11:00 PM + 3 hr drive = 2:00 AM on 7 Sep
      );

      expect(result.suggestedDeparture, isNotNull);
      expect(result.suggestedDeparture, anyOf(contains('11:00 PM'), contains('11:30 PM')));
      expect(result.departureReason, contains('7 Sep'));
      expect(result.departureReason, anyOf(contains('2:00 AM'), contains('2:30 AM')));
    });

    test('Overnight arrival pattern is extractable for Estimated Arrival display', () {
      final targetDate = DateTime(2026, 9, 6);
      final now = DateTime(2026, 9, 5, 10, 0);

      final items = <HourlyWeatherItem>[];
      for (int h = 0; h < 24; h++) {
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 6, h),
          timeLabel: '$h:00',
          temperature: 28,
          condition: 'Cloudy',
          iconCode: 'cloudy',
          weatherCode: 3,
        ));
      }
      for (int h = 0; h < 24; h++) {
        final isOptimalOvernightArrival = h == 2;
        items.add(HourlyWeatherItem(
          time: DateTime(2026, 9, 7, h),
          timeLabel: '$h:00',
          temperature: 24,
          condition: isOptimalOvernightArrival ? 'Clear' : 'Rain',
          iconCode: isOptimalOvernightArrival ? 'clear' : 'rain',
          weatherCode: isOptimalOvernightArrival ? 0 : 61,
        ));
      }

      final route = TravelRoute(
        originName: 'Kuala Lumpur',
        originLatitude: 3.139,
        originLongitude: 101.686,
        destinationName: 'Penang',
        destinationLatitude: 5.414,
        destinationLongitude: 100.329,
        distanceMeters: 350000,
        distanceKm: 350,
        durationSeconds: 10800,
        fetchedAt: DateTime.now(),
      );

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Night',
      );

      final reason = result.departureReason ?? '';
      final onMatch = RegExp(r'on (\d+ \w+) at (\d+:\d+ [AP]M)', caseSensitive: false).firstMatch(reason);
      expect(onMatch, isNotNull);
      final estimatedArrival = '${onMatch!.group(1)} · Around ${onMatch.group(2)}';
      expect(estimatedArrival, anyOf('7 Sep · Around 2:00 AM', '7 Sep · Around 2:30 AM'));
    });

    test('Manual Preferred Period strictly respects selected period even if Auto recommends different period', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      // Morning has moderate weather (code 3), Night has excellent weather (code 0)
      final items = List.generate(24, (h) {
        final isNight = h >= 18 && h <= 23;
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 25,
          condition: isNight ? 'Clear' : 'Cloudy',
          iconCode: isNight ? 'clear' : 'cloudy',
          weatherCode: isNight ? 0 : 3,
        );
      });

      final route = TravelRoute(
        originName: 'Kuala Lumpur',
        originLatitude: 3.139,
        originLongitude: 101.686,
        destinationName: 'Melaka',
        destinationLatitude: 2.189,
        destinationLongitude: 102.250,
        distanceMeters: 150000,
        distanceKm: 150,
        durationSeconds: 7200,
        fetchedAt: DateTime.now(),
      );

      // 1. In Auto, Night should be recommended
      final autoResult = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Auto',
      );
      expect(autoResult.recommendedPeriod, 'Night');
      expect(autoResult.suggestedDeparture, contains('PM'));

      // 2. In Manual Morning, recommendedPeriod may still be Night, BUT suggestedDeparture MUST be in Morning (AM)
      final morningResult = HourlyTravelAnalyzer.analyze(
        hourlyForecast: items,
        targetDate: targetDate,
        route: route,
        currentTimeOverride: now,
        preferredPeriod: 'Morning',
      );
      expect(morningResult.selectedPeriod, 'Morning');
      expect(morningResult.recommendedPeriod, 'Night');
      expect(morningResult.suggestedDeparture, contains('AM'));
      expect(morningResult.bestWeatherWindow, contains('AM'));
    });
  });

  group('HourlyTravelAnalyzer - Clean Travel Advice Strings', () {
    test('Never contains forbidden legacy strings', () {
      final targetDate = DateTime(2026, 9, 10);
      final now = DateTime(2026, 9, 5, 8, 0);

      // Test with bad weather
      final badWeatherItems = List.generate(24, (h) {
        return HourlyWeatherItem(
          time: DateTime(2026, 9, 10, h),
          timeLabel: '$h:00',
          temperature: 30,
          condition: 'Thunderstorm',
          iconCode: 'tstorm',
          weatherCode: 95,
          precipitationProbability: 90,
        );
      });

      final result = HourlyTravelAnalyzer.analyze(
        hourlyForecast: badWeatherItems,
        targetDate: targetDate,
        currentTimeOverride: now,
      );

      final advice = result.travelAdvice;
      expect(advice.contains('Indoor activities'), isFalse, reason: 'Must not contain "Indoor activities"');
      expect(advice.contains('Plan with Caution'), isFalse, reason: 'Must not contain "Plan with Caution"');
      expect(advice.contains('Flexible Departure'), isFalse, reason: 'Must not contain "Flexible Departure"');
    });
  });
}
