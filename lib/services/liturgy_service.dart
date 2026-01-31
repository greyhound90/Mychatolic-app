import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';

class LiturgyModel {
  final DateTime date;
  final String color; // e.g., 'green', 'white', 'red', 'purple'
  final String feastName;
  final Map<String, dynamic> readings;

  LiturgyModel({
    required this.date,
    required this.color,
    required this.feastName,
    required this.readings,
  });

  factory LiturgyModel.fromJson(Map<String, dynamic> json) {
    return LiturgyModel(
      date: DateTime.parse(json['date']),
      color: json['color'] ?? 'green',
      feastName: json['feast_name'] ?? '',
      readings: json['readings'] ?? {},
    );
  }
}

class LiturgicalPalette {
  final Color base;
  final Color accent;
  final Color tint;
  final Color border;
  final Color onAccent;
  final Color chipBg;
  final Color chipText;
  final Color dot;

  const LiturgicalPalette({
    required this.base,
    required this.accent,
    required this.tint,
    required this.border,
    required this.onAccent,
    required this.chipBg,
    required this.chipText,
    required this.dot,
  });

  LiturgicalPalette copyWith({
    Color? base,
    Color? accent,
    Color? tint,
    Color? border,
    Color? onAccent,
    Color? chipBg,
    Color? chipText,
    Color? dot,
  }) {
    return LiturgicalPalette(
      base: base ?? this.base,
      accent: accent ?? this.accent,
      tint: tint ?? this.tint,
      border: border ?? this.border,
      onAccent: onAccent ?? this.onAccent,
      chipBg: chipBg ?? this.chipBg,
      chipText: chipText ?? this.chipText,
      dot: dot ?? this.dot,
    );
  }
}

class LiturgyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch liturgy for a specific date (YYYY-MM-DD)
  Future<LiturgyModel?> getLiturgyByDate(DateTime date) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('daily_liturgy')
          .select()
          .eq('date', dateString)
          .maybeSingle(); // Returns null if no record found

      if (response == null) {
        return null;
      }

      return LiturgyModel.fromJson(response);
    } catch (e, st) {
      AppLogger.logError("Error fetching liturgy", error: e, stackTrace: st);
      return null;
    }
  }

  /// Helper to convert DB color string to Flutter Color
  static Color getLiturgicalColor(String? colorCode) {
    switch (colorCode?.toLowerCase()) {
      case 'red':
        return const Color(0xFFC62828);
      case 'green':
        return const Color(0xFF1B5E20);
      case 'purple':
        return const Color(0xFF5B2C83);
      case 'white':
      case 'gold':
      case 'putih':
        return const Color(0xFFFFFFFF);
      case 'rose':
      case 'pink':
        return const Color(0xFFD81B60);
      case 'black':
        return const Color(0xFF111111);
      default:
        return Colors.blue; // Safe fallback
    }
  }

  /// Helper for text color on top of liturgical backgrounds
  static Color getLiturgicalTextColor(String? colorCode) {
    switch (colorCode?.toLowerCase()) {
      case 'white':
      case 'gold':
      case 'putih':
        return const Color(0xFF1A1A1A);
      case 'rose':
      case 'pink':
        return const Color(0xFF1A1A1A);
      case 'black':
        return Colors.white;
      case 'red':
      case 'green':
      case 'purple':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  static LiturgicalPalette paletteFor(
    String? liturgyColorName, {
    required Brightness brightness,
  }) {
    final name = (liturgyColorName ?? '').trim().toLowerCase();
    final base = _baseFor(name);
    final accent = _accentFor(name);
    Color tint;
    Color border;
    Color onAccent = _onAccentFor(accent);
    Color chipBg;
    Color chipText;
    Color dot;

    if (name == 'white' || name == 'gold' || name == 'putih') {
      tint = const Color(0xFFFFFBF2);
      border = const Color(0xFFE6E6E6);
      onAccent = const Color(0xFF121212);
      chipBg = const Color(0xFFFFFFFF);
      chipText = const Color(0xFF121212);
      dot = const Color(0xFFFFFFFF);
    } else if (name == 'black') {
      tint = const Color(0xFFF2F2F2);
      border = const Color(0xFFE0E0E0);
      onAccent = Colors.white;
      chipBg = tint;
      chipText = const Color(0xFF111111);
      dot = const Color(0xFF2C2C2C);
    } else {
      tint = _softTintFromAccent(accent, brightness);
      border = accent.withOpacity(0.55);
      chipBg = accent.withOpacity(0.12);
      chipText = _chipTextFor(accent);
      dot = accent;
    }

    return LiturgicalPalette(
      base: base,
      accent: accent,
      tint: tint,
      border: border,
      onAccent: onAccent,
      chipBg: chipBg,
      chipText: chipText,
      dot: dot,
    );
  }

  static Color _baseFor(String name) {
    switch (name) {
      case 'white':
      case 'gold':
      case 'putih':
        return const Color(0xFFFFFFFF);
      case 'red':
        return const Color(0xFFC62828);
      case 'green':
        return const Color(0xFF1B5E20);
      case 'purple':
        return const Color(0xFF5B2C83);
      case 'rose':
      case 'pink':
        return const Color(0xFFD81B60);
      case 'black':
        return const Color(0xFF111111);
      default:
        return Colors.blue;
    }
  }

  static Color _accentFor(String name) {
    switch (name) {
      case 'white':
      case 'gold':
      case 'putih':
        return const Color(0xFFD4AF37);
      case 'red':
        return const Color(0xFFC62828);
      case 'green':
        return const Color(0xFF1B5E20);
      case 'purple':
        return const Color(0xFF5B2C83);
      case 'rose':
      case 'pink':
        return const Color(0xFFD81B60);
      case 'black':
        return const Color(0xFF2C2C2C);
      default:
        return Colors.blue;
    }
  }

  static Color _onAccentFor(Color accent) {
    return accent.computeLuminance() > 0.62
        ? const Color(0xFF1A1A1A)
        : Colors.white;
  }

  static Color _softTintFromAccent(Color accent, Brightness brightness) {
    final hsl = HSLColor.fromColor(accent);
    final lightness =
        (hsl.lightness + (brightness == Brightness.dark ? 0.35 : 0.55))
            .clamp(0.86, 0.97)
            .toDouble();
    final saturation = (hsl.saturation * 0.35).clamp(0.08, 0.4).toDouble();
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  static Color _chipTextFor(Color accent) {
    final lum = accent.computeLuminance();
    if (lum > 0.7) return const Color(0xFF121212);
    return accent;
  }
}
