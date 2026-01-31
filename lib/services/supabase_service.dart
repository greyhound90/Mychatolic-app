import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/features/social/data/chat_repository.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;
  final ChatRepository _chatRepository = ChatRepository();

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
    try {
      return await _chatRepository.getOrCreatePrivateChat(otherUserId);
    } catch (e) {
      throw Exception("Failed to start chat: $e");
    }
  }
}
