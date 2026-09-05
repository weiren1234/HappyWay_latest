import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_location.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../services/location_service.dart';
import '../main.dart' show navigatorKey, scaffoldMessengerKey;

class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  UserLocation? _currentLocation;
  LocationPermissionState _permissionState = LocationPermissionState.granted;
  bool _isLoading = false;
  String? _errorMessage;

  bool _isResolvingLocation = false;
  bool _waitingForLocationSettings = false;
  Completer<bool>? _pendingLocationCompleter;

  bool _isDisposed = false;

  UserLocation? get currentLocation => _currentLocation;
  LocationPermissionState get permissionState => _permissionState;
  bool get isLoading => _isLoading;
  bool get isResolvingLocation => _isResolvingLocation || _waitingForLocationSettings;
  String? get errorMessage => _errorMessage;

  bool get hasLocation => _currentLocation != null;
  bool get isGps => _currentLocation?.isGps ?? false;

  LocationProvider() {
    WidgetsBinding.instance.addObserver(this);
    fetchCurrentLocation();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    if (_pendingLocationCompleter != null && !_pendingLocationCompleter!.isCompleted) {
      _pendingLocationCompleter!.complete(false);
    }
    _pendingLocationCompleter = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForLocationSettings) {
      _handleResumeFromLocationSettings();
    }
  }

  Future<void> _handleResumeFromLocationSettings() async {

    _waitingForLocationSettings = false;

    await Future.delayed(const Duration(milliseconds: 200));

    final serviceNow = await Geolocator.isLocationServiceEnabled();
    if (!serviceNow) {

      _isLoading = false;
      _isResolvingLocation = false;
      notifyListeners();
      if (_pendingLocationCompleter != null && !_pendingLocationCompleter!.isCompleted) {
        _pendingLocationCompleter!.complete(false);
      }
      _pendingLocationCompleter = null;
      return;
    }

    final success = await _continueLocationFlow();

    _isResolvingLocation = false;
    if (_pendingLocationCompleter != null && !_pendingLocationCompleter!.isCompleted) {
      _pendingLocationCompleter!.complete(success);
    }
    _pendingLocationCompleter = null;
  }

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

  void setManualLocation(TravelLocation location) {
    _currentLocation = UserLocation.fromTravelLocation(location);
    _errorMessage = null;
    notifyListeners();
  }

  void setManualLocationFromMet(MetLocation location) {
    _currentLocation = UserLocation.fromMetLocation(location);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectCurrentLocation() async {
    await fetchCurrentLocation();
  }

  Future<void> retryGpsLocation() async {
    await fetchCurrentLocation();
  }

  Future<bool> requestCurrentLocation(BuildContext context) async {

    if (_isResolvingLocation || _waitingForLocationSettings) return false;
    _isResolvingLocation = true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) {
        _isResolvingLocation = false;
        return false;
      }
      final turnOn = await _showLocationServiceDialog(context);
      if (!turnOn) {
        _isResolvingLocation = false;
        return false;
      }

      _waitingForLocationSettings = true;
      _pendingLocationCompleter = Completer<bool>();

      try {
        await Geolocator.openLocationSettings();
      } catch (e) {
        debugPrint('[LocationProvider] Error opening location settings: $e');
        _waitingForLocationSettings = false;
        _isResolvingLocation = false;
        _pendingLocationCompleter = null;
        return false;
      }

      return await _pendingLocationCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _waitingForLocationSettings = false;
          _isResolvingLocation = false;
          _isLoading = false;
          _pendingLocationCompleter = null;
          notifyListeners();
          return false;
        },
      );
    }

    try {
      final success = await _continueLocationFlow();
      return success;
    } finally {
      _isResolvingLocation = false;
    }
  }

  Future<bool> _continueLocationFlow() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.deniedForever) {
        _permissionState = LocationPermissionState.permanentlyDenied;
        _isLoading = false;
        notifyListeners();
        await _showPermissionPermanentlyDeniedDialog();
        return false;
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          _permissionState = LocationPermissionState.permanentlyDenied;
          _isLoading = false;
          notifyListeners();
          await _showPermissionPermanentlyDeniedDialog();
          return false;
        }
        if (permission == LocationPermission.denied) {
          _permissionState = LocationPermissionState.denied;
          _isLoading = false;
          notifyListeners();
          _showPermissionDeniedMessage();
          return false;
        }
      }

      final result = await LocationService.getCurrentLocation();
      _permissionState = result.state;

      if (result.isSuccess) {
        _currentLocation = result.location;
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.errorMessage;
        _isLoading = false;
        notifyListeners();
        _showGpsFailureMessage();
        return false;
      }
    } catch (e) {
      debugPrint('[LocationProvider] Error during location flow: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _showLocationServiceDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Color(0xFFFFB300), size: 22),
            SizedBox(width: 10),
            Text('Turn on Location'),
          ],
        ),
        content: const Text(
          'Location services are turned off.\nTurn on location to use your current position.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Turn On Location'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showPermissionPermanentlyDeniedDialog() async {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;
    await showDialog<void>(
      context: navContext,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_disabled_rounded, color: Color(0xFFEF5350), size: 22),
            SizedBox(width: 10),
            Text('Location Permission Disabled'),
          ],
        ),
        content: const Text(
          'Location access is disabled for HappyWay.\nEnable it in App Settings to use Current Location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await Geolocator.openAppSettings();
              } catch (e) {
                debugPrint('[LocationProvider] Error opening app settings: $e');
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedMessage() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Location permission was denied. Please select a starting point manually or allow permission.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showGpsFailureMessage() {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Unable to get your current location. Please try again or choose a location manually.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
