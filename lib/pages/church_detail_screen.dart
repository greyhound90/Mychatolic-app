import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/schedule.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ChurchDetailScreen extends StatefulWidget {
  final Church church;

  const ChurchDetailScreen({super.key, required this.church});

  @override
  State<ChurchDetailScreen> createState() => _ChurchDetailScreenState();
}

class _ChurchDetailScreenState extends State<ChurchDetailScreen> {
  final MasterDataService _masterService = MasterDataService();
  late Future<List<Schedule>> _schedulesFuture;

  @override
  void initState() {
    super.initState();
    _schedulesFuture = _masterService.fetchSchedules(widget.church.id);
  }

  // Convert int day to String name
  String _getDayName(int day) {
    switch (day) {
      case 0: return "MINGGU";
      case 1: return "SENIN";
      case 2: return "SELASA";
      case 3: return "RABU";
      case 4: return "KAMIS";
      case 5: return "JUMAT";
      case 6: return "SABTU";
      default: return "HARI LAIN";
    }
  }

  // Group schedules by day
  Map<int, List<Schedule>> _groupSchedules(List<Schedule> schedules) {
    final Map<int, List<Schedule>> grouped = {};
    for (var s in schedules) {
      if (!grouped.containsKey(s.dayOfWeek)) {
        grouped[s.dayOfWeek] = [];
      }
      grouped[s.dayOfWeek]!.add(s);
    }
    // Sort keys just in case
    final sortedKeys = grouped.keys.toList()..sort();
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, grouped[k]!)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          // 1. HEADER
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.church.name,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.church.imageUrl != null
                      ? SafeNetworkImage(
                          imageUrl: widget.church.imageUrl!,
                          fit: BoxFit.cover,
                          fallbackColor: kPrimary,
                          fallbackIcon: Icons.church_outlined,
                          iconColor: Colors.white30,
                        )
                      : Container(
                          color: kPrimary,
                          child: const Icon(Icons.church_outlined, size: 80, color: Colors.white30),
                        ),
                  // Gradient Overlay for Readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7)
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. CONTENT (SCHEDULES)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Jadwal Misa", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: kTextTitle)),
                  const SizedBox(height: 16),
                  
                  FutureBuilder<List<Schedule>>(
                    future: _schedulesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return Text("Gagal memuat jadwal: ${snapshot.error}", style: const TextStyle(color: Colors.red));
                      }

                      final schedules = snapshot.data ?? [];
                      if (schedules.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Text("Belum ada jadwal tersedia.")),
                        );
                      }

                      final grouped = _groupSchedules(schedules);

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: grouped.keys.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final dayKey = grouped.keys.elementAt(index);
                          final daySchedules = grouped[dayKey]!;
                          final dayName = _getDayName(dayKey);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Day Header
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: kPrimary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dayName,
                                  style: GoogleFonts.outfit(color: kPrimary, fontWeight: FontWeight.bold),
                                ),
                              ),
                              
                              // List of Masses
                              ...daySchedules.map((schedule) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0,2))
                                    ],
                                    border: Border.all(color: kBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_filled, color: kSecondary, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        schedule.timeStart, // e.g. "08:00"
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: kTextTitle),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (schedule.label != null && schedule.label!.isNotEmpty)
                                              Text(schedule.label!, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: kTextBody)),
                                            if (schedule.language != null)
                                              Text(schedule.language!, style: GoogleFonts.outfit(fontSize: 12, color: kTextMeta)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              }), 
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
