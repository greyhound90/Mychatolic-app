import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/pages/profile_page.dart';
import 'package:mychatolic_app/pages/edit_post_page.dart';

class PostCard extends StatefulWidget {
  final UserPost post;
  final SocialService socialService;
  final VoidCallback? onLike;
  final VoidCallback? onTap;
  final Function(UserPost)? onPostUpdated;
  final String? heroTagPrefix;

  const PostCard({
    super.key,
    required this.post,
    required this.socialService,
    this.onLike,
    this.onTap,
    this.onPostUpdated,
    this.heroTagPrefix,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentImageIndex = 0;
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likesCount;
    }
  }

  void _handleMainTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      // Navigate to details
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: widget.post)),
      );

      if (result is UserPost && mounted) {
        widget.onPostUpdated?.call(result);
      }
    }
  }

  void _handleLike() async {
    // Optimistic Update
    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount--;
      } else {
        _isLiked = true;
        _likesCount++;
      }
    });

    if (widget.onLike != null) {
      widget.onLike!();
    }

    try {
      await widget.socialService.toggleLike(widget.post.id);
    } catch (_) {
      // Revert if failed
      if (mounted) {
        setState(() {
          if (_isLiked) {
            _isLiked = false;
            _likesCount--;
          } else {
            _isLiked = true;
            _likesCount++;
          }
        });
      }
    }
  }

  void _handleShare() {
    final String content =
        "${widget.post.caption}\n\n${widget.post.singleImageUrl}".trim();
    SharePlus.instance.share(
      ShareParams(
        text: content.isNotEmpty
            ? content
            : "Cek postingan menarik ini di MyCatholic!",
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    final currentUser = widget.socialService.currentUser;
    final bool isMyPost =
        currentUser != null && widget.post.userId == currentUser.id;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (isMyPost) ...[
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Edit Post'),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditPostPage(post: widget.post),
                      ),
                    );
                    if (result is UserPost && context.mounted) {
                      widget.onPostUpdated?.call(result);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text('Report Post'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportReasonDialog(context);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Postingan?"),
        content: const Text("Apakah Anda yakin ingin menghapus postingan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost();
            },
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      await widget.socialService.deletePost(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Postingan berhasil dihapus")),
        );
      }
      // Trigger refresh here?
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
      }
    }
  }

  void _showReportReasonDialog(BuildContext context) {
    final reasons = [
      "Inappropriate Content",
      "Spam",
      "Hate Speech",
      "Harassment",
      "False Information",
      "Other",
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Reason"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (r) => ListTile(
                    title: Text(r),
                    onTap: () {
                      Navigator.pop(context);
                      _submitReport(r);
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    try {
      await widget.socialService.reportPost(widget.post.id, reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Laporan terkirim.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal lapor: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        userId: post.userId,
                        isBackButtonEnabled: true,
                      ),
                    ),
                  ),
                  child: ClipOval(
                    child: SafeNetworkImage(
                      imageUrl: post.userAvatar,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfilePage(
                              userId: post.userId,
                              isBackButtonEnabled: true,
                            ),
                          ),
                        ),
                        child: Text(
                          post.userName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (post.userFullName.isNotEmpty &&
                          post.userFullName != post.userName)
                        Text(
                          post.userFullName,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showPostOptions(context),
                ),
              ],
            ),
          ),

          // 2. IMAGE (PageView if multiple)
          if (post.imageUrls.isNotEmpty)
            Container(
              height: 400, // Instagram-like aspect ratio container
              width: double.infinity,
              color: Colors.grey[100],
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: post.imageUrls.length,
                    onPageChanged: (index) =>
                        setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return SafeNetworkImage(
                        imageUrl: post.imageUrls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  ),
                  // Optional: Simple Dots indicator
                  if (post.imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${_currentImageIndex + 1}/${post.imageUrls.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // 3. ACTION BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleLike, // Call parent optimistic or local
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.black87,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$_likesCount Suka",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _handleMainTap,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 28,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: _handleShare,
                  child: const Icon(
                    Icons.send_outlined,
                    size: 28,
                    color: Colors.black87,
                  ), // Instagram share icon style
                ),
                const Spacer(),
                if (post.imageUrls.length > 1) ...[
                  // Dot indicator could also go here
                  Row(
                    children: List.generate(post.imageUrls.length, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index
                              ? Colors.blue
                              : Colors.grey[300],
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),

          // 5. CAPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: GoogleFonts.outfit(color: Colors.black, fontSize: 14),
                children: [
                  TextSpan(
                    text: "${post.userName} ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ),

          // 6. COMMENTS HINT & TIME
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.commentsCount > 0)
                  GestureDetector(
                    onTap: _handleMainTap,
                    child: Text(
                      "Lihat semua ${post.commentsCount} komentar",
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  post.timeAgo, // Uses timeago getter from model
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
