
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/post_service.dart';
import 'package:mychatolic_app/features/feed/widgets/post_card.dart';
import 'package:mychatolic_app/features/feed/pages/create_post_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();
  
  // Data lists
  List<UserPost> _photoPosts = [];
  List<UserPost> _textPosts = [];
  List<UserPost> _savedPosts = [];
  
  bool _isLoadingPhotos = true;
  bool _isLoadingText = true;
  bool _isLoadingSaved = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    _fetchPhotos();
    _fetchTexts();
    _fetchSaved();
  }

  Future<void> _fetchPhotos() async {
    try {
      final data = await _postService.fetchPhotoPosts();
      if (mounted) setState(() { _photoPosts = data; _isLoadingPhotos = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingPhotos = false);
      debugPrint("Error fetching photos: $e");
    }
  }

  Future<void> _fetchTexts() async {
    try {
      final data = await _postService.fetchTextPosts();
      if (mounted) setState(() { _textPosts = data; _isLoadingText = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingText = false);
      debugPrint("Error fetching texts: $e");
    }
  }

  Future<void> _fetchSaved() async {
    try {
      final data = await _postService.fetchSavedPosts();
      if (mounted) setState(() { _savedPosts = data; _isLoadingSaved = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingSaved = false);
      debugPrint("Error fetching saved: $e");
    }
  }

  void _onPostUpdated(UserPost updated) {
     setState(() {
       _updateList(_photoPosts, updated);
       _updateList(_textPosts, updated);
       _updateList(_savedPosts, updated);
     });
  }

  void _updateList(List<UserPost> list, UserPost updated) {
    final index = list.indexWhere((element) => element.id == updated.id);
    if (index != -1) {
      list[index] = updated;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Mychatolic", 
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              color: const Color(0xFF0088CC),
              fontSize: 22,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          bottom: TabBar(
            labelColor: const Color(0xFF0088CC),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0088CC),
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.image), text: "Foto"),
              Tab(icon: Icon(Icons.article), text: "Tulisan"),
              Tab(icon: Icon(Icons.bookmark), text: "Disimpan"),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        body: TabBarView(
          children: [
            _buildPostList(_photoPosts, _isLoadingPhotos, "Belum ada foto"),
            _buildPostList(_textPosts, _isLoadingText, "Belum ada tulisan"),
            _buildPostList(_savedPosts, _isLoadingSaved, "Belum ada yang disimpan"),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePostPage()));
            _loadAllData(); // Refresh after create
          },
          backgroundColor: const Color(0xFF0088CC),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPostList(List<UserPost> posts, bool isLoading, String emptyMessage) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(emptyMessage, style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          // STRICT usage of PostCard delegating all UI
          return PostCard(
            post: post,
            onUpdate: _onPostUpdated,
          );
        },
      ),
    );
  }
}
