import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import '../models/travel_location.dart';
import 'met_location_service.dart';

String _toTitleCase(String input) {
  if (input.isEmpty) return input;
  return input.split(' ').map((word) {
    if (word.isEmpty) return word;
    if (word == word.toUpperCase() && word.length > 1) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

class GeocodingResult {
  final List<TravelLocation> locations;
  final String? errorMessage;

  const GeocodingResult({
    this.locations = const [],
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null && locations.isNotEmpty;
}

class GeocodingService {

  static Future<GeocodingResult> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return const GeocodingResult(
        errorMessage: 'Please enter a destination name or address.',
      );
    }

    try {

      String searchQuery = cleanQuery;
      final lower = cleanQuery.toLowerCase();
      if (!lower.contains('malaysia') &&
          !lower.contains('kuala lumpur') &&
          !lower.contains('selangor') &&
          !lower.contains('penang') &&
          !lower.contains('johor') &&
          !lower.contains('perak') &&
          !lower.contains('sabah') &&
          !lower.contains('sarawak') &&
          !lower.contains('pahang') &&
          !lower.contains('kedah') &&
          !lower.contains('melaka') &&
          !lower.contains('negeri sembilan') &&
          !lower.contains('terengganu') &&
          !lower.contains('kelantan') &&
          !lower.contains('perlis')) {
        searchQuery = '$cleanQuery, Malaysia';
      }

      final locations = await locationFromAddress(searchQuery);

      if (locations.isEmpty) {
        return const GeocodingResult(
          errorMessage: 'Destination not found. Please try a more specific place or address.',
        );
      }

      final results = <TravelLocation>[];

      final seenCoords = <String>{};

      for (final loc in locations.take(5)) {
        final key = '${loc.latitude.toStringAsFixed(4)},${loc.longitude.toStringAsFixed(4)}';
        if (seenCoords.contains(key)) continue;
        seenCoords.add(key);

        final locationName = _toTitleCase(cleanQuery);
        String? formattedAddress;
        String state = 'Malaysia';

        try {
          final placemarks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );

          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final subLocality = p.subLocality?.isNotEmpty == true ? p.subLocality!.trim() : null;
            final locality = p.locality?.isNotEmpty == true ? p.locality!.trim() : null;
            final subAdmin = p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea!.trim() : null;
            final admin = p.administrativeArea?.isNotEmpty == true ? p.administrativeArea!.trim() : null;
            final street = p.street?.isNotEmpty == true && p.street != p.postalCode ? p.street!.trim() : null;

            state = admin ?? locality ?? 'Malaysia';

            final addressParts = [
              street,
              subLocality,
              locality,
              subAdmin,
              admin,
              p.country,
            ].where((part) => part != null && part.isNotEmpty).toSet().toList();

            formattedAddress = addressParts.join(', ');
          }
        } catch (e) {
          debugPrint('Reverse geocoding error: $e');
        }

        final matchedMet = await MetLocationService.findNearestWeatherLocation(
          loc.latitude,
          loc.longitude,
          preferredState: state,
        );

        results.add(TravelLocation.fromGeocodedPlace(
          name: locationName,
          formattedAddress: formattedAddress,
          latitude: loc.latitude,
          longitude: loc.longitude,
          state: state,
          category: 'Detailed Place',
          metLocationId: matchedMet?.id,
          metLocationName: matchedMet?.formattedName,
        ));
      }

      if (results.isEmpty) {
        return const GeocodingResult(
          errorMessage: 'Destination not found. Please try a more specific place or address.',
        );
      }

      return GeocodingResult(locations: results);
    } catch (e) {
      debugPrint('Geocoding searchPlaces error: $e');
      return const GeocodingResult(
        errorMessage: 'Destination not found. Please try a more specific place or address.',
      );
    }
  }
}
