import 'package:flutter/material.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool showBorder;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.color,
    this.showBorder = true,
    this.borderColor,
    this.borderRadius,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: borderColor ?? AppColors.border)
            : null,
        boxShadow: shadow ?? AppShadows.level1,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
