import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ManageParticipantsPage extends StatefulWidget {
  final String radarId;
  final String radarTitle;

  const ManageParticipantsPage({
    super.key,
    required this.radarId,
    required this.radarTitle,
  });

  @override
  State<ManageParticipantsPage> createState() => _ManageParticipantsPageState();
}

class _ManageParticipantsPageState extends State<ManageParticipantsPage> {
  final RadarService _radarService = RadarService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _pending = [];
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    final list = await _radarService.fetchPendingParticipants(widget.radarId);
    if (!mounted) return;
    setState(() {
      _pending = list;
      _isLoading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> participant) async {
    final userId = (participant['user_id'] ?? '').toString();
    if (userId.isEmpty) return;
    setState(() => _processing.add(userId));
    try {
      await _radarService.approveParticipant(widget.radarId, userId);
      if (!mounted) return;
      setState(() => _pending.removeWhere(
            (p) => (p['user_id'] ?? '').toString() == userId,
          ));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Peserta disetujui")),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR APPROVE UI] $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal menyetujui peserta")),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(userId));
    }
  }

  Future<void> _reject(Map<String, dynamic> participant) async {
    final userId = (participant['user_id'] ?? '').toString();
    if (userId.isEmpty) return;
    setState(() => _processing.add(userId));
    try {
      await _radarService.rejectParticipant(widget.radarId, userId);
      if (!mounted) return;
      setState(() => _pending.removeWhere(
            (p) => (p['user_id'] ?? '').toString() == userId,
          ));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Peserta ditolak")),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR REJECT UI] $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal menolak peserta")),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(userId));
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
          "Kelola Peserta",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadPending,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _pending.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Text(
                          "Tidak ada permintaan join.",
                          style: GoogleFonts.outfit(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pending.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _pending[index];
                      final profile = item['profiles'] is Map
                          ? Map<String, dynamic>.from(item['profiles'] as Map)
                          : const <String, dynamic>{};
                      final name = (profile['full_name'] ?? 'Umat').toString();
                      final avatarUrl =
                          (profile['avatar_url'] ?? '').toString();
                      final userId = (item['user_id'] ?? '').toString();
                      final isProcessing = _processing.contains(userId);

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            child: ClipOval(
                              child: SafeNetworkImage(
                                imageUrl: avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            "Ingin bergabung",
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                          trailing: isProcessing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "Tolak",
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _reject(item),
                                    ),
                                    IconButton(
                                      tooltip: "Setujui",
                                      icon: const Icon(
                                        Icons.check,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _approve(item),
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
