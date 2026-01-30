import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/services/story_service.dart';
import 'package:mychatolic_app/services/chat_service.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/services/post_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/pages/main_page.dart';
import 'package:mychatolic_app/features/settings/pages/settings_page.dart';
import 'package:mychatolic_app/features/social/pages/chat_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/radar/pages/create_personal_radar_page.dart';
import 'package:mychatolic_app/features/auth/pages/verification_page.dart';
import 'package:mychatolic_app/theme/app_colors.dart';
import 'package:share_plus/share_plus.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // If null, shows current user's profile
  final bool isBackButtonEnabled; // For navigation from other pages

  const ProfilePage({super.key, this.userId, this.isBackButtonEnabled = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final StoryService _storyService = StoryService();
  final ChatService _chatService = ChatService();
  final SocialService _socialService = SocialService();
  final PostService _postService = PostService();
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  // State Variables
  bool _isLoading = true;
  String? _error;

  Profile? _profile;
  Map<String, int> _stats = {'followers': 0, 'following': 0, 'posts': 0};
  bool _isFollowing = false;
  bool _isMe = false;

  // Post Lists (Pagination State)
  List<UserPost> _photoPosts = [];
  List<UserPost> _textPosts = [];
  List<UserPost> _savedPosts = [];

  bool _isFirstLoadRunning = false;
  bool _isLoadMoreRunning = false;
  bool _hasNextPage = true;
  int _currentPage = 0;
  final int _limit = 12;

  // Stories
  List<Story> _userStories = [];

  @override
  void initState() {
    super.initState();
    _checkIsMe();
    _tabController = TabController(length: _isMe ? 3 : 2, vsync: this);
    _loadProfileData();

    _scrollController.addListener(() {
      final bool isSavedTab = _isMe && _tabController.index == 2;
      if (!isSavedTab && // Don't paginate saved posts for now
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isFirstLoadRunning &&
          !_isLoadMoreRunning &&
          _hasNextPage) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIsMe() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (widget.userId == null || widget.userId == currentUserId) {
      _isMe = true;
    } else {
      _isMe = false;
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final targetUserId = widget.userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) {
        setState(() {
          _error = "User not found";
          _isLoading = false;
        });
        return;
      }

      final profile = await _profileService.fetchUserProfile(targetUserId);
      final followStats = await _profileService.fetchFollowCounts(targetUserId);
      final stories = await _storyService.fetchUserStories(targetUserId);

      if (!_isMe) {
        _isFollowing = await _profileService.checkIsFollowing(targetUserId);
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _stats = {
            'followers': followStats['followers'] ?? 0,
            'following': followStats['following'] ?? 0,
            'posts': _stats['posts'] ?? 0,
          };
          _userStories = stories;
        });
        await _loadInitialPosts(targetUserId);
        
        // Load saved posts only if it's me
        if (_isMe) {
          _loadSavedPosts();
        }
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        setState(() {
          _error = "Gagal memuat profil. Silakan coba lagi.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedPosts() async {
    try {
      final saved = await _postService.fetchSavedPosts();
      if (mounted) {
        setState(() {
          _savedPosts = saved;
        });
      }
    } catch (e) {
      debugPrint("Error loading saved posts: $e");
    }
  }

  void _separatePosts(List<UserPost> posts) {
    List<UserPost> photos = [];
    List<UserPost> texts = [];
    for (var p in posts) {
      bool isPhoto = p.type == 'photo' || p.imageUrls.isNotEmpty;
      if (isPhoto) {
        photos.add(p);
      } else {
        texts.add(p);
      }
    }
    _photoPosts = photos;
    _textPosts = texts;
    _stats['posts'] = posts.length;
  }

  Future<void> _loadInitialPosts(String userId) async {
    try {
      final posts = await _socialService.fetchPosts(
        userId: userId,
        page: 0,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (posts.isNotEmpty) {
            _separatePosts(posts);
          }
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading posts: $e");
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadMoreRunning || !_hasNextPage || _profile == null) return;
    setState(() => _isLoadMoreRunning = true);

    try {
      final nextPage = _currentPage + 1;
      final posts = await _socialService.fetchPosts(
        userId: _profile!.id,
        page: nextPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (posts.isNotEmpty) {
            for (var p in posts) {
              if (p.type == 'photo' || p.imageUrls.isNotEmpty) {
                _photoPosts.add(p);
              } else {
                _textPosts.add(p);
              }
            }
            _currentPage = nextPage;
          }
          if (posts.length < _limit) {
            _hasNextPage = false;
          }
          _isLoadMoreRunning = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadMoreRunning = false);
    }
  }

  Future<void> _handleFollowToggle() async {
    if (_profile == null) return;
    final bool previousState = _isFollowing;
    final int previousCount = _stats['followers'] ?? 0;

    setState(() {
      if (previousState) {
        _isFollowing = false;
        _stats['followers'] = (previousCount > 0) ? previousCount - 1 : 0;
      } else {
        _isFollowing = true;
        _stats['followers'] = previousCount + 1;
      }
    });

    try {
      if (previousState) {
        await _profileService.unfollowUser(_profile!.id);
      } else {
        await _profileService.followUser(_profile!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = previousState;
          _stats['followers'] = previousCount;
        });
      }
    }
  }

  Future<void> _navigateToChat() async {
    if (_profile == null) return;

    final homeState = context.findAncestorStateOfType<HomePageState>();
    if (homeState != null) {
      homeState.openChatWith(_profile!.id);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(partnerId: _profile!.id),
      ),
    );
  }

  void _handleInviteToMass() {
    if (_profile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatePersonalRadarPage(targetUser: _profile!),
        ),
      );
    }
  }

  void _handleBannerTap() {
    if (!_isMe) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text("Lihat Banner"),
            onTap: () {
              Navigator.pop(ctx);
              _showBannerPreview();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text("Ganti Banner"),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadBanner();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showBannerPreview() {
    final url = _profile?.bannerUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Banner belum tersedia")),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: AppColors.background,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SafeNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            fallbackColor: AppColors.backgroundAlt,
            fallbackIcon: Icons.image,
          ),
        ),
      ),
    );
  }

  Future<void> _shareProfile() async {
    if (_profile == null) return;
    final name = _profile!.fullName ?? "User";
    final userId = _profile!.id;
    final message =
        "Cek profil saya di MyChatolic!\nNama: $name\nID: $userId";
    await Share.share(message);
  }

  Future<void> _handleEditProfile() async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (result == true) {
      _loadProfileData();
    }
  }

  Future<void> _openSettings() async {
    if (_profile == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPage(profile: _profile!)),
    );
    _loadProfileData();
  }

  void _handleAvatarTap() {
    if (!_isMe) {
      if (_userStories.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoryViewPage(
              stories: _userStories,
              userProfile: {
                'full_name': _profile?.fullName,
                'avatar_url': _profile?.avatarUrl,
              },
            ),
          ),
        );
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text("Lihat Foto"),
            onTap: () {
              Navigator.pop(ctx);
              if (_userStories.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewPage(
                      stories: _userStories,
                      userProfile: {
                        'full_name': _profile?.fullName,
                        'avatar_url': _profile?.avatarUrl,
                      },
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text("Ganti Foto Profil"),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadAvatar();
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text("Ganti Sampul (Banner)"),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadBanner();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final File imageFile = File(picked.path);
      final String publicUrl = await _profileService.uploadAvatar(imageFile);
      
      if (_profile != null) {
        await _profileService.updateProfile(
          userId: _profile!.id,
          avatarUrl: publicUrl,
        );
        await _loadProfileData(); // Refresh UI
      }
    } catch (e) {
      debugPrint("Upload Avatar Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload foto: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final File imageFile = File(picked.path);
      final String publicUrl = await _profileService.uploadBanner(imageFile);
      
      if (_profile != null) {
        await _profileService.updateProfile(
          userId: _profile!.id,
          bannerUrl: publicUrl,
        );
        await _loadProfileData(); // Refresh UI
      }
    } catch (e) {
      debugPrint("Upload Banner Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload banner: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showReportDialog(BuildContext context) async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Report User"),
              content: const Text("Fitur pelaporan user akan segara hadir."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK"))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // DEBUG: Check Status
    if (_profile != null) {
      debugPrint('Current Verification Status by ENUM: ${_profile!.verificationStatus}');
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Profil")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.disabled),
              const SizedBox(height: 16),
              Text(_error ?? "Data profil tidak ditemukan.",
                  style: GoogleFonts.outfit(color: AppColors.mutedText)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text("Coba Lagi"),
              )
            ],
          ),
        ),
      );
    }

    final displayProfile = _profile!;

    return Scaffold(
      backgroundColor: AppColors.background,
      // RefreshIndicator wrapping NestedScrollView
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: ProfileHeader(
                  profile: displayProfile,
                  stats: _stats,
                  isMe: _isMe,
                  isFollowing: _isFollowing,
                  onFollowToggle: _handleFollowToggle,
                  onChatTap: _navigateToChat,
                  onInviteTap: _handleInviteToMass,
                  onEditTap: _handleEditProfile,
                  onSettingsTap: _openSettings,
                  hasStories: _userStories.isNotEmpty,
                  onAvatarTap: _handleAvatarTap,
                  onBannerTap: _handleBannerTap,
                  onShareTap: _shareProfile,
                  isBackEnabled: widget.isBackButtonEnabled,
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedText,
                    labelStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                    tabs: [
                      const Tab(text: "GALERI"),
                      const Tab(text: "STATUS"),
                      if (_isMe) const Tab(text: "DISIMPAN"),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildGridPosts(_photoPosts),
              _buildListPosts(_textPosts),
              if (_isMe) _buildGridPosts(_savedPosts, isSavedView: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridPosts(List<UserPost> posts, {bool isSavedView = false}) {
    if (posts.isEmpty) {
      return _buildEmptyState(isSavedView 
          ? "Belum ada postingan disimpan" 
          : "Belum ada foto");
    }
    return CustomScrollView(
      key: PageStorageKey<String>(isSavedView ? 'saved' : 'grid'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Instagram standard
              childAspectRatio: 1.0, // Square
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = posts[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(post: post),
                    ),
                  );
                },
                child: SafeNetworkImage(
                  imageUrl: post.imageUrl ?? "",
                  fit: BoxFit.cover,
                ),
              );
            }, childCount: posts.length),
          ),
        ),
        if (_isLoadMoreRunning && !isSavedView)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildListPosts(List<UserPost> posts) {
    if (posts.isEmpty) {
      return _buildEmptyState("Belum ada status");
    }
    return ListView.separated(
      key: const PageStorageKey<String>('list'),
      padding: EdgeInsets.zero,
      itemCount: posts.length + (_isLoadMoreRunning ? 1 : 0),
      separatorBuilder: (c, i) => Divider(height: 1, color: AppColors.backgroundAlt),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()));
        }
        final post = posts[index];
        return PostCard(
          post: post,
          onUpdate: (updated) {
            setState(() {
              posts[index] = updated;
            });
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 64, color: AppColors.backgroundAlt),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.outfit(color: AppColors.disabled, fontSize: 16)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPER CLASSES
// ---------------------------------------------------------------------------

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for divider
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1, thickness: 1, color: AppColors.backgroundAlt),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}

