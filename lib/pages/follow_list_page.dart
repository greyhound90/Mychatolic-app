import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class FollowListPage extends StatefulWidget {
  final String targetUserId;
  final bool isFollowersList; // true = Followers, false = Following

  const FollowListPage({
    super.key,
    required this.targetUserId,
    required this.isFollowersList,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _userList = [];
  Set<String> _myFollowingIds = {}; // IDs that the CURRENT user follows
  String? _currentUserId;

  // --- DESIGN SYSTEM CONSTANTS (Kulikeun Premium) ---
  static const Color bgNavy = Color(0xFF0B1121);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFF94A3B8);
  static const Color glassBorder = Colors.white12;
  static const Color cardGlass = Color(0x0DFFFFFF); // ~5% opacity

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentIndigo, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id;
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch the relevant IDs (Followers or Following of targetUser)
      List<dynamic> relationData;
      List<String> relatedUserIds = [];

      if (widget.isFollowersList) {
        // Who follows targetUserId?
        relationData = await _supabase
            .from('follows')
            .select('follower_id')
            .eq('following_id', widget.targetUserId);
        
        relatedUserIds = relationData.map((e) => e['follower_id'] as String).toList();
      } else {
        // Who does targetUserId follow?
        relationData = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', widget.targetUserId);
            
        relatedUserIds = relationData.map((e) => e['following_id'] as String).toList();
      }

      if (relatedUserIds.isEmpty) {
        setState(() {
          _userList = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch Profile Details for those IDs
      final profilesData = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, role') 
          .inFilter('id', relatedUserIds);

      // 3. Check which of THESE users *I* (CurrentUser) am following
      if (_currentUserId != null) {
        final myFollowsData = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', _currentUserId!)
            .inFilter('following_id', relatedUserIds);
            
        _myFollowingIds = myFollowsData.map((e) => e['following_id'] as String).toSet();
      }

      setState(() {
        _userList = List<Map<String, dynamic>>.from(profilesData);
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("Error fetching follow list: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error load: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String userId) async {
    if (_currentUserId == null) return;
    if (userId == _currentUserId) return; // Cannot follow self

    final isFollowing = _myFollowingIds.contains(userId);

    // Optimistic UI Update
    setState(() {
      if (isFollowing) {
        _myFollowingIds.remove(userId);
      } else {
        _myFollowingIds.add(userId);
      }
    });

    try {
      if (isFollowing) {
        // Unfollow
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', _currentUserId!)
            .eq('following_id', userId);
      } else {
        // Follow
        await _supabase.from('follows').insert({
          'follower_id': _currentUserId,
          'following_id': userId,
          'created_at': DateTime.now().toIso8601String()
        });
      }
    } catch (e) {
      // Revert if error
      setState(() {
        if (isFollowing) {
          _myFollowingIds.add(userId);
        } else {
          _myFollowingIds.remove(userId);
        }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal update follow: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFollowersList ? "Pengikut" : "Mengikuti";

    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold)),
        backgroundColor: bgNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: glassBorder, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentIndigo))
          : _userList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _userList.length,
                  itemBuilder: (context, index) {
                    final user = _userList[index];
                    return _buildUserItem(user);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isFollowersList ? Icons.group_off_outlined : Icons.person_off_outlined,
            color: Colors.white24, 
            size: 64
          ),
          const SizedBox(height: 16),
          Text(
            widget.isFollowersList ? "Belum ada pengikut" : "Belum mengikuti siapapun",
            style: GoogleFonts.outfit(color: textGrey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final String userId = user['id'];
    final String fullName = user['full_name'] ?? "User";
    final String? avatarUrl = user['avatar_url'];
    
    final bool isMe = userId == _currentUserId;
    final bool amIFollowing = _myFollowingIds.contains(userId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardGlass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder),
      ),
      child: Row(
        children: [
          // 1. Avatar
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: bgNavy,
              child: SafeNetworkImage(
                imageUrl: avatarUrl,
                width: 40, height: 40,
                borderRadius: BorderRadius.circular(20),
                fit: BoxFit.cover,
                fallbackIcon: Icons.person,
                iconColor: Colors.white54,
                fallbackColor: bgNavy,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // 2. Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName, 
                  style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "User", 
                  style: GoogleFonts.outfit(color: textGrey, fontSize: 12),
                ), 
              ],
            ),
          ),

          // 3. Action Button
          if (!isMe)
            SizedBox(
              height: 32,
              child: amIFollowing
                ? OutlinedButton(
                    onPressed: () => _toggleFollow(userId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: textWhite,
                    ),
                    child: Text("Following", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _toggleFollow(userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text("Follow", style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textWhite)),
                    ),
                  ),
            )
        ],
      ),
    );
  }
}
