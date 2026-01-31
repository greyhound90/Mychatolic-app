import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. DEFINISI PALET WARNA (Lengkap) ---
const Color kPrimary = Color(0xFF0088CC); // Biru Branding
const Color kSecondary = Color(0xFF4DA3D9);
const Color kBackground = Color(0xFFF5F5F5); // Abu-abu sangat muda
const Color kSurface = Color(0xFFFFFFFF); // Putih
const Color kBorder = Color(0xFFE6E6E6); // Abu-abu batas
const Color kTextTitle = Color(0xFF121212);
const Color kTextBody = Color(0xFF555555);
const Color kTextMeta = Color(0xFF9E9E9E);
const Color kError = Color(0xFFE74C3C);
const Color kSuccess = Color(0xFF2ECC71);

// --- Dark Premium Palette ---
const Color kDarkPrimary = Color(0xFF0088CC);
const Color kDarkSecondary = Color(0xFF4DA3D9);
const Color kDarkBackground = Color(0xFF121212);
const Color kDarkSurface = Color(0xFF1C1C1C);
const Color kDarkBorder = Color(0xFF2A2A2A);
const Color kDarkTextPrimary = Color(0xFFFFFFFF);
const Color kDarkTextSecondary = Color(0xFFBBBBBB);
const Color kDarkTextMuted = Color(0xFF9E9E9E);
const Color kDarkError = Color(0xFFE74C3C);

// --- 2. TEMA APLIKASI ---
class MyCatholicTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      primaryColor: kPrimary,
      scaffoldBackgroundColor: kBackground,
      cardColor: kSurface,
      dividerColor: kBorder,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        secondary: kSecondary,
        background: kBackground,
        surface: kSurface,
        error: kError,
        onPrimary: Colors.white,
        onSurface: kTextTitle,
        onBackground: kTextTitle,
      ),

      // Typography
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: kTextBody,
        displayColor: kTextTitle,
      ),

      cardTheme: CardThemeData(
        color: kSurface,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kBorder),
        ),
      ),

      // AppBar Theme (Biru)
      appBarTheme: AppBarTheme(
        backgroundColor: kPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Bottom Nav Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: kSurface,
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextMeta,
        selectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurface,
        hintStyle: const TextStyle(color: kTextMeta),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.4),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: GoogleFonts.outfit(
          color: kTextTitle,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: kTextBody,
          fontSize: 14,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kSurface,
        modalBackgroundColor: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: kSurface,
        headerForegroundColor: kTextTitle,
        dayForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          if (states.contains(MaterialState.disabled)) return kTextMeta;
          return kTextTitle;
        }),
        dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kPrimary;
          return Colors.transparent;
        }),
        yearForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kTextTitle;
          return kTextBody;
        }),
        yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return kPrimary.withOpacity(0.15);
          }
          return Colors.transparent;
        }),
        todayForegroundColor: const MaterialStatePropertyAll(kPrimary),
        todayBorder: const BorderSide(color: kPrimary, width: 1.2),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: kTextMeta, width: 1.4),
        checkColor: const MaterialStatePropertyAll(Colors.white),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kPrimary;
          return Colors.transparent;
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: kTextTitle,
        unselectedLabelColor: kTextMeta,
        indicatorColor: kPrimary,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: kTextTitle,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseText = GoogleFonts.outfitTextTheme();
    final darkTextTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(color: kDarkTextPrimary),
      displayMedium: baseText.displayMedium?.copyWith(color: kDarkTextPrimary),
      displaySmall: baseText.displaySmall?.copyWith(color: kDarkTextPrimary),
      headlineMedium: baseText.headlineMedium?.copyWith(color: kDarkTextPrimary),
      headlineSmall: baseText.headlineSmall?.copyWith(color: kDarkTextPrimary),
      titleLarge: baseText.titleLarge?.copyWith(color: kDarkTextPrimary),
      titleMedium: baseText.titleMedium?.copyWith(color: kDarkTextPrimary),
      titleSmall: baseText.titleSmall?.copyWith(color: kDarkTextSecondary),
      bodyLarge: baseText.bodyLarge?.copyWith(color: kDarkTextPrimary),
      bodyMedium: baseText.bodyMedium?.copyWith(color: kDarkTextPrimary),
      bodySmall: baseText.bodySmall?.copyWith(color: kDarkTextSecondary),
      labelLarge: baseText.labelLarge?.copyWith(color: kDarkTextSecondary),
      labelMedium: baseText.labelMedium?.copyWith(color: kDarkTextSecondary),
      labelSmall: baseText.labelSmall?.copyWith(color: kDarkTextMuted),
    );

    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      primaryColor: kDarkPrimary,
      scaffoldBackgroundColor: kDarkBackground,
      cardColor: kDarkSurface,
      dividerColor: kDarkBorder,
      colorScheme: const ColorScheme.dark(
        primary: kDarkPrimary,
        secondary: kDarkSecondary,
        surface: kDarkSurface,
        background: kDarkBackground,
        error: kDarkError,
        onPrimary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      textTheme: darkTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: kDarkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: kDarkSurface,
        selectedItemColor: kDarkPrimary,
        unselectedItemColor: kDarkTextMuted,
        selectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kDarkSurface,
        hintStyle: const TextStyle(color: kDarkTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDarkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kDarkPrimary, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
        contentTextStyle: GoogleFonts.outfit(
          color: kDarkTextSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kDarkSurface,
        modalBackgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: kDarkSurface,
        headerForegroundColor: Colors.white,
        dayForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          if (states.contains(MaterialState.disabled)) return kDarkTextMuted;
          return kDarkTextPrimary;
        }),
        dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kDarkPrimary;
          return Colors.transparent;
        }),
        yearForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return kDarkTextSecondary;
        }),
        yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return kDarkPrimary.withOpacity(0.2);
          }
          return Colors.transparent;
        }),
        todayForegroundColor: const MaterialStatePropertyAll(kDarkPrimary),
        todayBorder: const BorderSide(color: kDarkPrimary, width: 1.2),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: kDarkTextSecondary, width: 1.4),
        checkColor: const MaterialStatePropertyAll(kDarkBackground),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return kDarkPrimary;
          return Colors.transparent;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: kDarkTextMuted,
        indicatorColor: kDarkPrimary,
        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kDarkSurface,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
      ),
    );
  }
}
