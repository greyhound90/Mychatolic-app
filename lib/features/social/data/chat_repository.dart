import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  final SupabaseClient _supabase;

  ChatRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<String> getOrCreatePrivateChat(String otherUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      throw Exception("User belum login");
    }

    try {
      final existingByParticipants =
          await _findPrivateChatByParticipants(myId, otherUserId);
      if (existingByParticipants != null) {
        await _syncPrivateChat(existingByParticipants, myId, otherUserId);
        return existingByParticipants;
      }

      final existingByMembers =
          await _findPrivateChatByChatMembers(myId, otherUserId);
      if (existingByMembers != null) {
        await _syncPrivateChat(existingByMembers, myId, otherUserId);
        return existingByMembers;
      }

      final now = DateTime.now().toIso8601String();
      final created = await _supabase
          .from('social_chats')
          .insert({
            'is_group': false,
            'creator_id': myId,
            'participants': [myId, otherUserId],
            'updated_at': now,
            'last_message': 'Memulai percakapan',
          })
          .select('id')
          .single();

      final chatId = created['id']?.toString();
      if (chatId == null || chatId.isEmpty) {
        throw Exception("Chat tidak ditemukan setelah dibuat");
      }

      await _ensureChatMembers(chatId, [myId, otherUserId]);
      return chatId;
    } catch (e) {
      throw Exception("Gagal menyiapkan chat: $e");
    }
  }

  Future<String?> _findPrivateChatByParticipants(
    String myId,
    String otherUserId,
  ) async {
    final response = await _supabase
        .from('social_chats')
        .select('id, participants')
        .eq('is_group', false)
        .contains('participants', [myId, otherUserId])
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response?['id']?.toString();
  }

  Future<String?> _findPrivateChatByChatMembers(
    String myId,
    String otherUserId,
  ) async {
    final myChatsResponse = await _supabase
        .from('chat_members')
        .select('chat_id, social_chats!inner(is_group)')
        .eq('user_id', myId)
        .eq('social_chats.is_group', false);

    final myChatIds = (myChatsResponse as List)
        .map((row) => row['chat_id']?.toString())
        .whereType<String>()
        .toList();

    if (myChatIds.isEmpty) return null;

    final commonChat = await _supabase
        .from('chat_members')
        .select('chat_id')
        .inFilter('chat_id', myChatIds)
        .eq('user_id', otherUserId)
        .limit(1)
        .maybeSingle();

    return commonChat?['chat_id']?.toString();
  }

  Future<void> _syncPrivateChat(
    String chatId,
    String myId,
    String otherUserId,
  ) async {
    await _ensureChatMembers(chatId, [myId, otherUserId]);
    await _ensureParticipants(chatId, myId, otherUserId);
  }

  Future<void> _ensureChatMembers(
    String chatId,
    List<String> userIds,
  ) async {
    try {
      final existing = await _supabase
          .from('chat_members')
          .select('user_id')
          .eq('chat_id', chatId)
          .inFilter('user_id', userIds);
      final existingIds = (existing as List)
          .map((row) => row['user_id']?.toString())
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
      // Best-effort sync; do not block chat flow.
    }
  }

  Future<void> _ensureParticipants(
    String chatId,
    String myId,
    String otherUserId,
  ) async {
    try {
      final existing = await _supabase
          .from('social_chats')
          .select('participants')
          .eq('id', chatId)
          .maybeSingle();
      if (existing == null) return;

      final raw = existing['participants'];
      final expected = <String>{myId, otherUserId};
      var needsUpdate = true;

      if (raw is List) {
        final current = raw
            .map((item) => item?.toString())
            .whereType<String>()
            .toSet();
        needsUpdate = !current.containsAll(expected) || current.length != expected.length;
      }

      if (!needsUpdate) return;

      await _supabase.from('social_chats').update({
        'participants': expected.toList(),
      }).eq('id', chatId);
    } catch (_) {
      // Best-effort sync; do not block chat flow.
    }
  }
}
