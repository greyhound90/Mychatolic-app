import 'package:supabase_flutter/supabase_flutter.dart';

enum GroupJoinStatus { joined, pending, alreadyMember, invalid, failed }

class GroupJoinResult {
  final GroupJoinStatus status;
  final String? chatId;
  final String? groupName;

  const GroupJoinResult({
    required this.status,
    this.chatId,
    this.groupName,
  });
}

class GroupInviteService {
  final SupabaseClient _supabase;

  GroupInviteService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<GroupJoinResult> joinByLink(String input) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return const GroupJoinResult(status: GroupJoinStatus.failed);

    final chatId = _extractChatId(input);
    if (chatId == null) {
      return const GroupJoinResult(status: GroupJoinStatus.invalid);
    }

    final group = await _supabase
        .from('social_chats')
        .select('id, is_group, group_name, participants')
        .eq('id', chatId)
        .maybeSingle();
    if (group == null || group['is_group'] != true) {
      return const GroupJoinResult(status: GroupJoinStatus.invalid);
    }

    final groupName = group['group_name']?.toString();

    try {
      await _supabase.from('chat_members').insert({
        'chat_id': chatId,
        'user_id': myId,
      });
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        return GroupJoinResult(
          status: GroupJoinStatus.alreadyMember,
          chatId: chatId,
          groupName: groupName,
        );
      }
      if (msg.contains('permission') || msg.contains('denied') || msg.contains('policy')) {
        return GroupJoinResult(
          status: GroupJoinStatus.pending,
          chatId: chatId,
          groupName: groupName,
        );
      }
      return const GroupJoinResult(status: GroupJoinStatus.failed);
    }

    await _bestEffortAddParticipant(chatId, myId, group['participants']);

    return GroupJoinResult(
      status: GroupJoinStatus.joined,
      chatId: chatId,
      groupName: groupName,
    );
  }

  Future<void> _bestEffortAddParticipant(
    String chatId,
    String myId,
    dynamic participantsRaw,
  ) async {
    try {
      final participants = <String>{};
      if (participantsRaw is List) {
        for (final item in participantsRaw) {
          final value = item?.toString();
          if (value != null && value.isNotEmpty) participants.add(value);
        }
      }
      if (!participants.add(myId)) return;
      await _supabase
          .from('social_chats')
          .update({'participants': participants.toList()})
          .eq('id', chatId);
    } catch (_) {
      // Best-effort only; ignore errors to avoid blocking UX.
    }
  }

  String? _extractChatId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final params = uri.queryParameters;
      final paramChatId =
          params['chat_id'] ?? params['chatId'] ?? params['id'] ?? params['code'];
      if (paramChatId != null && paramChatId.trim().isNotEmpty) {
        return paramChatId.trim();
      }
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final last = pathSegments.last.trim();
        if (_looksLikeUuid(last)) return last;
      }
    }

    if (_looksLikeUuid(trimmed)) return trimmed;
    return null;
  }

  bool _looksLikeUuid(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(value);
  }
}
