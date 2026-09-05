import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/user_location.dart';
import 'package:happyway/models/travel_location.dart';
import 'package:happyway/providers/location_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Origin Selection & GPS Accuracy Tests', () {
    test('Test A: Current Location preserves exact GPS coordinates and strict naming', () {
      const realGpsLat = 3.152841;
      const realGpsLng = 101.703819;
      const gpsAccuracy = 8.3;

      final origin = UserLocation.fromGps(
        latitude: realGpsLat,
        longitude: realGpsLng,
        accuracy: gpsAccuracy,
        reverseGeocodedAddress: 'Taman Danau Kota, Kuala Lumpur',
      );

      // 1. UI display name must strictly remain "Current Location"
      expect(origin.name, equals('Current Location'));
      expect(origin.name, isNot(equals('Taman Danau Kota')));
      expect(origin.name, isNot(equals('Kuala Lumpur')));

      // 2. Type & flags
      expect(origin.type, equals(UserLocationType.currentLocation));
      expect(origin.isGps, isTrue);

      // 3. Exact GPS coordinates are retained directly for OSRM routing
      expect(origin.latitude, equals(realGpsLat));
      expect(origin.longitude, equals(realGpsLng));
      expect(origin.accuracy, equals(8.3));
      expect(origin.subtitle, contains('±8m'));

      // 4. Destination is independently defined
      final destination = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang Utara, Kuala Lumpur',
        latitude: 3.209400,
        longitude: 101.668200,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      expect(destination.name, equals('Jinjang Utara, Kuala Lumpur'));
      expect(destination.latitude, equals(3.209400));
      expect(destination.longitude, equals(101.668200));
    });

    test('Test B: Manual origin uses resolved place coordinates without GPS', () {
      final manualTravelLoc = TravelLocation.fromGeocodedPlace(
        name: 'Taman Danau Kota, Kuala Lumpur',
        formattedAddress: 'Jalan Danau Kota, Setapak, 53300 Kuala Lumpur',
        latitude: 3.203800,
        longitude: 101.714400,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      final origin = UserLocation.fromTravelLocation(manualTravelLoc);

      // 1. UI display name is the resolved place name
      expect(origin.name, equals('Taman Danau Kota, Kuala Lumpur'));
      expect(origin.type, equals(UserLocationType.selectedPlace));
      expect(origin.isGps, isFalse);

      // 2. Coordinates used for routing are exact place coordinates
      expect(origin.latitude, equals(3.203800));
      expect(origin.longitude, equals(101.714400));
      expect(origin.accuracy, isNull);

      // 3. Destination is independently defined
      final destination = TravelLocation.fromGeocodedPlace(
        name: 'Kepong, Kuala Lumpur',
        latitude: 3.218000,
        longitude: 101.636000,
        state: 'Kuala Lumpur',
        metLocationId: 'LOCATION:234',
        metLocationName: 'Kuala Lumpur',
      );

      expect(destination.name, equals('Kepong, Kuala Lumpur'));
      expect(destination.latitude, equals(3.218000));
      expect(destination.longitude, equals(101.636000));
    });

    test('Test C: Transition between Manual Origin and Current Location', () {
      // Step 1: User chooses manual origin
      final manualOrigin = UserLocation.fromTravelLocation(
        TravelLocation.fromGeocodedPlace(
          name: 'Setapak, Kuala Lumpur',
          latitude: 3.195000,
          longitude: 101.705000,
          state: 'Kuala Lumpur',
        ),
      );

      expect(manualOrigin.isGps, isFalse);
      expect(manualOrigin.name, equals('Setapak, Kuala Lumpur'));

      // Step 2: User re-selects Current Location
      const refreshedGpsLat = 3.160123;
      const refreshedGpsLng = 101.712345;
      final gpsOrigin = UserLocation.fromGps(
        latitude: refreshedGpsLat,
        longitude: refreshedGpsLng,
        accuracy: 5.2,
      );

      expect(gpsOrigin.isGps, isTrue);
      expect(gpsOrigin.name, equals('Current Location'));
      expect(gpsOrigin.latitude, equals(refreshedGpsLat));
      expect(gpsOrigin.longitude, equals(refreshedGpsLng));
      expect(gpsOrigin.accuracy, equals(5.2));
    });

    test('UserLocation JSON serialization round-trip', () {
      final gps = UserLocation.fromGps(
        latitude: 3.14,
        longitude: 101.69,
        accuracy: 10.5,
        reverseGeocodedAddress: 'KL Sentral',
      );
      final jsonGps = gps.toJson();
      final restoredGps = UserLocation.fromJson(jsonGps);

      expect(restoredGps.name, equals('Current Location'));
      expect(restoredGps.isGps, isTrue);
      expect(restoredGps.latitude, equals(3.14));
      expect(restoredGps.longitude, equals(101.69));
      expect(restoredGps.accuracy, equals(10.5));
      expect(restoredGps.reverseGeocodedAddress, equals('KL Sentral'));

      final manual = UserLocation(
        latitude: 4.47,
        longitude: 101.37,
        name: 'Cameron Highlands',
        subtitle: 'Highlands • Pahang',
        type: UserLocationType.selectedPlace,
      );
      final jsonManual = manual.toJson();
      final restoredManual = UserLocation.fromJson(jsonManual);

      expect(restoredManual.name, equals('Cameron Highlands'));
      expect(restoredManual.isGps, isFalse);
      expect(restoredManual.latitude, equals(4.47));
      expect(restoredManual.longitude, equals(101.37));
      expect(restoredManual.accuracy, isNull);
    });

    test('Test D: Manual location is preserved when manual place is set', () {
      final locProvider = LocationProvider();

      final manualLoc = TravelLocation.fromGeocodedPlace(
        name: 'George Town, Penang',
        latitude: 5.4141,
        longitude: 100.3288,
        state: 'Penang',
      );
      locProvider.setManualLocation(manualLoc);

      expect(locProvider.currentLocation?.name, equals('George Town, Penang'));
      expect(locProvider.isGps, isFalse);
      expect(locProvider.currentLocation?.latitude, equals(5.4141));
      expect(locProvider.currentLocation?.longitude, equals(100.3288));

      // Disposing provider unregisters lifecycle observer cleanly
      locProvider.dispose();
    });

    test('Test E: Lifecycle observer responds to AppLifecycleState without crashing', () {
      final locProvider = LocationProvider();

      // Inactive or paused when not waiting for settings does nothing
      locProvider.didChangeAppLifecycleState(AppLifecycleState.inactive);
      locProvider.didChangeAppLifecycleState(AppLifecycleState.paused);
      locProvider.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(locProvider.isResolvingLocation, isFalse);
      locProvider.dispose();
    });
  });
}

