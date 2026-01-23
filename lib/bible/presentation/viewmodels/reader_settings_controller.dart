import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSettings {
  final double fontSize;
  final double lineHeight;
  final String mode;
  final bool paragraphMode;

  const ReaderSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.mode,
    required this.paragraphMode,
  });

  static const ReaderSettings defaults = ReaderSettings(
    fontSize: 18,
    lineHeight: 1.8,
    mode: 'light',
    paragraphMode: true,
  );

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? mode,
    bool? paragraphMode,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      mode: mode ?? this.mode,
      paragraphMode: paragraphMode ?? this.paragraphMode,
    );
  }
}

class ReaderSettingsController extends ChangeNotifier {
  ReaderSettingsController() {
    _load();
  }

  static const String _fontSizeKey = 'bible_reader_font_size';
  static const String _lineHeightKey = 'bible_reader_line_height';
  static const String _modeKey = 'bible_reader_mode';
  static const String _paragraphKey = 'bible_reader_paragraph_mode';

  ReaderSettings _settings = ReaderSettings.defaults;
  bool _isReady = false;
  SharedPreferences? _prefs;

  ReaderSettings get settings => _settings;
  bool get isReady => _isReady;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _settings = ReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? ReaderSettings.defaults.fontSize,
      lineHeight: prefs.getDouble(_lineHeightKey) ?? ReaderSettings.defaults.lineHeight,
      mode: prefs.getString(_modeKey) ?? ReaderSettings.defaults.mode,
      paragraphMode: prefs.getBool(_paragraphKey) ?? ReaderSettings.defaults.paragraphMode,
    );
    _isReady = true;
    notifyListeners();
  }

  Future<void> update({
    double? fontSize,
    double? lineHeight,
    String? mode,
    bool? paragraphMode,
  }) async {
    _settings = _settings.copyWith(
      fontSize: fontSize,
      lineHeight: lineHeight,
      mode: mode,
      paragraphMode: paragraphMode,
    );
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble(_fontSizeKey, _settings.fontSize);
    await prefs.setDouble(_lineHeightKey, _settings.lineHeight);
    await prefs.setString(_modeKey, _settings.mode);
    await prefs.setBool(_paragraphKey, _settings.paragraphMode);
  }
}
