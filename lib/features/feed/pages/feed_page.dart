import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/post_service.dart';
import 'package:mychatolic_app/features/feed/widgets/post_card.dart';
import 'package:mychatolic_app/features/feed/pages/create_post_page.dart';
import 'package:shimmer/shimmer.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();

  static const int _photoLimit = 10;
  static const int _textLimit = 10;
  static const int _savedLimit = 10;

  // Photo tab state
  List<UserPost> _photoPosts = [];
  int _photoPage = 0;
  bool _photoHasMore = true;
  bool _photoLoading = true;
  bool _photoLoadingMore = false;
  late final ScrollController _photoScrollController;

  // Text tab state
  List<UserPost> _textPosts = [];
  int _textPage = 0;
  bool _textHasMore = true;
  bool _textLoading = true;
  bool _textLoadingMore = false;
  late final ScrollController _textScrollController;

  // Saved tab state
  List<UserPost> _savedPosts = [];
  int _savedPage = 0;
  bool _savedHasMore = true;
  bool _savedLoading = true;
  bool _savedLoadingMore = false;
  late final ScrollController _savedScrollController;

  @override
  void initState() {
    super.initState();
    _photoScrollController = ScrollController()..addListener(_onPhotoScroll);
    _textScrollController = ScrollController()..addListener(_onTextScroll);
    _savedScrollController = ScrollController()..addListener(_onSavedScroll);
    _refreshAll();
  }

  @override
  void dispose() {
    _photoScrollController.dispose();
    _textScrollController.dispose();
    _savedScrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshPhotos(),
      _refreshTexts(),
      _refreshSaved(),
    ]);
  }

  Future<void> _refreshPhotos() async {
    if (mounted) {
      setState(() {
        _photoLoading = true;
        _photoPage = 0;
        _photoHasMore = true;
        _photoPosts = [];
      });
    }
    try {
      final data = await _postService.fetchPhotoPostsPaged(
        page: 0,
        limit: _photoLimit,
      );
      if (!mounted) return;
      setState(() {
        _photoPosts = data;
        _photoLoading = false;
        _photoHasMore = data.length == _photoLimit;
      });
    } catch (e) {
      if (mounted) setState(() => _photoLoading = false);
      debugPrint("Error fetching photos: $e");
    }
  }

  Future<void> _refreshTexts() async {
    if (mounted) {
      setState(() {
        _textLoading = true;
        _textPage = 0;
        _textHasMore = true;
        _textPosts = [];
      });
    }
    try {
      final data = await _postService.fetchTextPostsPaged(
        page: 0,
        limit: _textLimit,
      );
      if (!mounted) return;
      setState(() {
        _textPosts = data;
        _textLoading = false;
        _textHasMore = data.length == _textLimit;
      });
    } catch (e) {
      if (mounted) setState(() => _textLoading = false);
      debugPrint("Error fetching texts: $e");
    }
  }

  Future<void> _refreshSaved() async {
    if (mounted) {
      setState(() {
        _savedLoading = true;
        _savedPage = 0;
        _savedHasMore = true;
        _savedPosts = [];
      });
    }
    try {
      final data = await _postService.fetchSavedPostsPaged(
        page: 0,
        limit: _savedLimit,
      );
      if (!mounted) return;
      setState(() {
        _savedPosts = data;
        _savedLoading = false;
        _savedHasMore = data.length == _savedLimit;
      });
    } catch (e) {
      if (mounted) setState(() => _savedLoading = false);
      debugPrint("Error fetching saved: $e");
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_photoLoadingMore || !_photoHasMore || _photoLoading) return;
    setState(() => _photoLoadingMore = true);
    final nextPage = _photoPage + 1;
    try {
      final data = await _postService.fetchPhotoPostsPaged(
        page: nextPage,
        limit: _photoLimit,
      );
      if (!mounted) return;
      setState(() {
        _photoPage = nextPage;
        _photoPosts.addAll(data);
        _photoLoadingMore = false;
        if (data.length < _photoLimit) _photoHasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _photoLoadingMore = false);
      debugPrint("Error loading more photos: $e");
    }
  }

  Future<void> _loadMoreTexts() async {
    if (_textLoadingMore || !_textHasMore || _textLoading) return;
    setState(() => _textLoadingMore = true);
    final nextPage = _textPage + 1;
    try {
      final data = await _postService.fetchTextPostsPaged(
        page: nextPage,
        limit: _textLimit,
      );
      if (!mounted) return;
      setState(() {
        _textPage = nextPage;
        _textPosts.addAll(data);
        _textLoadingMore = false;
        if (data.length < _textLimit) _textHasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _textLoadingMore = false);
      debugPrint("Error loading more texts: $e");
    }
  }

  Future<void> _loadMoreSaved() async {
    if (_savedLoadingMore || !_savedHasMore || _savedLoading) return;
    setState(() => _savedLoadingMore = true);
    final nextPage = _savedPage + 1;
    try {
      final data = await _postService.fetchSavedPostsPaged(
        page: nextPage,
        limit: _savedLimit,
      );
      if (!mounted) return;
      setState(() {
        _savedPage = nextPage;
        _savedPosts.addAll(data);
        _savedLoadingMore = false;
        if (data.length < _savedLimit) _savedHasMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => _savedLoadingMore = false);
      debugPrint("Error loading more saved: $e");
    }
  }

  void _onPhotoScroll() {
    if (!_photoScrollController.hasClients) return;
    if (_photoScrollController.position.pixels >=
        _photoScrollController.position.maxScrollExtent - 600) {
      _loadMorePhotos();
    }
  }

  void _onTextScroll() {
    if (!_textScrollController.hasClients) return;
    if (_textScrollController.position.pixels >=
        _textScrollController.position.maxScrollExtent - 600) {
      _loadMoreTexts();
    }
  }

  void _onSavedScroll() {
    if (!_savedScrollController.hasClients) return;
    if (_savedScrollController.position.pixels >=
        _savedScrollController.position.maxScrollExtent - 600) {
      _loadMoreSaved();
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
            _KeepAlive(
              child: _buildPostList(
                posts: _photoPosts,
                isLoading: _photoLoading,
                isLoadingMore: _photoLoadingMore,
                emptyMessage: "Belum ada foto",
                controller: _photoScrollController,
                onRefresh: _refreshPhotos,
              ),
            ),
            _KeepAlive(
              child: _buildPostList(
                posts: _textPosts,
                isLoading: _textLoading,
                isLoadingMore: _textLoadingMore,
                emptyMessage: "Belum ada tulisan",
                controller: _textScrollController,
                onRefresh: _refreshTexts,
              ),
            ),
            _KeepAlive(
              child: _buildPostList(
                posts: _savedPosts,
                isLoading: _savedLoading,
                isLoadingMore: _savedLoadingMore,
                emptyMessage: "Belum ada yang disimpan",
                controller: _savedScrollController,
                onRefresh: _refreshSaved,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostPage()),
            );
            _refreshAll();
          },
          backgroundColor: const Color(0xFF0088CC),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPostList({
    required List<UserPost> posts,
    required bool isLoading,
    required bool isLoadingMore,
    required String emptyMessage,
    required ScrollController controller,
    required Future<void> Function() onRefresh,
  }) {
    if (isLoading && posts.isEmpty) {
      return const _FeedShimmerList();
    }
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: controller,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final post = posts[index];
          return PostCard(
            post: post,
            onUpdate: _onPostUpdated,
          );
        },
      ),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _FeedShimmerList extends StatelessWidget {
  const _FeedShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFFE6E6E6),
          highlightColor: const Color(0xFFF5F5F5),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}
