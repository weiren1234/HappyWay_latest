import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/services/met_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MET Location Matching Tests', () {
    test('Haversine distance calculation is accurate', () {
      // KL (3.1390, 101.6869) to Petaling Jaya (3.1073, 101.6067) is ~10-11 km
      final dist = MetLocationService.calculateHaversineDistanceKm(
        3.1390,
        101.6869,
        3.1073,
        101.6067,
      );

      expect(dist, greaterThan(8.0));
      expect(dist, lessThan(15.0));
    });

    test('Haversine distance between same coordinates is 0', () {
      final dist = MetLocationService.calculateHaversineDistanceKm(
        3.2094,
        101.6682,
        3.2094,
        101.6682,
      );

      expect(dist, closeTo(0.0, 0.001));
    });

    test('Nearest weather location matches KL region for Jinjang Utara coordinates', () async {
      // Jinjang Utara: ~3.2094, 101.6682
      final match = await MetLocationService.findNearestWeatherLocation(
        3.2094,
        101.6682,
        preferredState: 'Kuala Lumpur',
      );

      expect(match, isNotNull);
      expect(match!.locationCategoryId.toUpperCase(), isNot(equals('WATERS')));
      // Should match either Kuala Lumpur, Batu Caves, or nearby town in KL/Selangor
      final name = match.formattedName.toLowerCase();
      final state = match.state.toLowerCase();
      expect(
        name.contains('kuala lumpur') ||
            name.contains('batu') ||
            name.contains('kepong') ||
            name.contains('jinjang') ||
            state.contains('kuala lumpur') ||
            state.contains('selangor'),
        isTrue,
      );
    });

    test('Nearest weather location matches KL region for Taman Danau Kota coordinates', () async {
      // Taman Danau Kota: ~3.2038, 101.7144
      final match = await MetLocationService.findNearestWeatherLocation(
        3.2038,
        101.7144,
        preferredState: 'Kuala Lumpur',
      );

      expect(match, isNotNull);
      expect(match!.locationCategoryId.toUpperCase(), isNot(equals('WATERS')));
      expect(
        match.state.toLowerCase().contains('kuala lumpur') ||
            match.state.toLowerCase().contains('selangor'),
        isTrue,
      );
    });

    test('Out of bounds coordinate returns null without mock data', () async {
      // Coordinate in Pacific Ocean (0.0, 160.0) -> thousands of km away
      final match = await MetLocationService.findNearestWeatherLocation(
        0.0,
        160.0,
        maxDistanceKm: 100.0,
      );

      expect(match, isNull);
    });

    test('Custom threshold is respected', () async {
      // Very strict 100 meter threshold on Jinjang coordinates should return null
      // unless an official MET station is literally at that exact spot
      final match = await MetLocationService.findNearestWeatherLocation(
        3.2094,
        101.6682,
        maxDistanceKm: 0.1, // 100 meters
      );

      expect(match, isNull);
    });
  });
}
