import 'met_location.dart';
import 'travel_destination.dart';

/// Source type for a travel location.
enum TravelLocationSource {
  /// Official location from the MET Malaysia catalogue (TOURISTDEST, TOWN, DISTRICT).
  metLocation,

  /// Detailed place or address resolved via platform forward geocoding.
  geocodedPlace,
}

/// TravelLocation is HappyWay's primary destination model.
/// It strictly separates the **Actual Travel Destination** (exact coordinates for routing,
/// trip planning, and saved bookmarks) from the **Official MET Weather Location**
/// (official MET location ID and forecast area for weather analysis).
class TravelLocation {
  /// Unique identifier:
  /// - For official MET locations: `met:LOCATION:317`
  /// - For geocoded places: `geo:3.209400,101.668200`
  final String id;

  /// User-friendly display name (e.g. "Jinjang Utara, Kuala Lumpur", "Cameron Highlands").
  final String name;

  /// Detailed resolved address if returned by geocoder.
  final String? formattedAddress;

  /// Exact destination latitude (used for OSRM route & navigation).
  final double latitude;

  /// Exact destination longitude (used for OSRM route & navigation).
  final double longitude;

  /// State / administrative area (e.g. "Kuala Lumpur", "Pahang", "Penang").
  final String state;

  /// Destination category (e.g. "Tourist Destination", "Town", "Detailed Place").
  final String category;

  /// Origin source of this location.
  final TravelLocationSource source;

  /// Matched official MET Malaysia location ID for weather lookup (e.g. "LOCATION:234").
  /// Null if no suitable official MET location is within the valid coverage range.
  final String? metLocationId;

  /// Matched official MET Malaysia location name (e.g. "Kuala Lumpur").
  final String? metLocationName;

  /// Optional image URL (available for featured/curated destinations).
  final String? imageUrl;

  /// Optional description (available for featured destinations).
  final String? description;

  const TravelLocation({
    required this.id,
    required this.name,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.state,
    required this.category,
    required this.source,
    this.metLocationId,
    this.metLocationName,
    this.imageUrl,
    this.description,
  });

  /// True if this location was directly selected from the official MET catalogue.
  bool get isMetLocation => source == TravelLocationSource.metLocation;

  /// True if an official MET location has been matched for weather forecasting.
  bool get hasWeatherLocation => metLocationId != null && metLocationId!.isNotEmpty;

  /// Creates a TravelLocation from an official MetLocation.
  factory TravelLocation.fromMetLocation(MetLocation loc) {
    return TravelLocation(
      id: 'met:${loc.id}',
      name: loc.formattedName,
      latitude: loc.latitude ?? 0.0,
      longitude: loc.longitude ?? 0.0,
      state: loc.state,
      category: loc.categoryLabel,
      source: TravelLocationSource.metLocation,
      metLocationId: loc.id,
      metLocationName: loc.formattedName,
    );
  }

  /// Creates a TravelLocation from a curated TravelDestination.
  factory TravelLocation.fromFeaturedDestination(TravelDestination dest) {
    return TravelLocation(
      id: 'met:${dest.metLocationId.isNotEmpty ? dest.metLocationId : dest.id}',
      name: dest.name,
      latitude: dest.latitude ?? 0.0,
      longitude: dest.longitude ?? 0.0,
      state: dest.state,
      category: dest.category,
      source: TravelLocationSource.metLocation,
      metLocationId: dest.metLocationId,
      metLocationName: dest.name,
      imageUrl: dest.imageUrl,
      description: dest.description,
    );
  }

  /// Creates a TravelLocation for a geocoded detailed place.
  factory TravelLocation.fromGeocodedPlace({
    required String name,
    String? formattedAddress,
    required double latitude,
    required double longitude,
    required String state,
    String category = 'Detailed Place',
    String? metLocationId,
    String? metLocationName,
  }) {
    final latStr = latitude.toStringAsFixed(6);
    final lngStr = longitude.toStringAsFixed(6);
    return TravelLocation(
      id: 'geo:$latStr,$lngStr',
      name: name,
      formattedAddress: formattedAddress,
      latitude: latitude,
      longitude: longitude,
      state: state,
      category: category,
      source: TravelLocationSource.geocodedPlace,
      metLocationId: metLocationId,
      metLocationName: metLocationName,
    );
  }

  /// Converts to MetLocation for backwards compatibility.
  MetLocation toMetLocation() {
    return MetLocation(
      id: metLocationId ?? id,
      name: name.toUpperCase(),
      locationCategoryId: category,
      state: state,
      latitude: latitude,
      longitude: longitude,
    );
  }

  TravelLocation copyWith({
    String? id,
    String? name,
    String? formattedAddress,
    double? latitude,
    double? longitude,
    String? state,
    String? category,
    TravelLocationSource? source,
    String? metLocationId,
    String? metLocationName,
    String? imageUrl,
    String? description,
  }) {
    return TravelLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      state: state ?? this.state,
      category: category ?? this.category,
      source: source ?? this.source,
      metLocationId: metLocationId ?? this.metLocationId,
      metLocationName: metLocationName ?? this.metLocationName,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'formattedAddress': formattedAddress,
      'latitude': latitude,
      'longitude': longitude,
      'state': state,
      'category': category,
      'source': source.name,
      'metLocationId': metLocationId,
      'metLocationName': metLocationName,
      'imageUrl': imageUrl,
      'description': description,
    };
  }

  factory TravelLocation.fromJson(Map<String, dynamic> json) {
    return TravelLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      formattedAddress: json['formattedAddress'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] as String? ?? '',
      category: json['category'] as String? ?? 'Destination',
      source: json['source'] == 'geocodedPlace'
          ? TravelLocationSource.geocodedPlace
          : TravelLocationSource.metLocation,
      metLocationId: json['metLocationId'] as String?,
      metLocationName: json['metLocationName'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
    );
  }
}
