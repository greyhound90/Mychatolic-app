import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StoryService {
  final _supabase = Supabase.instance.client;

  /// Uploads a new story (Image or Video)
  Future<void> uploadStory({
    required File file,
    required MediaType mediaType,
    String? caption,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final ext = mediaType == MediaType.video ? 'mp4' : 'jpg';
    final fileName = '${user.id}/${const Uuid().v4()}.$ext';

    // 1. Upload File to Storage
    await _supabase.storage.from('stories').upload(
      fileName,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    final mediaUrl = _supabase.storage.from('stories').getPublicUrl(fileName);

    // 2. Insert Metadata to DB
    await _supabase.from('stories').insert({
      'user_id': user.id,
      'media_url': mediaUrl,
      'media_type': mediaType == MediaType.video ? 'video' : 'image',
      'caption': caption,
      // created_at & expires_at handled by DB default (or we could set expires_at here)
    });
  }

  /// Fetches active stories grouped by User
  Future<List<UserStoryGroup>> fetchActiveStories() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Fetch active stories with uploader profile info
      // NOTE: Make sure 'stories' has a foreign key to 'profiles' named 'profiles' or 'user_id'
      final response = await _supabase
          .from('stories')
          .select('*, profiles:user_id(full_name, avatar_url)')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final List<Story> allStories = data.map((json) => Story.fromJson(json)).toList();

      // Group by User ID
      final Map<String, List<Story>> grouped = {};
      for (var story in allStories) {
        if (!grouped.containsKey(story.userId)) {
          grouped[story.userId] = [];
        }
        grouped[story.userId]!.add(story);
      }

      // Convert to List<UserStoryGroup>
      // We prioritize showing stories from others, maybe? Or just fetch list.
      // This simple implementation groups them.
      return grouped.entries.map((entry) {
        final stories = entry.value;
        final first = stories.first; // Use first story to get user info
        
        return UserStoryGroup(
          userId: entry.key,
          userName: first.authorName ?? "Unknown User",
          userAvatar: first.authorAvatar,
          stories: stories,
        );
      }).toList();

    } catch (e) {
      debugPrint("Error fetching stories: $e");
      return [];
    }
  }

  /// Mark story as viewed
  Future<void> viewStory(String storyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': user.id,
        'viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Ignore unique violation (already viewed)
      // Postgres error code 23505 is unique_violation, but Supabase SDK throws PlatformException or PostgrestException
      if (e.toString().contains("duplicate key") || e.toString().contains("23505")) {
        // already viewed, safe to ignore
      } else {
        debugPrint("Error viewing story: $e");
      }
    }
  }
  /// Fetches active stories for a specific user
  Future<List<Story>> fetchUserStories(String userId) async {
    try {
      final response = await _supabase
          .from('stories')
          .select('*, profiles:user_id(full_name, avatar_url)')
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Story.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching user stories: $e");
      return [];
    }
  }

  // --- INTERACTION FEATURES ---

  /// Check if current user has liked a story
  Future<bool> hasLikedStory(String storyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _supabase
          .from('story_likes')
          .select('story_id')
          .eq('story_id', storyId)
          .eq('user_id', user.id)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Like a story
  Future<void> likeStory(String storyId, String ownerId, String? mediaUrl) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Insert Like
      await _supabase.from('story_likes').upsert({
        'story_id': storyId,
        'user_id': user.id,
      });

      // 2. Notify Owner (Optional: Send a "Like" message to DM)
      // Only if not own story
      if (user.id != ownerId) {
        // Find or Create Chat
        final chatId = await _getOrCreateChatId(user.id, ownerId);
        
        // Send "Story Like" Message
        // Special type: story_like. Content: mediaUrl (thumbnail)
        await _supabase.from('social_messages').insert({
          'chat_id': chatId,
          'sender_id': user.id,
          'content': mediaUrl ?? '',
          'type': 'story_like',
        });
        
        // Update summary
        await _supabase.from('social_chats').update({
          'updated_at': DateTime.now().toIso8601String(),
          'last_message': '🔥 Menyukai story',
        }).eq('id', chatId);
      }

    } catch (e) {
      debugPrint("Error liking story: $e");
    }
  }

  /// Unlike a story
  Future<void> unlikeStory(String storyId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('story_likes')
          .delete()
          .eq('story_id', storyId)
          .eq('user_id', user.id);
    } catch (e) {
      debugPrint("Error unliking story: $e");
    }
  }

  /// Reply to a story
  Future<void> replyToStory(String storyId, String ownerId, String message, String mediaUrl) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    
    // Prevent replying to self? Maybe allowed for testing.
    // if (user.id == ownerId) return;

    try {
      // 1. Find or Create Chat
      final chatId = await _getOrCreateChatId(user.id, ownerId);
      
      // 2. Prepare content: mediaUrl|||message
      // Using '|||' as separator as observed in SocialChatDetailPage
      final content = '$mediaUrl|||$message';

      // 3. Insert Message
      await _supabase.from('social_messages').insert({
        'chat_id': chatId,
        'sender_id': user.id,
        'content': content,
        'type': 'story_reply',
      });

      // 4. Update Chat Summary
      await _supabase.from('social_chats').update({
        'updated_at': DateTime.now().toIso8601String(),
        'last_message': '💬 Membalas story',
      }).eq('id', chatId);

    } catch (e) {
      debugPrint("Error replying to story: $e");
      rethrow;
    }
  }

  /// Helper: Get existing chat or create new one
  Future<String> _getOrCreateChatId(String myId, String targetId) async {
    // 1. Check existing chats where I am a participant
    // Using a simpler client-side check for robustness without complex RPC
    try {
        final myChats = await _supabase
            .from('social_chats')
            .select()
            .contains('participants', [myId]);
        
        for (var chat in myChats) {
          final participants = List<dynamic>.from(chat['participants']);
          if (participants.contains(targetId)) {
            return chat['id'];
          }
        }
        
        // 2. Create new chat if not found
        final res = await _supabase
            .from('social_chats')
            .insert({
              'participants': [myId, targetId],
              'last_message': 'Started a conversation',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        
        return res['id'];
    } catch (e) {
      throw Exception("Failed to get or create chat: $e");
    }
  }
  /// Delete a story
  Future<void> deleteStory(String storyId) async {
     try {
       final user = _supabase.auth.currentUser;
       if (user == null) return;

       // RLS policy usually handles auth check, but explicit check is good
       await _supabase
           .from('stories')
           .delete()
           .eq('id', storyId)
           .eq('user_id', user.id);
     } catch (e) {
       debugPrint("Error deleting story: $e");
       rethrow;
     }
  }

  /// Fetch users who viewed a story
  Future<List<Map<String, dynamic>>> fetchStoryViewers(String storyId) async {
     try {
       // Query story_views joined with profiles
       final response = await _supabase
           .from('story_views')
           .select('viewed_at, profiles:viewer_id(full_name, avatar_url)')
           .eq('story_id', storyId)
           .order('viewed_at', ascending: false);
       
       // Transform to list of clean maps
       final List<dynamic> data = response as List<dynamic>;
       return data.map((item) {
          final profile = item['profiles'] ?? {};
          return {
            'full_name': profile['full_name'] ?? 'Unknown',
            'avatar_url': profile['avatar_url'],
            'viewed_at': item['viewed_at'],
          };
       }).toList();

     } catch (e) {
       debugPrint("Error fetching view stats: $e");
       return [];
     }
  }
}