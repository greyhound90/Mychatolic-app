import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago; // Time Ago import
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class PostDetailPage extends StatefulWidget {
  final Map<String, dynamic> postData;

  const PostDetailPage({super.key, required this.postData});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _supabase = Supabase.instance.client;

  // Logic Variables
  late int _likes;
  late int _commentCount;
  bool _isLiked = false;
  bool _isLoadingComments = true;

  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.postData['likes'] ?? 0;
    _commentCount = widget.postData['comments'] ?? 0;
    _checkLikeStatus();
    _fetchComments();
  }

  // --- 1. LIKE FEATURE ---
  Future<void> _checkLikeStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('post_likes')
          .select()
          .eq('user_id', user.id)
          .eq('post_id', widget.postData['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isLiked = data != null;
        });
      }
    } catch (e) {
      debugPrint("Error checking like: $e");
    }
  }

  Future<void> _toggleLike() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final postId = widget.postData['id'];

    // 1. Capture Old State
    final bool wasLiked = _isLiked;

    // 2. Optimistic Update (Prevent Negative)
    setState(() {
      if (wasLiked) {
        // UNLIKE
        _isLiked = false;
        _likes = (_likes > 0) ? _likes - 1 : 0; // Safety guard
      } else {
        // LIKE
        _isLiked = true;
        _likes = _likes + 1;
      }
    });

    try {
      if (wasLiked) {
        // WAS LIKED -> UNLIKE ACTION
        await _supabase
            .from('post_likes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', postId);
        await _supabase.rpc('decrement_likes', params: {'row_id': postId});
      } else {
        // WAS NOT LIKED -> LIKE ACTION
        await _supabase.from('post_likes').insert({
          'user_id': user.id,
          'post_id': postId,
        });
        await _supabase.rpc('increment_likes', params: {'row_id': postId});
      }
    } catch (e) {
      debugPrint("Like/Unlike failed: $e");
      // Revert UI if failed
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likes = wasLiked ? _likes + 1 : (_likes > 0 ? _likes - 1 : 0);
        });
      }
    }
  }

  // --- 2. COMMENT FEATURE ---
  Future<void> _fetchComments() async {
    try {
      // Assuming 'profiles' table join if `user_name` needs to be fetched,
      // OR assuming `user_name` is stored in comments table directly.
      // Based on request: "Insert to comments (..., user_name)", so we fetch directly.
      final res = await _supabase
          .from('comments')
          .select('*')
          .eq('post_id', widget.postData['id'])
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _comments = List<Map<String, dynamic>>.from(res);
          _commentCount = _comments.length; // Sync count
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isPostingComment = true);

    try {
      final userName = user.userMetadata?['nama_lengkap'] ?? "User";

      // 1. Insert Comment
      await _supabase.from('comments').insert({
        'post_id': widget.postData['id'],
        'user_id': user.id,
        'content': text,
        'user_name': userName,
      });

      // 2. Increment Counter
      await _supabase.rpc(
        'increment_comments',
        params: {'row_id': widget.postData['id']},
      );
      // Fallback: await _supabase.from('posts').update({'comments': _commentCount + 1}).eq('id', widget.postData['id']);

      if (!mounted) return;
      _commentController.clear();
      FocusScope.of(context).unfocus();
      _fetchComments(); // Refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal komentar: $e")));
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  // --- 3. DELETE LOGIC ---
  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Hapus Postingan?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text("Postingan yang dihapus tidak bisa dikembalikan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context); // Close Dialog
              try {
                await _supabase
                    .from('posts')
                    .delete()
                    .eq('id', widget.postData['id']);
                if (!mounted) return;
                navigator.pop(); // Close Page
                // No snackbar here as page closes, previous page handles refresh
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text("Gagal hapus: $e")),
                );
              }
            },
            child: const Text(
              "HAPUS",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = widget.postData['image_url'];
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final String creator = widget.postData['creator_name'] ?? 'User';
    final String content = widget.postData['content'] ?? '';

    final currentUserId = _supabase.auth.currentUser?.id;
    final ownerId = widget.postData['user_id'];
    final isOwner =
        currentUserId != null && ownerId != null && currentUserId == ownerId;

    return Scaffold(
      backgroundColor: const Color(0xFFCCFF00), // Lime Green
      appBar: AppBar(
        title: const Text(
          "Postingan",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOwner)
            IconButton(
              onPressed: _confirmDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 28,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(6, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Image or Big Text
                    if (hasImage)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(21),
                        ),
                        child: SafeNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.broken_image,
                          fallbackColor: Colors.grey,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF9C3), // Light Yellow
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(21),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.black, width: 3),
                          ),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 2. Action Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          // Like (Flame Icon)
                          GestureDetector(
                            onTap: _toggleLike,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                _isLiked
                                    ? Icons.whatshot
                                    : Icons.local_fire_department_outlined,
                                key: ValueKey(_isLiked),
                                color: _isLiked
                                    ? Colors.deepOrange
                                    : Colors.black,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$_likes",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Comment Display Icon
                          const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.black,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "$_commentCount",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),

                          const Spacer(),
                          const Icon(
                            Icons.bookmark_border,
                            color: Colors.black,
                            size: 30,
                          ),
                        ],
                      ),
                    ),

                    // 3. Caption (If Image Present)
                    if (hasImage && content.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: "$creator ",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(text: content),
                            ],
                          ),
                        ),
                      ),

                    // 3b. Timestamp
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        timeago.format(
                          DateTime.parse(widget.postData['created_at']),
                          locale: 'id',
                        ),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.black, height: 1),

                    // 4. Comments Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        "Komentar",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // 5. Comments List
                    if (_isLoadingComments)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        ),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            "Belum ada komentar. Jadilah yang pertama!",
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.black,
                                radius: 12,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['user_name'] ?? 'User',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c['content'] ?? '',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeago.format(
                                        DateTime.parse(c['created_at']),
                                        locale: 'id',
                                      ),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),

          // 6. Comment Input Field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black, width: 2)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: "Tulis komentar...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isPostingComment
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : IconButton(
                          onPressed: _addComment,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.black,
                            size: 32,
                          ),
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
