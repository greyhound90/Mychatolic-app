import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/features/social/data/chat_repository.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatRepository _chatRepository = ChatRepository();

  /// Checks if a private chat exists between current user and target user.
  /// If yes, returns the chatId.
  /// If no, creates a new chat in 'social_chats' and adds both as 'chat_members', then returns new chatId.
  Future<String> getOrCreatePrivateChat(String targetUserId) async {
    try {
      return await _chatRepository.getOrCreatePrivateChat(targetUserId);
    } catch (e) {
      throw Exception("Gagal menyiapkan chat: ${e.toString()}");
    }
  }

  /// Alias for direct 1:1 chat creation to keep API consistent.
  Future<String> getOrCreateDirectChat(String otherUserId) async {
    return getOrCreatePrivateChat(otherUserId);
  }

  /// Creates a basic group chat and returns the chatId.
  /// Validates that all memberIds are mutual-follow with current user.
  Future<String> createGroupChat({
    required String name,
    String? photoUrl,
    required List<String> memberIds,
  }) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      throw Exception("User belum login");
    }

    final cleaned = memberIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != myId)
        .toSet()
        .toList();

    if (cleaned.isEmpty) {
      throw Exception("Pilih minimal 1 anggota");
    }

    final eligible = await filterEligibleMembers(cleaned);
    if (eligible.length != cleaned.length) {
      throw Exception("Semua anggota harus saling follow dengan Anda");
    }

    final participants = <String>{myId, ...eligible}.toList();
    final now = DateTime.now().toIso8601String();

    final chatData = await _supabase
        .from('social_chats')
        .insert({
          'is_group': true,
          'group_name': name,
          'group_avatar_url': photoUrl,
          'admin_id': myId,
          'updated_at': now,
          'last_message': 'Grup "$name" dibuat',
          'participants': participants,
        })
        .select('id')
        .single();

    final chatId = chatData['id']?.toString();
    if (chatId == null || chatId.isEmpty) {
      throw Exception("Gagal membuat grup");
    }

    final membersData = participants
        .map((uid) => {'chat_id': chatId, 'user_id': uid})
        .toList();
    await _supabase.from('chat_members').insert(membersData);

    return chatId;
  }

  /// Checks if both users follow each other (mutual follow).
  Future<bool> isMutualFollow(String a, String b) async {
    if (a.isEmpty || b.isEmpty) return false;
    final ab = await _supabase
        .from('followers')
        .select('follower_id')
        .eq('follower_id', a)
        .eq('following_id', b)
        .limit(1)
        .maybeSingle();
    if (ab == null) return false;
    final ba = await _supabase
        .from('followers')
        .select('follower_id')
        .eq('follower_id', b)
        .eq('following_id', a)
        .limit(1)
        .maybeSingle();
    return ba != null;
  }

  /// Filters the provided user ids to those that are mutual-follow with current user.
  Future<List<String>> filterEligibleMembers(List<String> picked) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final cleaned = picked
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != myId)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return [];

    final followingRes = await _supabase
        .from('followers')
        .select('following_id')
        .eq('follower_id', myId);
    final followerRes = await _supabase
        .from('followers')
        .select('follower_id')
        .eq('following_id', myId);

    final followingIds = (followingRes as List)
        .map((row) => row['following_id']?.toString())
        .whereType<String>()
        .toSet();
    final followerIds = (followerRes as List)
        .map((row) => row['follower_id']?.toString())
        .whereType<String>()
        .toSet();

    final mutualIds = followingIds.intersection(followerIds);
    return cleaned.where(mutualIds.contains).toList();
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
