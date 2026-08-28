import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthService encapsulates Supabase Authentication operations.
/// Handles signup with display_name metadata, email/password login, logout,
/// session restoration, and password recovery deep links.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Current authenticated user (null if not logged in).
  User? get currentUser => _client.auth.currentUser;

  /// Current active Supabase session.
  Session? get currentSession => _client.auth.currentSession;

  /// True if a valid authenticated user session exists.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Stream of Supabase Auth state changes.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Registers a new user with email, password, and display_name metadata.
  /// NOTE: With Email Confirmation enabled, Supabase creates the user in `auth.users`
  /// and the database trigger automatically creates `profiles` & `user_preferences`.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: 'io.happyway.app://email-confirmed',
      data: {
        'display_name': displayName.trim(),
      },
    );
  }

  /// Signs in an existing user with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out the current user session.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a password reset email with deep link redirect URL.
  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.happyway.app://reset-password',
    );
  }

  /// Updates current user's password during password recovery.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Updates current user's email address via Supabase Auth (single-confirmation flow).
  /// Supabase sends one confirmation link to the NEW email address.
  /// After the user clicks it, Supabase redirects to [emailRedirectTo].
  ///
  /// Uses a distinct host (`email-change-confirmed`) so [_handleDeepLink] in main.dart
  /// can differentiate email-change confirmations (authenticated) from signup
  /// confirmations (`email-confirmed`, unauthenticated).
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _client.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
      emailRedirectTo: 'io.happyway.app://email-change-confirmed',
    );
  }
}
