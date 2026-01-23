import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. DEFINISI PALET WARNA (Lengkap) ---
const Color kPrimary = Color(0xFF0088CC); // Biru Branding
const Color kSecondary = Color(0xFF005580);
const Color kBackground = Color(0xFFF0F2F5); // Abu-abu sangat muda
const Color kSurface = Colors.white;         // Putih
const Color kBorder = Color(0xFFEEEEEE);     // Abu-abu batas
const Color kTextTitle = Color(0xFF1A1A1A);
const Color kTextBody = Color(0xFF4A4A4A);
const Color kTextMeta = Color(0xFF858585);
const Color kError = Color(0xFFE53935);

// --- 2. TEMA APLIKASI ---
class MyCatholicTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false, 
      primaryColor: kPrimary,
      scaffoldBackgroundColor: kBackground,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        secondary: kSecondary,
        surface: kSurface,
        error: kError,
        onPrimary: Colors.white,
      ),

      // Typography
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: kTextBody,
        displayColor: kTextTitle,
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
        backgroundColor: Colors.white,
        selectedItemColor: kPrimary,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 12),
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
    );
  }

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: kPrimary,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(primary: kPrimary),
    );
  }
}
