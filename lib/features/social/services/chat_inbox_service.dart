import 'package:supabase_flutter/supabase_flutter.dart';

class ChatInboxService {
  final SupabaseClient _supabase;

  ChatInboxService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<Map<String, int>> fetchUnreadCounts({
    required String myId,
    required List<String> chatIds,
    int limit = 800,
  }) async {
    if (chatIds.isEmpty) return {};

    final uniqueIds = chatIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return {};

    final List<dynamic> rows = await _supabase
        .from('social_messages')
        .select('chat_id, sender_id, is_read')
        .inFilter('chat_id', uniqueIds)
        .eq('is_read', false)
        .neq('sender_id', myId)
        .limit(limit);

    final counts = <String, int>{};
    for (final row in rows) {
      final chatId = row['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty) continue;
      counts[chatId] = (counts[chatId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, Map<String, dynamic>>> fetchLatestMessagesForChats({
    required List<String> chatIds,
    int limit = 500,
  }) async {
    if (chatIds.isEmpty) return {};

    final uniqueIds = chatIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return {};

    final List<dynamic> rows = await _supabase
        .from('social_messages')
        .select('chat_id, content, type, created_at')
        .inFilter('chat_id', uniqueIds)
        .order('created_at', ascending: false)
        .limit(limit);

    final latest = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final chatId = row['chat_id']?.toString();
      if (chatId == null || chatId.isEmpty) continue;
      latest.putIfAbsent(chatId, () => Map<String, dynamic>.from(row));
    }
    return latest;
  }

  String buildPreview({
    required Map<String, dynamic> chatRow,
    Map<String, dynamic>? lastMessage,
  }) {
    final messageType = (lastMessage?['type'] ?? chatRow['last_message_type'] ?? '')
        .toString()
        .toLowerCase();
    final hasImage = lastMessage?['image_url'] != null;
    final hasAudio = lastMessage?['audio_url'] != null;
    final hasLocation = lastMessage?['location_lat'] != null ||
        lastMessage?['location_lng'] != null;

    if (messageType == 'beeb') return '👋 BEEB!';
    if (messageType == 'image' || messageType == 'photo' || hasImage) {
      return '📷 Foto';
    }
    if (messageType == 'audio' || hasAudio) return '🎤 Pesan suara';
    if (messageType == 'location' || hasLocation) return '📍 Lokasi';

    final raw = (lastMessage?['content'] ?? chatRow['last_message'] ?? '').toString().trim();
    if (raw.isEmpty) return '';

    final normalized = _normalizeEmojiPreview(raw);
    if (normalized != null) return normalized;

    return _truncate(raw, 60);
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  String? _normalizeEmojiPreview(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('beeb') || text.contains('👋')) return '👋 BEEB!';
    if (lower.contains('foto') || lower.contains('gambar') || text.contains('📷')) {
      return '📷 Foto';
    }
    if (lower.contains('pesan suara') || lower.contains('voice') || text.contains('🎤')) {
      return '🎤 Pesan suara';
    }
    if (lower.contains('lokasi') || text.contains('📍')) return '📍 Lokasi';
    return null;
  }

  Future<List<String>> fetchMutualFollowIds(String myId) async {
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

    return followingIds.intersection(followerIds).toList();
  }
}
