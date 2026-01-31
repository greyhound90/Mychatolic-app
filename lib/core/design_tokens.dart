import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF0088CC);
  static const Color primaryMuted = Color(0xFF4DA3D9);
  static const Color primaryDark = Color(0xFF007AB8);

  // Neutrals
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF7F7F7);
  static const Color text = Color(0xFF121212);
  static const Color textBody = Color(0xFF555555);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textDisabled = Color(0xFFBBBBBB);
  static const Color border = Color(0xFFEAEAEA);

  // Status
  static const Color success = Color(0xFF2ECC71);
  static const Color danger = Color(0xFFE74C3C);
}

class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 22;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

class AppShadows {
  static final List<BoxShadow> level1 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> level2 = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppTextStyles {
  static final TextTheme baseTextTheme = GoogleFonts.outfitTextTheme();

  static TextStyle h1(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall ??
        baseTextTheme.displaySmall ??
        const TextStyle(fontSize: 28);
    return base.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    );
  }

  static TextStyle h2(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineSmall ??
        baseTextTheme.headlineSmall ??
        const TextStyle(fontSize: 22);
    return base.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    );
  }

  static TextStyle title(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge ??
        baseTextTheme.titleLarge ??
        const TextStyle(fontSize: 18);
    return base.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.text,
    );
  }

  static TextStyle body(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium ??
        baseTextTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    return base.copyWith(color: AppColors.textBody);
  }

  static TextStyle caption(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall ??
        baseTextTheme.bodySmall ??
        const TextStyle(fontSize: 12);
    return base.copyWith(color: AppColors.textMuted);
  }
}
