import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImagePrefetch {
  static final Set<String> _seen = <String>{};

  static void prefetch(BuildContext ctx, String? url) {
    final cleanUrl = url?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) return;
    if (!_seen.add(cleanUrl)) return;
    precacheImage(CachedNetworkImageProvider(cleanUrl), ctx);
  }
}
