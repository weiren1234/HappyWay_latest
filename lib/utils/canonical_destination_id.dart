import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../models/saved_location.dart';
import '../services/destination_data_service.dart';

class CanonicalDestinationId {
  CanonicalDestinationId._();

  static const Set<String> _sharedWeatherFeaturedIds = {
    'dest_danau_kota',
    'dest_titiwangsa',
    'dest_batu_caves',
    'dest_perdana_botanical',
  };

  static String fromDestination(TravelDestination dest) {

    if (dest.id.startsWith('geo:')) {
      return dest.id;
    }

    if (dest.id.startsWith('dest_')) {
      return fromString(dest.id);
    }

    if (dest.id.startsWith('met_') ||
        dest.id.startsWith('met:') ||
        dest.id.startsWith('LOCATION:')) {
      return fromString(dest.id);
    }

    if (dest.metLocationId.isNotEmpty) {
      return fromString(dest.metLocationId);
    }

    if (dest.latitude != null &&
        dest.longitude != null &&
        dest.latitude != 0.0 &&
        dest.longitude != 0.0) {
      return 'geo:${dest.latitude!.toStringAsFixed(6)},${dest.longitude!.toStringAsFixed(6)}';
    }

    return fromString(dest.id);
  }

  static String fromTravelLocation(TravelLocation loc) {
    if (loc.source == TravelLocationSource.geocodedPlace || loc.id.startsWith('geo:')) {
      if (loc.id.startsWith('geo:')) return loc.id;
      return 'geo:${loc.latitude.toStringAsFixed(6)},${loc.longitude.toStringAsFixed(6)}';
    }

    if (loc.id.startsWith('dest_')) {
      return fromString(loc.id);
    }

    if (loc.metLocationId != null && loc.metLocationId!.isNotEmpty) {
      return fromString(loc.metLocationId!);
    }

    return fromString(loc.id);
  }

  static String fromMetLocation(MetLocation loc) {
    return fromString(loc.id);
  }

  static String fromSavedLocation(SavedLocation loc) {
    if (loc.id.isNotEmpty) {
      return fromString(loc.id);
    }
    if (loc.metLocationId != null && loc.metLocationId!.isNotEmpty) {
      return fromString(loc.metLocationId!);
    }
    return '';
  }

  static String fromString(String rawId) {
    if (rawId.isEmpty) return '';

    if (rawId.startsWith('geo:')) {
      return rawId;
    }

    var clean = rawId.trim();
    while (clean.startsWith('met:') || clean.startsWith('met_') || clean.startsWith('dest:')) {
      if (clean.startsWith('met:')) {
        clean = clean.substring(4);
      } else if (clean.startsWith('met_')) {
        clean = clean.substring(4);
      } else if (clean.startsWith('dest:')) {
        clean = clean.substring(5);
      }
    }

    if (_sharedWeatherFeaturedIds.contains(clean)) {
      return 'dest:$clean';
    }

    if (clean.startsWith('dest_')) {
      final mappedMet = DestinationDataService.metLocationIds[clean];
      if (mappedMet != null && mappedMet.isNotEmpty) {
        return fromString(mappedMet);
      }
      return 'dest:$clean';
    }

    if (clean.startsWith('LOCATION:')) {
      return 'met:$clean';
    }

    if (int.tryParse(clean) != null) {
      return 'met:LOCATION:$clean';
    }

    final mapped = DestinationDataService.metLocationIds[clean];
    if (mapped != null && mapped.isNotEmpty) {
      if (_sharedWeatherFeaturedIds.contains(clean)) {
        return 'dest:$clean';
      }
      return fromString(mapped);
    }

    return 'met:$clean';
  }

  static bool match(String idA, String idB) {
    if (idA.isEmpty || idB.isEmpty) return false;
    return fromString(idA) == fromString(idB);
  }
}
