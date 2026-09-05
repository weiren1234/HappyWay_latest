import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'trip_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  StreamSubscription<AuthState>? _authSub;

  UserModel? _user;
  UserPreferences? _preferences;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSeenOnboarding = false;

  UserModel? get user => _user;
  UserPreferences? get preferences => _preferences;
  bool get isLoggedIn => _user != null && !_user!.isGuest;
  bool get isAuthenticated => (_user != null && !_user!.isGuest) || (_authService.isAuthenticated && !isGuest);
  bool get isGuest => _user == null || _user!.isGuest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  AuthProvider() {
    _initAuthListener();
    restoreSession();
  }

  void _initAuthListener() {
    _authSub = _authService.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      if (session != null &&
          (event == AuthChangeEvent.signedIn ||
              event == AuthChangeEvent.tokenRefreshed ||
              event == AuthChangeEvent.initialSession ||
              event == AuthChangeEvent.userUpdated)) {

        final bool isNewUser = _user == null || _user!.id != session.user.id;
        final bool isUserUpdated = event == AuthChangeEvent.userUpdated;
        if (isNewUser || isUserUpdated) {
          debugPrint('[AuthProvider] Auth event: $event — reloading profile. '
              'currentUser.email after confirmation = ${session.user.email}');
          _isLoading = true;
          notifyListeners();
          await _loadUserProfileAndPreferences(session.user);
          _isLoading = false;
          notifyListeners();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _user = null;
        _preferences = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void completeOnboarding() {
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  void continueAsGuest() {
    _user = UserModel.guest();
    _preferences = const UserPreferences(userId: 'guest_user');
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      _isLoading = true;
      notifyListeners();

      await _loadUserProfileAndPreferences(currentUser);

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAuthenticatedUser() async {
    try {
      final userResponse = await Supabase.instance.client.auth.getUser();
      final freshUser = userResponse.user ?? Supabase.instance.client.auth.currentUser;
      if (freshUser != null) {
        debugPrint('[AuthProvider] refreshAuthenticatedUser: fresh user email = ${freshUser.email}');
        _isLoading = true;
        notifyListeners();
        await _loadUserProfileAndPreferences(freshUser);
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthProvider] Error in refreshAuthenticatedUser: $e');
      final fallbackUser = Supabase.instance.client.auth.currentUser;
      if (fallbackUser != null) {
        await _loadUserProfileAndPreferences(fallbackUser);
        notifyListeners();
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        _errorMessage = 'Unable to sign in. Please check your email and password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _loadUserProfileAndPreferences(user);

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Unable to sign in. Please check your network connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: name,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPasswordForEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to send reset link. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updatePassword(newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Failed to update password. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout({TripProvider? tripProvider}) async {
    try {
      await _authService.signOut();
    } catch (_) {}
    _user = null;
    _preferences = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> updateDisplayName(String newName) async {
    if (_user == null || _user!.isGuest) return false;
    try {
      await _profileService.updateDisplayName(_user!.id, newName);
      _user = _user!.copyWith(name: newName);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<({bool success, String message, bool confirmationSent})> updateEmail(String newEmail) async {
    if (_user == null || _user!.isGuest) {
      return (success: false, message: 'You must be signed in to update your email.', confirmationSent: false);
    }
    final normalizedNew = newEmail.trim().toLowerCase();

    final liveEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    debugPrint('[AuthProvider] Email before request = $liveEmail');
    debugPrint('[AuthProvider] Requested new email  = $normalizedNew');

    if (normalizedNew == liveEmail.trim().toLowerCase()) {
      return (success: true, message: 'Email is unchanged.', confirmationSent: false);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.updateEmail(normalizedNew);
      _isLoading = false;
      notifyListeners();

      debugPrint('[AuthProvider] currentUser.email after request = '
          '${Supabase.instance.client.auth.currentUser?.email}');

      return (
        success: true,
        message: 'Confirmation email sent. Please check your new email address to confirm the change.',
        confirmationSent: true,
      );
    } on AuthException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return (success: false, message: _friendlyEmailError(e.message), confirmationSent: false);
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update email: $e';
      notifyListeners();
      return (success: false, message: 'Failed to update email. Please try again.', confirmationSent: false);
    }
  }

  String _friendlyEmailError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already been registered')) {
      return 'This email address is already associated with another account.';
    }
    if (lower.contains('invalid email') || lower.contains('unable to validate')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('same email')) {
      return 'The new email is the same as your current email.';
    }
    if (lower.contains('expired') || lower.contains('otp expired')) {
      return 'The confirmation link has expired. Please request another email change.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    return raw;
  }

  Future<String?> toggleTripReminders(bool value, {TripProvider? tripProvider}) async {
    if (_user == null || _user!.isGuest) return null;

    try {
      await _profileService.updateUserPreferences(
        _user!.id,
        tripRemindersEnabled: value,
      );
      _preferences = _preferences?.copyWith(tripRemindersEnabled: value) ??
          UserPreferences(userId: _user!.id, tripRemindersEnabled: value);

      tripProvider?.setRemindersEnabled(value);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Failed to update reminder settings.';
    }
  }

  Future<void> updateThemeMode(String mode) async {
    if (_user == null || _user!.isGuest) return;
    try {
      await _profileService.updateUserPreferences(
        _user!.id,
        themeMode: mode,
      );
      _preferences = _preferences?.copyWith(themeMode: mode) ??
          UserPreferences(userId: _user!.id, themeMode: mode);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadUserProfileAndPreferences(User supaUser) async {
    try {
      final profileData = await _profileService.getProfile(supaUser.id);
      _user = UserModel.fromSupabase(
        id: supaUser.id,
        email: supaUser.email ?? '',
        profileData: profileData,
        createdAt: DateTime.tryParse(supaUser.createdAt),
      );

      final prefsData = await _profileService.getUserPreferences(supaUser.id);
      _preferences = prefsData ?? UserPreferences(userId: supaUser.id);
    } catch (e) {
      debugPrint('[AuthProvider] Error loading profile from Supabase: $e');
      final metaName = supaUser.userMetadata?['display_name'] as String?;
      _user = UserModel(
        id: supaUser.id,
        email: supaUser.email ?? '',
        name: metaName != null && metaName.isNotEmpty
            ? metaName
            : (supaUser.email?.split('@').first ?? 'Traveler'),
        joinedAt: DateTime.tryParse(supaUser.createdAt) ?? DateTime.now(),
      );
      _preferences = UserPreferences(userId: supaUser.id);
    }
  }
}
