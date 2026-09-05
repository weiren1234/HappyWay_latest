import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setTab(int index) {
    debugPrint('[NavigationProvider] setTab: $index (previous: $_currentIndex)');
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
