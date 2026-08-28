import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/destination_image_info.dart';
import 'package:happyway/services/destination_image_service.dart';
import 'package:happyway/services/destination_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DestinationImageService Normalization & Fallback Tests', () {
    test('Normalizes destination names using curated alias map', () {
      expect(DestinationImageService.normalizeSearchTerm('Pulau Redang'), 'Redang Island');
      expect(DestinationImageService.normalizeSearchTerm('redang'), 'Redang Island');
      expect(DestinationImageService.normalizeSearchTerm('Pulau Perhentian'), 'Perhentian Islands');
      expect(DestinationImageService.normalizeSearchTerm('perhentian islands'), 'Perhentian Islands');
      expect(DestinationImageService.normalizeSearchTerm('Pulau Tioman'), 'Tioman Island');
      expect(DestinationImageService.normalizeSearchTerm('Pulau Pangkor'), 'Pangkor Island');
      expect(DestinationImageService.normalizeSearchTerm('Kundasang & Mt Kinabalu'), 'Mount Kinabalu Sabah');
      expect(DestinationImageService.normalizeSearchTerm('Taman Negara Rainforest'), 'Taman Negara National Park');
      expect(DestinationImageService.normalizeSearchTerm('Desaru Coast'), 'Desaru Beach');
      expect(DestinationImageService.normalizeSearchTerm('Batu Ferringhi'), 'Batu Ferringhi Penang');
      expect(DestinationImageService.normalizeSearchTerm('Melaka Historic City'), 'Melaka City');
      expect(DestinationImageService.normalizeSearchTerm('Tasik Kenyir'), 'Lake Kenyir');
    });

    test('Normalizes arbitrary Pulau and Tasik names correctly', () {
      expect(DestinationImageService.normalizeSearchTerm('Pulau Aur'), 'Aur Island');
      expect(DestinationImageService.normalizeSearchTerm('Tasik Dayang Bunting'), 'Lake Dayang Bunting');
      expect(DestinationImageService.normalizeSearchTerm('George Town'), 'George Town Penang');
      expect(DestinationImageService.normalizeSearchTerm('Kuala Lumpur'), 'Kuala Lumpur');
    });

    test('Builds multi-step fallback query cascade for curated destinations', () {
      final queries = DestinationImageService.buildFallbackQueries(
        name: 'Pulau Redang',
        state: 'Terengganu',
        isCurated: true,
      );

      expect(queries, [
        'Redang Island Terengganu Malaysia',
        'Redang Island Malaysia',
        'Redang Island',
        'Terengganu Malaysia',
      ]);
    });

    test('Builds fallback query cascade for general MET locations without generic state fallback', () {
      final queries = DestinationImageService.buildFallbackQueries(
        name: 'Temerloh',
        state: 'Pahang',
        isCurated: false,
      );

      expect(queries, [
        'Temerloh Pahang Malaysia',
        'Temerloh Malaysia',
        'Temerloh',
      ]);
      expect(queries.contains('Pahang Malaysia'), isFalse);
    });

    test('Correctly identifies curated vs general catalogue destinations', () {
      expect(DestinationImageService.isCuratedLocation('Cameron Highlands', 'LOCATION:314'), isTrue);
      expect(DestinationImageService.isCuratedLocation('Genting Highlands', 'LOCATION:317'), isTrue);
      expect(DestinationImageService.isCuratedLocation('Langkawi Island', 'LOCATION:323'), isTrue);
      expect(DestinationImageService.isCuratedLocation('Pulau Redang', 'LOCATION:326'), isTrue);
      expect(DestinationImageService.isCuratedLocation('Random Town', 'LOCATION:999'), isFalse);
    });
  });

  group('DestinationImageService Core Resolution Tests', () {
    final imageService = DestinationImageService();

    test('Resolves pre-verified local assets for curated destinations without remote network requests', () async {
      // 1. Cameron Highlands
      final cameron = await imageService.resolveImage(
        name: 'Cameron Highlands',
        state: 'Pahang',
        locationId: 'LOCATION:314',
      );
      expect(cameron, isNotNull);
      expect(cameron!.isLocalAsset, isTrue);
      expect(cameron.isVerified, isTrue);
      expect(cameron.imageUrl, 'assets/destinations/cameron_highlands.jpg');

      // 2. Genting Highlands
      final genting = await imageService.resolveImage(
        name: 'Genting Highlands',
        state: 'Pahang',
        locationId: 'LOCATION:317',
      );
      expect(genting, isNotNull);
      expect(genting!.isLocalAsset, isTrue);
      expect(genting.imageUrl, 'assets/destinations/genting_highlands.jpg');

      // 3. Langkawi Island
      final langkawi = await imageService.resolveImage(
        name: 'Langkawi Island',
        state: 'Kedah',
        locationId: 'LOCATION:323',
      );
      expect(langkawi, isNotNull);
      expect(langkawi!.isLocalAsset, isTrue);
      expect(langkawi.imageUrl, 'assets/destinations/langkawi_island.jpg');

      // 4. Kundasang & Mt Kinabalu
      final kundasang = await imageService.resolveImage(
        name: 'Kundasang & Mt Kinabalu',
        state: 'Sabah',
        locationId: 'LOCATION:829',
      );
      expect(kundasang, isNotNull);
      expect(kundasang!.isLocalAsset, isTrue);
      expect(kundasang.imageUrl, 'assets/destinations/kundasang.jpg');

      // 5. Taman Negara Rainforest
      final tamanNegara = await imageService.resolveImage(
        name: 'Taman Negara Rainforest',
        state: 'Pahang',
        locationId: 'LOCATION:331',
      );
      expect(tamanNegara, isNotNull);
      expect(tamanNegara!.isLocalAsset, isTrue);
      expect(tamanNegara.imageUrl, 'assets/destinations/taman_negara.jpg');

      // 6. Melaka Historic City
      final melaka = await imageService.resolveImage(
        name: 'Melaka Historic City',
        state: 'Melaka',
        locationId: 'LOCATION:174',
      );
      expect(melaka, isNotNull);
      expect(melaka!.isLocalAsset, isTrue);
      expect(melaka.imageUrl, 'assets/destinations/melaka_city.jpg');
    });

    test('DestinationDataService has authentic images for core destinations', () {
      final destinations = DestinationDataService.getDestinations();
      expect(destinations.length, 16);

      final cameron = destinations.firstWhere((d) => d.id == 'dest_cameron');
      expect(cameron.imageUrl, 'assets/destinations/cameron_highlands.jpg');

      final genting = destinations.firstWhere((d) => d.id == 'dest_genting');
      expect(genting.imageUrl, 'assets/destinations/genting_highlands.jpg');

      final langkawi = destinations.firstWhere((d) => d.id == 'dest_langkawi');
      expect(langkawi.imageUrl, 'assets/destinations/langkawi_island.jpg');

      final kundasang = destinations.firstWhere((d) => d.id == 'dest_kundasang');
      expect(kundasang.imageUrl, 'assets/destinations/kundasang.jpg');

      final tamanNegara = destinations.firstWhere((d) => d.id == 'dest_taman_negara');
      expect(tamanNegara.imageUrl, 'assets/destinations/taman_negara.jpg');

      final melaka = destinations.firstWhere((d) => d.id == 'dest_melaka');
      expect(melaka.imageUrl, 'assets/destinations/melaka_city.jpg');
    });

    test('DestinationImageInfo serialization and TTL validation', () {
      final info = DestinationImageInfo(
        imageUrl: 'https://images.pexels.com/photos/12345/pexels-photo-12345.jpeg',
        photographer: 'Jane Doe',
        photographerUrl: 'https://www.pexels.com/@janedoe',
        pexelsUrl: 'https://www.pexels.com/photo/12345',
        altText: 'Scenic view of Sibu',
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      // 2 days old is within 7-day TTL
      expect(info.isValid(ttl: const Duration(days: 7)), isTrue);
      // 2 days old exceeds 1-day TTL
      expect(info.isValid(ttl: const Duration(days: 1)), isFalse);

      final json = info.toJson();
      final restored = DestinationImageInfo.fromJson(json);

      expect(restored.imageUrl, info.imageUrl);
      expect(restored.photographer, 'Jane Doe');
      expect(restored.photographerUrl, 'https://www.pexels.com/@janedoe');
      expect(restored.pexelsUrl, 'https://www.pexels.com/photo/12345');
      expect(restored.altText, 'Scenic view of Sibu');
    });
  });
}
