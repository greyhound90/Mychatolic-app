import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JoinRadarOutcome {
  final String status;
  final String? chatRoomId;

  const JoinRadarOutcome({required this.status, this.chatRoomId});

  bool get isJoined => status.toUpperCase() == 'JOINED';
  bool get isPending => status.toUpperCase() == 'PENDING';
}

class RadarService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch PUBLIC radar events (future only), with creator profile + participant count.
  Future<List<Map<String, dynamic>>> fetchPublicRadars({
    int page = 0,
    int limit = 10,
  }) async {
    try {
      try {
        await _supabase.rpc('check_and_update_radar_status');
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR STATUS RPC ERROR]',
          error: e,
          stackTrace: st,
          payload: {'fn': 'check_and_update_radar_status'},
        );
      }

      // Use UTC in comparisons to avoid timezone-related filtering bugs.
      // Keep a small buffer so events don't disappear the moment they start.
      final cutoffIso = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String();

      final start = page * limit;
      final end = start + limit - 1;

      final response = await _supabase
          .from('radar_events')
          .select('*, profiles:creator_id(*), radar_participants(count)')
          .eq('visibility', 'PUBLIC')
          .inFilter('status', ['PUBLISHED', 'UPDATED'])
          .gt('event_time', cutoffIso)
          .order('event_time', ascending: true)
          .range(start, end);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final radarParticipantsAgg = row['radar_participants'];
        final participantCount =
            radarParticipantsAgg is List &&
                radarParticipantsAgg.isNotEmpty &&
                radarParticipantsAgg.first is Map &&
                (radarParticipantsAgg.first as Map).containsKey('count')
            ? (radarParticipantsAgg.first as Map)['count']
            : 0;

        return {
          ...row,
          // Backward-compatible keys used by some UI widgets.
          'schedule_time': row['event_time'],
          'location_name': row['church_name'],
          'participant_count': participantCount,
        };
      }).toList();
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH PUBLIC ERROR]',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // Fetch my radars (JOINED or INVITED) via radar_participants, with nested radar_events data.
  Future<List<Map<String, dynamic>>> fetchMyRadars() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      try {
        await _supabase.rpc('check_and_update_radar_status');
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR STATUS RPC ERROR]',
          error: e,
          stackTrace: st,
          payload: {'fn': 'check_and_update_radar_status'},
        );
      }

      final cutoffIso = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 2))
          .toIso8601String();

      final response = await _supabase
          .from('radar_participants')
          .select('status, event:radar_events!inner(*, profiles:creator_id(*))')
          .eq('user_id', userId)
          .inFilter('status', ['JOINED', 'INVITED'])
          .gt('event.event_time', cutoffIso)
          .order('event_time', referencedTable: 'event', ascending: true);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final event = Map<String, dynamic>.from(row['event'] as Map);
        final participantStatus = row['status']?.toString();

        return {
          ...event,
          // Backward-compatible keys used by some UI widgets.
          'schedule_time': event['event_time'],
          'location_name': event['church_name'],

          // Useful for newer UI.
          'participant_status': participantStatus,

          // Legacy UI expects `status` like "active".
          'status': participantStatus == 'JOINED'
              ? 'active'
              : (participantStatus ?? 'INVITED').toLowerCase(),
        };
      }).toList();
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH MY ERROR]',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // Create PUBLIC radar event.
  //
  // IMPORTANT: Backend trigger (handle_new_radar_event) will handle:
  // - create chat_rooms
  // - add creator to radar_participants (JOINED)
  // - set creator admin in chat_members
  // - update radar_events.chat_room_id
  //
  // So client only inserts into radar_events.
  Future<void> createPublicRadar({
    required String title,
    required String description,
    required String churchId, // mandatory UUID
    required String scheduleTimeUtcIso,
    required String churchName,
    int? maxParticipants,
    bool allowMemberInvite = true,
    bool requireHostApproval = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (churchId.trim().isEmpty) throw Exception("Gereja belum dipilih");

    final radarPayload = <String, dynamic>{
      'title': title,
      'description': description,
      'church_id': churchId,
      'church_name': churchName,
      'event_time': scheduleTimeUtcIso,
      'creator_id': userId,
      'visibility': 'PUBLIC',
      'status': 'PUBLISHED',
      'allow_member_invite': allowMemberInvite,
      'require_host_approval': requireHostApproval,
    };
    if (maxParticipants != null) {
      radarPayload['max_participants'] = maxParticipants;
    }

    try {
      final inserted = await _supabase
          .from('radar_events')
          .insert(radarPayload)
          .select('id')
          .single();

      final radarId = inserted['id']?.toString();
      if (radarId != null && radarId.isNotEmpty) {
        await _insertRadarLog(
          radarId: radarId,
          userId: userId,
          changeType: 'CREATE',
          description: 'Membuat Radar',
        );
      }
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR CREATE PUBLIC ERROR]',
        error: e,
        stackTrace: st,
        payload: radarPayload,
      );
      throw Exception("Gagal membuat radar");
    }
  }

  // Update radar event (HOST edit) + create audit log.
  Future<void> updateRadar({
    required String id,
    required Map<String, dynamic> updates,
    required String changeDescription,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (id.trim().isEmpty) throw Exception("Radar tidak valid");
    if (updates.isEmpty) throw Exception("Tidak ada perubahan");

    final sanitizedUpdates = Map<String, dynamic>.from(updates);
    sanitizedUpdates.remove('id');

    try {
      await _supabase
          .from('radar_events')
          .update(sanitizedUpdates)
          .eq('id', id);
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR UPDATE ERROR]',
        error: e,
        stackTrace: st,
        payload: {'id': id, 'updates': sanitizedUpdates},
      );
      throw Exception("Gagal menyimpan perubahan");
    }

    try {
      await _supabase.from('radar_change_logs').insert({
        'radar_id': id,
        'changed_by': userId,
        'change_type': 'UPDATE',
        'description': changeDescription.trim().isEmpty
            ? 'Update Informasi Event'
            : changeDescription.trim(),
      });
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR CHANGE LOG ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': id, 'changed_by': userId},
      );
      throw Exception("Gagal mencatat log perubahan");
    }
  }

  // Delete radar event (HOST only).
  Future<void> deleteRadar(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (id.trim().isEmpty) throw Exception("Radar tidak valid");

    try {
      // Optional: create audit log before delete
      await _supabase.from('radar_change_logs').insert({
        'radar_id': id,
        'changed_by': userId,
        'change_type': 'DELETE',
        'description': 'Menghapus Radar',
      });
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR DELETE LOG ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': id},
      );
      // Continue delete even if log insert fails
    }

    try {
      await _supabase.rpc('delete_radar_safely', params: {'p_radar_id': id});
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR DELETE ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': id},
      );
      throw Exception("Gagal menghapus radar");
    }
  }

  // Create PRIVATE radar invite for a specific friend.
  //
  // Step A: Insert radar_events (PRIVATE) and get new id
  // Step B: Insert radar_participants for target friend with status INVITED
  Future<void> createPersonalRadar({
    required String targetUserId,
    required String churchId,
    required String churchName,
    required DateTime scheduleTime,
    required String message,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (churchId.trim().isEmpty) throw Exception("Gereja belum dipilih");

    final radarPayload = <String, dynamic>{
      'title': "Misa Bersama",
      'description': message,
      'church_id': churchId,
      'church_name': churchName,
      'event_time': scheduleTime.toUtc().toIso8601String(),
      'creator_id': userId,
      'visibility': 'PRIVATE',
      'status': 'PUBLISHED',
      'allow_member_invite': true,
      'require_host_approval': false,
    };

    try {
      final inserted = await _supabase
          .from('radar_events')
          .insert(radarPayload)
          .select('id')
          .single();
      final radarId = inserted['id'].toString();

      await _supabase.from('radar_participants').insert({
        'radar_id': radarId,
        'user_id': targetUserId,
        'status': 'INVITED',
        'role': 'MEMBER',
      });

      await _insertRadarLog(
        radarId: radarId,
        userId: userId,
        changeType: 'CREATE_PRIVATE',
        description: 'Membuat Radar Personal',
      );
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR CREATE PRIVATE ERROR]',
        error: e,
        stackTrace: st,
        payload: radarPayload,
      );
      throw Exception("Gagal membuat personal radar");
    }
  }

  // Create PUBLIC radar based on an existing mass schedule row.
  Future<void> createRadarFromSchedule({
    required String scheduleId,
    String? notes,
  }) async {
    if (scheduleId.trim().isEmpty) {
      throw Exception("Jadwal tidak valid");
    }

    try {
      final schedule = await _supabase
          .from('mass_schedules')
          .select('id, church_id, day_of_week, time_start, language')
          .eq('id', scheduleId)
          .single();

      final churchId = schedule['church_id']?.toString() ?? '';
      if (churchId.isEmpty) {
        throw Exception("Gereja tidak valid");
      }

      final churchRow = await _supabase
          .from('churches')
          .select('name')
          .eq('id', churchId)
          .maybeSingle();

      final churchName = churchRow?['name']?.toString() ?? 'Gereja';

      final int rawDay = int.tryParse(schedule['day_of_week'].toString()) ?? 0;
      final String timeStart = schedule['time_start']?.toString() ?? '00:00';

      final dayNames = [
        'Minggu',
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
      ];
      final dayName = rawDay >= 0 && rawDay < dayNames.length
          ? dayNames[rawDay]
          : 'Minggu';

      final parts = timeStart.split(':');
      final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      final now = DateTime.now();
      final targetDay = rawDay == 0 ? 7 : rawDay;
      int daysToAdd = (targetDay - now.weekday + 7) % 7;

      if (daysToAdd == 0) {
        final currentMinutes = now.hour * 60 + now.minute;
        final scheduleMinutes = hour * 60 + minute;
        if (currentMinutes > scheduleMinutes) {
          daysToAdd = 7;
        }
      }

      final scheduleDate = DateTime(
        now.year,
        now.month,
        now.day + daysToAdd,
        hour,
        minute,
      );

      final description = (notes != null && notes.trim().isNotEmpty)
          ? notes.trim()
          : 'Mengikuti Misa di $churchName.';

      await createPublicRadar(
        title: 'Misa $dayName, ${timeStart.substring(0, 5)}',
        description: description,
        churchId: churchId,
        scheduleTimeUtcIso: scheduleDate.toUtc().toIso8601String(),
        churchName: churchName,
      );
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR CREATE FROM SCHEDULE ERROR]',
        error: e,
        stackTrace: st,
        payload: {'schedule_id': scheduleId},
      );
      throw Exception("Gagal membuat radar");
    }
  }

  // Join a radar (accept invite / join public radar) with rule checks.
  // Returns status: JOINED or PENDING, and chat_room_id if joined.
  Future<JoinRadarOutcome> joinRadar(String radarId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");

    try {
      // Prefer RPC for atomic checks (if installed).
      final rpc = await _supabase.rpc('join_radar_event', params: {
        'p_radar_id': radarId,
        'p_user_id': userId,
      });

      if (rpc is Map) {
        final status = (rpc['status'] ?? 'JOINED').toString();
        final chatRoomId = rpc['chat_room_id']?.toString();
        await _notifyHostOnJoin(
          radarId: radarId,
          actorId: userId,
          status: status,
        );
        return JoinRadarOutcome(status: status, chatRoomId: chatRoomId);
      }
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR JOIN RPC ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      // Continue to fallback if RPC not available.
    }

    // Fallback logic (non-atomic).
    try {
      final event = await _supabase
          .from('radar_events')
          .select(
            'id, status, event_time, max_participants, require_host_approval, creator_id, chat_room_id',
          )
          .eq('id', radarId)
          .single();

      final status = (event['status'] ?? '').toString().toUpperCase();
      if (status != 'PUBLISHED' && status != 'UPDATED') {
        throw Exception("Radar tidak aktif");
      }

      final eventTime =
          DateTime.tryParse(event['event_time']?.toString() ?? '');
      if (eventTime != null &&
          eventTime.toUtc().isBefore(DateTime.now().toUtc())) {
        throw Exception("Radar sudah lewat");
      }

      final maxParticipants = event['max_participants'] is int
          ? event['max_participants'] as int
          : int.tryParse(event['max_participants']?.toString() ?? '') ?? 0;

      if (maxParticipants > 0) {
        final joinedCount = await _supabase
            .from('radar_participants')
            .select('id')
            .eq('radar_id', radarId)
            .eq('status', 'JOINED');
        final joinedList = List<Map<String, dynamic>>.from(joinedCount as List);
        if (joinedList.length >= maxParticipants) {
          throw Exception("Kuota penuh");
        }
      }

      final requireHostApproval =
          event['require_host_approval'] == true;

      final existing = await _supabase
          .from('radar_participants')
          .select('status')
          .eq('radar_id', radarId)
          .eq('user_id', userId)
          .maybeSingle();

      final existingStatus = existing?['status']?.toString().toUpperCase();
      if (existingStatus == 'JOINED') {
        await _notifyHostOnJoin(
          radarId: radarId,
          actorId: userId,
          status: 'JOINED',
        );
        return JoinRadarOutcome(
          status: 'JOINED',
          chatRoomId: event['chat_room_id']?.toString(),
        );
      }
      if (existingStatus == 'PENDING') {
        await _notifyHostOnJoin(
          radarId: radarId,
          actorId: userId,
          status: 'PENDING',
        );
        return const JoinRadarOutcome(status: 'PENDING');
      }

      final newStatus = requireHostApproval ? 'PENDING' : 'JOINED';

      await _supabase.from('radar_participants').upsert({
        'radar_id': radarId,
        'user_id': userId,
        'status': newStatus,
        'role': 'MEMBER',
      }, onConflict: 'radar_id, user_id');

      if (newStatus == 'JOINED') {
        final chatRoomId = event['chat_room_id']?.toString();
        if (chatRoomId != null && chatRoomId.isNotEmpty) {
          await _supabase.from('chat_members').upsert(
            {'chat_id': chatRoomId, 'user_id': userId},
            onConflict: 'chat_id, user_id',
          );
        }
        await _insertRadarLog(
          radarId: radarId,
          userId: userId,
          changeType: 'JOIN',
          description: 'Bergabung ke Radar',
        );
        await _notifyHostOnJoin(
          radarId: radarId,
          actorId: userId,
          status: 'JOINED',
        );
        return JoinRadarOutcome(status: 'JOINED', chatRoomId: chatRoomId);
      }

      await _insertRadarLog(
        radarId: radarId,
        userId: userId,
        changeType: 'REQUEST_JOIN',
        description: 'Mengajukan permintaan join',
      );
      await _notifyHostOnJoin(
        radarId: radarId,
        actorId: userId,
        status: 'PENDING',
      );
      return const JoinRadarOutcome(status: 'PENDING');
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR JOIN ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      throw Exception("Gagal bergabung");
    }
  }

  // Best-effort: fetch chat_room_id generated by DB trigger for a radar.
  // Uses small retries to handle eventual consistency after triggers.
  Future<String?> fetchRadarChatRoomId(
    String radarId, {
    int maxRetries = 6,
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    if (radarId.trim().isEmpty) return null;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final row = await _supabase
            .from('radar_events')
            .select('chat_room_id')
            .eq('id', radarId)
            .maybeSingle();

        final chatRoomId = row?['chat_room_id']?.toString();
        if (chatRoomId != null && chatRoomId.trim().isNotEmpty) {
          return chatRoomId;
        }
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR FETCH CHAT ROOM ERROR]',
          error: e,
          stackTrace: st,
          payload: {'radar_id': radarId},
        );
        return null;
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    return null;
  }

  // Best-effort: ensure current user is a member of the radar chat group.
  // Will not throw if chat membership fails, to avoid blocking join flow.
  Future<String?> prepareChatForRadar(String radarId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");

    final chatRoomId = await fetchRadarChatRoomId(radarId);
    if (chatRoomId == null) return null;

    try {
      await _supabase.from('chat_members').upsert(
        {'chat_id': chatRoomId, 'user_id': userId},
        onConflict: 'chat_id, user_id',
      );
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR CHAT MEMBER ERROR]',
        error: e,
        stackTrace: st,
        payload: {'chat_id': chatRoomId, 'user_id': userId},
      );
    }

    return chatRoomId;
  }

  // Fetch participants for a radar with embedded profiles.
  // Returns JOINED participants only.
  Future<List<Map<String, dynamic>>> fetchParticipants(String radarId) async {
    if (radarId.trim().isEmpty) return [];

    try {
      final response = await _supabase
          .from('radar_participants')
          .select(
            'id, radar_id, user_id, status, role, created_at, profiles:user_id(id, full_name, avatar_url)',
          )
          .eq('radar_id', radarId)
          .eq('status', 'JOINED')
          .order('created_at', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      list.sort((a, b) {
        final ar = (a['role'] ?? '').toString().toUpperCase();
        final br = (b['role'] ?? '').toString().toUpperCase();
        final aRank = ar == 'HOST' ? 0 : 1;
        final bRank = br == 'HOST' ? 0 : 1;
        if (aRank != bRank) return aRank.compareTo(bRank);

        final ap = a['profiles'] is Map
            ? Map<String, dynamic>.from(a['profiles'] as Map)
            : const <String, dynamic>{};
        final bp = b['profiles'] is Map
            ? Map<String, dynamic>.from(b['profiles'] as Map)
            : const <String, dynamic>{};
        final an = (ap['full_name'] ?? '').toString();
        final bn = (bp['full_name'] ?? '').toString();
        return an.compareTo(bn);
      });

      return list;
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH PARTICIPANTS ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId},
      );
      return [];
    }
  }

  // Fetch PENDING participants for a radar (host approval list).
  Future<List<Map<String, dynamic>>> fetchPendingParticipants(
    String radarId,
  ) async {
    if (radarId.trim().isEmpty) return [];

    try {
      final response = await _supabase
          .from('radar_participants')
          .select(
            'id, radar_id, user_id, status, role, created_at, profiles:user_id(id, full_name, avatar_url)',
          )
          .eq('radar_id', radarId)
          .eq('status', 'PENDING')
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH PENDING ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId},
      );
      return [];
    }
  }

  // Approve participant: set JOINED + add to chat_members.
  Future<void> approveParticipant(String radarId, String userId) async {
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");
    if (userId.trim().isEmpty) throw Exception("User tidak valid");

    try {
      await _supabase
          .from('radar_participants')
          .update({'status': 'JOINED', 'role': 'MEMBER'})
          .eq('radar_id', radarId)
          .eq('user_id', userId);
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR APPROVE ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      throw Exception("Gagal menyetujui peserta");
    }

    try {
      final chatRoomId = await fetchRadarChatRoomId(radarId);
      if (chatRoomId != null && chatRoomId.trim().isNotEmpty) {
        await _supabase.from('chat_members').upsert(
          {'chat_id': chatRoomId, 'user_id': userId},
          onConflict: 'chat_id, user_id',
        );
      }
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR APPROVE CHAT ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
    }
  }

  // Reject participant: mark as REJECTED for history.
  Future<void> rejectParticipant(String radarId, String userId) async {
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");
    if (userId.trim().isEmpty) throw Exception("User tidak valid");

    try {
      await _supabase
          .from('radar_participants')
          .update({'status': 'REJECTED'})
          .eq('radar_id', radarId)
          .eq('user_id', userId);
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR REJECT ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      throw Exception("Gagal menolak peserta");
    }
  }

  // Fetch current user's participant status for a radar.
  Future<String?> fetchMyParticipantStatus(String radarId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;
    if (radarId.trim().isEmpty) return null;

    try {
      final row = await _supabase
          .from('radar_participants')
          .select('status, role')
          .eq('radar_id', radarId)
          .eq('user_id', userId)
          .maybeSingle();

      return row?['status']?.toString();
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH MY STATUS ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      return null;
    }
  }

  // Leave a radar: mark status LEFT and remove chat membership.
  Future<void> leaveRadar(String radarId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");

    // Prefer RPC if available (atomic).
    try {
      await _supabase.rpc('leave_radar_event', params: {
        'p_radar_id': radarId,
        'p_user_id': userId,
      });
      return;
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR LEAVE RPC ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      // continue fallback
    }

    try {
      await _supabase
          .from('radar_participants')
          .update({'status': 'LEFT'})
          .eq('radar_id', radarId)
          .eq('user_id', userId);

      // Remove from chat group (best-effort).
      try {
        final row = await _supabase
            .from('radar_events')
            .select('chat_room_id')
            .eq('id', radarId)
            .maybeSingle();
        final chatRoomId = row?['chat_room_id']?.toString();
        if (chatRoomId != null && chatRoomId.isNotEmpty) {
          await _supabase
              .from('chat_members')
              .delete()
              .eq('chat_id', chatRoomId)
              .eq('user_id', userId);
        }
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR LEAVE CHAT ERROR]',
          error: e,
          stackTrace: st,
          payload: {'radar_id': radarId, 'user_id': userId},
        );
      }

      await _insertRadarLog(
        radarId: radarId,
        userId: userId,
        changeType: 'LEAVE',
        description: 'Keluar dari Radar',
      );
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR LEAVE ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      throw Exception("Gagal keluar");
    }
  }

  // Kick participant (HOST only): set participant status to KICKED.
  Future<void> kickParticipant(String radarId, String userId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) throw Exception("User belum login");
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");
    if (userId.trim().isEmpty) throw Exception("User tidak valid");

    try {
      await _supabase.rpc('kick_radar_participant', params: {
        'p_radar_id': radarId,
        'p_user_id': userId,
        'p_actor_id': currentUserId,
      });
      return;
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR KICK RPC ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      // continue fallback
    }

    try {
      final event = await _supabase
          .from('radar_events')
          .select('creator_id, chat_room_id')
          .eq('id', radarId)
          .single();
      final creatorId = event['creator_id']?.toString();
      if (creatorId == null || creatorId != currentUserId) {
        throw Exception("Hanya host yang boleh mengeluarkan peserta");
      }

      await _supabase
          .from('radar_participants')
          .update({'status': 'KICKED'})
          .eq('radar_id', radarId)
          .eq('user_id', userId);

      final chatRoomId = event['chat_room_id']?.toString();
      if (chatRoomId != null && chatRoomId.isNotEmpty) {
        await _supabase
            .from('chat_members')
            .delete()
            .eq('chat_id', chatRoomId)
            .eq('user_id', userId);
      }

    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR KICK ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'user_id': userId},
      );
      throw Exception("Gagal mengeluarkan peserta");
    }
  }

  // Invite system (Radar Misa V2)
  //
  // Send an invite: insert into radar_invites, prevent duplicates.
  Future<void> sendInvite({
    required String radarId,
    required String inviteeId,
  }) async {
    final inviterId = _supabase.auth.currentUser?.id;
    if (inviterId == null) throw Exception("User belum login");
    if (radarId.trim().isEmpty) throw Exception("Radar tidak valid");
    if (inviteeId.trim().isEmpty) throw Exception("User tidak valid");
    if (inviteeId == inviterId) {
      throw Exception("Tidak bisa mengundang diri sendiri");
    }

    try {
      final event = await _supabase
          .from('radar_events')
          .select('creator_id, allow_member_invite, title')
          .eq('id', radarId)
          .single();

      final creatorId = event['creator_id']?.toString();
      final allowMemberInvite = event['allow_member_invite'] == true;
      final isHost = creatorId != null && creatorId == inviterId;

      if (!isHost && !allowMemberInvite) {
        throw Exception("Host tidak mengizinkan undangan peserta");
      }

      final existingInvite = await _supabase
          .from('radar_invites')
          .select('id, status')
          .eq('radar_id', radarId)
          .eq('invitee_id', inviteeId)
          .maybeSingle();
      final existingStatus = existingInvite?['status']?.toString();
      if (existingInvite != null && existingStatus == 'PENDING') {
        throw Exception("Undangan sudah dikirim");
      }
      if (existingInvite != null && existingStatus == 'ACCEPTED') {
        throw Exception("User sudah menerima undangan");
      }

      final existingParticipant = await _supabase
          .from('radar_participants')
          .select('status')
          .eq('radar_id', radarId)
          .eq('user_id', inviteeId)
          .maybeSingle();
      final existingParticipantStatus =
          existingParticipant?['status']?.toString().toUpperCase();
      if (existingParticipantStatus == 'JOINED') {
        throw Exception("User sudah menjadi peserta");
      }
      if (existingParticipantStatus == 'PENDING') {
        throw Exception("User sudah meminta join");
      }

      await _supabase.from('radar_invites').insert({
        'radar_id': radarId,
        'inviter_id': inviterId,
        'invitee_id': inviteeId,
        'status': 'PENDING',
      });

      await _insertRadarLog(
        radarId: radarId,
        userId: inviterId,
        changeType: 'INVITE',
        description: 'Mengundang peserta',
      );

      await _insertNotification(
        userId: inviteeId,
        actorId: inviterId,
        type: 'radar_invite',
        title: 'Undangan Radar Misa',
        body: 'mengajak Anda ke radar "${event['title'] ?? 'Radar'}".',
        relatedId: radarId,
      );
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR INVITE SEND ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'invitee_id': inviteeId},
      );
      rethrow;
    }
  }

  // Fetch pending invites addressed to current user.
  Future<List<Map<String, dynamic>>> fetchMyInvites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('radar_invites')
          .select(
            'id, radar_id, inviter_id, invitee_id, status, created_at, profiles:inviter_id(id, full_name, avatar_url), event:radar_events!inner(id, title, church_name, event_time)',
          )
          .eq('invitee_id', userId)
          .eq('status', 'PENDING')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR INVITE FETCH ERROR]',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // Respond to an invite: mark ACCEPTED/DECLINED.
  // Side effect: if accepted, auto-join radar.
  Future<void> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User belum login");
    if (inviteId.trim().isEmpty) throw Exception("Invite tidak valid");

    final newStatus = accept ? 'ACCEPTED' : 'DECLINED';

    try {
      // Prefer RPC for atomic response (if installed).
      try {
        await _supabase.rpc('respond_radar_invite', params: {
          'p_invite_id': inviteId,
          'p_accept': accept,
          'p_user_id': userId,
        });
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR INVITE RESPOND RPC ERROR]',
          error: e,
          stackTrace: st,
          payload: {'invite_id': inviteId, 'accept': accept},
        );
        // fallback to manual flow
        final updated = await _supabase
            .from('radar_invites')
            .update({'status': newStatus})
            .eq('id', inviteId)
            .select('radar_id, inviter_id')
            .single();

        if (accept) {
          final radarId = updated['radar_id']?.toString();
          if (radarId != null && radarId.isNotEmpty) {
            // Force-join on accept (invite overrides approval).
            final event = await _supabase
                .from('radar_events')
                .select('chat_room_id')
                .eq('id', radarId)
                .single();

            await _supabase.from('radar_participants').upsert({
              'radar_id': radarId,
              'user_id': userId,
              'status': 'JOINED',
              'role': 'MEMBER',
            }, onConflict: 'radar_id, user_id');

            final chatRoomId = event['chat_room_id']?.toString();
            if (chatRoomId != null && chatRoomId.isNotEmpty) {
              await _supabase.from('chat_members').upsert(
                {'chat_id': chatRoomId, 'user_id': userId},
                onConflict: 'chat_id, user_id',
              );
            }
          }
        }
      }

      // Notify inviter about response
      try {
        final inviteRow = await _supabase
            .from('radar_invites')
            .select('radar_id, inviter_id')
            .eq('id', inviteId)
            .single();
        final radarId = inviteRow['radar_id']?.toString();
        final inviterId = inviteRow['inviter_id']?.toString();

        if (radarId != null &&
            radarId.isNotEmpty &&
            inviterId != null &&
            inviterId.isNotEmpty) {
          final event = await _supabase
              .from('radar_events')
              .select('title')
              .eq('id', radarId)
              .maybeSingle();
          final title = event?['title']?.toString() ?? 'Radar';

          await _insertNotification(
            userId: inviterId,
            actorId: userId,
            type: accept ? 'radar_invite_accepted' : 'radar_invite_declined',
            title: accept ? 'Undangan diterima' : 'Undangan ditolak',
            body: accept
                ? 'menerima undangan ke "$title".'
                : 'menolak undangan ke "$title".',
            relatedId: radarId,
          );
        }
      } catch (e, st) {
        _logPostgrestError(
          tag: '[RADAR INVITE NOTIF ERROR]',
          error: e,
          stackTrace: st,
          payload: {'invite_id': inviteId, 'accept': accept},
        );
      }
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR INVITE RESPOND ERROR]',
        error: e,
        stackTrace: st,
        payload: {'invite_id': inviteId, 'accept': accept},
      );
      throw Exception("Gagal merespons undangan");
    }
  }

  // Fetch radar invites for current user (status INVITED).
  // Used by NotificationScreen.
  Future<List<Map<String, dynamic>>> fetchRadarInvites() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('radar_participants')
          .select('status, event:radar_events!inner(*, profiles:creator_id(*))')
          .eq('user_id', userId)
          .eq('status', 'INVITED')
          .order('event_time', referencedTable: 'event', ascending: true);

      return List<Map<String, dynamic>>.from(response).map((row) {
        final event = Map<String, dynamic>.from(row['event'] as Map);
        return {
          ...event,
          'schedule_time': event['event_time'],
          'location_name': event['church_name'],
          // Keep legacy key expected by NotificationScreen.
          'user_id': event['creator_id'],
        };
      }).toList();
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR FETCH INVITES ERROR]',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  void _logPostgrestError({
    required String tag,
    required Object error,
    required StackTrace stackTrace,
    Map<String, dynamic>? payload,
  }) {
    if (!kDebugMode) return;

    debugPrint("$tag type=${error.runtimeType}");
    debugPrint("$tag $error");

    if (error is PostgrestException) {
      debugPrint("$tag message=${error.message}");
      debugPrint("$tag code=${error.code}");
      debugPrint("$tag details=${error.details}");
      debugPrint("$tag hint=${error.hint}");
    }

    debugPrint("$tag stacktrace=$stackTrace");
    if (payload != null) {
      debugPrint("$tag payload=$payload");
    }
  }

  Future<void> _insertRadarLog({
    required String radarId,
    required String userId,
    required String changeType,
    required String description,
  }) async {
    try {
      await _supabase.from('radar_change_logs').insert({
        'radar_id': radarId,
        'changed_by': userId,
        'change_type': changeType,
        'description': description,
      });
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR LOG ERROR]',
        error: e,
        stackTrace: st,
        payload: {
          'radar_id': radarId,
          'user_id': userId,
          'change_type': changeType,
        },
      );
    }
  }

  Future<void> _insertNotification({
    required String userId,
    required String actorId,
    required String type,
    required String title,
    required String body,
    required String relatedId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'actor_id': actorId,
        'type': type,
        'title': title,
        'body': body,
        'related_id': relatedId,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR NOTIF ERROR]',
        error: e,
        stackTrace: st,
        payload: {'user_id': userId, 'type': type, 'related_id': relatedId},
      );
    }
  }

  Future<void> _notifyHostOnJoin({
    required String radarId,
    required String actorId,
    required String status,
  }) async {
    try {
      final event = await _supabase
          .from('radar_events')
          .select('creator_id, title')
          .eq('id', radarId)
          .single();
      final creatorId = event['creator_id']?.toString();
      if (creatorId == null || creatorId == actorId) return;
      final title = (event['title'] ?? 'Radar').toString();

      if (status.toUpperCase() == 'PENDING') {
        await _insertNotification(
          userId: creatorId,
          actorId: actorId,
          type: 'radar_join_request',
          title: 'Permintaan Join Radar',
          body: 'meminta bergabung ke "$title".',
          relatedId: radarId,
        );
      } else {
        await _insertNotification(
          userId: creatorId,
          actorId: actorId,
          type: 'radar_joined',
          title: 'Peserta Bergabung',
          body: 'bergabung ke "$title".',
          relatedId: radarId,
        );
      }
    } catch (e, st) {
      _logPostgrestError(
        tag: '[RADAR JOIN NOTIF ERROR]',
        error: e,
        stackTrace: st,
        payload: {'radar_id': radarId, 'actor_id': actorId},
      );
    }
  }
}
