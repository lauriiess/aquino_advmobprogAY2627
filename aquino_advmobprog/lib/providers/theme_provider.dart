import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeData get lightTheme {
    return ThemeData.light();
  }

  ThemeData get darkTheme {
    return ThemeData.dark();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}