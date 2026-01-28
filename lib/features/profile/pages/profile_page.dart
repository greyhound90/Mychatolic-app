
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart'; // UserRole, AccountStatus
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/services/post_service.dart'; // New Post Service
import 'package:mychatolic_app/features/radar/pages/create_personal_radar_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/settings/pages/settings_page.dart';
import 'package:mychatolic_app/features/profile/pages/follow_list_page.dart';
import 'package:mychatolic_app/features/feed/widgets/post_card.dart'; // Re-use PostCard
import 'package:mychatolic_app/widgets/secure_image_loader.dart';
import 'package:mychatolic_app/features/feed/pages/post_detail_page.dart';
import 'package:mychatolic_app/pages/chat/chat_page.dart'; // Chat Import

class ProfilePage extends StatefulWidget {
  final String? userId; // Optional, null means "Me"
  final bool isBackButtonEnabled;

  const ProfilePage({
    Key? key,
    this.userId,
    this.isBackButtonEnabled = false,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final ProfileService _profileService = ProfileService();
  final PostService _postService = PostService(); // Use new PostService
  final _supabase = Supabase.instance.client;
 
  late Future<void> _loadDataFuture;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  Profile? _profile;
  Map<String, int> _stats = {'followers': 0, 'following': 0, 'posts': 0};
  
  // Split data
  List<UserPost> _photoPosts = [];
  List<UserPost> _textPosts = [];
  List<UserPost> _savedPosts = []; 
  
  bool _isFollowing = false;
  bool _isMe = false;
  
  String? _countryName;
  String? _dioceseName;
  String? _churchName;

  final Color _primaryColor = const Color(0xFF0088CC);
  final Color _gradientEnd = const Color(0xFF007AB8);
  final Color _bgColor = const Color(0xFFF5F5F5);

  String get _targetUserId {
    return widget.userId ?? _supabase.auth.currentUser?.id ?? '';
  }

  @override
  void initState() {
    super.initState();
    final currentUserId = _supabase.auth.currentUser?.id;
    final target = _targetUserId;
    _isMe = target.isNotEmpty && target == currentUserId;

    // Logic for Tab Length
    // if _isMe: 3 Tabs (Galeri, Status, Disimpan)
    // else: 2 Tabs (Galeri, Status)
    _tabController = TabController(length: _isMe ? 3 : 2, vsync: this);
    
    _loadDataFuture = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final target = _targetUserId;
    if (target.isEmpty) return;

    try {
      // 1. Fetch Profile Data (Critical)
      final profileResponse = await _supabase
          .from('profiles')
          .select('*, countries:country_id(name), dioceses:diocese_id(name), churches:church_id(name)')
          .eq('id', target)
          .single();

      final profile = Profile.fromJson(profileResponse);
      
      final countryData = profileResponse['countries'];
      final dioceseData = profileResponse['dioceses'];
      final churchData = profileResponse['churches'];
      
      String? cName = (countryData != null) ? countryData['name'] : profile.country;
      String? dName = (dioceseData != null) ? dioceseData['name'] : profile.diocese;
      String? chName = (churchData != null) ? churchData['name'] : profile.parish;

      // 2. Fetch Stats
      Map<String, int> stats = {'followers': 0, 'following': 0, 'posts': 0};
      try {
        stats = await _profileService.fetchFollowCounts(target);
      } catch (e) {
        debugPrint("Error stats: $e");
      }

      bool isFollowing = false;
      if (!_isMe) {
        try {
          isFollowing = await _profileService.isFollowing(target);
        } catch (e) { debugPrint("Error isFollowing: $e"); }
      }

      // 3. Update State with Base Info First (Optimization)
      if (mounted) {
         setState(() {
           _profile = profile;
           _countryName = cName;
           _dioceseName = dName;
           _churchName = chName;
           _stats = stats;
           _isFollowing = isFollowing;
         });
      }

      // 4. Fetch Posts independently (non-blocking if one fails)
      
      // A. Photos (Galeri)
      try {
         final photos = await _postService.fetchUserPhotoPosts(target);
         if (mounted) setState(() => _photoPosts = photos);
      } catch (e) {
         debugPrint("Error fetching photos: $e");
      }
      
      // B. Text (Status)
      try {
         final texts = await _postService.fetchUserTextPosts(target);
         if (mounted) setState(() => _textPosts = texts);
      } catch (e) {
         debugPrint("Error fetching texts: $e");
      }

      // C. Saved (Only if Me)
      if (_isMe) {
         try {
            // Verify session before call
            if (_supabase.auth.currentUser?.id == target) {
               final saved = await _postService.fetchSavedPosts();
               if (mounted) setState(() => _savedPosts = saved);
            }
         } catch (e) {
            debugPrint("Error fetching saved: $e");
         }
      }

      // Update total posts count
      if (mounted) {
         setState(() {
            _stats['posts'] = _photoPosts.length + _textPosts.length;
         });
      }

    } catch (e) {
      debugPrint("Critical Error loading profile: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (_isMe) return;
    try {
      if (_isFollowing) {
        await _profileService.unfollowUser(_targetUserId);
        setState(() => _isFollowing = false);
      } else {
        await _profileService.followUser(_targetUserId);
        setState(() => _isFollowing = true);
      }
      final stats = await _profileService.fetchFollowCounts(_targetUserId);
      setState(() => _stats = stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  void _navigateToFollowList(int initialIndex) {
    if (_profile == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListPage(userId: _targetUserId, initialTabIndex: initialIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bannerHeight = 220.0;
    final double whiteContentTopMargin = 180.0; 
    final double avatarRadius = 65.0;
    final double avatarTop = whiteContentTopMargin - avatarRadius; 

    return Scaffold(
      backgroundColor: _bgColor,
      body: FutureBuilder(
        future: _loadDataFuture, // Keeping this, though logic now does incremental setStates
        builder: (context, snapshot) {
           // We can rely on _profile being null or not
           if (_profile == null && snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
           }
           if (_profile == null) {
              return const Center(child: Text("Gagal memuat profil"));
           }

          return Stack(
            children: [
              NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // A. BANNER
                          Container(
                             height: bannerHeight,
                             width: double.infinity,
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                  colors: [_primaryColor, _gradientEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight
                               ), 
                             ),
                             child: _profile?.bannerUrl != null 
                                 ? SecureImageLoader(imageUrl: _profile!.bannerUrl!, fit: BoxFit.cover)
                                 : const Center(child: Icon(Icons.church_outlined, size: 60, color: Colors.white24)),
                           ),
                           
                           // B. BODY CONTENT
                           Column(
                             children: [
                               SizedBox(height: whiteContentTopMargin),
                               Container(
                                 width: double.infinity,
                                 decoration: const BoxDecoration(
                                   color: Color(0xFFF5F5F5), 
                                   borderRadius: BorderRadius.vertical(top: Radius.circular(30))
                                 ),
                                 child: Column(
                                   children: [
                                      const SizedBox(height: 75), 
                                      
                                      // 1. NAME & ROLE
                                      Text(
                                        _profile!.fullName ?? "User",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      if (_profile!.isClergy)
                                        Container(
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            _profile!.roleLabel,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _primaryColor,
                                            ),
                                          ),
                                        ),
                                        
                                      // 2. BIO
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Text(
                                          _profile!.bio ?? "Belum ada bio.",
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            height: 1.4,
                                          ),
                                        ),
                                      ),

                                      // 3. LOCATION INFO
                                      const SizedBox(height: 16),
                                      if (_countryName != null || _churchName != null) 
                                        Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 30),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200)
                                          ),
                                          child: Column(
                                            children: [
                                              if (_countryName != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        "$_countryName${_dioceseName != null ? ', $_dioceseName' : ''}",
                                                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (_churchName != null)
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.church_outlined, size: 16, color: Colors.grey[600]),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        _churchName!,
                                                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
                                                        textAlign: TextAlign.center,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      
                                      const SizedBox(height: 24),
                                      _buildActionButtons(),
                                      const SizedBox(height: 24),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: _buildStatsCard(),
                                      ),
                                      const SizedBox(height: 24),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                           
                           // C. AVATAR
                           Positioned(
                             top: avatarTop, 
                             left: 0,
                             right: 0,
                             child: Center(
                               child: Stack(
                                 children: [
                                   Container(
                                     width: avatarRadius * 2,
                                     height: avatarRadius * 2,
                                     decoration: BoxDecoration(
                                       shape: BoxShape.circle,
                                       border: Border.all(color: Colors.white, width: 4), 
                                       boxShadow: [
                                         BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                         )
                                       ],
                                     ),
                                     child: ClipOval(
                                       child: SecureImageLoader(
                                         imageUrl: _profile?.avatarUrl ?? '',
                                         fit: BoxFit.cover,
                                       ),
                                     ),
                                   ),
                                   if (_profile?.isVerified == true)
                                      Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.verified, color: Colors.blue, size: 24),
                                        ),
                                      ),
                                 ],
                               ),
                             ),
                           ),
                        ],
                      ),
                    ),
                    
                    SliverPersistentHeader(
                      delegate: _StickyTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: _primaryColor,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: _primaryColor,
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                          tabs: [
                            const Tab(text: "GALERI"),
                            const Tab(text: "STATUS"),
                            if (_isMe) const Tab(text: "DISIMPAN"), 
                          ],
                        ),
                        color: _bgColor,
                      ),
                      pinned: true,
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPhotoGrid(),
                    _buildTextList(),
                    if (_isMe) _buildSavedList(), 
                  ],
                ),
              ),

              // Floating Nav
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        widget.isBackButtonEnabled
                            ? CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.3),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              )
                            : const SizedBox.shrink(),
                        
                        _isMe
                            ? CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.3),
                                child: IconButton(
                                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                                  onPressed: () {
                                     Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                                  },
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.black.withValues(alpha: 0.3),
                                child: IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  onPressed: () {},
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helpers
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            offset: const Offset(0, 5),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("Post", _stats['posts'] ?? 0),
          _buildVerticalDivider(),
          InkWell(
            onTap: () => _navigateToFollowList(0),
            child: _buildStatItem("Pengikut", _stats['followers'] ?? 0),
          ),
          _buildVerticalDivider(),
          InkWell(
            onTap: () => _navigateToFollowList(1),
            child: _buildStatItem("Mengikuti", _stats['following'] ?? 0),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    // Jika Profil Saya (Edit & Share)
    if (_isMe) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final reload = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage())
              );
              if (reload == true) _loadData();
            },
            icon: const Icon(Icons.edit, size: 18),
            label: Text("Edit Profil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () { /* Share Logic */ },
            icon: const Icon(Icons.share, size: 18),
            label: Text("Share", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      );
    } 
    
    // Jika Profil Orang Lain (Ikuti, Pesan, Ajak Misa)
    else {
      // Warna Hijau untuk tombol Ajak Misa
      final Color colorGreen = const Color(0xFF2ECC71); 

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Tombol Ikuti
            Expanded(
              child: ElevatedButton(
                onPressed: _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing ? Colors.grey.shade200 : _primaryColor,
                  foregroundColor: _isFollowing ? Colors.black : Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  _isFollowing ? "Mengikuti" : "Ikuti",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            
            const SizedBox(width: 8),

            // 2. Tombol Pesan (Chat)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Unified Chat System: Direct to ChatPage with partnerId
                      // This triggers the auto-redirect logic in ChatPage to open the specific room
                      builder: (_) => ChatPage(partnerId: _targetUserId),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: BorderSide(color: _primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  backgroundColor: Colors.white,
                ),
                child: Text(
                  "Pesan", 
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 3. Tombol Ajak Misa (Fitur Radar)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                   if (_profile != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatePersonalRadarPage(targetUser: _profile!),
                        ),
                      );
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorGreen, 
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text(
                  "Ajak Misa",
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPhotoGrid() {
    if (_photoPosts.isEmpty) { 
       return Center(child: Text("Belum ada foto", style: GoogleFonts.outfit(color: Colors.grey)));
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      itemCount: _photoPosts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        final post = _photoPosts[index];
        final imageUrl = post.imageUrls.isNotEmpty ? post.imageUrls.first : null;
        return GestureDetector(
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailPage(post: post)));
          },
          child: Container(
            color: Colors.grey.shade200,
            child: imageUrl != null 
               ? SecureImageLoader(imageUrl: imageUrl, fit: BoxFit.cover)
               : const Center(child: Icon(Icons.image)),
          ),
        );
      },
    );
  }

  Widget _buildTextList() {
    if (_textPosts.isEmpty) { 
       return Center(child: Text("Belum ada status", style: GoogleFonts.outfit(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, bottom: 20),
      itemCount: _textPosts.length,
      itemBuilder: (context, index) {
         final post = _textPosts[index];
         return PostCard(post: post);
      },
    );
  }

  Widget _buildSavedList() {
    if (_savedPosts.isEmpty) { 
       return Center(child: Text("Belum ada yang disimpan atau akun diprivate", style: GoogleFonts.outfit(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 0, bottom: 20),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
         final post = _savedPosts[index];
         return PostCard(post: post);
      },
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;
  _StickyTabBarDelegate(this.tabBar, {this.color = Colors.white});
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: color, child: tabBar);
  @override double get maxExtent => tabBar.preferredSize.height;
  @override double get minExtent => tabBar.preferredSize.height;
  @override bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
