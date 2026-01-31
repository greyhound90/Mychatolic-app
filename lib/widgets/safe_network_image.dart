import 'package:flutter/material.dart';
import 'package:mychatolic_app/core/theme.dart';

class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final Color? iconColor;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_not_supported,
    this.fallbackColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackColor ?? kSurface,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kPrimary.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    final double safeIconSize = (width != null && width!.isFinite && width! > 0) 
        ? width! * 0.4 
        : 24.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fallbackColor ?? Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: iconColor ?? Colors.grey,
          size: safeIconSize,
        ),
      ),
    );
  }
}
