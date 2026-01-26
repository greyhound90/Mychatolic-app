import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/post_service.dart';
import 'package:mychatolic_app/models/comment.dart';

class CommentsPage extends StatefulWidget {
  final String processId; // postId

  const CommentsPage({Key? key, required this.processId}) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  
  // Key to access the list state for optimistic updates
  final GlobalKey<_HybridCommentsListState> _listKey = GlobalKey();

  String? _replyToId;
  String? _replyToName;
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onReply(String commentId, String userName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = userName;
    });
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    
    setState(() => _isSending = true);

    try {
      final replyId = _replyToId;
      _commentController.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });

      // Call RPC
      final newComment = await _postService.addComment(widget.processId, content, parentId: replyId);
      
      // Update UI via Key
      _listKey.currentState?.addLocalComment(newComment);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Komentar", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      // STRUKTUR UTAMA YANG BENAR: Column [ Expanded(ListView), InputArea ]
      body: Column(
        children: [
          Expanded(
            child: _HybridCommentsList(
              key: _listKey,
              processId: widget.processId
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
         color: Colors.white,
         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: SafeArea( 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             if (_replyToName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                  child: Row(
                    children: [
                       Text("Membalas $_replyToName", style: GoogleFonts.outfit(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                       const Spacer(),
                       GestureDetector(
                         onTap: () => setState(() { _replyToId = null; _replyToName = null; }),
                         child: const Icon(Icons.close, size: 16, color: Colors.grey),
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
                         hintText: _replyToName != null ? "Tulis balasan..." : "Tulis komentar...",
                         hintStyle: GoogleFonts.outfit(fontSize: 14),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                         filled: true,
                         fillColor: Colors.grey[100],
                     ),
                     minLines: 1,
                     maxLines: 4,
                   ),
                 ),
                 const SizedBox(width: 8),
                 IconButton(
                   onPressed: _isSending ? null : _sendComment,
                   icon: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.send, color: Colors.blue),
                 ),
               ],
             ),
          ],
        ),
      ),
    );
  }
}

class _HybridCommentsList extends StatefulWidget {
  final String processId;
  const _HybridCommentsList({Key? key, required this.processId}) : super(key: key);

  @override
  State<_HybridCommentsList> createState() => _HybridCommentsListState();
}

class _HybridCommentsListState extends State<_HybridCommentsList> {
  final PostService _postService = PostService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  late RealtimeChannel _channel;
  
  // Safe User ID Access
  String get _myUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetchInitialComments();
    _subscribeRealtime();
  }
  
  void _subscribeRealtime() {
    _channel = _supabase.channel('public:comments:${widget.processId}');
    _channel
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, 
          column: 'post_id', 
          value: widget.processId
        ),
        callback: (payload) => _handleNewCommentEvent(payload),
      )
      .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    _scrollController.dispose();
    super.dispose();
  }

  void addLocalComment(Comment c) {
    if (mounted) {
       setState(() {
         _comments.add(c);
       });
       _scrollToBottom();
    }
  }

  Future<void> _fetchInitialComments() async {
     try {
       final data = await _postService.getComments(widget.processId);
       if (mounted) {
         setState(() {
           _comments = data;
           _isLoading = false;
         });
       }
     } catch (e) {
       if (mounted) setState(() => _isLoading = false);
     }
  }

  Future<void> _handleNewCommentEvent(PostgresChangePayload payload) async {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final newId = newRecord['id'];
    
    // Prevent duplicates
    if (_comments.any((c) => c.id == newId.toString())) return;
    
    // Fetch full data from View
    try {
      final response = await _supabase
          .from('comments_with_profiles')
          .select()
          .eq('id', newId)
          .maybeSingle();

      if (response != null && mounted) {
        final newComment = Comment.fromJson(response);
        setState(() {
          _comments.add(newComment);
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut
          );
      }
    });
  }
  
  void _showCommentOptions(Comment comment) {
    final isOwner = comment.userId == _myUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) 
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text("Hapus Komentar", style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(comment.id);
                  },
                )
              else 
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                  title: Text("Laporkan Komentar", style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportDialog(comment.id);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Hapus Komentar?", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: const Text("Tindakan ini tidak dapat dibatalkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          TextButton(
             onPressed: () => Navigator.pop(ctx, true), 
             child: const Text("Hapus", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) {
         setState(() {
           _comments.removeWhere((c) => c.id == commentId);
         });
      }
      try {
        await _postService.deleteComment(commentId, widget.processId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
      }
    }
  }

  Future<void> _showReportDialog(String commentId) async {
     // Simple list of reasons
     final reasons = ["Spam", "Ujaran Kebencian", "Penipuan", "Informasi Palsu", "Lainnya"];
     
     final selected = await showDialog<String>(
       context: context,
       builder: (ctx) => SimpleDialog(
         title: Text("Pilih Alasan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
         children: reasons.map((r) => SimpleDialogOption(
           onPressed: () => Navigator.pop(ctx, r),
           child: Text(r, style: GoogleFonts.outfit()),
         )).toList(),
       )
     );

     if (selected != null) {
       try {
         await _postService.reportComment(commentId, selected);
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan terkirim. Terima kasih.")));
       } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_comments.isEmpty) return Center(child: Text("Belum ada komentar", style: GoogleFonts.outfit(color: Colors.grey)));

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
          final comment = _comments[index];
          return _buildCommentItem(comment);
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    // NULL SAFETY FIXES
    // Gunakan ?. dan ?? untuk menghindari error null check
    final author = comment.author;
    final avatarUrl = author?.avatarUrl;
    final userName = author?.fullName ?? 'Tanpa Nama';
    final content = comment.content;
    final timeStr = timeago.format(comment.createdAt, locale: 'id');
    final isOwner = comment.userId == _myUserId;
    
    // Identasi untuk reply (jika ada parentId)
    final double indent = comment.parentId != null ? 32.0 : 0.0;

    return Container(
      padding: EdgeInsets.only(left: 16 + indent, right: 16, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // Avatar
           ClipOval(
             child: SafeNetworkImage(
               imageUrl: avatarUrl,
               width: 32,
               height: 32,
               fallbackIcon: Icons.person,
               fit: BoxFit.cover,
             ),
           ),
           const SizedBox(width: 12),
           
           // Content Column (Wrapped in Expanded)
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Header (Name & Time)
                 Row(
                   children: [
                     Expanded(
                       child: Text(
                         userName, 
                         style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Text(timeStr, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
                   ],
                 ),
                 const SizedBox(height: 2),
                 
                 // Comment Text
                 Text(content, style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: Colors.black87)),
                 const SizedBox(height: 6),
                 
                 // Action Row: Reply & Delete
                 Row(
                   children: [
                     GestureDetector(
                       onTap: () {
                         final parentState = context.findAncestorStateOfType<_CommentsPageState>();
                         if (parentState != null) {
                           parentState._onReply(comment.id, userName);
                         }
                       },
                       child: Text("Balas", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                     ),
                     
                     // Spacer pushes Delete to the right side
                     const Spacer(),
                     
                     // Option Menu (Delete/Report)
                     GestureDetector(
                        onTap: () => _showCommentOptions(comment),
                        child: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                     ),
                   ],
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }
}
