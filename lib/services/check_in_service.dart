import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/social/data/chat_repository.dart';

class CheckInService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ChatRepository _chatRepository = ChatRepository();

  // --- CHECK IN ---
  Future<Map<String, dynamic>?> checkIn({
    required String churchId,
    String? scheduleId,
    String visibility = 'PUBLIC', // 'PUBLIC', 'FOLLOWERS', 'PRIVATE'
    required DateTime selectedMassTime,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("User not logged in");

    try {
      // 1. Auto-checkout previous active check-ins
      await _supabase
          .from('mass_checkins')
          .update({'status': 'FINISHED'})
          .eq('user_id', userId)
          .eq('status', 'ACTIVE');

      // 2. Insert new check-in
      final response = await _supabase.from('mass_checkins').insert({
        'user_id': userId,
        'church_id': churchId,
        'schedule_id': scheduleId,
        'check_in_time': DateTime.now().toUtc().toIso8601String(), // Log actual click time
        'mass_time': selectedMassTime.toUtc().toIso8601String(), // Actual mass time
        'status': 'ACTIVE',
        'visibility': visibility,
      }).select().single();

      return response;
    } catch (e) {
      debugPrint("CheckInService: Check-in error: $e");
      rethrow;
    }
  }

  // --- CHECK OUT ---
  Future<void> checkOut() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('mass_checkins')
          .update({'status': 'FINISHED'})
          .eq('user_id', userId)
          .eq('status', 'ACTIVE');
    } catch (e) {
      debugPrint("CheckInService: Check-out error: $e");
      rethrow;
    }
  }

  // --- GET CURRENT CHECK-IN ---
  Future<Map<String, dynamic>?> getCurrentCheckIn() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _supabase
          .from('mass_checkins')
          .select('*, churches(name)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE')
          .maybeSingle();

      if (response != null) {
        final checkInTime = DateTime.parse(response['check_in_time']).toLocal();
        final now = DateTime.now();
        
        // Auto-checkout if more than 3 hours
        if (now.difference(checkInTime).inHours >= 3) {
          await checkOut();
          return null;
        }
        return response;
      }
      return null;
    } catch (e) {
      debugPrint("CheckInService: getCurrentCheckIn error: $e");
      return null;
    }
  }

  // --- FETCH ACTIVE USERS AT CHURCH (With Privacy Logic) ---
  Future<List<Map<String, dynamic>>> fetchActiveUsers(String churchId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      // 1. Get my following list
      final List<dynamic> followingRes = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', myId);
      
      final Set<String> followingIds = followingRes
          .map((row) => row['following_id'] as String)
          .toSet();

      // 2. Fetch all active check-ins at this church (excluding me)
      //    Supabase join: profiles table for user info
      final List<dynamic> checkIns = await _supabase
          .from('mass_checkins')
          .select('*, profiles(id, full_name, avatar_url, role)')
          .eq('church_id', churchId)
          .eq('status', 'ACTIVE')
          .neq('user_id', myId);

      // 3. Filter based on visibility
      final List<Map<String, dynamic>> filteredUsers = [];

      for (var row in checkIns) {
        final String visibility = row['visibility'] ?? 'PUBLIC';
        final String userId = row['user_id'];
        
        // Skip user if their profile is null (data integrity check)
        if (row['profiles'] == null) continue;

        bool shouldShow = false;

        if (visibility == 'PUBLIC') {
          shouldShow = true;
        } else if (visibility == 'FOLLOWERS') {
          // Show only if I follow this user
          if (followingIds.contains(userId)) {
            shouldShow = true;
          }
        } else if (visibility == 'PRIVATE') {
          shouldShow = false;
        }

        if (shouldShow) {
          filteredUsers.add(Map<String, dynamic>.from(row));
        }
      }

      return filteredUsers;

    } catch (e) {
      debugPrint("CheckInService: fetchActiveUsers error: $e");
      return [];
    }
  }

  // --- INITIATE GREETING (CHAT) ---
  Future<String> initiateGreeting(String targetUserId, String targetUserName, String churchName) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("User not logged in");

    try {
      // 1. Check for existing Private Chat (via repository)
      final chatRoomId =
          await _chatRepository.getOrCreatePrivateChat(targetUserId);
      
      // 2. Send Greeting Message
      final content =
          "Hai $targetUserName, salam damai! Tadi kita sama-sama misa di $churchName. 🙏";
      
      await _supabase.from('social_messages').insert({
        'chat_id': chatRoomId,
        'sender_id': myId,
        'content': content,
        'type': 'text'
      });

      // Update last message in chat room
      await _supabase.from('social_chats').update({
        'last_message': "👋 Salam Damai",
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', chatRoomId);
      
      return chatRoomId;

    } catch (e) {
      debugPrint("CheckInService: initiateGreeting error: $e");
      rethrow;
    }
  }
}
