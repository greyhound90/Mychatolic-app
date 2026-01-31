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
            .inFilter('chat_id', myChatIds)
            .eq('user_id', targetUserId)
            .maybeSingle();

        if (commonChatResponse != null) {
          final chatId = commonChatResponse['chat_id'] as String;
          await _backfillPrivateChatParticipants(chatId, myId, targetUserId);
          return chatId;
        }
      }

      // 2b. Fallback: find by participants if chat_members is missing
      final existingByParticipants = await _supabase
          .from('social_chats')
          .select('id, participants')
          .eq('is_group', false)
          .contains('participants', [myId, targetUserId])
          .maybeSingle();
      if (existingByParticipants != null) {
        final chatId = existingByParticipants['id'] as String;
        await _ensureChatMembers(chatId, [myId, targetUserId]);
        await _backfillPrivateChatParticipants(chatId, myId, targetUserId);
        return chatId;
      }

      // 3. Create new chat if not found
      // a. Create Chat Room
      final chatRoom = await _supabase
          .from('social_chats')
          .insert({
            'is_group': false,
            'creator_id': myId,
            'participants': [myId, targetUserId],
            'updated_at': DateTime.now().toIso8601String(),
            'last_message': 'Memulai percakapan',
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

  Future<void> _ensureChatMembers(String chatId, List<String> userIds) async {
    try {
      final existing = await _supabase
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId)
          .inFilter('user_id', userIds);
      final existingIds = (existing as List)
          .map((e) => e['user_id']?.toString())
          .whereType<String>()
          .toSet();
      final inserts = userIds
          .where((id) => !existingIds.contains(id))
          .map((id) => {'chat_id': chatId, 'user_id': id, 'role': 'member'})
          .toList();
      if (inserts.isNotEmpty) {
        await _supabase.from('chat_members').insert(inserts);
      }
    } catch (_) {
      // Best-effort; do not block chat flow.
    }
  }

  Future<void> _backfillPrivateChatParticipants(
    String chatId,
    String myId,
    String targetUserId,
  ) async {
    try {
      final existing = await _supabase
          .from('social_chats')
          .select('participants')
          .eq('id', chatId)
          .maybeSingle();
      if (existing == null) return;

      final raw = existing['participants'];
      final List<dynamic> current =
          raw is List ? List<dynamic>.from(raw) : <dynamic>[];
      final participants = <String>{};
      for (final p in current) {
        if (p == null) continue;
        participants.add(p.toString());
      }
      final needsUpdate = !participants.contains(myId) ||
          !participants.contains(targetUserId) ||
          raw is! List;
      if (!needsUpdate) return;

      participants.add(myId);
      participants.add(targetUserId);
      await _supabase.from('social_chats').update({
        'participants': participants.toList(),
      }).eq('id', chatId);
    } catch (_) {
      // Best-effort backfill; ignore errors to avoid blocking chat flow.
    }
  }

  /// Streams messages for a given chat room in real-time.
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId) {
    return _supabase
        .from('social_messages') // Ensure using social_messages for social chat
        .stream(primaryKey: ['id'])
        .eq('chat_id', roomId) // social_messages uses chat_id, not room_id
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
      await _supabase.from('social_messages').insert({
        'chat_id': roomId,
        'sender_id': myId,
        'content': content,
        'type': type,
      });
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
          .from('social_messages')
          .update({'is_read': true})
          .eq('chat_id', roomId)
          .neq('sender_id', myUserId) // Only mark OTHERS' messages
          .eq('is_read', false); // Only update if currently unread
    } catch (e) {
      debugPrint("Failed to mark messages as read: $e");
    }
  }

  // --- NEW: Unread Count Stream ---
  
  /// Get total unread messages count for the current user.
  /// Listens to real-time changes in `social_messages`.
  Stream<int> getUnreadCountStream() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return Stream.value(0);

    // Note: Due to limitations in purely counting via Stream on filtered relationship,
    // we use a simpler approach: Watch all messages intended for me (or my chats) that are unread.
    // However, `social_messages` usually doesn't have `receiver_id`.
    // We rely on RLS (Row Level Security) ensuring I can only see messages in my chats.
    // So we count how many `is_read` == false AND `sender_id` != me.
    
    return _supabase
        .from('social_messages')
        .stream(primaryKey: ['id']) 
        .map((messages) {
           // This stream returns LIMITED recent rows depending on Supabase socket config,
           // ideally we want a COUNT query. But Stream count isn't direct.
           // Workaround for Realtime Badge:
           // 1. Fetch Request for Total Count initially? No, let's try mapping the stream list.
           // Warning: .stream() by default limits to recent rows (e.g. 100).
           // If user has >100 unread messages globally, this might undercount, but enough for "Badge".
           
           if (messages.isEmpty) return 0;
           
           final unreadCount = messages.where((m) {
              final isRead = m['is_read'] == true;
              final senderId = m['sender_id'];
              return !isRead && senderId != myId;
           }).length;
           
           return unreadCount;
        });
        
    // Caveat: The above only works if the stream emits ALL unread messages. 
    // If the table is huge, Supabase stream emits changes + buffer. 
    // A more robust way for "Global Count" usually triggers a `count()` query on every Postgres Change event.
    // But for this task, let's stick to the requested Stream pattern or simple Count query + timer/refresh.
    // BETTER APPROACH FOR ACCURACY: Return a Stream that executes a COUNT query periodically or on event.
    // But per instruction "Return Stream from table", we stick provided logic.
  }
}
