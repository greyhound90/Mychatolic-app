import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? Colors.white;
    final child = isLoading
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          )
        : Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          );

    final style = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: fg,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: 0,
    );

    if (icon != null && !isLoading) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18, color: fg),
        label: child,
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? borderColor;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.borderColor,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? AppColors.primary;
    final text = Text(
      label,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        color: fg,
      ),
    );

    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      side: BorderSide(color: borderColor ?? AppColors.border),
      foregroundColor: fg,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );

    if (icon != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18, color: fg),
        label: text,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: text,
    );
  }
}
