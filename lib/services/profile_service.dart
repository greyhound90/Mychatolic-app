
import 'dart:io';
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
            account_status,
            avatar_url, 
            banner_url,
            country, 
            diocese, 
            parish,
            country_id,
            diocese_id,
            church_id, 
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

  // 1b. Update Profile
  Future<void> updateProfile({
    required String fullName,
    String? bio,
    String? country,
    String? diocese,
    String? parish,
    String? countryId,
    String? dioceseId,
    String? churchId,
    String? ethnicity,
    bool showAge = false,
    bool showEthnicity = false,
    String? avatarUrl,
    String? bannerUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    try {
      final updates = {
        'full_name': fullName,
        'bio': bio,
        'country': country, // Keep updating strings for now
        'diocese': diocese,
        'parish': parish,
        'country_id': countryId,
        'diocese_id': dioceseId,
        'church_id': churchId,
        'ethnicity': ethnicity,
        'is_age_visible': showAge,
        'is_ethnicity_visible': showEthnicity,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }
      if (bannerUrl != null) {
        updates['banner_url'] = bannerUrl;
      }

      await _supabase.from('profiles').update(updates).eq('id', user.id);
    } catch (e) {
      throw Exception("Gagal update profile: $e");
    }
  }

  // 1c. Upload Avatar (returns public URL)
  Future<String> uploadAvatar(File imageFile) async {
    return _uploadImage(imageFile, 'avatars');
  }

  // 1d. Upload Banner
  Future<String> uploadBanner(File imageFile) async {
    return _uploadImage(imageFile, 'banners');
  }

  Future<String> _uploadImage(File imageFile, String folder) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = fileName; // Typically storage structure puts it in folder defined by bucket

      // Assuming separate buckets 'avatars' and 'banners' exist
      // OR assuming one bucket 'public-images' with folders?
      // Spec said: bucket 'avatars' or create folder 'banners'.
      // Let's assume bucket name is consistent. If we need a 'banners' bucket, 
      // we might fail if not created. Let's try to use 'verification-docs' pattern or 'avatars'.
      // Safest: Use 'avatars' bucket for banners too if possible or 'common'.
      // Given instructions: "Upload file banner ke Supabase Storage (bucket `avatars` atau buat folder `banners`)."
      // I will use 'avatars' bucket but prefixed/foldered if I could, but 'avatars' bucket usually flat.
      // I'll stick to 'avatars' bucket for simplicity as instructed.

      await _supabase.storage.from('avatars').upload(path, imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false));

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      throw Exception("Gagal upload image: $e");
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
          .from('followers')
          .select('id')
          .match({
            'follower_id': currentUser.id,
            'following_id': targetUserId,
          })
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
      await _supabase.from('followers').insert({
        'follower_id': currentUser.id,
        'following_id': targetUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
        // Ignore duplicate key error safely
       if(e.toString().contains("duplicate")) return;
       throw Exception("Gagal follow: $e");
    }
  }

  // 4. Unfollow User
  Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception("User belum login");

    try {
      await _supabase
          .from('followers')
          .delete()
          .match({
            'follower_id': currentUser.id,
            'following_id': targetUserId,
          });
    } catch (e) {
      throw Exception("Gagal unfollow: $e");
    }
  }

  // 5. Fetch User Posts (Assuming logic)
  Future<List<UserPost>> fetchUserPosts(String userId) async {
      try {
        final response = await _supabase
            .from('posts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        return (response as List).map((e) => UserPost.fromJson(e)).toList();
      } catch (e) {
          // If table doesn't exist yet, return empty list
          return [];
      }
  }

  // 6. Fetch Follow Counts
  Future<Map<String, int>> fetchFollowCounts(String userId) async {
    try {
      final followers = await _supabase
          .from('followers')
          .count(CountOption.exact)
          .eq('following_id', userId);
      
      final following = await _supabase
          .from('followers')
          .count(CountOption.exact)
          .eq('follower_id', userId);
      
      return {
        'followers': followers,
        'following': following,
      };
    } catch (e) {
      return {'followers': 0, 'following': 0};
    }
  }
}
