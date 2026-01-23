import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppTypography {
  static TextStyle title(Color color) => GoogleFonts.manrope(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle subtitle(Color color) => GoogleFonts.manrope(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body(Color color) => GoogleFonts.manrope(
        fontSize: 14,
        height: 1.6,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle small(Color color) => GoogleFonts.manrope(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

class ReaderTypography {
  static TextStyle verseText({
    required double fontSize,
    required double lineHeight,
    required Color color,
  }) {
    return GoogleFonts.sourceSerif4(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
    );
  }

  static TextStyle verseNumber({
    required double fontSize,
    required Color color,
  }) {
    return GoogleFonts.sourceSerif4(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color.withValues(alpha: 0.6),
    );
  }
}
