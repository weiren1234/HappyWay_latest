import 'dart:convert';
import 'package:flutter/services.dart';

/// AppConfig loads the token from the bundled assets/config/app_config.json.
///
/// NOTE: This file is git-ignored to keep the token out of source control.
/// However, assets are bundled into the APK and can be extracted by anyone
/// who has access to the built binary. This approach is acceptable for this
/// academic/demo project but should not be used for production credentials.
class AppConfig {
  AppConfig._();

  static String? _metToken;
  static String? _pexelsApiKey;
  static bool _loaded = false;

  /// Loads configuration from assets/config/app_config.json if not already loaded.
  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/config/app_config.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _metToken = json['met_token'] as String?;
      _pexelsApiKey = json['pexels_api_key'] as String?;
    } catch (_) {
      _metToken = null;
      _pexelsApiKey = null;
    }
    _loaded = true;
  }

  /// Returns the MET Malaysia token.
  static Future<String?> getMetToken() async {
    await _ensureLoaded();
    return _metToken;
  }

  /// Returns the Pexels API key.
  static Future<String?> getPexelsApiKey() async {
    await _ensureLoaded();
    return _pexelsApiKey;
  }

  /// Resets the cached tokens (useful for testing).
  static void reset() {
    _loaded = false;
    _metToken = null;
    _pexelsApiKey = null;
  }
}
