
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/pages/radars/radar_chat_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/features/notifications/widgets/radar_invite_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final RadarService _radarService = RadarService();
  bool _isLoadingAction = false;
  List<Map<String, dynamic>> _invites = [];
  
  // Theme Colors
  static const Color _blue = Color(0xFF0088CC);
  static const Color _blueDark = Color(0xFF007AB8);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _black = Color(0xFF000000);
  static const Color _textSecondary = Color(0xFF555555);
  static const Color _muted = Color(0xFF9E9E9E);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _error = Color(0xFFE74C3C);

  @override
  void initState() {
    super.initState();
    _fetchInvites();
  }

  Future<void> _fetchInvites() async {
    // UPDATED: Using fetchRadarInvites (Participant System) instead of fetchMyInvites (V2 Invite System)
    // to align with CreatePersonalRadarPage which inserts into radar_participants directly.
    final invites = await _radarService.fetchRadarInvites(); // This fetches INVITED participants
    if (mounted) {
      setState(() {
        _invites = invites;
      });
    }
  }

  Future<void> _handleResponse(
    Map<String, dynamic> invite,
    bool accepted,
  ) async {
    setState(() => _isLoadingAction = true);
    
    // Extract radarId correctly from the flattened map (fetchRadarInvites flattens event props)
    // The structure returned by fetchRadarInvites puts 'id' of radar in 'id'.
    // Wait, fetchRadarInvites map logic:
    // return { ...event, schedule_time: ..., user_id: aspect ... }
    // So 'id' is the radar_events.id
    final radarId = (invite['id'] ?? '').toString();
    final title = (invite['title'] ?? 'Misa Bersama').toString();

    if (accepted) {
      try {
        // Accept -> Join Radar
        final result = await _radarService.joinRadar(radarId);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Undangan diterima!"),
            backgroundColor: _success,
          ),
        );

        if (result.chatRoomId != null && result.chatRoomId!.trim().isNotEmpty) {
           // Navigate to Chat
           // Ensure user is added to chat (joinRadar does this but verify)
           await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RadarChatPage(chatRoomId: result.chatRoomId!, title: title),
            ),
          );
        } else {
           // Fallback if chat room not ready yet (e.g. triggers slow)
           // Maybe try prepareChatForRadar
           final chatRoomId = await _radarService.prepareChatForRadar(radarId);
           if (chatRoomId != null && mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RadarChatPage(chatRoomId: chatRoomId, title: title),
                ),
              );
           }
        }

      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
              content: Text("Gagal menerima undangan: $e"),
              backgroundColor: _error,
            ),
          );
        }
      }
    } else {
      // Decline
      try {
        await _radarService.declineRadar(radarId);
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Undangan ditolak"),
                backgroundColor: _muted,
            ),
            );
        }
      } catch (e) {
         debugPrint("Error declining: $e");
      }
    }

    if (mounted) {
      setState(() {
        _invites.removeWhere((element) => element['id'] == radarId); // radarId is the id in this map
        _isLoadingAction = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchInvites,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader("Undangan Misa"),
                    const SizedBox(height: 12),
                    if (_invites.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _bg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          "Belum ada undangan misa baru.",
                          style: GoogleFonts.outfit(color: _muted),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _invites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => RadarInviteCard(
                           invite: _invites[index],
                           isLoading: _isLoadingAction,
                           onRespond: (accepted) => _handleResponse(_invites[index], accepted),
                        ),
                      ),
                    const SizedBox(height: 28),
                    _buildSectionHeader("Lainnya"),
                    const SizedBox(height: 12),
                    _buildGeneralNotificationItem(
                      "Admin",
                      "Selamat datang di MyCatholic App!",
                    ),
                    _buildGeneralNotificationItem(
                      "System",
                      "Lengkapi profil Anda untuk pengalaman lebih baik.",
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_white, _bg],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -40,
            child: _buildGlow(_blue.withOpacity(0.18), 200),
          ),
          Positioned(
            left: -40,
            bottom: -50,
            child: _buildGlow(_blueDark.withOpacity(0.12), 180),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue, _blueDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Notifikasi",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Update terbaru & undangan misa",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: _white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _black,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  _blue.withOpacity(0.8),
                  _blueDark.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
 
  Widget _buildGeneralNotificationItem(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _bg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              color: _muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
