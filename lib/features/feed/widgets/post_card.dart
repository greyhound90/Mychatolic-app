
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/post_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/core/ui/image_prefetch.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/features/feed/pages/comments_page.dart';
import 'package:mychatolic_app/features/feed/pages/full_screen_image_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostCard extends StatefulWidget {
  final UserPost post;
  final VoidCallback? onPlay; 
  final Function(UserPost updatedPost)? onUpdate;

  const PostCard({
    Key? key, 
    required this.post,
    this.onPlay,
    this.onUpdate,
    dynamic socialService, // ignored, for compatibility
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  late bool _isLiked;
  late Stream<Map<String, dynamic>> _postStream;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    // We stream the post to get the latest likes_count & comments_count in Realtime
    _postStream = _postService.streamPost(widget.post.id);
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      if (oldWidget.post.id != widget.post.id) {
         _postStream = _postService.streamPost(widget.post.id);
      }
      _isLiked = widget.post.isLiked;
    }
  }

  Future<void> _toggleLike() async {
    final bool oldLiked = _isLiked;
    final bool newLiked = !oldLiked;

    // Instant Optimistic Update (UI)
    setState(() {
      _isLiked = newLiked;
    });

    AnalyticsService.instance.track(
      AnalyticsEvents.postLikeToggle,
      props: {'action': newLiked ? 'like' : 'unlike'},
    );

    // Notify Parent (Feed) immediately so it updates too
    widget.onUpdate?.call(widget.post.copyWith(
      isLiked: newLiked,
      likesCount: widget.post.likesCount + (newLiked ? 1 : -1) // Temporary adjust
    ));

    try {
      await _postService.toggleLike(widget.post.id);
      // Success. Stream will eventually correct the count from Server if needed.
    } catch (e) {
      // Revert if failed
      setState(() {
        _isLiked = oldLiked;
      });
      widget.onUpdate?.call(widget.post.copyWith(isLiked: oldLiked, likesCount: widget.post.likesCount));
    }
  }

  Future<void> _toggleSave() async {
    // Optimistic
    final oldSaved = widget.post.isSaved;
    final newSaved = !oldSaved;

    // Optimistic Update UI via Parent Callback (since isSaved is in widget.post)
    widget.onUpdate?.call(widget.post.copyWith(isSaved: newSaved));

    try {
       await _postService.toggleSavePost(widget.post.id);
       ScaffoldMessenger.of(context).hideCurrentSnackBar();
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newSaved ? "Disimpan ke koleksi" : "Dihapus dari koleksi"),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Revert if failed
       widget.onUpdate?.call(widget.post.copyWith(isSaved: oldSaved));
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menyimpan: $e")));
    }
  }
  
  void _sharePost() {
    Share.share(
      "Lihat postingan dari ${widget.post.userName} di MyCatholic App!\n\n${widget.post.caption}", 
    );
  }

  void _showOptions(BuildContext context) {
    final isOwner = widget.post.userId == _currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (isOwner) ...[
                 ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text("Edit Postingan"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditDialog();
                    },
                 ),
                 ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text("Hapus Postingan"),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog(
                         context: context, 
                         builder: (_) => AlertDialog(
                           title: const Text("Hapus Postingan?"),
                           content: const Text("Tindakan ini tidak dapat dibatalkan."),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
                             TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
                           ],
                         )
                      );
                      if (confirm == true) {
                         try {
                           await _postService.deletePost(widget.post.id);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Postingan dihapus")));
                         } catch (e) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
                         }
                      }
                    },
                 ),
               ] else ...[
                 ListTile(
                    leading: const Icon(Icons.flag, color: Colors.orange),
                    title: const Text("Laporkan Postingan"),
                    onTap: () async {
                       Navigator.pop(ctx);
                       try {
                          await _postService.reportPost(widget.post.id, "Inappropriate Content");
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan terkirim. Terima kasih.")));
                       } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
                       }
                    },
                 ),
                 ListTile(
                    leading: const Icon(Icons.block, color: Colors.grey),
                    title: const Text("Blokir User Ini"),
                    onTap: () {
                       Navigator.pop(ctx);
                    },
                 ),
               ],
               const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.post.caption);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Caption"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
               Navigator.pop(context);
               try {
                  await _postService.editPost(widget.post.id, controller.text);
                  widget.onUpdate?.call(widget.post.copyWith(caption: controller.text));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil diedit")));
               } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
               }
            }, 
            child: const Text("Simpan")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.post.imageUrls.isNotEmpty;
    final String? imageUrl = hasImage ? widget.post.imageUrls.first : null;

    ImagePrefetch.prefetch(context, widget.post.userAvatar);
    ImagePrefetch.prefetch(context, imageUrl);

    return RepaintBoundary(
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 1. HEADER (Avatar, Name, Time)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.post.userId, isBackButtonEnabled: true))),
              child: ClipOval(
                child: SafeNetworkImage(
                  imageUrl: widget.post.userAvatar,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.person,
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: widget.post.userId, isBackButtonEnabled: true))),
              child: Text(
                widget.post.userName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
              ),
            ),
            subtitle: Text(
              widget.post.timeAgo,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              onPressed: () => _showOptions(context),
            ),
          ),

          // 2. TEXT CAPTION (Placed ABOVE Image)
          if (widget.post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                widget.post.caption,
                textAlign: TextAlign.left,
                style: GoogleFonts.outfit(
                  fontSize: 15, 
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          
          const SizedBox(height: 8),

          // 3. IMAGE (4:5 Ratio, Hero, Zoomable)
          if (imageUrl != null) 
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => FullScreenImagePage(imageUrl: imageUrl))
                );
              },
              child: Hero(
                tag: imageUrl,
                child: AspectRatio(
                  aspectRatio: 4 / 5, // Instagram Portrait Standard
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: SafeNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover, // Fills the 4:5 box
                    ),
                  ),
                ),
              ),
            ),

          // 4. ACTIONS (Wrapped in StreamBuilder for Realtime Counter)
          StreamBuilder<Map<String, dynamic>>(
            stream: _postStream,
            builder: (context, snapshot) {
              int likesCount = widget.post.likesCount;
              int commentsCount = widget.post.commentsCount;

              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                 final realtimePost = snapshot.data!;
                 
                 if (realtimePost.containsKey('likes_count')) {
                    likesCount = realtimePost['likes_count'] as int;
                 }
                 if (realtimePost.containsKey('comments_count')) {
                    commentsCount = realtimePost['comments_count'] as int;
                 }
              } else {
                 // Optimistic Fallback
                 if (_isLiked != widget.post.isLiked) {
                    likesCount += (_isLiked ? 1 : -1);
                 }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.local_fire_department, 
                      iconColor: _isLiked ? Colors.deepOrange : Colors.grey[600]!, 
                      label: "$likesCount",
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      iconColor: Colors.grey[600]!,
                      label: "$commentsCount", 
                      onTap: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(builder: (_) => CommentsPage(processId: widget.post.id)), 
                         );
                      },
                    ),
                    const Spacer(),
                    _buildActionButton(
                      icon: widget.post.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      iconColor: widget.post.isSaved ? const Color(0xFF0088CC) : Colors.grey[600]!,
                      onTap: _toggleSave,
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      iconColor: Colors.grey[600]!,
                      onTap: _sharePost,
                    ),
                  ],
                ),
              );
            }
          ),
          
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, String? label, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container( 
        color: Colors.transparent, 
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            if (label != null) ...[
              const SizedBox(width: 6),
               Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87))
            ]
          ],
        ),
      ),
    );
  }
}
