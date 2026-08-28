import 'package:flutter/material.dart';

/// ThemeProvider manages dark and light theme selection and glassmorphism settings.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _glassBlurSigma = 12.0;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  double get glassBlurSigma => _glassBlurSigma;

  /// Sets the theme mode based on string key ('dark' or 'light').
  /// Defaults to [ThemeMode.dark] for null, unknown, or legacy values.
  void setThemeMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    if (normalized == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  /// Toggles between dark and light themes.
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void updateGlassBlur(double sigma) {
    _glassBlurSigma = sigma;
    notifyListeners();
  }
}
