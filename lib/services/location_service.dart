import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/user_location.dart';

enum LocationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

class LocationResult {
  final UserLocation? location;
  final LocationPermissionState state;
  final String? errorMessage;

  const LocationResult({
    this.location,
    required this.state,
    this.errorMessage,
  });

  bool get isSuccess => state == LocationPermissionState.granted && location != null;
}

class LocationService {

  static Future<LocationResult> getCurrentLocation() async {
    try {

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          state: LocationPermissionState.serviceDisabled,
          errorMessage: 'Location services are disabled on your device. Please enable GPS or select a starting location manually.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const LocationResult(
            state: LocationPermissionState.denied,
            errorMessage: 'Location permission was denied. Please select a starting point manually.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          state: LocationPermissionState.permanentlyDenied,
          errorMessage: 'Location permission is permanently denied. You can select your starting point manually or enable permissions in App Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('Current GPS position: (${position.latitude}, ${position.longitude}), accuracy: ${position.accuracy} m');

      String? internalAddress;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final subLocality = p.subLocality?.isNotEmpty == true ? p.subLocality!.trim() : null;
          final locality = p.locality?.isNotEmpty == true ? p.locality!.trim() : null;
          final admin = p.administrativeArea?.isNotEmpty == true ? p.administrativeArea!.trim() : null;

          if (subLocality != null && locality != null && subLocality != locality) {
            internalAddress = '$subLocality, $locality';
          } else if (subLocality != null) {
            internalAddress = subLocality;
          } else if (locality != null) {
            internalAddress = admin != null ? '$locality, $admin' : locality;
          } else {
            internalAddress = admin;
          }
        }
      } catch (e) {
        debugPrint('Optional reverse geocoding note: $e');
      }

      final userLoc = UserLocation.fromGps(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        reverseGeocodedAddress: internalAddress,
      );

      return LocationResult(
        location: userLoc,
        state: LocationPermissionState.granted,
      );
    } catch (e) {
      return LocationResult(
        state: LocationPermissionState.error,
        errorMessage: 'Unable to acquire GPS position: ${e.toString()}',
      );
    }
  }

  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  static Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
