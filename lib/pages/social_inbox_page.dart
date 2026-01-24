import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/features/social/search_user_page.dart';
import 'package:mychatolic_app/widgets/story_rail.dart'; // Import StoryRail

class SocialInboxPage extends StatefulWidget {
  const SocialInboxPage({super.key});

  @override
  State<SocialInboxPage> createState() => _SocialInboxPageState();
}

class _SocialInboxPageState extends State<SocialInboxPage> {
  final _supabase = Supabase.instance.client;

  // State untuk Chat & Cache Profile
  final Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  void initState() {
    super.initState();
  }

  // --- CHAT & CACHE LOGIC ---

  Future<void> _cacheProfiles(List<String> ids) async {
    // Filter ID yang belum ada di cache dan belum null
    final idsToFetch = ids
        .where((id) => !_profileCache.containsKey(id))
        .toSet()
        .toList();

    if (idsToFetch.isEmpty) return;

    try {
      // Menggunakan .filter('id', 'in', ids) sebagai pengganti .in_()
      final List<dynamic> data = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .filter('id', 'in', idsToFetch);

      if (mounted) {
        setState(() {
          for (var item in data) {
            _profileCache[item['id']] = item as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      debugPrint("Error caching profiles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Pesan",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUserPage()),
              );
            },
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.black,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. STORY SECTION (Now using StoryRail)
          const StoryRail(),

          const SizedBox(height: 10),

          // 2. CHAT BODY (List)
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI: CHAT LIST (OPTIMIZED)
  // ---------------------------------------------------------------------------
  Widget _buildChatList() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      return const Center(child: Text("Silakan login kembali."));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('social_chats')
          .stream(primaryKey: ['id'])
          .order('updated_at', ascending: false)
          .map((list) {
            return list.where((chat) {
              final participants = List<dynamic>.from(
                chat['participants'] ?? [],
              );
              final creatorId = chat['creator_id'];
              return participants.contains(myId) || creatorId == myId;
            }).toList();
          }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "Belum ada percakapan",
                  style: GoogleFonts.outfit(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // --- COLLECT MISSING PROFILES ---
        List<String> missingIds = [];
        for (var chat in chats) {
          final participants = List<dynamic>.from(chat['participants'] ?? []);
          final opponentId = participants.firstWhere(
            (id) => id != myId,
            orElse: () => null,
          );
          if (opponentId != null && !_profileCache.containsKey(opponentId)) {
            missingIds.add(opponentId.toString());
          }
        }

        // Trigger batch fetch jika ada yang hilang
        if (missingIds.isNotEmpty) {
          // Gunakan Future.microtask agar tidak error setState saat build
          Future.microtask(() => _cacheProfiles(missingIds));
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return _buildChatItem(chat, myId);
          },
        );
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, String myId) {
    final participants = List<dynamic>.from(chat['participants'] ?? []);
    final opponentId = participants.firstWhere(
      (id) => id != myId,
      orElse: () => null,
    );

    if (opponentId == null) return const SizedBox.shrink();

    // BACA DARI CACHE (Synchronous)
    final profile = _profileCache[opponentId];

    // Tampilan Loading Sementara (Shimmer-like) jika data belum siap
    if (profile == null) {
      return ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.grey),
        title: Container(width: 100, height: 16, color: Colors.grey[200]),
        subtitle: Container(width: 200, height: 12, color: Colors.grey[100]),
      );
    }

    final name = profile['full_name'] ?? "User";
    final avatarUrl = profile['avatar_url'];
    final lastMsg = chat['last_message'] ?? "Memulai percakapan";
    final updatedAt = chat['updated_at'];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: SafeNetworkImage(
        imageUrl: avatarUrl,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(28),
        fit: BoxFit.cover,
        fallbackIcon: Icons.person,
      ),
      title: Text(
        name,
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          lastMsg,
          style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            updatedAt != null
                ? timeago.format(DateTime.parse(updatedAt), locale: 'en_short')
                : "",
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
          ),
          // const SizedBox(height: 4),
          // Optional: Read indicator or Unread Count here
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SocialChatDetailPage(
              chatId: chat['id'],
              opponentProfile: {
                'id': opponentId,
                'full_name': name,
                'avatar_url': avatarUrl,
              },
            ),
          ),
        );
      },
    );
  }
}
