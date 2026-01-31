
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/comment.dart'; // IMPORT ADDED
import 'package:image_picker/image_picker.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // STREAM POST Realtime Updates
  // Allows checking likes/comments count instantly
  Stream<Map<String, dynamic>> streamPost(String postId) {
    return _supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('id', postId)
        .map((event) => event.isNotEmpty ? event.first : {});
  }

  // STREAM COMMENTS
  // Allows realtime chat-like experience
  Stream<List<Map<String, dynamic>>> streamComments(String postId) {
    return _supabase
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true);
  }

  // 1. Create Post
  Future<void> createPost({
    required String caption, 
    File? imageFile,
    required String type, // 'photo' or 'text'
  }) async {
     final user = _supabase.auth.currentUser;
     if (user == null) throw Exception("User belum login");

     try {
       String? imageUrl;
       
       if (imageFile != null) {
          final fileExt = imageFile.path.split('.').last;
          final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          final path = fileName;
          
          await _supabase.storage.from('posts').upload(path, imageFile,
             fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
             
          imageUrl = _supabase.storage.from('posts').getPublicUrl(path);
       }

       await _supabase.from('posts').insert({
         'user_id': user.id,
         'caption': caption,
         'image_url': imageUrl,
         'type': type,
         'created_at': DateTime.now().toIso8601String(),
         'likes_count': 0,
         'comments_count': 0,
       });

     } catch (e) {
       throw Exception("Gagal membuat postingan: $e");
     }
  }

  // 1. Fetch Photo Posts (Global Feed) - Paginated
  Future<List<UserPost>> fetchPhotoPostsPaged({required int page, int limit = 10}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final int from = page * limit;
      final int to = from + limit - 1;
      final response = await _supabase
          .from('posts')
          .select('*, profiles(*)')
          .filter('image_url', 'not.is', null) 
          .order('created_at', ascending: false)
          .range(from, to);

      final posts = (response as List).map((e) => UserPost.fromJson(e)).toList();
      
      if (userId != null) {
        return await _enrichPostsWithUserInteraction(posts, userId);
      }
      return posts;
    } catch (e) {
      throw Exception('Gagal memuat foto: $e');
    }
  }

  // Backward-compatible (Default small page)
  Future<List<UserPost>> fetchPhotoPosts() async {
    return fetchPhotoPostsPaged(page: 0, limit: 10);
  }

  // 2. Fetch Text Posts (Global Feed) - Paginated
  Future<List<UserPost>> fetchTextPostsPaged({required int page, int limit = 10}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final int from = page * limit;
      final int to = from + limit - 1;
      final response = await _supabase
          .from('posts')
          .select('*, profiles(*)')
          .filter('image_url', 'is', null) 
          .order('created_at', ascending: false)
          .range(from, to);

      final posts = (response as List).map((e) => UserPost.fromJson(e)).toList();

      if (userId != null) {
        return await _enrichPostsWithUserInteraction(posts, userId);
      }
      return posts;
    } catch (e) {
      throw Exception('Gagal memuat tulisan: $e');
    }
  }

  // Backward-compatible (Default small page)
  Future<List<UserPost>> fetchTextPosts() async {
    return fetchTextPostsPaged(page: 0, limit: 10);
  }
  
  // 3. Fetch User Photo Posts (For Profile - Gallery) - Paginated
  // Logic: has image_url (not null)
  Future<List<UserPost>> fetchUserPhotoPostsPaged(String userId, {required int page, int limit = 12}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final int from = page * limit;
      final int to = from + limit - 1;
      final response = await _supabase
          .from('posts')
          .select('*, profiles(*)')
          .eq('user_id', userId)
          .filter('image_url', 'not.is', null) 
          .order('created_at', ascending: false)
          .range(from, to);

      final posts = (response as List).map((e) => UserPost.fromJson(e)).toList();

      if (currentUserId != null) {
        try {
           return await _enrichPostsWithUserInteraction(posts, currentUserId);
        } catch (e) {
           debugPrint("Enrich failed (ignoring): $e");
           return posts; 
        }
      }
      return posts;
    } catch (e) {
      debugPrint("Error Fetching User Photos: $e");
      return [];
    }
  }

  // Backward-compatible (Default small page)
  Future<List<UserPost>> fetchUserPhotoPosts(String userId) async {
    return fetchUserPhotoPostsPaged(userId, page: 0, limit: 12);
  }

  // 4. Fetch User Text Posts (For Profile - Status) - Paginated
  // Logic: image_url is null
  Future<List<UserPost>> fetchUserTextPostsPaged(String userId, {required int page, int limit = 12}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final int from = page * limit;
      final int to = from + limit - 1;
      final response = await _supabase
          .from('posts')
          .select('*, profiles(*)')
          .eq('user_id', userId)
          .filter('image_url', 'is', null)
          .order('created_at', ascending: false)
          .range(from, to);

      final posts = (response as List).map((e) => UserPost.fromJson(e)).toList();

      if (currentUserId != null) {
        try {
          return await _enrichPostsWithUserInteraction(posts, currentUserId);
        } catch (e) {
          return posts;
        }
      }
      return posts;
    } catch (e) {
       debugPrint("Error Fetching User Text: $e");
      return [];
    }
  }

  // Backward-compatible (Default small page)
  Future<List<UserPost>> fetchUserTextPosts(String userId) async {
    return fetchUserTextPostsPaged(userId, page: 0, limit: 12);
  }

  // 5. Fetch Saved Posts (Only for Current User) - Paginated
  Future<List<UserPost>> fetchSavedPostsPaged({required int page, int limit = 10}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];
      final int from = page * limit;
      final int to = from + limit - 1;

      final response = await _supabase
          .from('saved_posts')
          .select('*, posts:post_id(*, profiles(*))')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      List<UserPost> posts = [];
      for (var item in (response as List)) {
        if (item['posts'] != null) {
          final postJson = item['posts'];
          postJson['is_saved'] = true; 
          posts.add(UserPost.fromJson(postJson));
        }
      }
      
      return await _enrichPostsWithUserInteraction(posts, userId, checkSaved: false);
    } catch (e) {
      debugPrint("Error Fetching Saved: $e");
      return [];
    }
  }

  // Backward-compatible (Default small page)
  Future<List<UserPost>> fetchSavedPosts() async {
    return fetchSavedPostsPaged(page: 0, limit: 10);
  }

  // Helper
  Future<List<UserPost>> _enrichPostsWithUserInteraction(List<UserPost> posts, String userId, {bool checkSaved = true}) async {
     if (posts.isEmpty) return [];
     
     final postIds = posts.map((p) => p.id).toList();

     final likedResponse = await _supabase
         .from('likes')
         .select('post_id')
         .eq('user_id', userId)
         .filter('post_id', 'in', postIds);
     
     final likedPostIds = (likedResponse as List).map((e) => e['post_id'].toString()).toSet();

     Set<String> savedPostIds = {};
     if (checkSaved) {
       final savedResponse = await _supabase
           .from('saved_posts')
           .select('post_id')
           .eq('user_id', userId)
           .filter('post_id', 'in', postIds);
        savedPostIds = (savedResponse as List).map((e) => e['post_id'].toString()).toSet();
     }

     return posts.map((p) {
       return p.copyWith(
         isLiked: likedPostIds.contains(p.id),
         isSaved: checkSaved ? savedPostIds.contains(p.id) : p.isSaved,
       );
     }).toList();
  }

  // 6. Toggle Save Post
  Future<void> toggleSavePost(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");

    try {
      final existing = await _supabase
          .from('saved_posts')
          .select('id')
          .match({'user_id': userId, 'post_id': postId})
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('saved_posts').delete().eq('id', existing['id']);
      } else {
        await _supabase.from('saved_posts').insert({
          'user_id': userId,
          'post_id': postId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception("Gagal menyimpan postingan: $e");
    }
  }
  
  // Toggle Like with manual count update fallback
  Future<void> toggleLike(String postId) async {
     final userId = _supabase.auth.currentUser?.id;
     if (userId == null) throw Exception("User belum login");
     
     try {
       final existing = await _supabase
          .from('likes')
          .select('id')
          .match({'user_id': userId, 'post_id': postId})
          .maybeSingle();
       
       if (existing != null) {
         await _supabase.from('likes').delete().eq('id', existing['id']);
       } else {
         await _supabase.from('likes').insert({
           'user_id': userId,
           'post_id': postId,
           'created_at': DateTime.now().toIso8601String(),
         });
       }

       // Manual Update Count
       final countResponse = await _supabase
           .from('likes')
           .count(CountOption.exact)
           .eq('post_id', postId);
       
       await _supabase.from('posts').update({'likes_count': countResponse}).eq('id', postId);

     } catch (e) {
       throw Exception("Gagal like: $e");
     }
  }

  // 7. Add Comment (RPC Atomic) - returns the new Comment object
  Future<Comment> addComment(String postId, String content, {String? parentId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    
    try {
      // RPC should strictly return a single JSON object representing the inserted row
      // Make sure your backend RPC 'add_comment_v2' returns `setof comments_with_profiles` or similar.
      final response = await _supabase.rpc('add_comment_v2', params: {
        'p_post_id': postId,
        'p_content': content,
        'p_parent_id': parentId, // Pass as UUID String or null
      });
      
      // If RPC returns list, take first. If object, take it.
      final data = (response is List && response.isNotEmpty) ? response.first : response;
      
      return Comment.fromJson(Map<String, dynamic>.from(data));
      
    } catch (e) {
      debugPrint("Add comment error: $e");
      throw Exception("Gagal mengirim komentar: $e");
    }
  }

  // 11. Delete Comment (RPC Atomic)
  Future<void> deleteComment(String commentId, String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");

    try {
      await _supabase.rpc('delete_comment_v2', params: {
        'p_comment_id': commentId,
        'p_post_id': postId,
      });
    } catch (e) {
      debugPrint("Delete comment error: $e");
      throw Exception("Gagal menghapus komentar.");
    }
  }

  // 12. Report Comment
  Future<void> reportComment(String commentId, String reason) async {
     final userId = _supabase.auth.currentUser?.id;
     if (userId == null) throw Exception("User belum login");

     try {
       await _supabase.from('comment_reports').insert({
         'reporter_id': userId,
         'comment_id': commentId,
         'reason': reason,
         'created_at': DateTime.now().toIso8601String(),
       });
     } catch (e) {
       debugPrint("Report comment error: $e");
       throw Exception("Gagal melaporkan komentar.");
     }
  }

  // New: Get Comments from VIEW
  Future<List<Comment>> getComments(String postId) async {
    try {
      final response = await _supabase
          .from('comments_with_profiles') // Queries the VIEW
          .select()
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List).map((e) => Comment.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Get Comments Error: $e");
      return [];
    }
  }

  // 8. Delete Post
  Future<void> deletePost(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");

    try {
      await _supabase.from('posts').delete().eq('id', postId).eq('user_id', userId);
    } catch (e) {
      throw Exception("Gagal menghapus postingan: $e");
    }
  }

  // 9. Edit Post
  Future<void> editPost(String postId, String newCaption) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");

    try {
      await _supabase.from('posts').update({'caption': newCaption}).eq('id', postId).eq('user_id', userId);
    } catch (e) {
      throw Exception("Gagal mengedit postingan: $e");
    }
  }

  // 10. Report Post
  Future<void> reportPost(String postId, String reason) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");

    try {
      await _supabase.from('reports').insert({
        'post_id': postId,
        'reporter_id': userId,
        'reason': reason,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Gagal melaporkan postingan: $e");
    }
  }
}
