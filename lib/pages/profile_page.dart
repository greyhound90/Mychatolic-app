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
  bool _isLoading = false; // False by default to rely on dummy data or immediate check
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
    
    // -----------------------------------------------------------------------
    // CRITICAL: DUMMY DATA INITIALIZATION
    // -----------------------------------------------------------------------
    _initializeDummyData();
    
    _checkIsMe();
    
    // Fetch Real Data (Silent update)
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

  void _initializeDummyData() {
    // Initial dummy data to render UI immediately
    _profile = Profile(
      id: 'dummy_user',
      fullName: 'Gabriella Wulandari',
      bio: 'Pencinta seni, musik liturgi, dan traveling. Berbagi momen iman setiap hari. 🕊️',
      userRole: UserRole.umat,
      accountStatus: AccountStatus.verified_catholic,
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=300&auto=format&fit=crop',
      parish: 'Katedral Jakarta',
      diocese: 'Keuskupan Agung Jakarta',
      country: 'Indonesia',
       ministryCount: 2,
    );

    _stats = {'followers': 1250, 'following': 340, 'posts': 48};
    _isMe = true; 

    // Dummy Photos for immediate visual feedback
    _photoPosts = List.generate(6, (index) {
       return UserPost(
         id: 'post_$index',
         userId: 'dummy_user',
         userName: 'Gabriella',
         userFullName: 'Gabriella Wulandari',
         userAvatar: _profile!.avatarUrl!,
         caption: 'Momen indah di gereja hari ini.',
         imageUrls: ['https://images.unsplash.com/photo-1543791959-8b61074e8979?q=80&w=${800+index}&auto=format&fit=crop'],
         likesCount: 50 + index * 2,
         commentsCount: 5,
         createdAt: DateTime.now().subtract(Duration(days: index)),
       );
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
    // Note: We do NOT set _isLoading=true here to preserve dummy UI
    
    try {
      final targetUserId = widget.userId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

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
           // If error persists from somewhere else, clear it
          _error = null;
        });
      }

      _loadInitialPosts(targetUserId);
    } catch (e) {
      debugPrint("Error loading profile: $e");
      // Don't set state error to avoid showing error screen if dummy data exists
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
    const primaryBlue = Color(0xFF0088CC);
    const bgColor = Color(0xFFF5F5F5);

    // -----------------------------------------------------------------------
    // CRITICAL FIX 1: STRICT NULL CHECK
    // -----------------------------------------------------------------------
    // This prevents "Null check operator used on a null value" 
    // down the tree if data is not ready.
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: const Text("Error")),
        body: Center(child: Text(_error ?? "Unknown Error")),
      );
    }

    // Safe to unwrap
    final displayProfile = _profile!;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              floating: false,
              pinned: true,
              stretch: true,
              backgroundColor: primaryBlue,
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
                      "https://images.unsplash.com/photo-1437603568260-1950d3ca6eab?q=80&w=2000&auto=format&fit=crop", 
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black26],
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
                  indicatorColor: primaryBlue,
                  labelColor: primaryBlue,
                  unselectedLabelColor: Colors.grey,
                  indicatorWeight: 3,
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded), text: "Foto"),
                    Tab(icon: Icon(Icons.list_rounded), text: "Status"),
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
              child: Center(child: CircularProgressIndicator()),
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
              child: Center(child: CircularProgressIndicator()));
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
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // CRITICAL FIX 2: Cannot provide both color and decoration
    // Moved color inside BoxDecoration
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
    const primaryBlue = Color(0xFF0088CC);
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
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(width: 110), 
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             profile.fullName ?? "Umat",
                             style: GoogleFonts.outfit(
                               fontSize: 22, 
                               fontWeight: FontWeight.bold,
                               height: 1.2
                             ),
                           ),
                           const SizedBox(height: 8),
                           Text(
                             "Biografi",
                             style: GoogleFonts.outfit(
                               fontSize: 14,
                               fontWeight: FontWeight.bold,
                               color: Colors.grey[800],
                             ),
                           ),
                         ],
                       )
                     )
                   ],
                 ),
                 
                 const SizedBox(height: 8),
                 
                 Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(
                                profile.bio ?? "-",
                                style: GoogleFonts.outfit(
                                  fontSize: 14, color: Colors.grey[600],
                                  height: 1.4
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStat(stats['posts'].toString(), "Post"),
                                  _buildStat(stats['followers'].toString(), "Followers"),
                                  _buildStat(stats['following'].toString(), "Following"),
                                ],
                              )
                          ],
                        ),
                      )
                   ],
                 ),
                 
                 const SizedBox(height: 24),
                 
                 Row(
                   children: [
                     Expanded(
                       flex: 4,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Row(
                              children: [
                                const Icon(Icons.church, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    (profile.parish ?? "Paroki -").toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                           const SizedBox(height: 4),
                           Text(
                             "${profile.diocese ?? '-'}, ${profile.country ?? 'Indonesia'}",
                             style: GoogleFonts.outfit(
                               fontSize: 11, color: Colors.grey[500]
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(width: 12),
                     Expanded(
                       flex: 5,
                       child: _buildActionButton(primaryBlue),
                     )
                   ],
                 )
              ],
            ),
          ),
        ),
        
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
        
        Positioned(
          top: -20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(50),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0,2))
              ]
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  "100% KATOLIK",
                  style: GoogleFonts.outfit(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
  
  Widget _buildActionButton(Color primaryColor) {
    if (isMe) {
      return SizedBox(
        height: 45,
        child: ElevatedButton(
          onPressed: onEditTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder()
          ),
          child: Text("EDIT PROFIL", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      return SizedBox(
        height: 45,
        child: ElevatedButton(
          onPressed: onFollowToggle,
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[300] : primaryColor,
            foregroundColor: isFollowing ? Colors.black87 : Colors.white,
            elevation: 0,
            shape: const StadiumBorder()
          ),
          child: Text(isFollowing ? "MENGIKUTI" : "IKUTI", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      );
    }
  }

  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
