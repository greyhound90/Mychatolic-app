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
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';
import 'package:mychatolic_app/pages/settings_page.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/pages/story/story_view_page.dart';
import 'package:mychatolic_app/pages/profile/edit_profile_page.dart';

// --- VISUAL CONSTANTS ---
const Color kBrownAccent = Color(0xFF8B5A2B); // Cokelat Emas/Tua
const Color kScaffoldBg = Color(0xFFF5F5F5);

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
    _tabController = TabController(length: 2, vsync: this);
    
    // Check if current user
    _checkIsMe();
    
    // Fetch Real Data 
    _loadProfileData();

    // Scroll Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
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

      final data = await _profileService.fetchUserProfile(targetUserId);
      final stories = await _storyService.fetchUserStories(targetUserId);

      if (!_isMe) {
        _isFollowing = await _profileService.checkIsFollowing(targetUserId);
      }

      if (mounted) {
        setState(() {
          _profile = data['profile'] as Profile;
          _stats = data['stats'] as Map<String, int>;
          _userStories = stories;
        });
        // Fetch posts after profile is loaded
        await _loadInitialPosts(targetUserId);
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

  // --- PAGINATION LOGIC ---

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
             // Update posts count in stats based on actual valid posts
             int totalPosts = _photoPosts.length + _textPosts.length;
             // _stats['posts'] = totalPosts; // Optional: Override stats or keep DB count
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

  // --- ACTIONS ---

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
          'role': _profile!.role,
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: kBrownAccent)),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: kScaffoldBg,
        appBar: AppBar(title: const Text("Profil")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(_error ?? "Data profil tidak ditemukan.", style: GoogleFonts.outfit(color: Colors.black54)),
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
      backgroundColor: kScaffoldBg,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: Colors.black, // Dark bg for banner
              leading: widget.isBackButtonEnabled
                  ? Container(
                      margin: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black26, 
                        shape: BoxShape.circle
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [
                  StretchMode.zoomBackground,
                  StretchMode.blurBackground,
                ],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      "https://i.pinimg.com/originals/9a/b3/24/9ab324c3563fb3518bb9019379ca774b.jpg", // Heart Hand Sunset
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                         // Fallback if pinterest blocks request
                         return Image.network(
                           "https://images.unsplash.com/photo-1518621736915-f3b1c41bfd00?q=80&w=2000&auto=format&fit=crop",
                           fit: BoxFit.cover
                         );
                      },
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black38],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: _isMe
                      ? IconButton(
                          icon: const Icon(Icons.settings, color: Colors.white),
                          onPressed: _openSettings,
                        )
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (val) {
                             if(val == 'report') _showReportDialog(context);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'report',
                              child: Text("Report User"),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -50), 
                child: ProfileHeader(
                  profile: displayProfile,
                  stats: _stats,
                  isMe: _isMe,
                  isFollowing: _isFollowing,
                  onFollowToggle: _handleFollowToggle,
                  onChatTap: _navigateToChat,
                  onEditTap: _handleEditProfile,
                  hasStories: _userStories.isNotEmpty,
                  onAvatarTap: _handleAvatarTap,
                ),
              ),
            ),

            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: kBrownAccent, // Brown indicator
                  labelColor: Colors.black, // Dark text for active tab
                  unselectedLabelColor: Colors.grey,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.grid_on_rounded), 
                      text: "Foto",
                    ),
                    Tab(
                      icon: Icon(Icons.list_rounded), 
                      text: "Status",
                    ),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: Container(
          color: Colors.white,
          child: TabBarView(
            controller: _tabController,
            children: [_buildGridPosts(), _buildListPosts()],
          ),
        ),
      ),
    );
  }

  Widget _buildGridPosts() {
    if (_photoPosts.isEmpty) {
      return _buildEmptyState("Belum ada foto");
    }
    return CustomScrollView(
      key: const PageStorageKey<String>('grid'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, 
              childAspectRatio: 0.8,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = _photoPosts[index];
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
            }, childCount: _photoPosts.length),
          ),
        ),
        if (_isLoadMoreRunning)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Center(child: CircularProgressIndicator(color: kBrownAccent)),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
      ],
    );
  }

  Widget _buildListPosts() {
     if (_textPosts.isEmpty) {
      return _buildEmptyState("Belum ada postingan teks");
    }
    return ListView.separated(
      key: const PageStorageKey<String>('list'),
      padding: EdgeInsets.zero,
      itemCount: _textPosts.length + (_isLoadMoreRunning ? 1 : 0),
      separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        if (index == _textPosts.length) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: kBrownAccent)));
        }
        final post = _textPosts[index];
        return PostCard(
           post: post,
           socialService: _socialService,
           onPostUpdated: (updated) {
              setState(() {
                _textPosts[index] = updated;
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
          Icon(Icons.filter_none, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(msg, style: GoogleFonts.outfit(color: Colors.grey)),
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
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 for border
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: _tabBar,
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
  final VoidCallback? onEditTap;
  final bool hasStories;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.stats,
    required this.isMe,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.onChatTap,
    this.onEditTap,
    this.hasStories = false,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarRadius = 55; 
    const double avatarDiameter = avatarRadius * 2;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 0), 
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 // Info Row (Name & Bio)
                 // NOTE: Spacer for avatar is needed because Avatar is floating
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(width: 110), // Space for floating avatar
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             profile.fullName ?? "User",
                             style: GoogleFonts.outfit(
                               fontSize: 24, 
                               fontWeight: FontWeight.bold, // Name Bold
                               height: 1.2,
                               color: Colors.black,
                             ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             "Biografi", // Label "Biografi"
                             style: GoogleFonts.outfit(
                               fontSize: 16,
                               fontWeight: FontWeight.bold, // Bold
                               color: Colors.black,
                             ),
                           ),
                         ],
                       )
                     )
                   ],
                 ),
                 
                 const SizedBox(height: 24),
                 
                 // Stats Row
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 8.0),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       _buildStat(stats['posts'] ?? 0, "Post"),
                       _buildStat(stats['followers'] ?? 0, "Followers"),
                       _buildStat(stats['following'] ?? 0, "Following"),
                     ],
                   ),
                 ),

                 const SizedBox(height: 30),
                 
                 // Bottom Row: Location & Button
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     // Location (Left side)
                     Expanded(
                       flex: 4,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // Hardcoded Location Text to match reference
                           Text(
                             "INDONESIA,\n${(profile.diocese ?? 'Keuskupan').toUpperCase()}\n${(profile.parish ?? 'Paroki').toUpperCase()}",
                             style: GoogleFonts.outfit(
                               fontSize: 10, 
                               fontWeight: FontWeight.w600, // Semi bold
                               color: Colors.black87,
                               height: 1.3
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(width: 16),
                     
                     // Button (Right side, expanded)
                     Expanded(
                       flex: 5,
                       child: _buildActionButton(kBrownAccent),
                     )
                   ],
                 )
              ],
            ),
          ),
        ),
        
        // Avatar (Floating)
        Positioned(
          top: -50,
          left: 20,
          child: GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: avatarDiameter,
              height: avatarDiameter,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0,4))
                ]
              ),
              child: ClipOval(
                child: SafeNetworkImage(
                  imageUrl: profile.avatarUrl ?? "",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        
        // Badge "100% KATOLIK"
        Positioned(
          top: -20, // Overlapping height (20 above, 20 below approx)
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kBrownAccent, // Brown Gold
              borderRadius: BorderRadius.circular(50), // Stadium / Pill
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))
              ]
            ),
            child: Text(
              "100% KATOLIK",
              style: GoogleFonts.outfit(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        )
      ],
    );
  }
  
  Widget _buildActionButton(Color primaryColor) {
    if (isMe) {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onEditTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder() // Pill shape
          ),
          child: Text("EDIT PROFIL", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      );
    } else {
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onFollowToggle,
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[300] : primaryColor,
            foregroundColor: isFollowing ? Colors.black87 : Colors.white,
            elevation: 0,
            shape: const StadiumBorder()
          ),
          child: Text(isFollowing ? "MENGIKUTI" : "IKUTI", style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      );
    }
  }

  Widget _buildStat(int val, String label) {
    String displayVal = val.toString();
    // Simple formatter k
    if (val >= 1000) {
      double v = val / 1000;
      // Remove decimal if .0
      String s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1); 
      displayVal = "${s}k";
    }

    return Column(
      children: [
        Text(
          displayVal,
          style: GoogleFonts.outfit(
            fontSize: 24, 
            fontWeight: FontWeight.w900, // Black/Extrabold
            color: Colors.black
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14, 
            color: Colors.black, // Dark text
            fontWeight: FontWeight.w600 // Semibold
          ),
        ),
      ],
    );
  }
}
