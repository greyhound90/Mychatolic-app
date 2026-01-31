
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        // Close button (back) is automatically handled by AppBar leading
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Hero(
              tag: imageUrl,
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 180),
                  placeholder: (context, _) => _FullscreenShimmer(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                  errorWidget: (context, url, error) {
                    return const Center(
                      child: Icon(Icons.broken_image, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FullscreenShimmer extends StatelessWidget {
  final double width;
  final double height;

  const _FullscreenShimmer({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1C1C1C),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        width: width,
        height: height,
        color: Colors.black,
      ),
    );
  }
}
