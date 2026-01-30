import 'dart:io';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  
  _ProfilePalette get _palette => _ProfilePalette.of(context);

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
      if (kDebugMode) {
        debugPrint("Error loading profile: $e");
      }
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
      if (kDebugMode) {
        debugPrint("Error loading saved posts: $e");
      }
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
      if (kDebugMode) {
        debugPrint("Error loading posts: $e");
      }
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
        backgroundColor: _palette.background,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SafeNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            fallbackColor: _palette.backgroundAlt,
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
      if (kDebugMode) {
        debugPrint("Upload Avatar Failed: $e");
      }
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

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Atur Banner',
          toolbarColor: _palette.primary,
          toolbarWidgetColor: Theme.of(context).colorScheme.onPrimary,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Atur Banner',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final File imageFile = File(croppedFile.path);
      final String publicUrl = await _profileService.uploadBanner(imageFile);
      
      if (_profile != null) {
        await _profileService.updateProfile(
          userId: _profile!.id,
          bannerUrl: publicUrl,
        );
        await _loadProfileData(); // Refresh UI
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Upload Banner Failed: $e");
      }
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
      return Scaffold(
        backgroundColor: _palette.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // DEBUG: Check Status
    if (_profile != null) {
      if (kDebugMode) {
        debugPrint('Current Verification Status by ENUM: ${_profile!.verificationStatus}');
      }
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: _palette.background,
        appBar: AppBar(title: const Text("Profil")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: _palette.disabled),
              const SizedBox(height: 16),
              Text(_error ?? "Data profil tidak ditemukan.",
                  style: GoogleFonts.outfit(color: _palette.mutedText)),
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
      backgroundColor: _palette.background,
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
                    indicatorWeight: 3,
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
    final basePadding = 16 + MediaQuery.of(context).padding.bottom;
    final bottomPadding =
        posts.length <= 3 ? basePadding : basePadding + kBottomNavigationBarHeight;
    return CustomScrollView(
      key: PageStorageKey<String>(isSavedView ? 'saved' : 'grid'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Instagram standard
              childAspectRatio: 4 / 5, // 4:5 portrait
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SafeNetworkImage(
                    imageUrl: post.imageUrl ?? "",
                    fit: BoxFit.cover,
                  ),
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
        SliverToBoxAdapter(
          child: SizedBox(height: bottomPadding),
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
      separatorBuilder: (c, i) => Divider(height: 1, color: _palette.border),
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
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 64, color: _palette.mutedText),
                const SizedBox(height: 16),
                Text(
                  msg,
                  style: GoogleFonts.outfit(color: _palette.disabled, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
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
    final _palette = _ProfilePalette.of(context);
    return Container(
      color: _palette.background,
      child: Column(
        children: [
          _tabBar,
          Divider(height: 1, thickness: 1, color: _palette.border),
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
    final _palette = _ProfilePalette.of(context);
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
              icon: Icon(Icons.check, size: 16, color: _palette.onPrimary),
              label: Text(
                "Mengikuti",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: _palette.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _palette.muted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            )
          : ElevatedButton.icon(
              key: const ValueKey('follow'),
              onPressed: onFollowToggle,
              icon: Icon(Icons.person_add, size: 16, color: _palette.onPrimary),
              label: Text(
                "Follow",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: _palette.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _palette.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
            ),
    );

    Widget animateSection(Widget child) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: child,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          );
        },
      );
    }

    Widget glassIconButton({
      required VoidCallback? onTap,
      required Widget icon,
      EdgeInsets padding = const EdgeInsets.all(8),
    }) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Container(
                padding: padding,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _palette.background.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _palette.border.withValues(alpha: 0.5),
                  ),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: _palette.backgroundAlt,
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
              color: _palette.backgroundAlt,
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
                    _palette.shadow.withValues(alpha: 0.0),
                    _palette.shadow.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Settings / Camera Buttons (Overlay on Banner)
        Positioned(
          top: 0,
          right: 12,
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 8, right: 4),
            child: Column(
              children: [
                glassIconButton(
                  onTap: onSettingsTap,
                  icon: Icon(Icons.settings, color: _palette.text, size: 22),
                ),
                if (isMe) ...[
                  const SizedBox(height: 10),
                  glassIconButton(
                    onTap: onBannerTap,
                    icon: Icon(Icons.photo_camera, size: 22, color: _palette.text),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isBackEnabled)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: glassIconButton(
              onTap: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: _palette.text, size: 24),
            ),
          ),
        // 2. WHITE CARD BODY
        Container(
          margin: const EdgeInsets.only(top: cardTopMargin),
          padding: EdgeInsets.only(top: cardTopPadding, bottom: 20),
          decoration: BoxDecoration(
            color: _palette.backgroundAlt,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: _palette.text.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: _palette.shadow.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Section 1: Identity + badges
              animateSection(
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _palette.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _palette.text.withValues(alpha: 0.08),
                    ),
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
                                color: _palette.text,
                              ),
                            ),
                          ),
                          if (profile.isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.verified,
                                  color: _palette.primary, size: 20),
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
                                  size: 14, color: _palette.muted),
                              const SizedBox(width: 4),
                              Text(
                                "Nama Baptis: ${profile.baptismName}",
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: _palette.muted,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _palette.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _palette.muted.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              "${profile.age} Tahun",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: _palette.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Section 2: Bio + location
              animateSection(
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _palette.backgroundAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _palette.text.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: _palette.shadow.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
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
                              color: _palette.mutedText,
                            ),
                          ),
                        ),
                      if (profile.bio != null && profile.bio!.isNotEmpty)
                        const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: _palette.mutedText),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "${profile.country ?? '-'}, ${profile.diocese ?? '-'}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: _palette.mutedText),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.church_outlined,
                              size: 16, color: _palette.mutedText),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              profile.parish ?? "Paroki -",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: _palette.mutedText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // VERIFICATION BANNER
              _buildVerificationBanner(context),
              const SizedBox(height: 12),

              // Section 3: Action buttons
              animateSection(
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _palette.backgroundAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _palette.text.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: _palette.shadow.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
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
                              icon: Icon(Icons.edit, size: 16, color: _palette.onPrimary),
                              label: Text("Edit Profil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _palette.onPrimary)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _palette.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: onShareTap,
                            icon: Icon(Icons.share_outlined, size: 16, color: _palette.text),
                            label: Text("Share Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _palette.text)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(color: _palette.text.withValues(alpha: 0.2)),
                            ),
                          ),
                        ],
                      );
                    }

                    final Widget chatButton = OutlinedButton.icon(
                      onPressed: onChatTap,
                      icon: Icon(Icons.mark_chat_unread_outlined, size: 16, color: _palette.text),
                      label: Text("Chat", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _palette.text)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: _palette.text.withValues(alpha: 0.2)),
                      ),
                    );

                    final Widget inviteButton = ElevatedButton(
                      onPressed: onInviteTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _palette.muted,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Ajak Misa",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: _palette.onPrimary,
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
              ),

              const SizedBox(height: 16),
              Divider(height: 1, indent: 20, endIndent: 20, color: _palette.border),
              const SizedBox(height: 12),

              // Section 4: Stats
              animateSection(
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _palette.backgroundAlt,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _palette.text.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: _palette.shadow.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(context, "${stats['posts'] ?? 0}", "Post"),
                      _buildStatItem(context, "${stats['followers'] ?? 0}", "Pengikut"),
                      _buildStatItem(context, "${stats['following'] ?? 0}", "Mengikuti"),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
                border: Border.all(color: _palette.backgroundAlt, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: _palette.shadow.withValues(alpha: 0.2),
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
                  fallbackColor: _palette.backgroundAlt,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildStatItem(BuildContext context, String count, String label) {
    final palette = _ProfilePalette.of(context);
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.text,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: palette.mutedText,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBanner(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();
    // Logic: verified -> hidden
    if (profile.isVerified) return const SizedBox.shrink();

    final palette = _ProfilePalette.of(context);
    final status = profile.verificationStatus;
    // Map status to UI
    Color bgColor;
    Color borderColor;
    Color contentColor;
    IconData icon;
    String text;
    Widget? actionButton;

    if (status == AccountStatus.pending) {
      bgColor = palette.primary.withValues(alpha: 0.12);
      borderColor = Colors.transparent; 
      contentColor = palette.primaryDark;
      icon = Icons.hourglass_top;
      text = "Dokumen Anda sedang ditinjau oleh Admin.";
    } else {
      // unverified, rejected, unknown
      bgColor = palette.danger.withValues(alpha: 0.12);
      borderColor = palette.danger;
      contentColor = palette.danger;
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
    final palette = _ProfilePalette.of(context);
    String label;
    Color color;
    Color textColor;
    IconData icon;

    if (profile.verificationStatus == AccountStatus.verified_catholic ||
        profile.verificationStatus == AccountStatus.verified_pastoral) {
      if (profile.isClergy) {
        label = "${profile.roleLabel} Terverifikasi";
        color = palette.primary.withValues(alpha: 0.12);
        textColor = palette.primaryDark;
        icon = Icons.verified_user;
      } else {
        label = "100% Katolik";
        color = palette.success.withValues(alpha: 0.12);
        textColor = palette.success;
        icon = Icons.star;
      }
    } else if (profile.verificationStatus == AccountStatus.pending) {
      label = "Menunggu Verifikasi";
      color = palette.backgroundAlt;
      textColor = palette.mutedText;
      icon = Icons.hourglass_empty;
    } else if (profile.role == UserRole.katekumen) {
      label = "Katekumen";
      color = palette.muted.withValues(alpha: 0.12);
      textColor = palette.primaryDark;
      icon = Icons.local_florist;
    } else {
      // Unverified Badge
      label = "Belum Verifikasi";
      color = palette.danger.withValues(alpha: 0.12);
      textColor = palette.danger;
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

class _ProfilePalette {
  final Color primary;
  final Color onPrimary;
  final Color primaryDark;
  final Color muted;
  final Color background;
  final Color backgroundAlt;
  final Color text;
  final Color mutedText;
  final Color border;
  final Color disabled;
  final Color success;
  final Color danger;
  final Color shadow;

  const _ProfilePalette._({
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.muted,
    required this.background,
    required this.backgroundAlt,
    required this.text,
    required this.mutedText,
    required this.border,
    required this.disabled,
    required this.success,
    required this.danger,
    required this.shadow,
  });

  factory _ProfilePalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final onSurface = colors.onSurface;
    return _ProfilePalette._(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryDark: colors.primary,
      muted: colors.secondary,
      background: theme.scaffoldBackgroundColor,
      backgroundAlt: colors.surface,
      text: onSurface,
      mutedText: onSurface.withOpacity(0.7),
      border: theme.dividerColor,
      disabled: onSurface.withOpacity(0.4),
      success: colors.secondary,
      danger: colors.error,
      shadow: theme.shadowColor,
    );
  }
}
