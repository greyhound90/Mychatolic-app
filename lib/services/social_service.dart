import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/models/comment.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:flutter/foundation.dart';

class SocialService {
  final _supabase = Supabase.instance.client;

  // --- REAL-TIME POST STREAM (EVENT BUS) ---
  static final StreamController<UserPost> _postStream =
      StreamController.broadcast();
  static Stream<UserPost> get postUpdateStream => _postStream.stream;

  static void broadcastPostUpdate(UserPost post) {
    if (!_postStream.isClosed) {
      _postStream.add(post);
    }
  }

  // Helper
  User? get currentUser => _supabase.auth.currentUser;

  // 1. Fetch Single Post by ID
  Future<UserPost?> fetchPostById(String postId) async {
    final userId = _supabase.auth.currentUser?.id;
    try {
      // 1. Fetch Post Data
      final postData = await _supabase
          .from('posts')
          .select()
          .eq('id', postId)
          .single();

      // 2. Fetch Author Profile
      final authorId = postData['user_id'];
      final authorData = await _supabase
          .from('profiles')
          .select()
          .eq('id', authorId)
          .single();
      // 3. Fetch Counts & Status
      final likesCount = await _supabase
          .from('post_likes')
          .count()
          .eq('post_id', postId);
      final commentsCount = await _supabase
          .from('post_comments')
          .count()
          .eq('post_id', postId);

      bool isLiked = false;
      if (userId != null) {
        final likeCheck = await _supabase
            .from('post_likes')
            .select('id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();
        isLiked = likeCheck != null;
      }

      return UserPost(
        id: postData['id'].toString(),
        userId: authorId?.toString() ?? '',
        userName: authorData['username'] ?? 'User',
        userAvatar: authorData['avatar_url'] ?? '',
        userFullName: authorData['full_name'] ?? 'Umat',
        caption: postData['caption'],
        imageUrls: postData['image_url'] != null
            ? [postData['image_url'].toString()]
            : [],
        createdAt:
            DateTime.tryParse(postData['created_at']?.toString() ?? '') ??
            DateTime.now(),
        likesCount: (likesCount as num?)?.toInt() ?? 0,
        commentsCount: (commentsCount as num?)?.toInt() ?? 0,
        isLiked: isLiked,
      );
    } catch (e) {
      debugPrint("Error fetching single post: $e");
      return null;
    }
  }

  // 2. Fetch Posts (Optimized & Paginated)
  Future<List<UserPost>> fetchPosts({
    int page = 0,
    int limit = 10,
    String? filterType, // 'diocese', 'church', 'country', 'user'
    String? filterId,
    String? userId, // Backward compatibility
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final int from = page * limit;
    final int to = from + limit - 1;

    // Handle backward compatibility: if userId is passed, treat it as a user filter
    if (userId != null) {
      filterType = 'user';
      filterId = userId;
    }

    try {
      // 1. Build Query
      // PostgrestFilterBuilder
      var query = _supabase
          .from('posts')
          .select('*, profiles(full_name, avatar_url, role)');

      // 2. Apply Filters (STILL on FilterBuilder)
      if (filterType != null && filterId != null) {
        if (filterType == 'user') {
          query = query.eq('user_id', filterId);
        } else if (filterType == 'diocese') {
          query = query.eq('diocese_id', filterId);
        } else if (filterType == 'church') {
          query = query.eq('church_id', filterId);
        }
      }

      // 3. Apply Modifiers (Order & Range) -> PostgrestTransformBuilder
      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);

      final List<dynamic> postsData = response as List<dynamic>;

      // 4. Optimized "Is Liked" Check (Batch)
      Set<String> likedPostIds = {};
      if (currentUserId != null && postsData.isNotEmpty) {
        final postIds = postsData.map((p) => p['id']).toList();
        final likesResponse = await _supabase
            .from('likes')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);

        likedPostIds = (likesResponse as List)
            .map((l) => l['post_id'].toString())
            .toSet();
      }

      // 5. Map to UserPost Model
      return postsData
          .map((json) {
            final profile = json['profiles'] ?? {};
            final String uName = profile['username'] ?? 'user';
            final String uAvatar = profile['avatar_url'] ?? '';
            final String uFull = profile['full_name'] ?? 'Umat';

            // Image Logic
            List<String> imgs = [];
            if (json['image_url'] != null) {
              if (json['image_url'] is List) {
                imgs = List<String>.from(json['image_url']);
              } else {
                final str = json['image_url'].toString();
                if (str.isNotEmpty) imgs.add(str);
              }
            }

            return UserPost(
              id: json['id'].toString(),
              userId: json['user_id']?.toString() ?? '',
              userName: uName,
              userAvatar: uAvatar,
              userFullName: uFull,
              caption: json['caption'] ?? '',
              imageUrls: imgs,
              createdAt: DateTime.parse(json['created_at']),
              likesCount: json['likes_count'] ?? 0,
              commentsCount: json['comments_count'] ?? 0,
              isLiked: likedPostIds.contains(json['id']),
            );
          })
          .toList()
          .cast<UserPost>();
    } catch (e) {
      debugPrint("Error fetching posts: $e");
      return [];
    }
  }

