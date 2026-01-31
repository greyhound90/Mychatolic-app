import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadTheme();
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode');
    if (themeString == 'dark') {
      _themeMode = ThemeMode.light;
      await prefs.setString('themeMode', 'light');
    } else if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
      await prefs.setString('themeMode', 'light');
    }
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';

    await prefs.setString('themeMode', value);
  }
}
