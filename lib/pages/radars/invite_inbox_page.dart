import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/pages/radar_detail_page.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class InviteInboxPage extends StatefulWidget {
  const InviteInboxPage({super.key});

  @override
  State<InviteInboxPage> createState() => _InviteInboxPageState();
}

class _InviteInboxPageState extends State<InviteInboxPage> {
  final RadarService _radarService = RadarService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _invites = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);
    final list = await _radarService.fetchMyInvites();
    if (!mounted) return;
    setState(() {
      _invites = list;
      _isLoading = false;
    });
  }

  Future<void> _respond(Map<String, dynamic> invite, bool accept) async {
    final inviteId = (invite['id'] ?? '').toString();
    if (inviteId.isEmpty) return;
    setState(() => _processing.add(inviteId));
    try {
      await _radarService.respondToInvite(inviteId: inviteId, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? "Undangan diterima" : "Undangan ditolak"),
        ),
      );
      if (accept) {
        final event = invite['event'] is Map
            ? Map<String, dynamic>.from(invite['event'] as Map)
            : null;
        if (event != null) {
          final radarEvent = RadarEvent.fromJson(event);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  RadarDetailPage(event: radarEvent, radarData: event),
            ),
          );
        }
      }
      await _loadInvites();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR INVITE INBOX] respond failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal memproses undangan")));
    } finally {
      if (mounted) setState(() => _processing.remove(inviteId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "Undangan Masuk",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvites,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _invites.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      "Tidak ada undangan baru",
                      style: GoogleFonts.outfit(color: Colors.grey[700]),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _invites.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final invite = _invites[index];
                  final inviter = invite['profiles'] is Map
                      ? Map<String, dynamic>.from(invite['profiles'] as Map)
                      : const <String, dynamic>{};
                  final event = invite['event'] is Map
                      ? Map<String, dynamic>.from(invite['event'] as Map)
                      : const <String, dynamic>{};

                  final inviterName = (inviter['full_name'] ?? 'Seseorang')
                      .toString();
                  final inviterAvatar = (inviter['avatar_url'] ?? '')
                      .toString();
                  final title = (event['title'] ?? 'Radar Misa').toString();
                  final whenRaw = (event['event_time'] ?? '').toString();
                  final when = DateTime.tryParse(whenRaw)?.toLocal();
                  final whenText = when != null
                      ? DateFormat('EEE, dd MMM • HH:mm').format(when)
                      : "-";

                  final inviteId = (invite['id'] ?? '').toString();
                  final isProcessing = _processing.contains(inviteId);

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: ClipOval(
                                  child: SafeNetworkImage(
                                    imageUrl: inviterAvatar,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  inviterName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            whenText,
                            style: GoogleFonts.outfit(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _respond(invite, false),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    "Tolak",
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _respond(invite, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0088CC),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: isProcessing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "Terima",
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