  // 3. Create Post
  Future<void> createPost({
    required String content,
    String? imageUrl,
    required String type,
    String? countryId,
    String? dioceseId,
    String? churchId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').insert({
        'user_id': user.id,
        'caption': content,
        'image_url': imageUrl,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
        'country_id': countryId,
        'diocese_id': dioceseId,
        'church_id': churchId,
      });
    } catch (e) {
      throw Exception("Post creation failed: $e");
    }
  }

  // 4. Upload Post Image
  Future<String> uploadPostImage(File image) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final fileExt = image.path.split('.').last;
    final fileName =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    try {
      await _supabase.storage
          .from('post_images')
          .upload(
            fileName,
            image,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      return _supabase.storage.from('post_images').getPublicUrl(fileName);
    } catch (e) {
      throw Exception("Image upload failed: $e");
    }
  }

  // 5. Toggle Like (Optimized)
  Future<bool> toggleLike(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      // 1. Check if liked (Low cost index scan)
      final existingLike = await _supabase
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike -> Trigger will verify decrement
        await _supabase.from('likes').delete().eq('id', existingLike['id']);
        return false;
      } else {
        // Like -> Trigger will verify increment
        await _supabase.from('likes').insert({
          'post_id': postId,
          'user_id': user.id,
        });
        return true;
      }
    } catch (e) {
      debugPrint("Error toggling like: $e");
      return false;
    }
  }

  // 6. Fetch Comments
  Future<List<Comment>> fetchComments(String postId) async {
    final currentUser = _supabase.auth.currentUser;

    try {
      final response = await _supabase
          .from('post_comments')
          .select('*, profiles(*), comment_likes(user_id)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      final data = response as List<dynamic>;

      final List<Comment> allComments = [];
      for (var json in data) {
        try {
          final likesList = json['comment_likes'] as List<dynamic>? ?? [];
          final isLiked =
              currentUser != null &&
              likesList.any((l) => l['user_id'] == currentUser.id);

          final map = Map<String, dynamic>.from(json);
          map['likes_count'] = likesList.length;
          map['is_liked_by_me'] = isLiked;

          final comment = Comment.fromJson(map);
          allComments.add(comment);
        } catch (e) {
          debugPrint("Error parsing comment: $e");
        }
      }

      final Map<String, List<Comment>> childrenMap = {};
      for (var c in allComments) {
        if (c.parentId != null) {
          if (!childrenMap.containsKey(c.parentId!)) {
            childrenMap[c.parentId!] = [];
          }
          childrenMap[c.parentId!]!.add(c);
        }
      }

      Comment buildTree(Comment c) {
        final children = childrenMap[c.id] ?? [];
        return Comment(
          id: c.id,
          userId: c.userId,
          content: c.content,
          createdAt: c.createdAt,
          author: c.author,
          parentId: c.parentId,
          replies: children.map((child) => buildTree(child)).toList(),
          likesCount: c.likesCount,
          isLikedByMe: c.isLikedByMe,
        );
      }

      final List<Comment> rootComments = [];
      for (var c in allComments) {
        if (c.parentId == null) {
          rootComments.add(buildTree(c));
        }
      }
      return rootComments;
    } catch (e, stack) {
      debugPrint("Failed to fetch comments: $e");
      debugPrint(stack.toString());
      return [];
    }
  }

  // 7. Add Comment
  Future<void> addComment(
    String postId,
    String content, {
    String? parentId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
        'parent_id': parentId,
      });
    } catch (e) {
      throw Exception("Failed to add comment: $e");
    }
  }

  // 8. Toggle Comment Like
  Future<bool> toggleCommentLike(String commentId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final check = await _supabase
          .from('comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (check != null) {
        await _supabase.from('comment_likes').delete().eq('id', check['id']);
        return false;
      } else {
        await _supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': user.id,
        });
        return true;
      }
    } catch (e) {
      throw Exception("Like comment failed: $e");
    }
  }

  // 9. Report Comment
  Future<void> reportComment(String commentId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Not logged in");

    try {
      await _supabase.from('comment_reports').insert({
        'comment_id': commentId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Report comment failed: $e");
    }
  }

  // 10. Report Post
  Future<void> reportPost(String postId, String reason) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('post_reports').insert({
        'post_id': postId,
        'reporter_id': user.id,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception("Report failed: $e");
    }
  }

  // 11. Delete Post
  Future<void> deletePost(String postId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      await _supabase.from('posts').delete().eq('id', postId);
    } catch (e) {
      throw Exception("Delete failed: $e");
    }
  }

  // 12. Search Users (Advanced)
  Future<List<Profile>> searchUsersAdvanced({
    String? query,
    String? countryId,
    String? dioceseId,
    String? churchId,
  }) async {
    try {
      var dbQuery = _supabase.from('profiles').select();

      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('full_name', '%$query%');
      }
      if (countryId != null) {
        dbQuery = dbQuery.eq('country_id', countryId);
      }
      if (dioceseId != null) {
        dbQuery = dbQuery.eq('diocese_id', dioceseId);
      }
      if (churchId != null) {
        dbQuery = dbQuery.eq('church_id', churchId);
      }

      final response = await dbQuery.limit(20);
      final data = response as List<dynamic>;

      return data.map((json) => Profile.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error searching users: $e");
      return [];
    }
  }
}
