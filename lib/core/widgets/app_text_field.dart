import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData? icon;
  final bool isObscure;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool isFocused;
  final Color? fillColor;
  final Color? borderColor;
  final Color? focusBorderColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? labelColor;
  final Color? iconColor;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final List<BoxShadow>? shadow;
  final List<BoxShadow>? focusShadow;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.isObscure = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.onChanged,
    this.isFocused = false,
    this.fillColor,
    this.borderColor,
    this.focusBorderColor,
    this.textColor,
    this.hintColor,
    this.labelColor,
    this.iconColor,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.suffixIcon,
    this.contentPadding,
    this.enabled = true,
    this.shadow,
    this.focusShadow,
  });

  @override
  Widget build(BuildContext context) {
    final activeBorder = focusBorderColor ?? AppColors.primary;
    final inactiveBorder = borderColor ?? AppColors.border;
    final baseFill = fillColor ?? AppColors.surfaceAlt;
    final baseText = textColor ?? AppColors.text;
    final baseHint = hintColor ?? AppColors.textMuted;
    final baseLabel = labelColor ?? AppColors.textMuted;
    final baseIcon = iconColor ?? AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: baseLabel,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: baseFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isFocused ? activeBorder : inactiveBorder,
                width: 1.2,
              ),
              boxShadow: isFocused
                  ? (focusShadow ?? AppShadows.level2)
                  : (shadow ?? AppShadows.level1),
            ),
            child: IgnorePointer(
              ignoring: readOnly && onTap != null,
              child: TextField(
                controller: controller,
                obscureText: isObscure,
                keyboardType: keyboardType,
                readOnly: readOnly,
                enabled: enabled,
                focusNode: focusNode,
                onChanged: onChanged,
                maxLines: maxLines,
                textCapitalization: textCapitalization,
                textInputAction: textInputAction,
                style: GoogleFonts.outfit(
                  color: baseText,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: contentPadding ?? const EdgeInsets.all(16),
                  hintText: hint,
                  hintStyle: GoogleFonts.outfit(color: baseHint),
                  prefixIcon: icon != null
                      ? Icon(
                          icon,
                          color: isFocused ? activeBorder : baseIcon,
                        )
                      : null,
                  suffixIcon: onToggleObscure != null
                      ? IconButton(
                          icon: Icon(
                            isObscure
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: baseIcon,
                          ),
                          onPressed: onToggleObscure,
                        )
                      : suffixIcon,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
