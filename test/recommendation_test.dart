import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/travel_destination.dart';
import 'package:happyway/models/destination_recommendation.dart';
import 'package:happyway/models/weather_info.dart';
import 'package:happyway/models/user_location.dart';
import 'package:happyway/services/destination_data_service.dart';
import 'package:happyway/services/recommendation_service.dart';
import 'package:happyway/services/reachability_service.dart';

void main() {
  group('Featured Destination Catalogue Verification', () {
    test('Contains between 10 and 20 curated destinations with verified MET IDs', () {
      final destinations = DestinationDataService.getDestinations();

      expect(destinations.length, inInclusiveRange(10, 20));

      for (final dest in destinations) {
        expect(dest.id, isNotEmpty);
        expect(dest.name, isNotEmpty);
        expect(dest.state, isNotEmpty);
        expect(dest.category, isNotEmpty);
        expect(dest.metLocationId, startsWith('LOCATION:'));
        expect(dest.activityTags, isNotEmpty);
        expect(dest.latitude, isNotNull);
        expect(dest.longitude, isNotNull);
        expect(dest.description, isNotEmpty);

        expect(dest.weather, isNull);
      }
    });

    test('Includes all key travel preference categories across catalogue', () {
      final destinations = DestinationDataService.getDestinations();
      final allTags = destinations.expand((d) => d.activityTags).toSet();

      for (final cat in DestinationDataService.preferenceCategories) {
        expect(allTags.contains(cat), isTrue,
            reason: 'Category $cat should be covered by at least one curated destination');
      }
    });

    test('Core curated destinations have verified authentic local assets', () {
      final destinations = DestinationDataService.getDestinations();

      final genting = destinations.firstWhere((d) => d.id == 'dest_genting');
      expect(genting.imageUrl, 'assets/destinations/genting_highlands.jpg');
      expect(genting.name, 'Genting Highlands');

      final cameron = destinations.firstWhere((d) => d.id == 'dest_cameron');
      expect(cameron.imageUrl, 'assets/destinations/cameron_highlands.jpg');
      expect(cameron.name, 'Cameron Highlands');

      final kundasang = destinations.firstWhere((d) => d.id == 'dest_kundasang');
      expect(kundasang.imageUrl, 'assets/destinations/kundasang.jpg');
      expect(kundasang.name, 'Kundasang & Mt Kinabalu');

      final langkawi = destinations.firstWhere((d) => d.id == 'dest_langkawi');
      expect(langkawi.imageUrl, 'assets/destinations/langkawi_island.jpg');
      expect(langkawi.name, 'Langkawi Island');

      final tamanNegara = destinations.firstWhere((d) => d.id == 'dest_taman_negara');
      expect(tamanNegara.imageUrl, 'assets/destinations/taman_negara.jpg');
      expect(tamanNegara.name, 'Taman Negara Rainforest');

      final melaka = destinations.firstWhere((d) => d.id == 'dest_melaka');
      expect(melaka.imageUrl, 'assets/destinations/melaka_city.jpg');
      expect(melaka.name, 'Melaka Historic City');
    });
  });

  group('ReachabilityService Classification Tests', () {
    test('Correctly identifies Peninsular road-accessible destinations from Kuala Lumpur', () {

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Genting Highlands',
          destinationState: 'Pahang',
        ),
        isTrue,
      );

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Cameron Highlands',
          destinationState: 'Pahang',
        ),
        isTrue,
      );

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Melaka Historic City',
          destinationState: 'Melaka',
        ),
        isTrue,
      );

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Batu Ferringhi',
          destinationState: 'Penang',
        ),
        isTrue,
      );
    });

    test('Correctly identifies East Malaysia destinations as not road-accessible from Peninsular Malaysia', () {

      final isRoadFeasible = ReachabilityService.isDirectRoadFeasible(
        originState: 'Kuala Lumpur',
        destinationName: 'Kundasang & Mt Kinabalu',
        destinationState: 'Sabah',
      );
      expect(isRoadFeasible, isFalse);

      final label = ReachabilityService.getReachabilityLabel(
        isRoadAccessible: isRoadFeasible,
        destinationName: 'Kundasang & Mt Kinabalu',
      );
      expect(label, 'Direct driving route unavailable');
    });

    test('Correctly identifies offshore islands as requiring water/air transport from Peninsular', () {

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Langkawi Island',
          destinationState: 'Kedah',
        ),
        isFalse,
      );

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Pulau Redang',
          destinationState: 'Terengganu',
        ),
        isFalse,
      );

      expect(
        ReachabilityService.isDirectRoadFeasible(
          originState: 'Kuala Lumpur',
          destinationName: 'Pulau Tioman',
          destinationState: 'Pahang',
        ),
        isFalse,
      );
    });
  });

  group('Destination Match Score & Model Tests', () {
    test('Correctly computes 40% Activity Match + 60% Weather Suitability and includes reachability', () {
      final dest = DestinationDataService.getDestinations().first;

      const weather = WeatherInfo(
        condition: 'Clear',
        morningCondition: 'Cerah / Clear',
        afternoonCondition: 'Cerah / Clear',
        nightCondition: 'Tiada Hujan / No Rain',
        alertLevel: 'None',
        iconCode: 'sunny',
        minTemperature: 24.0,
        maxTemperature: 32.0,
      );

      final rec = DestinationRecommendation.build(
        destination: dest,
        selectedPreference: 'Highlands',
        activityMatchScore: 100,
        weatherSuitabilityScore: 85,
        bestTravelPeriod: 'Morning & Afternoon',
        reason: 'Dry conditions forecast throughout the day.',
        isRoadAccessible: true,
        reachabilityNote: 'Direct road route available',
        weather: weather,
      );

      expect(rec.recommendationScore, 91);
      expect(rec.matchLevel, 'Great Match');
      expect(rec.selectedPreference, 'Highlands');
      expect(rec.isRoadAccessible, isTrue);
      expect(rec.reachabilityNote, 'Direct road route available');
    });

    test('Handles cross-region destination match with unavailable driving route note', () {
      final kundasang = DestinationDataService.getDestinations()
          .firstWhere((d) => d.name.contains('Kundasang'));

      final rec = DestinationRecommendation.build(
        destination: kundasang,
        selectedPreference: 'Highlands',
        activityMatchScore: 100,
        weatherSuitabilityScore: 90,
        bestTravelPeriod: 'Morning',
        reason: 'Pleasant morning highland climate.',
        isRoadAccessible: false,
        reachabilityNote: 'Direct driving route unavailable',
      );

      expect(rec.recommendationScore, 94);
      expect(rec.isRoadAccessible, isFalse);
      expect(rec.reachabilityNote, 'Direct driving route unavailable');
    });
  });

  group('RecommendationService Category & Reachability Integration Tests', () {
    late List<TravelDestination> allDestinations;
    late RecommendationService recommendationService;

    setUp(() {
      allDestinations = DestinationDataService.getDestinations();
      recommendationService = RecommendationService();
    });

    test('Recommends top Highlands destinations with reachability context for user in Setapak, KL', () async {
      const userOrigin = UserLocation(
        name: 'Current Location',
        subtitle: 'Device GPS',
        latitude: 3.1950,
        longitude: 101.7100,
        state: 'Kuala Lumpur',
        type: UserLocationType.currentLocation,
      );

      final recs = await recommendationService.getRecommendations(
        preference: 'Highlands',
        allDestinations: allDestinations,
        userOrigin: userOrigin,
      );

      expect(recs, isNotEmpty);

      final gentingRec = recs.where((r) => r.destination.name.contains('Genting')).firstOrNull;
      if (gentingRec != null) {
        expect(gentingRec.isRoadAccessible, isTrue);
        expect(gentingRec.reachabilityNote, 'Direct road route available');
      }

      final kundasangRec = recs.where((r) => r.destination.name.contains('Kundasang')).firstOrNull;
      if (kundasangRec != null) {
        expect(kundasangRec.isRoadAccessible, isFalse);
        expect(kundasangRec.reachabilityNote, 'Direct driving route unavailable');
      }
    });

    test('Recommends top Beach destinations', () async {
      final recs = await recommendationService.getRecommendations(
        preference: 'Beach',
        allDestinations: allDestinations,
      );

      expect(recs, isNotEmpty);
      for (final rec in recs) {
        final matches = rec.destination.activityTags.contains('Beach') ||
            rec.destination.category.toLowerCase().contains('beach');
        expect(matches, isTrue,
            reason: '${rec.destination.name} should match Beach preference');
        expect(rec.reason, isNotEmpty);
        expect(rec.bestTravelPeriod, isNotEmpty);
      }
    });
  });
}
