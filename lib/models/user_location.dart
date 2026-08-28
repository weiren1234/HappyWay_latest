import 'met_location.dart';
import 'travel_location.dart';

/// Type of travel origin.
enum UserLocationType {
  /// Real device GPS position. Visible UI label is strictly "Current Location".
  currentLocation,

  /// Manually selected place, town, or address.
  selectedPlace,
}

/// UserLocation represents the journey starting point (origin).
/// It clearly distinguishes between:
/// - Real device GPS position (`UserLocationType.currentLocation`, with exact GPS coords & accuracy)
/// - Manually selected place (`UserLocationType.selectedPlace`, with resolved place coords)
class UserLocation {
  /// Exact origin latitude used directly for OSRM route calculation.
  final double latitude;

  /// Exact origin longitude used directly for OSRM route calculation.
  final double longitude;

  /// Visible display name:
  /// - For GPS: strictly "Current Location"
  /// - For manual: resolved place name (e.g. "Taman Danau Kota, Kuala Lumpur")
  final String name;

  /// Supporting subtitle (e.g. "Device GPS (±8m)" or "Selected Origin").
  final String subtitle;

  /// Origin type (currentLocation vs selectedPlace).
  final UserLocationType type;

  /// Optional state (e.g. "Kuala Lumpur", "Selangor", "Sabah").
  final String? state;

  /// GPS horizontal accuracy in meters (null for manual locations).
  final double? accuracy;

  /// Optional internal reverse-geocoded address for reference.
  final String? reverseGeocodedAddress;

  /// True if this location was acquired from real device GPS.
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

  /// Factory for device GPS location.
  /// The visible [name] is strictly "Current Location" — never replaced by reverse-geocoded names.
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

  /// Factory for a manually selected [TravelLocation] (geocoded place or MET location).
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

  /// Factory for a manually selected [MetLocation].
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
