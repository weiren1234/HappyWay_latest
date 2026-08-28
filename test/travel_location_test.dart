import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/travel_location.dart';
import 'package:happyway/models/met_location.dart';
import 'package:happyway/models/saved_location.dart';
import 'package:happyway/models/travel_destination.dart';
import 'package:happyway/models/travel_score.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TravelLocation Model Tests', () {
    test('Official MET location creates stable met: ID', () {
      const met = MetLocation(
        id: 'LOCATION:317',
        name: 'CAMERON HIGHLANDS',
        locationCategoryId: 'TOURISTDEST',
        state: 'Pahang',
        latitude: 4.4715,
        longitude: 101.3756,
      );

      final travelLoc = TravelLocation.fromMetLocation(met);

      expect(travelLoc.id, equals('met:LOCATION:317'));
      expect(travelLoc.name, equals('Cameron Highlands'));
      expect(travelLoc.isMetLocation, isTrue);
      expect(travelLoc.hasWeatherLocation, isTrue);
      expect(travelLoc.metLocationId, equals('LOCATION:317'));
      expect(travelLoc.latitude, equals(4.4715));
      expect(travelLoc.longitude, equals(101.3756));
    });

    test('Geocoded detailed place creates deterministic geo: ID', () {
      final jinjang = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang Utara, Kuala Lumpur',
        formattedAddress: 'Jalan Jinjang Utara, Kepong, 52000 Kuala Lumpur',
        latitude: 3.2094,
        longitude: 101.6682,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      expect(jinjang.id, equals('geo:3.209400,101.668200'));
      expect(jinjang.name, equals('Jinjang Utara, Kuala Lumpur'));
      expect(jinjang.isMetLocation, isFalse);
      expect(jinjang.hasWeatherLocation, isTrue);
      expect(jinjang.metLocationId, equals('LOCATION:234'));
      expect(jinjang.metLocationName, equals('Kuala Lumpur'));
    });

    test('Different geocoded destinations sharing same MET location have distinct IDs', () {
      final jinjang = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang Utara, Kuala Lumpur',
        latitude: 3.2094,
        longitude: 101.6682,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      final danauKota = TravelLocation.fromGeocodedPlace(
        name: 'Taman Danau Kota, Kuala Lumpur',
        latitude: 3.2038,
        longitude: 101.7144,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      // Both share the same MET weather location ID
      expect(jinjang.metLocationId, equals(danauKota.metLocationId));
      // But their destination IDs are strictly unique
      expect(jinjang.id, isNot(equals(danauKota.id)));
      expect(jinjang.id, equals('geo:3.209400,101.668200'));
      expect(danauKota.id, equals('geo:3.203800,101.714400'));
    });

    test('SavedLocation preserves detailed destination metadata and MET mapping', () {
      final jinjang = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang Utara, Kuala Lumpur',
        formattedAddress: 'Jalan Jinjang Utara, Kepong, 52000 Kuala Lumpur',
        latitude: 3.2094,
        longitude: 101.6682,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      final saved = SavedLocation.fromTravelLocation(jinjang);
      final supabaseMap = saved.toSupabase(userId: 'user-123');

      expect(supabaseMap['user_id'], equals('user-123'));
      expect(supabaseMap['location_id'], equals('geo:3.209400,101.668200'));
      expect(supabaseMap['location_name'], equals('Jinjang Utara, Kuala Lumpur'));
      expect(supabaseMap['latitude'], equals(3.2094));
      expect(supabaseMap['longitude'], equals(101.6682));
      expect(supabaseMap['met_location_id'], equals('LOCATION:234'));
      expect(supabaseMap['met_location_name'], equals('Kuala Lumpur'));
      expect(supabaseMap['source_type'], equals('geocodedPlace'));
      expect(supabaseMap['formatted_address'], equals('Jalan Jinjang Utara, Kepong, 52000 Kuala Lumpur'));

      // Restore from Supabase
      final restored = SavedLocation.fromSupabase(supabaseMap);
      expect(restored.id, equals('geo:3.209400,101.668200'));
      expect(restored.name, equals('Jinjang Utara, Kuala Lumpur'));
      expect(restored.metLocationId, equals('LOCATION:234'));
      expect(restored.metLocationName, equals('Kuala Lumpur'));
      expect(restored.sourceType, equals('geocodedPlace'));

      final restoredTravelLoc = restored.toTravelLocation();
      expect(restoredTravelLoc.latitude, equals(3.2094));
      expect(restoredTravelLoc.longitude, equals(101.6682));
      expect(restoredTravelLoc.metLocationId, equals('LOCATION:234'));
      expect(restoredTravelLoc.hasWeatherLocation, isTrue);
    });

    test('Curated featured destination conversion to TravelLocation', () {
      final dest = TravelDestination(
        id: 'dest_genting',
        name: 'Genting Highlands',
        state: 'Pahang',
        category: 'Highlands',
        imageUrl: 'https://example.com/genting.jpg',
        description: 'Cool resort mountain',
        travelScore: TravelScore(score: 95, suitability: TravelSuitability.ideal, recommendation: 'Good', highlights: [], bestTravelPeriod: 'All Day'),
        metLocationId: 'LOCATION:314',
        latitude: 3.4240,
        longitude: 101.7932,
      );

      final loc = TravelLocation.fromFeaturedDestination(dest);
      expect(loc.id, equals('met:LOCATION:314'));
      expect(loc.name, equals('Genting Highlands'));
      expect(loc.latitude, equals(3.4240));
      expect(loc.longitude, equals(101.7932));
      expect(loc.metLocationId, equals('LOCATION:314'));
      expect(loc.isMetLocation, isTrue);
    });
  });
}
