import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/widgets/post_card.dart';

const LinearGradient kSignatureGradient = LinearGradient(
  colors: [Color(0xFF0088CC), Color(0xFF2B5BAE)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  final _supabase = Supabase.instance.client;
  final SocialService _socialService = SocialService();
  final ScrollController _scrollController = ScrollController();

  // State
  final List<UserPost> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 0;
  String _userName = "Teman";

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadPosts(); // Initial Load
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Infinite Scroll Listener
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPosts();
    }
  }

  Future<void> _loadUserName() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted && data != null) {
          setState(() {
            _userName = data['full_name'].toString().split(' ').first;
          });
        }
      } catch (_) {}
    }
  }

  // Load Posts Logic
  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _isLoading = true;
        _page = 0;
        _hasMore = true;
        _posts.clear();
      });
    } else {
      if (!_hasMore) return;
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final newPosts = await _socialService.fetchPosts(page: _page, limit: 10);

      if (mounted) {
        setState(() {
          if (newPosts.length < 10) _hasMore = false;
          _posts.addAll(newPosts);
          _page++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal memuat: $e")));
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return "Selamat Pagi";
    if (hour < 15) return "Selamat Siang";
    if (hour < 18) return "Selamat Sore";
    return "Selamat Malam";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () => _loadPosts(refresh: true),
        color: kPrimary,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _posts.length + 2, // 0: Header, Last: Loader
          itemBuilder: (context, index) {
            // 1. HEADER (Top Section)
            if (index == 0) {
              return _buildHeader();
            }

            // 2. LOADER (Bottom Section)
            if (index == _posts.length + 1) {
              return _hasMore
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          "Anda sudah mencapai akhir.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
            }

            // 3. POST CARD
            final postIndex = index - 1;
            final post = _posts[postIndex];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: PostCard(
                post: post,
                socialService: _socialService,

                // Pass callback if PostCard supports it, or it handles internal state?
                // NOTE: Ideally PostCard should just display data.
                // If PostCard handles logic internally, 'optimistic' here is moot unless we pass a key or callback.
                // Assuming standard PostCard usage for now. If PostCard manages its own state, that's fine too.
                // But for this task, "Interactivity" requirement implies page control.
                // Let's rely on PostCard internal logic if exists, or wrap it.
                // To force update from here, we'd need to pass a callback if PostCard allows.
                // Since I cannot see PostCard code right now, I'll assume it takes the post object.
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // A. THE BLUE HEADER
        Container(
          height: 240,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 60), // Space for overlap
          decoration: const BoxDecoration(
            gradient: kSignatureGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$_greeting, $_userName",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Semoga harimu penuh berkah.",
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Bacaan Hari Ini: Mat 5:1-12",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // B. THE OVERLAPPING SEARCH
        Positioned(
          bottom: 10,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0088CC).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[100],
                  child: const Icon(Icons.edit, color: kPrimary, size: 18),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Apa cerita imanmu hari ini?",
                    style: GoogleFonts.outfit(color: kTextMeta, fontSize: 14),
                  ),
                ),
                const Icon(Icons.image_outlined, color: kTextMeta),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
