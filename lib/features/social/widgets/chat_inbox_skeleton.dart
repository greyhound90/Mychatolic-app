import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mychatolic_app/core/design_tokens.dart';

class ChatInboxSkeleton extends StatelessWidget {
  final int itemCount;

  const ChatInboxSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: itemCount,
      itemBuilder: (_, __) => const _SkeletonTile(),
    );
  }
}

class ChatStorySkeleton extends StatelessWidget {
  final int itemCount;

  const ChatStorySkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (_, __) => const _StoryBubble(),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: itemCount,
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceAlt,
        highlightColor: AppColors.surface,
        child: Container(
          height: 78,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
