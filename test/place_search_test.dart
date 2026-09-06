import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:happyway/models/travel_location.dart';
import 'package:happyway/services/place_search_service.dart';
import 'package:happyway/widgets/destination_picker_sheet.dart';

class MockPlaceSearchService implements PlaceSearchService {
  int searchCallCount = 0;
  final List<PlaceSearchResult> cannedResults;

  MockPlaceSearchService({this.cannedResults = const []});

  @override
  Future<List<PlaceSearchResult>> searchPlaces(String query) async {
    searchCallCount++;
    return cannedResults;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaceSearchResult Tests', () {
    test('Correctly parses Nominatim node JSON into osm:N ID', () {
      final json = {
        'place_id': 12345,
        'osm_type': 'node',
        'osm_id': 987654321,
        'lat': '5.4164',
        'lon': '100.3327',
        'category': 'amenity',
        'type': 'restaurant',
        'name': 'Line Clear Nasi Kandar',
        'display_name': 'Line Clear Nasi Kandar, Jalan Penang, 10000 George Town, Pulau Pinang, Malaysia',
        'address': {
          'road': 'Jalan Penang',
          'city': 'George Town',
          'state': 'Pulau Pinang',
          'country': 'Malaysia',
        },
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result.id, equals('osm:N987654321'));
      expect(result.name, equals('Line Clear Nasi Kandar'));
      expect(result.state, equals('Pulau Pinang'));
      expect(result.category, equals('restaurant'));
      expect(result.latitude, equals(5.4164));
      expect(result.longitude, equals(100.3327));
      expect(result.formattedAddress, contains('George Town'));
    });

    test('Correctly parses Nominatim way JSON into osm:W ID', () {
      final json = {
        'place_id': 67890,
        'osm_type': 'way',
        'osm_id': 11223344,
        'lat': '5.4405',
        'lon': '100.3086',
        'category': 'highway',
        'type': 'secondary',
        'name': 'Persiaran Gurney',
        'display_name': 'Persiaran Gurney, George Town, Pulau Pinang, Malaysia',
        'address': {
          'state': 'Pulau Pinang',
        },
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result.id, equals('osm:W11223344'));
      expect(result.name, equals('Persiaran Gurney'));
    });

    test('Correctly parses Nominatim relation JSON into osm:R ID', () {
      final json = {
        'place_id': 99999,
        'osm_type': 'relation',
        'osm_id': 556677,
        'lat': '5.4244',
        'lon': '100.2694',
        'category': 'leisure',
        'type': 'nature_reserve',
        'name': 'Penang Hill',
        'display_name': 'Penang Hill, Bukit Bendera, Pulau Pinang, Malaysia',
        'address': {
          'state': 'Pulau Pinang',
        },
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result.id, equals('osm:R556677'));
      expect(result.name, equals('Penang Hill'));
    });

    test('Falls back to display_name when name field is missing', () {
      final json = {
        'place_id': 11111,
        'osm_type': 'node',
        'osm_id': 22222,
        'lat': '3.14',
        'lon': '101.69',
        'display_name': 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia',
        'address': {'state': 'Kuala Lumpur'},
      };

      final result = PlaceSearchResult.fromNominatimJson(json);

      expect(result.name, equals('Kuala Lumpur City Centre'));
    });
  });

  group('TravelLocation Source & dbSourceType Tests', () {
    test('dbSourceType maps correctly to persisted values', () {
      const metLoc = TravelLocation(
        id: 'met:LOCATION:1',
        name: 'Kuala Lumpur',
        latitude: 3.14,
        longitude: 101.69,
        state: 'Kuala Lumpur',
        category: 'Town',
        source: TravelLocationSource.metLocation,
      );
      expect(metLoc.dbSourceType, equals('metLocation'));

      final geoLoc = TravelLocation.fromGeocodedPlace(
        name: 'Jinjang',
        latitude: 3.20,
        longitude: 101.66,
        state: 'Kuala Lumpur',
      );
      expect(geoLoc.dbSourceType, equals('geocodedPlace'));

      const osmResult = PlaceSearchResult(
        id: 'osm:N999',
        name: 'Eastern & Oriental Hotel',
        state: 'Pulau Pinang',
        category: 'hotel',
        latitude: 5.423,
        longitude: 100.336,
      );

      final osmLoc = TravelLocation.fromPlaceSearchResult(
        osmResult,
        metLocationId: 'LOCATION:123',
        metLocationName: 'George Town',
      );
      expect(osmLoc.source, equals(TravelLocationSource.osmPlace));
      expect(osmLoc.dbSourceType, equals('osm_place'));
      expect(osmLoc.isOsmPlace, isTrue);
      expect(osmLoc.id, equals('osm:N999'));
      expect(osmLoc.metLocationId, equals('LOCATION:123'));
    });
  });

  group('DestinationPickerSheet Widget Tests', () {
    testWidgets('Does not query Nominatim on typing; queries only on explicit search', (tester) async {
      final mockService = MockPlaceSearchService(
        cannedResults: [
          const PlaceSearchResult(
            id: 'osm:N123',
            name: 'Line Clear Nasi Kandar',
            state: 'Pulau Pinang',
            category: 'restaurant',
            latitude: 5.4164,
            longitude: 100.3327,
            formattedAddress: 'Jalan Penang, George Town',
          ),
        ],
      );

      TravelLocation? selected;
      SharedPreferences.setMockInitialValues({
        'met_locations_cache_v1': '[]',
        'met_locations_cache_timestamp_v1': DateTime.now().millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DestinationPickerSheet(
              placeSearchService: mockService,
              onSelectTravelLocation: (loc) => selected = loc,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Line Clear');
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockService.searchCallCount, equals(0));

      final searchBtn = find.textContaining('Search "Line Clear" Places & Sights');
      expect(searchBtn, findsOneWidget);

      await tester.tap(searchBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(mockService.searchCallCount, equals(1));

      expect(find.text('Line Clear Nasi Kandar'), findsOneWidget);
      expect(find.text('Places & Attractions (1)'), findsOneWidget);
      expect(find.text('Place data © OpenStreetMap contributors'), findsOneWidget);

      await tester.tap(find.text('Line Clear Nasi Kandar'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(selected, isNotNull);
      expect(selected!.id, equals('osm:N123'));
      expect(selected!.name, equals('Line Clear Nasi Kandar'));
      expect(selected!.source, equals(TravelLocationSource.osmPlace));
      expect(selected!.dbSourceType, equals('osm_place'));
    });
  });
}
