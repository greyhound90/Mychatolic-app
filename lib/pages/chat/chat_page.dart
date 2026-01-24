import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For BackdropFilter
import 'chat_detail_page.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // --- DESIGN SYSTEM CONSTANTS (White UI) ---

  static const Color kTextTitle = Color(0xFF0F172A); // Navy 900
  static const Color kTextBody = Color(0xFF334155); // Slate 700
  static const Color kTextMeta = Color(0xFF64748B); // Slate 500
  static const Color kCardColor = kSurface;

  final SupabaseClient _supabase = Supabase.instance.client;

  // Data
  List<Map<String, dynamic>> _storyProfiles = [];
  bool _isLoadingStories = true;

  // Dummy Chats (Fallback/Prototype)
  final List<Map<String, dynamic>> _dummyChats = [
    {
      "id": 1,
      "name": "Romo Budi",
      "role": "Romo",
      "message": "Berkah Dalem, misa besok jadi jam 5 ya?",
      "time": "10:30",
      "unread": 2,
      "avatar_url": "https://i.pravatar.cc/150?u=romo",
    },
    {
      "id": 2,
      "name": "Suster Levina",
      "role": "Suster",
      "message": "Terima kasih atas donasinya, Pak.",
      "time": "Kemarin",
      "unread": 0,
      "avatar_url": "https://i.pravatar.cc/150?u=suster",
    },
    {
      "id": 3,
      "name": "Komunitas OMK",
      "role": "Grup",
      "message": "Stefanus: Jangan lupa latihan koor nanti malam!",
      "time": "Kemarin",
      "unread": 5,
      "avatar_url": "",
    },
    {
      "id": 4,
      "name": "Sekretariat Paroki",
      "role": "Admin",
      "message": "Surat baptis sudah bisa diambil.",
      "time": "Senin",
      "unread": 1,
      "avatar_url": "https://i.pravatar.cc/150?u=admin",
    },
    {
      "id": 5,
      "name": "Ibu Theresia",
      "role": "Umat",
      "message": "Baik, nanti saya kabari lagi.",
      "time": "Minggu",
      "unread": 0,
      "avatar_url": "https://i.pravatar.cc/150?u=theresia",
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchStoryProfiles();
  }

  Future<void> _fetchStoryProfiles() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', _supabase.auth.currentUser?.id ?? '')
          .limit(10);

      if (mounted) {
        setState(() {
          _storyProfiles = List<Map<String, dynamic>>.from(res);
          _isLoadingStories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stories: $e");
      if (mounted) setState(() => _isLoadingStories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        backgroundColor: kBackground.withValues(alpha: 0.8),
        elevation: 0,
        title: Text(
          "Pesan",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 28,
            color: kTextTitle,
            letterSpacing: 0.5,
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: kCardColor,
              shape: BoxShape.circle,
              // border: Border.all(color: kBorder),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search, color: kTextBody),
              tooltip: "Cari Pesan",
            ),
          ),

          // NEW CHAT ACTION (Correctly Placed)
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kSecondary, kPrimary]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kSecondary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                // Future: Open New Chat Dialog
              },
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
              ),
              tooltip: "Pesan Baru",
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- SECTION 1: STORY BAR ---
          // Fixed Height to 125.0 to prevent pixel overflow
          Container(
            height: 125.0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              // First item is My Story, then fetched profiles
              itemCount: 1 + (_isLoadingStories ? 5 : _storyProfiles.length),
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                if (index == 0) return _buildMyStory();

                if (_isLoadingStories) return _buildSkeletonStory();

                final profile = _storyProfiles[index - 1]; // Offset index
                return _buildFriendStory(profile);
              },
            ),
          ),

          // --- SECTION 2: CHAT LIST ---
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 100,
              ), // Padding ensures last item visible
              itemCount: _dummyChats.length,
              itemBuilder: (context, index) {
                final chat = _dummyChats[index];
                return _buildChatItem(chat);
              },
            ),
          ),
        ],
      ),
      // NO FAB (Removed to avoid clutter)
    );
  }

  // --- WIDGETS ---

  Widget _buildMyStory() {
    // FIX COMPILATION ERROR: Explicitly extract avatarUrl
    final currentUser = _supabase.auth.currentUser;
    final avatarUrl = currentUser?.userMetadata?['avatar_url'];

    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kPrimary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: kCardColor,
                child: avatarUrl == null || avatarUrl.toString().isEmpty
                    ? Center(
                        child: Text(
                          "?",
                          style: GoogleFonts.outfit(
                            color: kTextMeta,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      )
                    : SafeNetworkImage(
                        imageUrl: avatarUrl?.toString(),
                        width: 56,
                        height: 56,
                        borderRadius: BorderRadius.circular(28),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                        iconColor: kTextMeta,
                        fallbackColor: kCardColor,
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBackground, width: 2),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Cerita Anda",
          style: GoogleFonts.outfit(color: kTextBody, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFriendStory(Map profile) {
    String name = profile['full_name'] ?? "User";
    String firstName = name.split(" ").first;
    String? avatarUrl = profile['avatar_url'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            // Gradient Ring for "Story"
            gradient: LinearGradient(
              colors: [kSecondary, kPrimary],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(2), // Gap
            decoration: const BoxDecoration(
              color: kBackground,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: kCardColor,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Center(
                      child: Text(
                        firstName.isNotEmpty ? firstName[0] : "?",
                        style: GoogleFonts.outfit(
                          color: kTextTitle,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : SafeNetworkImage(
                      imageUrl: avatarUrl,
                      width: 56,
                      height: 56,
                      borderRadius: BorderRadius.circular(28),
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                      iconColor: kTextTitle,
                      fallbackColor: kCardColor,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          firstName,
          style: GoogleFonts.outfit(color: kTextBody, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSkeletonStory() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: kCardColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 8,
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildChatItem(Map chat) {
    final bool isUnread = chat['unread'] > 0;
    final String? avatarUrl = chat['avatar_url'];
    final String name = chat['name'] ?? "User";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              // Passing chat ID and Name to detail page
              MaterialPageRoute(
                builder: (_) => ChatDetailPage(chatId: chat['id'], name: name),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          splashColor: kPrimary.withValues(alpha: 0.1),
          highlightColor: kPrimary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // AVATAR
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isUnread
                          ? kPrimary.withValues(alpha: 0.1)
                          : kCardColor,
                      child: SafeNetworkImage(
                        imageUrl: avatarUrl,
                        width: 56,
                        height: 56,
                        borderRadius: BorderRadius.circular(28),
                        fit: BoxFit.cover,
                        fallbackColor: isUnread
                            ? kPrimary.withValues(alpha: 0.1)
                            : kCardColor,
                        fallbackIcon: Icons.person,
                        iconColor: kTextTitle,
                      ),
                    ),
                    if (isUnread)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981), // Online Green
                            shape: BoxShape.circle,
                            border: Border.all(color: kBackground, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.outfit(
                                color: kTextTitle,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            chat['time'],
                            style: GoogleFonts.outfit(
                              color: isUnread ? kPrimary : kTextMeta,
                              fontSize: 12,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat['message'],
                              style: GoogleFonts.outfit(
                                color: isUnread ? kTextTitle : kTextBody,
                                fontSize: 13,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: kPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat['unread'].toString(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
