import 'dart:convert';
import 'package:flutter/services.dart';

class AppConfig {
  AppConfig._();

  static String? _metToken;
  static String? _pexelsApiKey;
  static bool _loaded = false;

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

  static Future<String?> getMetToken() async {
    await _ensureLoaded();
    return _metToken;
  }

  static Future<String?> getPexelsApiKey() async {
    await _ensureLoaded();
    return _pexelsApiKey;
  }

  static void reset() {
    _loaded = false;
    _metToken = null;
    _pexelsApiKey = null;
  }
}
