import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/comment.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/profile.dart'; // IMPORT PROFILE MODEL
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final UserPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SocialService _socialService = SocialService();
  final TextEditingController _commentController = TextEditingController();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  late UserPost _post;
  
  // Reply State
  String? _replyToId;
  String? _replyToName;
  final FocusNode _focusNode = FocusNode();
  
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _setupRealtimeSubscription();
    _fetchComments();
    _refreshPostData(); // Ensure fresh data (likes/status) from server
  }

  Future<void> _refreshPostData() async {
    final freshPost = await _socialService.fetchPostById(widget.post.id);
    if (freshPost != null && mounted) {
      setState(() {
        _post = freshPost;
      });
      // Broadcast this fresh data to Home/Profile as well!
      SocialService.broadcastPostUpdate(freshPost);
    }
  }

  void _setupRealtimeSubscription() {
    final channelName = 'public:post_update_v2:${widget.post.id}';
    _subscription = Supabase.instance.client.channel(channelName);

    // 1. Listen to COMMENTS (Insert/Update/Delete)
    _subscription!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'post_comments',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: widget.post.id.toString(),
      ),
      callback: (payload) {
         debugPrint("🔔 Realtime COMMENT Update: $payload");
         
         if (payload.eventType == PostgresChangeEvent.insert) {
            _handleOptimisticCommentInsert(payload);
         }
         // Always fetch latest to be sure
         _fetchComments();
      }
    );

    // 2. Listen to POST LIKES (Insert/Delete) for Realtime Like Count
    _subscription!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'post_likes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'post_id',
        value: widget.post.id.toString(),
      ),
      callback: (payload) {
        debugPrint("❤️ Realtime LIKE Update: $payload");
        final myId = _socialService.currentUser?.id;

        if (payload.eventType == PostgresChangeEvent.insert) {
           final newRecord = payload.newRecord;
           final userId = newRecord['user_id'];
           
           // Only update if it's NOT ME (I already did optimistic update)
           if (userId != myId) {
             _updateLikeCount(1);
           }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
           final oldRecord = payload.oldRecord;
           final userId = oldRecord['user_id'];
           
           if (userId != myId) {
             _updateLikeCount(-1);
           }
        }
      }
    );

    _subscription!.subscribe((status, error) {
       if (status == RealtimeSubscribeStatus.subscribed) {
         debugPrint("✅ REALTIME CONNECTED: $channelName");
       } else if (status == RealtimeSubscribeStatus.closed) {
         debugPrint("❌ REALTIME CLOSED");
       } else {
         debugPrint("ℹ️ REALTIME STATUS: $status ${error ?? ''}");
       }
    });
  }

  void _updateLikeCount(int delta) {
    if (!mounted) return;
    setState(() {
      _post = _post.copyWith(likesCount: _post.likesCount + delta);
    });
    // Broadcast so Home knows too
    SocialService.broadcastPostUpdate(_post);
  }

  void _handleOptimisticCommentInsert(PostgresChangePayload payload) {
      try {
        final json = payload.newRecord;
        final currentUser = _socialService.currentUser;
        final isMyComment = currentUser != null && json['user_id'] == currentUser.id;
        
        // Only if NOT my comment (since I added mine optimistically or want to see others instantly)
        // Wait, current logic adds placeholder but list fetch overwrites.
        // Let's just create a dummy for visual feedback
        
        if (isMyComment) return; // Assume local add handled it? No, explicit add is better.

        final dummyProfile = Profile(id: json['user_id'].toString(), fullName: "User Baru", userRole: UserRole.umat);
        final newItem = Comment(
          id: json['id'].toString(),
          userId: json['user_id'].toString(),
          content: json['content'] ?? '',
          createdAt: DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now(),
          author: dummyProfile,
          parentId: json['parent_id']?.toString(),
          likesCount: 0,
          isLikedByMe: false,
        );

        if (mounted) {
           setState(() {
             _comments.add(newItem);
             _post = _post.copyWith(commentsCount: _post.commentsCount + 1);
           });
           SocialService.broadcastPostUpdate(_post);
        }
      } catch (e) {
        debugPrint("Optimistic insert error: $e");
      }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final comments = await _socialService.fetchComments(widget.post.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    
    _commentController.clear();
    _focusNode.unfocus();

    setState(() => _isSending = true);
    final originalText = content;
    final replyToId = _replyToId;
    
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });

    try {
      await _socialService.addComment(
        widget.post.id, 
        content, 
        parentId: replyToId
      );
      // Wait for Realtime or Fetch
    } catch (e) {
      if (mounted) {
        _commentController.text = originalText;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _handleReply(Comment comment) {
    setState(() {
      _replyToId = comment.id;
      _replyToName = comment.author?.fullName ?? "User";
    });
    _focusNode.requestFocus();
  }

  Future<void> _handleLikeComment(Comment comment) async {
    try {
      await _socialService.toggleCommentLike(comment.id);
      _fetchComments(); // Refresh to update count/icon
    } catch (e) {
      // ignore
    }
  }

  Future<void> _handleReportComment(Comment comment) async {
    final reasons = ["Spam", "Komentar Kasar", "Pelecehan", "Lainnya"];
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Laporkan Komentar"),
        children: reasons.map((r) => SimpleDialogOption(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await _socialService.reportComment(comment.id, r);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan terkirim")));
              }
            } catch (e) {
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(r),
          ),
        )).toList(),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Menangani pop manual
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        Navigator.pop(context, _post);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kTextTitle),
            onPressed: () => Navigator.pop(context, _post),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Post Content
                    PostCard(
                      post: _post, 
                      socialService: _socialService,
                      onTap: () {}, // Disable navigation to self
                      onPostUpdated: (updated) {
                         // Update local _post state immediately when child PostCard changes (e.g. Like)
                        setState(() {
                          _post = updated;
                        });
                        // Broadcast change upwards
                        SocialService.broadcastPostUpdate(updated);
                      },
                      heroTagPrefix: 'detail',
                    ),
                    
                    const Divider(thickness: 1, color: Color(0xFFF3F4F6), height: 1),
                    
                    // 2. Comments List (Using Tree Renderer)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        return _buildCommentTree(_comments[index]);
                      },
                    ),
                    
                    if (_isLoading)
                       const Padding(padding: EdgeInsets.all(20.0), child: Center(child: CircularProgressIndicator())),
                    
                    if (!_isLoading && _comments.isEmpty)
                       Padding(
                         padding: const EdgeInsets.all(40.0), 
                         child: Center(child: Text("Belum ada komentar.", style: GoogleFonts.outfit(color: kTextMeta)))
                       ),
  
                    const SizedBox(height: 80), // Space for bottom input
                  ],
                ),
              ),
            ),
            
            // 3. Sticky Bottom Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_replyToName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Membalas $_replyToName", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() { _replyToId = null; _replyToName = null; }),
                              child: const Icon(Icons.close, size: 14, color: Colors.grey),
                            )
                          ],
                        ),
                      ),
                    Row(
                      children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: "Tulis komentar anda...", 
                          hintStyle: GoogleFonts.outfit(color: kTextMeta),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        focusNode: _focusNode,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _isSending ? null : _sendComment,
                      icon: _isSending 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.send_rounded, color: kPrimary),
                    )
                  ],
                ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTree(Comment comment) {
    // Determine if this is a reply (depth > 0) based on parentId check or context
    final bool isReply = comment.parentId != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Parent Comment
        _buildCommentItem(comment, isReply: isReply),
        
        // Replies (Indented recursively)
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40.0), // Indentation using standard 40.0
            child: Column(
              children: comment.replies.map((reply) => _buildCommentTree(reply)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
    final author = comment.author;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: isReply ? 28 : 36, height: isReply ? 28 : 36,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: SafeNetworkImage(
              imageUrl: author?.avatarUrl,
              width: isReply ? 28 : 36, 
              height: isReply ? 28 : 36,
              borderRadius: BorderRadius.circular(isReply ? 14 : 18),
              fit: BoxFit.cover,
              fallbackIcon: Icons.person,
              iconColor: Colors.grey,
              fallbackColor: kBorder,
            ),
          ),
          const SizedBox(width: 10),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Container(
                   decoration: BoxDecoration(
                     color: const Color(0xFFF3F4F6),
                     borderRadius: BorderRadius.circular(12),
                   ),
                   padding: const EdgeInsets.all(10),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(
                          author?.fullName ?? "User",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: kTextTitle),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment.content,
                          style: GoogleFonts.outfit(color: kTextBody, fontSize: 14),
                        ),
                     ],
                   ),
                 ),
                 
                 const SizedBox(height: 4),
                 
                 // Actions Row
                 Row(
                   children: [
                     Text(
                       timeago.format(comment.createdAt, locale: 'en_short'),
                       style: GoogleFonts.outfit(color: kTextMeta, fontSize: 11),
                     ),
                     const SizedBox(width: 16),
                     
                     // Reply Button
                     GestureDetector(
                       onTap: () => _handleReply(comment),
                       child: Text("Balas", style: GoogleFonts.outfit(color: kTextMeta, fontWeight: FontWeight.bold, fontSize: 11)),
                     ),
                     
                     const Spacer(),
                     
                     // Like Button
                     GestureDetector(
                       onTap: () => _handleLikeComment(comment),
                       child: Row(
                         children: [
                           Icon(
                             Icons.local_fire_department_rounded,
                             size: 16, 
                             color: comment.isLikedByMe ? Colors.deepOrange : Colors.grey,
                           ),
                           if (comment.likesCount > 0) ...[
                             const SizedBox(width: 4),
                             Text("${comment.likesCount}", style: GoogleFonts.outfit(fontSize: 11, color: kTextMeta)),
                           ]
                         ],
                       ),
                     ),

                     const SizedBox(width: 16),

                     // More / Report
                     GestureDetector(
                       onTap: () => _handleReportComment(comment),
                       child: const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                     ),
                   ],
                 )
              ],
            ),
          )
        ],
      ),
    );
  }
}
