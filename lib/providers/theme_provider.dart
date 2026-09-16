import 'package:flutter/material.dart';

// ThemeProvider — global state for dark/light mode.
// Wraps the app in MultiProvider so any widget can call context.watch<ThemeProvider>()
// to rebuild instantly when theme changes (no setState hacks).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // triggers rebuild across all listeners
  }
}
