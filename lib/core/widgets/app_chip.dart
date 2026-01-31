import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class AppChip extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? textColor;
  final Color? borderColor;

  const AppChip({
    super.key,
    required this.label,
    this.background,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor ?? AppColors.text,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
