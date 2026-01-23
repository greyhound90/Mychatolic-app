import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;



  // --- AUTH ---
  User? get currentUser => _supabase.auth.currentUser;

// Master Data has been moved to master_data_service.dart





  // 9. Fetch Notifications
  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    try {
      // Mock notifications for now
      return [];
    } catch (e) {
      debugPrint("Fetch notifications error: $e");
      return [];
    }
  }

// Search Locations moved to master_data_service.dart



  // 13. Start Chat
  Future<String> startChat(String otherUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception("Not logged in");

    try {
      final response = await _supabase
          .from('social_chats')
          .select('id')
          .contains('participants', [myId, otherUserId])
          .maybeSingle();

      if (response != null) {
        return response['id'] as String;
      }
    } catch (e) {
      debugPrint("Start chat lookup failed: $e");
    }

    try {
      final newChat = await _supabase.from('social_chats').insert({
        'participants': [myId, otherUserId],
        'last_message': "Memulai percakapan",
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      return newChat['id'] as String;
    } catch (e) {
      throw Exception("Failed to start chat: $e");
    }
  }




}
