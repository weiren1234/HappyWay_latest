import 'met_location.dart';
import 'travel_destination.dart';

enum TravelLocationSource {

  metLocation,

  geocodedPlace,
}

class TravelLocation {

  final String id;

  final String name;

  final String? formattedAddress;

  final double latitude;

  final double longitude;

  final String state;

  final String category;

  final TravelLocationSource source;

  final String? metLocationId;

  final String? metLocationName;

  final String? imageUrl;

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

  bool get isMetLocation => source == TravelLocationSource.metLocation;

  bool get hasWeatherLocation => metLocationId != null && metLocationId!.isNotEmpty;

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