class ProfileHeader extends StatelessWidget {
  final Profile profile;
  final Map<String, int> stats;
  final bool isMe;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final VoidCallback onChatTap;
  final VoidCallback? onInviteTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onSettingsTap;
  final bool hasStories;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onBannerTap;
  final VoidCallback? onShareTap;
  final bool isBackEnabled;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.stats,
    required this.isMe,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.onChatTap,
    this.onInviteTap,
    this.onEditTap,
    this.onSettingsTap,
    this.hasStories = false,
    this.onAvatarTap,
    this.onBannerTap,
    this.onShareTap,
    this.isBackEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    // LAYOUT CONSTANTS
    const double coverHeight = 180;
    const double avatarSize = 120;
    const double cardTopMargin = 160; // Overlaps cover by 20px
    final double cardTopPadding = (avatarSize / 2) + 20;

    String displayName = profile.fullName ?? "User";
    if (profile.baptismName != null && 
        profile.baptismName!.trim().isNotEmpty && 
        profile.baptismName != "null") {
      displayName = "${profile.baptismName} ${profile.fullName}";
    }

    final followButton = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: isFollowing
          ? ElevatedButton.icon(
              key: const ValueKey('following'),
              onPressed: onFollowToggle,
              icon: const Icon(Icons.check, size: 16, color: AppColors.background),
              label: Text(
                "Mengikuti",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.background,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.muted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            )
          : ElevatedButton.icon(
              key: const ValueKey('follow'),
              onPressed: onFollowToggle,
              icon: const Icon(Icons.person_add, size: 16, color: AppColors.background),
              label: Text(
                "Follow",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.background,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
    );

    return Container(
      color: AppColors.backgroundAlt,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
        // 1. BANNER IMAGE
        GestureDetector(
          onTap: isMe ? onBannerTap : null,
          child: Container(
            height: coverHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.backgroundAlt,
              image: profile.bannerUrl != null
                  ? DecorationImage(
                      image: NetworkImage(profile.bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
        ),
        // Gradient overlay for readability
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Settings / Back Button (Overlay on Banner)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: GestureDetector(
            onTap: onSettingsTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings, color: AppColors.background, size: 24),
            ),
          ),
        ),
        if (isBackEnabled)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.arrow_back, color: AppColors.background, size: 24),
              ),
            ),
          ),
        // 2. WHITE CARD BODY
        Container(
          margin: const EdgeInsets.only(top: cardTopMargin),
          padding: EdgeInsets.only(top: cardTopPadding, bottom: 20),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Section 1: Identity + badges
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profile.fullName ?? "User",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if (profile.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified,
                                color: AppColors.primary, size: 20),
                          ),
                      ],
                    ),
                    if (profile.baptismName != null &&
                        profile.baptismName!.trim().isNotEmpty &&
                        profile.baptismName != "null")
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.water_drop,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              "Nama Baptis: ${profile.baptismName}",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    _buildTrustBadge(context),
                    if (profile.shouldShowAge && profile.age != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.muted.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.muted.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "${profile.age} Tahun",
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Section 2: Bio + location
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.backgroundAlt),
                ),
                child: Column(
                  children: [
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          profile.bio!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: AppColors.mutedText,
                          ),
                        ),
                      ),
                    if (profile.bio != null && profile.bio!.isNotEmpty)
                      const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.mutedText),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            "${profile.country ?? '-'}, ${profile.diocese ?? '-'}",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.mutedText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.church_outlined,
                            size: 16, color: AppColors.mutedText),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            profile.parish ?? "Paroki -",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.mutedText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // VERIFICATION BANNER
              _buildVerificationBanner(context),
              const SizedBox(height: 12),

              // Section 3: Action buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 360;
                    if (isMe) {
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onEditTap,
                              icon: const Icon(Icons.edit, size: 16, color: AppColors.background),
                              label: Text("Edit Profil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.background)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: onShareTap,
                            icon: const Icon(Icons.share_outlined, size: 16, color: AppColors.text),
                            label: Text("Share Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.text)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ],
                      );
                    }

                    final Widget chatButton = OutlinedButton.icon(
                      onPressed: onChatTap,
                      icon: const Icon(Icons.mark_chat_unread_outlined, size: 16, color: AppColors.text),
                      label: Text("Chat", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.text)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    );

                    final Widget inviteButton = ElevatedButton(
                      onPressed: onInviteTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.muted,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Ajak Misa",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppColors.background,
                        ),
                      ),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: followButton),
                              const SizedBox(width: 12),
                              Expanded(child: chatButton),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: inviteButton),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: followButton),
                        const SizedBox(width: 12),
                        Expanded(child: chatButton),
                        const SizedBox(width: 12),
                        Expanded(child: inviteButton),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 12),

              // Section 4: Stats
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem("${stats['posts'] ?? 0}", "Post"),
                    _buildStatItem("${stats['followers'] ?? 0}", "Pengikut"),
                    _buildStatItem("${stats['following'] ?? 0}", "Mengikuti"),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        if (isMe)
          Positioned(
            right: 16,
            top: cardTopMargin - 52,
            child: GestureDetector(
              onTap: onBannerTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.background, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.photo_camera, size: 16, color: AppColors.background),
              ),
            ),
          ),

        // 3. AVATAR (Positioned to overlap)
        Positioned(
          top: cardTopMargin - (avatarSize / 2),
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: SafeNetworkImage(
                  imageUrl: profile.avatarUrl ?? "",
                  width: avatarSize,
                  height: avatarSize,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.person,
                  fallbackColor: AppColors.backgroundAlt,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBanner(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();
    // Logic: verified -> hidden
    if (profile.isVerified) return const SizedBox.shrink();

    final status = profile.verificationStatus;
    // Map status to UI
    Color bgColor;
    Color borderColor;
    Color contentColor;
    IconData icon;
    String text;
    Widget? actionButton;

    if (status == AccountStatus.pending) {
      bgColor = AppColors.primary.withValues(alpha: 0.12);
      borderColor = Colors.transparent; 
      contentColor = AppColors.primaryDark;
      icon = Icons.hourglass_top;
      text = "Dokumen Anda sedang ditinjau oleh Admin.";
    } else {
      // unverified, rejected, unknown
      bgColor = AppColors.danger.withValues(alpha: 0.12);
      borderColor = AppColors.danger;
      contentColor = AppColors.danger;
      icon = Icons.warning_amber_rounded;
      text = "Akun belum terverifikasi. Upload dokumen untuk akses fitur penuh.";
      actionButton = TextButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VerificationPage(profile: profile)),
          );
        },
        style: TextButton.styleFrom(
           padding: EdgeInsets.zero,
           minimumSize: const Size(0,0),
           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          "VERIFIKASI",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: contentColor,
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0), // Vertical margin handled by parent SizedBox
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != Colors.transparent ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: contentColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: contentColor,
                fontSize: 12,
              ),
            ),
          ),
          if (actionButton != null) ...[
             const SizedBox(width: 8),
             actionButton,
          ]
        ],
      ),
    );
  }

  Widget _buildTrustBadge(BuildContext context) {
    String label;
    Color color;
    Color textColor;
    IconData icon;

    if (profile.verificationStatus == AccountStatus.verified_catholic ||
        profile.verificationStatus == AccountStatus.verified_pastoral) {
      if (profile.isClergy) {
        label = "${profile.roleLabel} Terverifikasi";
        color = AppColors.primary.withValues(alpha: 0.12);
        textColor = AppColors.primaryDark;
        icon = Icons.verified_user;
      } else {
        label = "100% Katolik";
        color = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        icon = Icons.star;
      }
    } else if (profile.verificationStatus == AccountStatus.pending) {
      label = "Menunggu Verifikasi";
      color = AppColors.backgroundAlt;
      textColor = AppColors.mutedText;
      icon = Icons.hourglass_empty;
    } else if (profile.role == UserRole.katekumen) {
      label = "Katekumen";
      color = AppColors.muted.withValues(alpha: 0.12);
      textColor = AppColors.primaryDark;
      icon = Icons.local_florist;
    } else {
      // Unverified Badge
      label = "Belum Verifikasi";
      color = AppColors.danger.withValues(alpha: 0.12);
      textColor = AppColors.danger;
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
