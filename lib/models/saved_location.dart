import 'met_location.dart';
import 'travel_destination.dart';
import 'travel_location.dart';
import '../utils/canonical_destination_id.dart';

/// SavedLocation stores persistent metadata to restore a saved travel destination
/// (either an official MET location, a curated featured destination, or a precise geocoded place).
///
/// Persisted in Supabase table `saved_destinations`.
/// Unique key in DB: `(user_id, location_id)`
/// - For official MET locations: `met:LOCATION:317`
/// - For geocoded places: `geo:3.209400,101.668200`
class SavedLocation {
  final String id; // Unique travel destination ID (e.g. "met:LOCATION:314", "geo:3.209400,101.668200")
  final String name; // Precise destination display name
  final String category;
  final String state;
  final double? latitude; // Precise destination latitude
  final double? longitude; // Precise destination longitude
  final String? metLocationId; // Matched official MET location ID (e.g. "LOCATION:234")
  final String? metLocationName; // Matched official MET weather area name (e.g. "Kuala Lumpur")
  final String? sourceType; // "metLocation" or "geocodedPlace"
  final String? formattedAddress; // Detailed resolved address if available
  final String? imageUrl;
  final String? description;
  final bool isFeatured;
  final DateTime savedAt;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.state,
    this.latitude,
    this.longitude,
    this.metLocationId,
    this.metLocationName,
    this.sourceType,
    this.formattedAddress,
    this.imageUrl,
    this.description,
    this.isFeatured = false,
    required this.savedAt,
  });

  /// Factory for a TravelLocation.
  factory SavedLocation.fromTravelLocation(TravelLocation loc) {
    return SavedLocation(
      id: loc.id,
      name: loc.name,
      category: loc.category,
      state: loc.state,
      latitude: loc.latitude,
      longitude: loc.longitude,
      metLocationId: loc.metLocationId,
      metLocationName: loc.metLocationName,
      sourceType: loc.source.name,
      formattedAddress: loc.formattedAddress,
      imageUrl: loc.imageUrl,
      description: loc.description,
      isFeatured: loc.imageUrl != null && loc.imageUrl!.isNotEmpty,
      savedAt: DateTime.now(),
    );
  }

  /// Factory for any TravelDestination (curated, recommended, or candidate).
  factory SavedLocation.fromAnyDestination(TravelDestination dest) {
    final canonicalId = CanonicalDestinationId.fromDestination(dest);
    final metId = dest.metLocationId.isNotEmpty ? dest.metLocationId : (dest.id.startsWith('dest_') ? '' : dest.id);
    return SavedLocation(
      id: canonicalId,
      name: dest.name,
      category: dest.category,
      state: dest.state,
      latitude: dest.latitude,
      longitude: dest.longitude,
      metLocationId: metId.isNotEmpty ? metId : null,
      metLocationName: dest.name,
      sourceType: 'metLocation',
      imageUrl: dest.imageUrl,
      description: dest.description,
      isFeatured: dest.id.startsWith('dest_'),
      savedAt: DateTime.now(),
    );
  }

  /// Factory for a curated featured destination.
  factory SavedLocation.fromFeaturedDestination(TravelDestination dest) {
    return SavedLocation.fromAnyDestination(dest);
  }

  /// Factory for an official MET location.
  factory SavedLocation.fromMetLocation(MetLocation loc) {
    return SavedLocation(
      id: CanonicalDestinationId.fromMetLocation(loc),
      name: loc.formattedName,
      category: loc.categoryLabel,
      state: loc.state,
      latitude: loc.latitude,
      longitude: loc.longitude,
      metLocationId: loc.id,
      metLocationName: loc.formattedName,
      sourceType: 'metLocation',
      isFeatured: false,
      savedAt: DateTime.now(),
    );
  }

  SavedLocation copyWith({
    String? id,
    String? name,
    String? category,
    String? state,
    double? latitude,
    double? longitude,
    String? metLocationId,
    String? metLocationName,
    String? sourceType,
    String? formattedAddress,
    String? imageUrl,
    String? description,
    bool? isFeatured,
    DateTime? savedAt,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      metLocationId: metLocationId ?? this.metLocationId,
      metLocationName: metLocationName ?? this.metLocationName,
      sourceType: sourceType ?? this.sourceType,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isFeatured: isFeatured ?? this.isFeatured,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  factory SavedLocation.fromSupabase(Map<String, dynamic> json) {
    final rawId = json['location_id'] as String? ?? json['id'] as String? ?? '';
    // Backwards compatibility for existing records stored without prefix
    final id = (rawId.startsWith('met:') || rawId.startsWith('geo:'))
        ? rawId
        : (rawId.startsWith('LOCATION:') ? 'met:$rawId' : rawId);

    return SavedLocation(
      id: id,
      name: json['location_name'] as String? ?? json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      metLocationId: json['met_location_id'] as String? ?? json['metLocationId'] as String?,
      metLocationName: json['met_location_name'] as String? ?? json['metLocationName'] as String?,
      sourceType: json['source_type'] as String? ?? json['sourceType'] as String? ?? 'metLocation',
      formattedAddress: json['formatted_address'] as String? ?? json['formattedAddress'] as String?,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      description: json['description'] as String?,
      isFeatured: json['is_featured'] as bool? ?? json['isFeatured'] as bool? ?? false,
      savedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['savedAt'] != null
              ? (json['savedAt'] is int
                  ? DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int)
                  : DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now())
              : DateTime.now()),
    );
  }

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    final rawId = json['location_id'] as String? ?? json['id'] as String? ?? '';
    final id = (rawId.startsWith('met:') || rawId.startsWith('geo:'))
        ? rawId
        : (rawId.startsWith('LOCATION:') ? 'met:$rawId' : rawId);

    return SavedLocation(
      id: id,
      name: json['location_name'] as String? ?? json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      metLocationId: json['metLocationId'] as String? ?? json['met_location_id'] as String?,
      metLocationName: json['metLocationName'] as String? ?? json['met_location_name'] as String?,
      sourceType: json['sourceType'] as String? ?? json['source_type'] as String? ?? 'metLocation',
      formattedAddress: json['formattedAddress'] as String? ?? json['formatted_address'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String?,
      description: json['description'] as String?,
      isFeatured: json['isFeatured'] as bool? ?? json['is_featured'] as bool? ?? false,
      savedAt: json['savedAt'] != null
          ? (json['savedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int)
              : DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase({required String userId}) {
    return {
      'user_id': userId,
      'location_id': id,
      'location_name': name,
      'state': state,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'met_location_id': metLocationId,
      'met_location_name': metLocationName,
      'source_type': sourceType ?? 'metLocation',
      'formatted_address': formattedAddress,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'metLocationId': metLocationId,
      'metLocationName': metLocationName,
      'sourceType': sourceType,
      'formattedAddress': formattedAddress,
      'imageUrl': imageUrl,
      'description': description,
      'isFeatured': isFeatured,
      'savedAt': savedAt.millisecondsSinceEpoch,
    };
  }

  /// Converts this saved location to a [TravelLocation].
  TravelLocation toTravelLocation() {
    return TravelLocation(
      id: id,
      name: name,
      formattedAddress: formattedAddress,
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
      state: state,
      category: category,
      source: sourceType == 'geocodedPlace'
          ? TravelLocationSource.geocodedPlace
          : TravelLocationSource.metLocation,
      metLocationId: metLocationId ?? (id.startsWith('met:') ? id.substring(4) : null),
      metLocationName: metLocationName ?? (sourceType != 'geocodedPlace' ? name : null),
      imageUrl: imageUrl,
      description: description,
    );
  }
}
