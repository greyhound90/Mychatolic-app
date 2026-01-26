
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/post_service.dart';

class CommentsPage extends StatefulWidget {
  final String processId; // This is the postId

  const CommentsPage({Key? key, required this.processId}) : super(key: key);

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final PostService _postService = PostService();
  final TextEditingController _commentController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Realtime Stream
  late Stream<List<Map<String, dynamic>>> _commentsStream;
  
  String? _replyToId;
  String? _replyToName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Initialize Realtime Stream directly for the list
    // Note: Stream naturally doesn't support JOINs easily.
    // So we use the same Hybrid Logic: Stream events -> Fetch Full Data.
    // Assuming _HybridCommentsList already implements this logic.
    // But to ensure the main page body uses it:
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

      await _postService.addComment(widget.processId, content, parentId: replyId);
      // Stream will auto-update UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onReply(String commentId, String userName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = userName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Komentar", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            // Use the Hybrid Widget that handles Stream + Join
            child: _HybridCommentsList(processId: widget.processId),
          ),
          
          // INPUT AREA
          Container(
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
          ),
        ],
      ),
    );
  }
}

// HYBRID STREAM LIST
// 1. Listens to Stream (Realtime Triggers)
// 2. Fetches Data with JOIN (Profiles)
class _HybridCommentsList extends StatefulWidget {
  final String processId;
  const _HybridCommentsList({required this.processId});

  @override
  State<_HybridCommentsList> createState() => _HybridCommentsListState();
}

class _HybridCommentsListState extends State<_HybridCommentsList> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  
  late RealtimeChannel _channel;

  @override
  void initState() {
    super.initState();
    _fetchComments();
    
    // Subscribe to REALTIME events properly
    _channel = _supabase.channel('public:comments:${widget.processId}');
    _channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq, 
          column: 'post_id', 
          value: widget.processId
        ),
        callback: (payload) {
          // Trigger reload when ANY change happens
          _fetchComments(scrollToBottom: payload.eventType == PostgresChangeEvent.insert);
        }
      )
      .subscribe();
  }
  
  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments({bool scrollToBottom = false}) async {
     try {
      final response = await _supabase
          .from('comments')
          .select('*, profiles:user_id(*)') 
          .eq('post_id', widget.processId)
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        
        if (scrollToBottom) {
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
      }
    } catch (e) {
      // ignore or log to analytic
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

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final profile = comment['profiles'] ?? {};
    final avatarUrl = profile['avatar_url'];
    final userName = profile['full_name'] ?? 'User';
    final content = comment['content'] ?? '';
    final createdAt = DateTime.tryParse(comment['created_at'] ?? '') ?? DateTime.now();
    final parentId = comment['parent_id'];
    final timeStr = timeago.format(createdAt, locale: 'id');

    final double indent = parentId != null ? 32.0 : 0.0;

    return Container(
      padding: EdgeInsets.only(left: 16 + indent, right: 16, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Text(userName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                     const SizedBox(width: 8),
                     Text(timeStr, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
                   ],
                 ),
                 const SizedBox(height: 2),
                 Text(content, style: GoogleFonts.outfit(fontSize: 13, height: 1.4, color: Colors.black87)),
                 const SizedBox(height: 4),
                 GestureDetector(
                   onTap: () {
                     final parentState = context.findAncestorStateOfType<_CommentsPageState>();
                     if (parentState != null) {
                       parentState._onReply(comment['id'], userName);
                     }
                   },
                   child: Text("Balas", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }
}
