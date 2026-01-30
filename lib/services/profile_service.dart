
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Fetch User Profile with Stats
  Future<Profile> fetchUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select(
            '*, countries:country_id(name), dioceses:diocese_id(name), churches:church_id(name)',
          )
          .eq('id', userId)
          .order('updated_at', ascending: false)
          .single();

      final data = Map<String, dynamic>.from(response);

      debugPrint("=== AUDIT PROFIL ===");
      debugPrint("NAMA BAPTIS DB: ${data['baptism_name']}");
      debugPrint("ID NEGARA: ${data['country_id']}");
      debugPrint("DATA JOIN NEGARA: ${data['countries']}");
      debugPrint("DATA JOIN GEREJA: ${data['churches']}");
      debugPrint("====================");

      // Manual Flattening / Safety Check for Nested JSON
      // This ensures we prioritize the Relation Data if available, matching user request.
      if (data['countries'] != null && data['countries'] is Map) {
         data['country'] = data['countries']['name'] ?? data['country'];
      }
      if (data['dioceses'] != null && data['dioceses'] is Map) {
         data['diocese'] = data['dioceses']['name'] ?? data['diocese'];
      }
      if (data['churches'] != null && data['churches'] is Map) {
         data['parish'] = data['churches']['name'] ?? data['parish'];
      }

      return Profile.fromJson(data);
    } catch (e) {
      debugPrint("Fetch User Profile Error: $e");
      throw Exception('Gagal mengambil data profil: ${e.toString()}');
    }
  }

  // 1b. Update Profile
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? baptismName,
    String? bio,
    String? country,
    String? diocese,
    String? parish,
    String? countryId,
    String? dioceseId,
    String? churchId,
    String? ethnicity,
    bool? showAge,
    bool? showEthnicity,
    String? avatarUrl,
    String? bannerUrl,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final updatePayload = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        if (fullName != null) 'full_name': fullName,
        if (baptismName != null) 'baptism_name': baptismName,
        if (bio != null) 'bio': bio,
        if (country != null) 'country': country,
        if (diocese != null) 'diocese': diocese,
        if (parish != null) 'parish': parish,
        if (countryId != null) 'country_id': countryId,
        if (dioceseId != null) 'diocese_id': dioceseId,
        if (churchId != null) 'church_id': churchId,
        if (ethnicity != null) 'ethnicity': ethnicity,
        if (showAge != null) 'is_age_visible': showAge,
        if (showEthnicity != null) 'is_ethnicity_visible': showEthnicity,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bannerUrl != null) 'banner_url': bannerUrl,
      };

      if (updates != null && updates.isNotEmpty) {
        updatePayload.addAll(updates);
      }

      await _supabase.from('profiles').update(updatePayload).eq('id', userId);
    } catch (e) {
      throw Exception("Gagal update profile: $e");
    }
  }

  // 1c. Upload Avatar (returns public URL and updates DB)
  Future<String> uploadAvatar(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    final publicUrl = await _uploadImage(imageFile, 'avatars');
    
    // Update DB
    await _supabase.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    return publicUrl;
  }

  // 1d. Upload Banner (returns public URL and updates DB)
  Future<String> uploadBanner(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    // Use 'banners' bucket if available, else fallback logic could be added.
    // Assuming 'banners' bucket exists or we use 'avatars' bucket with banner prefix.
    // For safety with existing setup, I'll use 'avatars' bucket but with a 'banners/' folder prefix in the path?
    // Supabase storage paths are just strings. 
    // Let's try to use 'property' or 'banners' bucket. 
    // If we want to be safe and use ONE bucket 'avatars':
    final publicUrl = await _uploadImage(imageFile, 'avatars', folderPrefix: 'banners');

    // Update DB
    await _supabase.from('profiles').update({
      'banner_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    return publicUrl;
  }

  Future<String> _uploadImage(File imageFile, String bucketName, {String folderPrefix = ''}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User belum login");

    try {
      final fileExt = imageFile.path.split('.').last;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      // Path: userID/prefix_timestamp.ext
      final fileName = '${folderPrefix.isNotEmpty ? "${folderPrefix}_" : ""}$timeStamp.$fileExt';
      final path = '${user.id}/$fileName';

      await _supabase.storage.from(bucketName).upload(
            path,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final imageUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      return imageUrl;
    } catch (e) {
      debugPrint("Upload Storage Error: $e");
      throw Exception("Gagal upload image ke storage: $e");
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
