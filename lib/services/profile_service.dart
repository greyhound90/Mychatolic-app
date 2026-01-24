import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fetch User Profile with Stats
  Future<Map<String, dynamic>> fetchUserProfile(String userId) async {
    try {
      // Fetch Explicit Columns (No Join, Flat Data)
      final response = await _supabase
          .from('profiles')
          .select('''
            id, 
            full_name, 
            bio, 
            role, 
            user_role,
            account_status,
            avatar_url, 
            country, 
            diocese, 
            parish, 
            ethnicity, 
            birth_date, 
            is_age_visible, 
            is_ethnicity_visible, 
            verification_status, 
            followers_count, 
            following_count
          ''')
          .eq('id', userId)
          .single();

      // Safe Extract Profile
      final profile = Profile.fromJson(response);

      // Safe Extract Stats (Nullable Integers)
      int followers = (response['followers_count'] as num?)?.toInt() ?? 0;
      int following = (response['following_count'] as num?)?.toInt() ?? 0;

      // Posts count is handled locally by counting fetched posts in ProfilePage
      // or we return 0 here.
      Map<String, int> stats = {
        'followers': followers,
        'following': following,
        'posts': 0,
      };

      return {'profile': profile, 'stats': stats};
    } catch (e) {
      throw Exception('Gagal mengambil data profil: ${e.toString()}');
    }
  }

  // 2. Check if Current User follows Target User (Legacy naming)
  Future<bool> checkIsFollowing(String targetUserId) async {
    return isFollowing(targetUserId);
  }

  // 2b. Check if Current User follows Target User (New standard)
  Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return false;

    try {
      final response = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // 3. Follow User
  Future<void> followUser(String targetUserId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User belum login");

    try {
      // Parallel Execution: Insert Follow & Insert Notification
      await Future.wait([
        _supabase.from('follows').insert({
          'follower_id': currentUser.id,
          'following_id': targetUserId,
        }),
        _supabase.from('notifications').insert({
          'user_id': targetUserId, // Receiver
          'actor_id': currentUser.id, // Sender
          'type': 'follow',
          'title': 'Pengikut Baru',
          'body': 'mulai mengikuti Anda.',
          'related_id': currentUser.id,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        }),
      ]);
    } catch (e) {
      if (e.toString().contains('duplicate key')) return;
      throw Exception('Gagal follow user: ${e.toString()}');
    }
  }

  // 4. Unfollow User
  Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User belum login");

    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_id', currentUser.id)
          .eq('following_id', targetUserId);
    } catch (e) {
      throw Exception('Gagal unfollow user: ${e.toString()}');
    }
  }

  // 16. Report User
  Future<void> reportUser(
    String targetUserId,
    String reason,
    String description,
  ) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User belum login");

    try {
      await _supabase.from('user_reports').insert({
        'reporter_id': currentUser.id,
        'reported_id': targetUserId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Gagal mengirim laporan: $e");
    }
  }

  // 5. Fetch User Posts
  Future<List<UserPost>> fetchUserPosts(String userId) async {
    try {
      final response = await _supabase
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((json) => UserPost.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // 6. Search Users (Advanced)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = _supabase.auth.currentUser;
    if (user == null || query.isEmpty) return [];

    try {
      final response = await _supabase.rpc(
        'search_profiles_advanced',
        params: {
          'search_term': query, // Ensure SQL param name matches
          'current_user_id': user.id, // Ensure SQL param name matches
        },
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Search users failed: $e");
      return [];
    }
  }
}
