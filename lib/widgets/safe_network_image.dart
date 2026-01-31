import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:shimmer/shimmer.dart';

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
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _buildFallback();
    }

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final int? memCacheWidth = (width != null && width!.isFinite && width! > 0)
        ? (width! * dpr).round()
        : null;
    final int? memCacheHeight = (height != null && height!.isFinite && height! > 0)
        ? (height! * dpr).round()
        : null;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, _) => _buildLoading(),
        errorWidget: (context, url, error) => _buildFallback(),
      ),
    );
  }

  Widget _buildLoading() {
    final base = fallbackColor ?? kSurface;
    return Shimmer.fromColors(
      baseColor: base.withOpacity(0.9),
      highlightColor: Colors.white.withOpacity(0.9),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: borderRadius,
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
