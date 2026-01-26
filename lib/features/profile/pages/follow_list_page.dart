
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/features/profile/pages/profile_page.dart';
import 'package:mychatolic_app/widgets/secure_image_loader.dart';

class FollowListPage extends StatefulWidget {
  final String userId;
  final int initialTabIndex; // 0 for followers, 1 for following

  const FollowListPage({
    super.key,
    required this.userId,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> with SingleTickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  final ProfileService _profileService = ProfileService();
  late TabController _tabController;

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  final String _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: widget.initialTabIndex
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _socialService.getFollowers(widget.userId),
        _socialService.getFollowing(widget.userId),
      ]);
      
      if (mounted) {
        setState(() {
          _followers = results[0];
          _following = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowAction(String targetId, bool isUnfollow) async {
    try {
       if (isUnfollow) {
         await _profileService.unfollowUser(targetId);
       } else {
         await _profileService.followUser(targetId);
       }
       // Reload data to reflect changes if viewing own profile
       // Or optimistically update local set? 
       // For simplicity, let's just reload.
       _loadData(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0088CC);
    const bgColor = Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Jaringan",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryColor,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Pengikut"),
            Tab(text: "Mengikuti"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_followers, "Belum ada pengikut"),
                _buildUserList(_following, "Belum mengikuti siapapun"),
              ],
            ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMessage, style: GoogleFonts.outfit(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final isMe = user['id'] == _currentUserId;
        
        // This button logic is simplified. Realistically we need to know:
        // "Do I follow this person?" for each item to show "Follow/Unfollow".
        // Currently getFollowers/getFollowing returns raw profiles.
        // We'd need an extra check 'amIFollowing' for each. 
        // For 'Following' tab (my own), I am definitely following them, so 'Unfollow' is valid.
        // For 'Followers' tab, I might not follow them back.
        
        // MVP: Just show profile for now.
        // Or if viewing MY OWN following list -> Show Unfollow button.
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(userId: user['id']),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                 ClipOval(
                   child: SecureImageLoader(
                     imageUrl: user['avatar_url'] ?? '',
                     width: 50,
                     height: 50,
                     fit: BoxFit.cover,
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(
                          user['full_name'] ?? 'Umat',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (user['role'] != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user['role'].toString().toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                            ),
                          ),
                     ],
                   ),
                 ),
                 // Only show trailing actions if viewing OWN profile logic roughly
                 if (widget.userId == _currentUserId && !isMe)
                   // If tab index 1 (Following) -> Show Unfollow
                   if (_tabController.index == 1)
                     IconButton(
                       icon: const Icon(Icons.person_remove, color: Colors.red),
                       onPressed: () => _handleFollowAction(user['id'], true),
                     )
                   // If tab index 0 (Followers) -> Usually "Remove" logic, or "Follow Back"
                   // Leave empty for now for safety.
              ],
            ),
          ),
        );
      },
    );
  }
}
