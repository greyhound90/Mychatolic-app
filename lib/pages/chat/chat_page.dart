import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_detail_page.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ChatPage extends StatefulWidget {
  final String? partnerId;
  final String? initialMessage;
  const ChatPage({super.key, this.partnerId, this.initialMessage});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Auto Redirect ke chat jika ada partnerId dari profil
    if (widget.partnerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint("DEBUG: Auto-redirecting to chat with partnerId: ${widget.partnerId}");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              chatId: 'new', // Placeholder, akan dihandle detail page
              name: "Chat",
              partnerId: widget.partnerId,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan user sudah login
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text("Silakan login.")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Pesan", 
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A), // Navy
            fontSize: 24,
          )
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Hide back button if needed, or set to true
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('my_chat_list')
            .stream(primaryKey: ['room_id'])
            .eq('owner_id', userId)
            .order('last_time', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             debugPrint("Stream Error: ${snapshot.error}");
             return Center(child: Text("Terjadi kesalahan memuat data."));
          }
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final chats = snapshot.data!;
          
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                   const SizedBox(height: 16),
                   Text("Belum ada pesan", style: GoogleFonts.outfit(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  child: ClipOval(
                    child: SafeNetworkImage(
                      imageUrl: chat['avatar_url'], 
                      width: 56, 
                      height: 56,
                      fit: BoxFit.cover,
                      fallbackIcon: Icons.person,
                      iconColor: Colors.grey,
                    ),
                  ),
                ),
                title: Text(
                  chat['display_name'] ?? 'User',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                subtitle: Text(
                  chat['last_message'] ?? '...', 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
                ),
                trailing: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     if (chat['unread_count'] != null && chat['unread_count'] > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0088CC),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          chat['unread_count'].toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                   ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatDetailPage(
                        chatId: chat['room_id'],
                        name: chat['display_name'] ?? 'Chat',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
