
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

// Import SocialService though we might not use it directly, to keep compatibility if needed, 
// OR we just remove it from the constructor if home_screen is updated. 
// Plan: Update constructor to accept socialService but ignore it or use internal logic.
// However, the cleanest is to update the caller. 
// But since I am overwriting the LEGACY file, I should try to minimize breakage or update the caller.
// Let's update the caller (home_screen.dart) in the next step.
// For now, this file is the NEW PostCard implementation.

class PostCard extends StatefulWidget {
  final UserPost post;
  final VoidCallback? onPlay; 
  final Function(UserPost updatedPost)? onUpdate;
  // Legacy params (optional, to avoid immediate crash if hot reload happens before home_screen update)
  final dynamic socialService; 

  const PostCard({
    Key? key, 
    required this.post,
    this.onPlay,
    this.onUpdate,
    this.socialService,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostService _postService = PostService();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id;
  
  late bool _isLiked;
  late int _likesCount;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isSaved = widget.post.isSaved;
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      setState(() {
        _isLiked = widget.post.isLiked;
        _likesCount = widget.post.likesCount;
        _isSaved = widget.post.isSaved;
      });
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    AnalyticsService.instance.track(
      AnalyticsEvents.postLikeToggle,
      props: {'action': _isLiked ? 'like' : 'unlike'},
    );

    try {
      await _postService.toggleLike(widget.post.id);
      widget.onUpdate?.call(widget.post.copyWith(isLiked: _isLiked, likesCount: _likesCount));
    } catch (e) {
      // Revert
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave() async {
    setState(() {
      _isSaved = !_isSaved;
    });

    try {
      await _postService.toggleSavePost(widget.post.id);
      widget.onUpdate?.call(widget.post.copyWith(isSaved: _isSaved));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? "Disimpan ke koleksi" : "Dihapus dari koleksi"),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _isSaved = !_isSaved;
      });
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
                            // Using PostService directly
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
    // If post has multiple images, user logic usually handles it. 
    // This implementation defaults to using the FIRST imageUrl if available, 
    // or checks imageUrls list. The model 'UserPost' has 'imageUrls'.
    
    final bool hasImage = widget.post.imageUrls.isNotEmpty;
    // Fallback: Check if there's a single image property, adapt as needed. 
    // Assuming 'imageUrls' is the source of truth.
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

          // 4. ACTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.local_fire_department, 
                  color: _likesCount > 0 || _isLiked ? Colors.deepOrange : Colors.grey[600]!, 
                  label: "$_likesCount",
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 24),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.grey[600]!,
                  label: "", 
                  onTap: () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => CommentsPage(processId: widget.post.id)), 
                     );
                  },
                ),
                const Spacer(),
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? const Color(0xFF0088CC) : Colors.grey[600]!,
                  onTap: _toggleSave,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.grey[600]!,
                  onTap: _sharePost,
                ),
              ],
            ),
          ),
          
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, String? label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container( 
        color: Colors.transparent, 
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            if (label != null && label.isNotEmpty) ...[
              const SizedBox(width: 6),
               Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14, color: color))
            ]
          ],
        ),
      ),
    );
  }
}
