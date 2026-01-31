import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, AppColors.success);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, AppColors.danger);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, AppColors.primary);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
