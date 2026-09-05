import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../models/saved_location.dart';
import '../services/destination_data_service.dart';

/// Single source of truth for canonical destination identities in HappyWay.
///
/// Ensures consistent comparison and storage across:
/// - Official MET locations (`met:LOCATION:xxx`)
/// - Geocoded coordinate places (`geo:latitude,longitude`)
/// - Curated destinations (`met:LOCATION:xxx` when mapped to MET, or `dest:dest_xxx`)
class CanonicalDestinationId {
  CanonicalDestinationId._();

  /// Curated featured destination IDs that share a common regional MET weather area (e.g. Setapak/KL).
  /// These must retain their unique individual identity to avoid colliding in saved state.
  static const Set<String> _sharedWeatherFeaturedIds = {
    'dest_danau_kota',
    'dest_titiwangsa',
    'dest_batu_caves',
    'dest_perdana_botanical',
  };

  /// Resolves the canonical ID for a [TravelDestination].
  static String fromDestination(TravelDestination dest) {
    // 1. Stable geocoded coordinate destination
    if (dest.id.startsWith('geo:')) {
      return dest.id;
    }

    // 2. Curated featured destination
    if (dest.id.startsWith('dest_')) {
      return fromString(dest.id);
    }

    // 3. Recommendation or MET destination with explicit ID
    if (dest.id.startsWith('met_') ||
        dest.id.startsWith('met:') ||
        dest.id.startsWith('LOCATION:')) {
      return fromString(dest.id);
    }

    // 4. MET location ID if available
    if (dest.metLocationId.isNotEmpty) {
      return fromString(dest.metLocationId);
    }

    // 5. Coordinates fallback
    if (dest.latitude != null &&
        dest.longitude != null &&
        dest.latitude != 0.0 &&
        dest.longitude != 0.0) {
      return 'geo:${dest.latitude!.toStringAsFixed(6)},${dest.longitude!.toStringAsFixed(6)}';
    }

    return fromString(dest.id);
  }

  /// Resolves the canonical ID for a [TravelLocation].
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

  /// Resolves the canonical ID for an official [MetLocation].
  static String fromMetLocation(MetLocation loc) {
    return fromString(loc.id);
  }

  /// Resolves the canonical ID for a [SavedLocation].
  ///
  /// Strictly relies on [SavedLocation.id] as the primary canonical identity.
  static String fromSavedLocation(SavedLocation loc) {
    if (loc.id.isNotEmpty) {
      return fromString(loc.id);
    }
    if (loc.metLocationId != null && loc.metLocationId!.isNotEmpty) {
      return fromString(loc.metLocationId!);
    }
    return '';
  }

  /// Normalizes any raw string ID into its canonical representation.
  static String fromString(String rawId) {
    if (rawId.isEmpty) return '';

    // Handle geocoded coordinates
    if (rawId.startsWith('geo:')) {
      return rawId;
    }

    // Strip multiple nested prefixes if any (e.g. met:met_LOCATION:172)
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

    // Curated destinations with shared weather station retain individual unique identity
    if (_sharedWeatherFeaturedIds.contains(clean)) {
      return 'dest:$clean';
    }

    // Check if it's a known featured destination key (e.g. 'dest_cameron') with 1-to-1 MET ID
    if (clean.startsWith('dest_')) {
      final mappedMet = DestinationDataService.metLocationIds[clean];
      if (mappedMet != null && mappedMet.isNotEmpty) {
        return fromString(mappedMet);
      }
      return 'dest:$clean';
    }

    // If it's a raw LOCATION:xxx
    if (clean.startsWith('LOCATION:')) {
      return 'met:$clean';
    }

    // If it's pure numbers like 172
    if (int.tryParse(clean) != null) {
      return 'met:LOCATION:$clean';
    }

    // Check if clean matches any featured destination ID
    final mapped = DestinationDataService.metLocationIds[clean];
    if (mapped != null && mapped.isNotEmpty) {
      if (_sharedWeatherFeaturedIds.contains(clean)) {
        return 'dest:$clean';
      }
      return fromString(mapped);
    }

    return 'met:$clean';
  }

  /// Determines whether two destination IDs represent the exact same canonical destination.
  static bool match(String idA, String idB) {
    if (idA.isEmpty || idB.isEmpty) return false;
    return fromString(idA) == fromString(idB);
  }
}
