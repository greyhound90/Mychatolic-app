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
import 'package:mychatolic_app/features/settings/pages/settings_page.dart';
import 'package:mychatolic_app/features/social/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/radar/pages/create_personal_radar_page.dart';
import 'package:mychatolic_app/features/auth/pages/verification_page.dart';

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
    if (_profile != null) {
      try {
        final chatId = await _chatService.getOrCreatePrivateChat(_profile!.id);
        if (!mounted) return;

        final Map<String, dynamic> opponentProfileMap = {
          'id': _profile!.id,
          'full_name': _profile!.fullName ?? "User",
          'avatar_url': _profile!.avatarUrl,
          'role': _profile!.roleLabel,
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SocialChatDetailPage(
              chatId: chatId,
              opponentProfile: opponentProfileMap,
            ),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
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
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // DEBUG: Check Status
    if (_profile != null) {
      debugPrint('Current Verification Status by ENUM: ${_profile!.verificationStatus}');
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text("Profil")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error ?? "Data profil tidak ditemukan.",
                  style: GoogleFonts.outfit(color: Colors.black54)),
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
      backgroundColor: Colors.white,
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
                  isBackEnabled: widget.isBackButtonEnabled,
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blue,
                    indicatorWeight: 3,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
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
      separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey[200]),
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
          Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
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
      color: Colors.white,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
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
    this.isBackEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    // LAYOUT CONSTANTS
    const double coverHeight = 180;
    const double avatarSize = 100;
    const double cardTopMargin = 150; // Overlaps cover by 30px

    String displayName = profile.fullName ?? "User";
    if (profile.baptismName != null && profile.baptismName!.trim().isNotEmpty) {
      // Format: "NamaBaptis NamaLengkap"
      displayName = "${profile.baptismName} ${profile.fullName}";
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 1. BANNER IMAGE
        Container(
          height: coverHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: profile.bannerUrl != null
                ? DecorationImage(
                    image: NetworkImage(profile.bannerUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
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
              child: const Icon(Icons.settings, color: Colors.white, size: 24),
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
                    const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),

        // 2. WHITE CARD BODY
        Container(
          margin: const EdgeInsets.only(top: cardTopMargin),
          padding: const EdgeInsets.only(top: 60, bottom: 20), // Top padding for Avatar clearance
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 2A. NAME & VERIFIED
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (profile.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.verified, color: Colors.blue, size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2B. TRUST BADGE
              _buildTrustBadge(context),
              const SizedBox(height: 12),
              
              // 2C. AGE (Only if < 18)
              if (profile.shouldShowAge && profile.age != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                     decoration: BoxDecoration(
                       color: Colors.pink[50],
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.pink[100]!),
                     ),
                     child: Text(
                       "${profile.age} Tahun",
                       style: GoogleFonts.outfit(fontSize: 12, color: Colors.pink[800], fontWeight: FontWeight.bold),
                     ),
                  ),
                ),

              // 2D. BIO
              if (profile.bio != null && profile.bio!.isNotEmpty)
              if (profile.bio != null && profile.bio!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    profile.bio!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // 2C. LOCATION / DETAILS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    "${profile.country ?? '-'}, ${profile.diocese ?? '-'}",
                     style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
               Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.church_outlined,
                      size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    profile.parish ?? "Paroki -",
                     style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 12),

              // VERIFICATION BANNER
              _buildVerificationBanner(context),
              const SizedBox(height: 12),

              // 2D. ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    if (isMe) ...[
                      // EDIT PROFILE BUTTON
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onEditTap,
                          icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                          label: Text("Edit Profil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC), // Primary Blue
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // SHARE BUTTON
                      OutlinedButton.icon(
                        onPressed: () {}, // TO DO
                        icon: const Icon(Icons.share_outlined, size: 16, color: Colors.black87),
                        label: Text("Share", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87)),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide.none, // Or grey border
                        ),
                      ),
                    ] else ...[
                       // AJAK MISA BUTTON
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onInviteTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: Text(
                            "Ajak Misa",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, 
                              color: Colors.white
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // CHAT BUTTON
                      OutlinedButton.icon(
                        onPressed: onChatTap,
                        icon: const Icon(Icons.mark_chat_unread_outlined, size: 16, color: Colors.black87),
                        label: Text("Chat", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black87)),
                         style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: const BorderSide(color: Colors.grey), 
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1, indent: 20, endIndent: 20),
              const SizedBox(height: 16),

              // 2E. STATS ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem("${stats['posts'] ?? 0}", "Post"),
                  _buildStatItem("${stats['followers'] ?? 0}", "Pengikut"),
                  _buildStatItem("${stats['following'] ?? 0}", "Mengikuti"),
                ],
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
                border: Border.all(color: Colors.white, width: 4),
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
                  fallbackColor: Colors.grey[200],
                ),
              ),
            ),
          ),
        ),
      ],
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
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey[500],
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
      bgColor = const Color(0xFFE3F2FD); // Light Blue
      borderColor = Colors.transparent; 
      contentColor = const Color(0xFF0D47A1); // Dark Blue
      icon = Icons.hourglass_top;
      text = "Dokumen Anda sedang ditinjau oleh Admin.";
    } else {
      // unverified, rejected, unknown
      bgColor = const Color(0xFFFFF3CD); // Light Orange
      borderColor = Colors.orange;
      contentColor = const Color(0xFFE65100); // Dark Orange
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
        color = const Color(0xFFE3F2FD); // Light Blue
        textColor = const Color(0xFF1565C0);
        icon = Icons.verified_user;
      } else {
        label = "100% Katolik";
        color = const Color(0xFFFFF8E1); // Gold/Yellow
        textColor = const Color(0xFFF57F17);
        icon = Icons.star;
      }
    } else if (profile.verificationStatus == AccountStatus.pending) {
      label = "Menunggu Verifikasi";
      color = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      icon = Icons.hourglass_empty;
    } else if (profile.role == UserRole.katekumen) {
      label = "Katekumen";
      color = const Color(0xFFE8F5E9); // Light Green
      textColor = const Color(0xFF2E7D32);
      icon = Icons.local_florist;
    } else {
      // Unverified Badge
      label = "Belum Verifikasi";
      color = const Color(0xFFFFEBEE); // Light Red
      textColor = const Color(0xFFC62828); // Dark Red
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
