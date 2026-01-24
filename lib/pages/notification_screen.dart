import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/pages/radars/radar_chat_page.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final RadarService _radarService = RadarService();
  bool _isLoadingAction = false;
  List<Map<String, dynamic>> _invites =
      []; // Using generic map for now, until we fully migrate to MassInvitation model usage
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
    final invites = await _radarService.fetchMyInvites();
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
    if (accepted) {
      try {
        final inviteId = (invite['id'] ?? '').toString();
        await _radarService.respondToInvite(inviteId: inviteId, accept: true);
        if (!mounted) return;

        final event = invite['event'] is Map
            ? Map<String, dynamic>.from(invite['event'] as Map)
            : const <String, dynamic>{};
        final radarId = (event['id'] ?? '').toString();
        final title = (event['title'] ?? 'Grup Radar').toString();

        final chatRoomId = await _radarService.prepareChatForRadar(radarId);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Undangan diterima!"),
            backgroundColor: _success,
          ),
        );

        if (chatRoomId != null && chatRoomId.trim().isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RadarChatPage(chatRoomId: chatRoomId, title: title),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gagal menerima undangan"),
              backgroundColor: _error,
            ),
          );
        }
      }
    } else {
      try {
        final inviteId = (invite['id'] ?? '').toString();
        await _radarService.respondToInvite(inviteId: inviteId, accept: false);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Undangan ditolak"),
            backgroundColor: _muted,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _invites.removeWhere((element) => element['id'] == invite['id']);
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
                              color: Colors.black.withValues(alpha: 0.04),
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
                        shrinkWrap:
                            true, // Vital for nesting in SingleChildScrollView
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _invites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _buildInvitationCard(_invites[index]),
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
            child: _buildGlow(_blue.withValues(alpha: 0.18), 200),
          ),
          Positioned(
            left: -40,
            bottom: -50,
            child: _buildGlow(_blueDark.withValues(alpha: 0.12), 180),
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
            color: _blue.withValues(alpha: 0.28),
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
                    color: _white.withValues(alpha: 0.9),
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
              color: _white.withValues(alpha: 0.2),
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
                  _blue.withValues(alpha: 0.8),
                  _blueDark.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invite) {
    final senderProfile = invite['profiles'] ?? {};
    final event = invite['event'] is Map
        ? Map<String, dynamic>.from(invite['event'] as Map)
        : const <String, dynamic>{};
    final churchName = event['church_name'] ?? 'Gereja';
    final scheduleTimeStr = event['event_time'];
    DateTime? scheduleTime;
    if (scheduleTimeStr != null) {
      scheduleTime = DateTime.tryParse(scheduleTimeStr);
    }
    final message = event['description'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SafeNetworkImage(
                  imageUrl: senderProfile['avatar_url'] ?? '',
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  // Removed fallbackWidget as requested, rely on widget default
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          color: _black,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: senderProfile['full_name'] ?? 'Seseorang',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " mengajak misa di "),
                          TextSpan(
                            text: churchName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (scheduleTime != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: _muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat(
                              'EEEE, d MMM HH:mm',
                              'id_ID',
                            ).format(scheduleTime),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (message != null && message.toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '"$message"',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: _textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoadingAction
                      ? null
                      : () => _handleResponse(invite, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    "Tolak",
                    style: GoogleFonts.outfit(color: _error),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingAction
                      ? null
                      : () => _handleResponse(invite, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Terima",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
