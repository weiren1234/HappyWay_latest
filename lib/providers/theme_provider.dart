import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  double _glassBlurSigma = 12.0;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  double get glassBlurSigma => _glassBlurSigma;

  void setThemeMode(String mode) {
    final normalized = mode.trim().toLowerCase();
    if (normalized == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void updateGlassBlur(double sigma) {
    _glassBlurSigma = sigma;
    notifyListeners();
  }
}
