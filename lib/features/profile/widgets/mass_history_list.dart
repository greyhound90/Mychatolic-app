import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class MassHistoryList extends StatefulWidget {
  final String userId;
  final bool isMyProfile;

  const MassHistoryList({
    super.key,
    required this.userId,
    this.isMyProfile = false,
  });

  @override
  State<MassHistoryList> createState() => _MassHistoryListState();
}

class _MassHistoryListState extends State<MassHistoryList> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    try {
      final response = await _supabase
          .from('mass_checkins')
          .select('*, churches(name)') // Join with churches table
          .eq('user_id', widget.userId)
          .eq('status', 'FINISHED')
          .order('check_in_time', ascending: false) // Newest first
          .limit(20); // Limit nicely

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      // Format: "Minggu, 28 Jan • 18:00"
      return DateFormat('EEEE, d MMM • HH:mm', 'id_ID').format(date);
    } catch (_) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Gagal memuat riwayat.", style: GoogleFonts.outfit(color: Colors.grey)));
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  widget.isMyProfile 
                      ? "Belum ada riwayat misa.\nYuk check-in misa pertamamu!"
                      : "Belum ada riwayat misa.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(), // Usually inside a ScrollView profile
          shrinkWrap: true,
          itemCount: data.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            final item = data[index];
            final churchName = item['churches']?['name'] ?? 'Gereja tidak dikenal';
            final massTimeRaw = item['mass_time'] ?? item['check_in_time'];
            final dateStr = _formatDate(massTimeRaw);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[100]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50], 
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Icon(Icons.church_outlined, color: Colors.blue[700], size: 20),
                  ),
                  const SizedBox(width: 12),
                  
                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(churchName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(dateStr, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                          ],
                        )
                      ],
                    ),
                  ),

                  // Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20), 
                      border: Border.all(color: Colors.green[100]!)
                    ),
                    child: Text("Selesai", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[700])),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
