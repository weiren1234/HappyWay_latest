import 'package:flutter/material.dart';
import '../models/user_location.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../services/location_service.dart';

/// LocationProvider manages the user's travel origin:
/// - Real device GPS positioning (strictly displayed as "Current Location")
/// - Manual place/address selection with resolved exact coordinates
/// - Runtime permission states and GPS refresh actions
class LocationProvider extends ChangeNotifier {
  UserLocation? _currentLocation;
  LocationPermissionState _permissionState = LocationPermissionState.granted;
  bool _isLoading = false;
  String? _errorMessage;

  UserLocation? get currentLocation => _currentLocation;
  LocationPermissionState get permissionState => _permissionState;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasLocation => _currentLocation != null;
  bool get isGps => _currentLocation?.isGps ?? false;

  LocationProvider() {
    fetchCurrentLocation();
  }

  /// Requests device GPS permission and fetches high-accuracy GPS coordinates.
  /// Sets origin to "Current Location" with real device coordinates.
  Future<void> fetchCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await LocationService.getCurrentLocation();
    _permissionState = result.state;

    if (result.isSuccess) {
      _currentLocation = result.location;
      _errorMessage = null;
    } else {
      _errorMessage = result.errorMessage;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Sets a manually selected starting place (geocoded place or MET location).
  void setManualLocation(TravelLocation location) {
    _currentLocation = UserLocation.fromTravelLocation(location);
    _errorMessage = null;
    notifyListeners();
  }

  /// Sets a manually selected starting point from an official MET location.
  void setManualLocationFromMet(MetLocation location) {
    _currentLocation = UserLocation.fromMetLocation(location);
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears manual selection and refreshes device GPS position.
  Future<void> selectCurrentLocation() async {
    await fetchCurrentLocation();
  }

  /// Retries GPS acquisition.
  Future<void> retryGpsLocation() async {
    await fetchCurrentLocation();
  }
}
