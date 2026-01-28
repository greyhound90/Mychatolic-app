import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class OtherUserProfilePage extends StatelessWidget {
  final String userId; // Changed to userId to fetch fresh data or pass map
  final Map<String, dynamic>? initialData; // Optional initial data

  const OtherUserProfilePage({super.key, required this.userId, this.initialData});

  @override
  Widget build(BuildContext context) {
    // Ideally fetch full profile, but for now use what we have or placeholder
    final name = initialData?['full_name'] ?? initialData?['name'] ?? 'Umat';
    final avatarUrl = initialData?['avatar_url'];
    final parish = initialData?['parish'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // Avatar
             Container(
               padding: const EdgeInsets.all(4),
               decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.blue, width: 2)),
               child: ClipOval(
                  child: SafeNetworkImage(
                    imageUrl: avatarUrl,
                    width: 100, height: 100,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.person,
                  ),
               ),
             ),
             const SizedBox(height: 16),
             Text(name, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
             if (parish != null)
               Text(parish, style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey)),
               
             const SizedBox(height: 32),
             
             // CHAT BUTTON (FIXED LOGIC)
             ElevatedButton.icon(
               onPressed: () {
                 Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SocialChatDetailPage(
                        chatId: 'new', // Logic handled by detail page or auto-redirect
                        otherUserId: userId,
                        opponentProfile: {
                           'id': userId,
                           'full_name': name,
                           'avatar_url': avatarUrl,
                        },
                      ),
                    ),
                 );
               },
               icon: const Icon(Icons.chat_bubble_outline),
               label: const Text("Kirim Pesan"),
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF0088CC),
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
