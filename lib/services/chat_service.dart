import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Checks if a private chat exists between current user and target user.
  /// If yes, returns the chatId.
  /// If no, creates a new chat in 'social_chats' and adds both as 'chat_members', then returns new chatId.
  Future<String> getOrCreatePrivateChat(String targetUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("User belum login");

    try {
      // 1. Get all private chat IDs that I am part of
      // We filter by joining social_chats where is_group = false
      final myChatsResponse = await _supabase
          .from('chat_members')
          .select('chat_id, social_chats!inner(is_group)')
          .eq('user_id', myId)
          .eq('social_chats.is_group', false);

      final List<dynamic> myChatsData = myChatsResponse as List<dynamic>;
      final List<String> myChatIds = myChatsData
          .map((row) => row['chat_id'] as String)
          .toList();

      // 2. Check if targetUser is also a member in any of these chats
      if (myChatIds.isNotEmpty) {
        final commonChatResponse = await _supabase
            .from('chat_members')
            .select('chat_id')
            .filter('chat_id', 'in', myChatIds)
            .eq('user_id', targetUserId)
            .maybeSingle();

        if (commonChatResponse != null) {
          return commonChatResponse['chat_id'] as String;
        }
      }

      // 3. Create new chat if not found
      // a. Create Chat Room
      final chatRoom = await _supabase
          .from('social_chats')
          .insert({
            'is_group': false,
            'creator_id': myId,
            'updated_at': DateTime.now().toIso8601String(),
            // 'last_message': 'Chat started', // Optional
          })
          .select()
          .single();

      final String newChatId = chatRoom['id'];

      // b. Add Members
      await _supabase.from('chat_members').insert([
        {'chat_id': newChatId, 'user_id': myId, 'role': 'member'},
        {'chat_id': newChatId, 'user_id': targetUserId, 'role': 'member'},
      ]);

      return newChatId;
    } catch (e) {
      throw Exception("Gagal menyiapkan chat: ${e.toString()}");
    }
  }

  /// Streams messages for a given chat room in real-time.
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId) {
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
  }

  /// Sends a new message to the chat room.
  Future<void> sendMessage({
    required String roomId,
    required String content,
    String type = 'text',
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await _supabase.from('chat_messages').insert({
        'room_id': roomId,
        'sender_id': myId,
        'content': content,
        'type': type,
        // 'created_at' is usually handled by DB default, but can be explicit if needed
      });

      // Optional: Update last_message in parent table if needed,
      // but keeping it simple as per "Send Message (Optimized)" instruction.
    } catch (e) {
      throw Exception("Gagal mengirim pesan: $e");
    }
  }

  /// Marks all unread messages in the room as read (only those sent by others).
  Future<void> markMessagesAsRead(String roomId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return;

    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('room_id', roomId)
          .neq('sender_id', myUserId) // Only mark OTHERS' messages
          .eq('is_read', false); // Only update if currently unread
    } catch (e) {
      // Create silent error or log it, marking read shouldn't block the user
      debugPrint("Failed to mark messages as read: $e");
    }
  }
}
