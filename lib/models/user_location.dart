import 'met_location.dart';
import 'travel_location.dart';

enum UserLocationType {

  currentLocation,

  selectedPlace,
}

class UserLocation {

  final double latitude;

  final double longitude;

  final String name;

  final String subtitle;

  final UserLocationType type;

  final String? state;

  final double? accuracy;

  final String? reverseGeocodedAddress;

  bool get isGps => type == UserLocationType.currentLocation;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.subtitle,
    required this.type,
    this.state,
    this.accuracy,
    this.reverseGeocodedAddress,
  });

  factory UserLocation.fromGps({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? reverseGeocodedAddress,
    String? state,
  }) {
    final sub = accuracy != null
        ? 'Device GPS (±${accuracy.round()}m)'
        : 'Device GPS';

    return UserLocation(
      latitude: latitude,
      longitude: longitude,
      name: 'Current Location',
      subtitle: sub,
      type: UserLocationType.currentLocation,
      state: state,
      accuracy: accuracy,
      reverseGeocodedAddress: reverseGeocodedAddress,
    );
  }

  factory UserLocation.fromTravelLocation(TravelLocation location) {
    return UserLocation(
      latitude: location.latitude,
      longitude: location.longitude,
      name: location.name,
      subtitle: '${location.category} • ${location.state}',
      type: UserLocationType.selectedPlace,
      state: location.state,
      reverseGeocodedAddress: location.formattedAddress,
    );
  }

  factory UserLocation.fromMetLocation(MetLocation location) {
    return UserLocation(
      latitude: location.latitude ?? 3.1390,
      longitude: location.longitude ?? 101.6869,
      name: location.formattedName,
      subtitle: '${location.categoryLabel} • ${location.state}',
      type: UserLocationType.selectedPlace,
      state: location.state,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'name': name,
        'subtitle': subtitle,
        'type': type.name,
        'state': state,
        'accuracy': accuracy,
        'reverseGeocodedAddress': reverseGeocodedAddress,
      };

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? (json['isGps'] == true ? 'currentLocation' : 'selectedPlace');
    return UserLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      name: json['name'] as String? ?? 'Current Location',
      subtitle: json['subtitle'] as String? ?? '',
      type: typeStr == 'currentLocation'
          ? UserLocationType.currentLocation
          : UserLocationType.selectedPlace,
      state: json['state'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      reverseGeocodedAddress: json['reverseGeocodedAddress'] as String?,
    );
  }
}
