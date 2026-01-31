import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'app_locale';

  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get loaded => _loaded;
  String? get localeCode => _locale?.languageCode;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == 'id') {
      _locale = const Locale('id', 'ID');
    } else if (code == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = null; // Follow device locale
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocaleCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      _locale = null;
      await prefs.remove(_prefKey);
    } else {
      _locale = code == 'id'
          ? const Locale('id', 'ID')
          : const Locale('en', 'US');
      await prefs.setString(_prefKey, code);
    }
    notifyListeners();
  }
}
