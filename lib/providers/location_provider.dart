import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_location.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../services/location_service.dart';
import '../main.dart' show navigatorKey, scaffoldMessengerKey;

/// LocationProvider manages the user's travel origin:
/// - Real device GPS positioning (strictly displayed as "Current Location")
/// - Manual place/address selection with resolved exact coordinates
/// - Runtime permission states and GPS refresh actions
/// - Automatic continuation of location flow after returning from Android Location Settings
class LocationProvider extends ChangeNotifier with WidgetsBindingObserver {
  UserLocation? _currentLocation;
  LocationPermissionState _permissionState = LocationPermissionState.granted;
  bool _isLoading = false;
  String? _errorMessage;

  // Lifecycle & settings resume tracking
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

  // ─── Lifecycle Observer ───────────────────────────────────────────────────────
  // Handles automatic continuation when returning from system Location Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForLocationSettings) {
      _handleResumeFromLocationSettings();
    }
  }

  Future<void> _handleResumeFromLocationSettings() async {
    // Clear waiting flag immediately to prevent re-entrant triggers
    _waitingForLocationSettings = false;

    // Small delay to allow Android LocationManager cache to refresh after Settings activity returns
    await Future.delayed(const Duration(milliseconds: 200));

    final serviceNow = await Geolocator.isLocationServiceEnabled();
    if (!serviceNow) {
      // User returned without enabling location:
      // Keep previous/manual location, do not loop or reopen dialog.
      _isLoading = false;
      _isResolvingLocation = false;
      notifyListeners();
      if (_pendingLocationCompleter != null && !_pendingLocationCompleter!.isCompleted) {
        _pendingLocationCompleter!.complete(false);
      }
      _pendingLocationCompleter = null;
      return;
    }

    // Location service is now ON! Automatically continue permission + GPS flow
    final success = await _continueLocationFlow();

    _isResolvingLocation = false;
    if (_pendingLocationCompleter != null && !_pendingLocationCompleter!.isCompleted) {
      _pendingLocationCompleter!.complete(success);
    }
    _pendingLocationCompleter = null;
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Centralized user-facing "Current Location" flow with interactive dialogs.
  // Call this from any screen instead of calling selectCurrentLocation() directly.
  // Returns true if GPS position was successfully resolved.
  // ─────────────────────────────────────────────────────────────────────────────

  /// Runs the full location resolution flow with user-facing dialogs for each
  /// error state (service off, denied, denied-forever, GPS failure).
  /// Screens should call this single method and react to the result via
  /// [currentLocation] / [isGps] / [permissionState].
  Future<bool> requestCurrentLocation(BuildContext context) async {
    // Guard: ignore duplicate taps while a request is already in-flight or waiting for resume
    if (_isResolvingLocation || _waitingForLocationSettings) return false;
    _isResolvingLocation = true;

    // ── 1. Check if location service is enabled ──────────────────────────────
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

      // User chose "Turn On Location": wait for app to resume after user toggles setting
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

    // ── 2. Location service is already ON: proceed directly with permission & GPS flow
    try {
      final success = await _continueLocationFlow();
      return success;
    } finally {
      _isResolvingLocation = false;
    }
  }

  /// Sequential check for HappyWay app permission, then high-accuracy GPS position.
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

      // Permission granted: acquire high-accuracy GPS position
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

  // ─── Private dialog helpers ──────────────────────────────────────────────────

  /// Shows "Turn on Location" dialog when device location services are OFF.
  /// Returns true if the user chose "Turn On Location" (agreed to open settings).
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

  /// Shows dialog when permission is permanently denied (deniedForever).
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

  /// Shows a SnackBar when permission is denied (not permanently).
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

  /// Shows a SnackBar when GPS lookup fails.
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
