import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/models/schedule.dart';
import 'package:mychatolic_app/pages/search/friend_search_page.dart';

class ChurchDetailPage extends StatefulWidget {
  final Map<String, dynamic> churchData;

  const ChurchDetailPage({super.key, required this.churchData});

  @override
  State<ChurchDetailPage> createState() => _ChurchDetailPageState();
}

class _ChurchDetailPageState extends State<ChurchDetailPage> {
  final MasterDataService _masterService = MasterDataService();
  final RadarService _radarService = RadarService();
  bool _isLoading = true;

  // Grouped Data: Key = Day Name (e.g. "Minggu"), Value = List of Schedules
  Map<String, List<Schedule>> _schedulesByDay = {};

  // --- DESIGN SYSTEM CONSTANTS ---
  static const Color kBackgroundMain = Color(0xFFFFFFFF); // Putih Bersih
  static const Color kSurfaceCard = Color(0xFFF5F5F5);    // Abu sangat muda
  static const Color kPrimaryBrand = Color(0xFF0088CC);   // Primary Blue
  static const Color kTextPrimary = Color(0xFF000000);
  static const Color kTextSecondary = Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    try {
      final churchId = widget.churchData['id']?.toString();
      if (churchId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch schedules using the Service
      final schedules = await _masterService.fetchSchedules(churchId);

      // Explicit Sort: Ensure order is 100% correct
      // 1. Day of Week Ascending (0=Sunday, 6=Saturday)
      // 2. Time Start Ascending ("06:00" < "08:00")
      schedules.sort((a, b) {
        int dayComp = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayComp != 0) return dayComp; // Different days
        return a.timeStart.compareTo(b.timeStart); // Same day, sort by time
      });

      // Group by Day Text
      final grouped = <String, List<Schedule>>{};
      for (var s in schedules) {
        if (!grouped.containsKey(s.dayName)) grouped[s.dayName] = [];
        grouped[s.dayName]!.add(s);
      }

      if (mounted) {
        setState(() {
          _schedulesByDay = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schedules: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchMap() async {
    final lat = widget.churchData['latitude'];
    final lng = widget.churchData['longitude'];
    if (lat != null && lng != null) {
      final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lokasi tidak tersedia")));
    }
  }

  Future<void> _launchExternal(String? url) async {
    if (url == null || url.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link tidak tersedia")));
       return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch URL")));
    }
  }

  // --- RADAR FEATURE ---
  void _showCreateRadarModal(Schedule schedule) {
    final notesController = TextEditingController();
    bool isSubmitting = false;
    bool showForm = false; // State to toggle between Menu and Form

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                left: 20, right: 20, top: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STEP 1: MENU SELECTION ---
                  if (!showForm) ...[
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
                      ),
                    ),
                    Text(
                      "Misa ${schedule.dayName}, ${schedule.timeStart}",
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: kTextPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text("Pilih tipe radar yang ingin dibuat:", style: GoogleFonts.outfit(color: kTextSecondary)),
                    const SizedBox(height: 24),

                    // OPTION A: PUBLIC RADAR
                    _buildRadarOption(
                      icon: Icons.campaign_rounded,
                      color: Colors.blue,
                      title: "Buat Radar Misa",
                      subtitle: "Beritahu umat lain bahwa kamu akan Misa di sini.",
                      onTap: () {
                        setModalState(() => showForm = true);
                      },
                    ),
                    const SizedBox(height: 16),

                    // OPTION B: INVITE FRIEND
                    _buildRadarOption(
                      icon: Icons.person_add_rounded,
                      color: Colors.orange,
                      title: "Ajak Teman Spesifik",
                      subtitle: "Kirim undangan personal ke temanmu.",
                      onTap: () async {
                        // Capture Messenger & Navigator from the stable OUTER context
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        // 1. Close Modal
                        Navigator.pop(modalContext);

                        // 2. Select Friend
                        final selectedFriend = await navigator.push<Map<String, dynamic>>(
                          MaterialPageRoute(builder: (_) => const FriendSearchPage(isSelectionMode: true))
                        );

                        if (selectedFriend == null || !mounted) return;

                        // 3. Show Loading
                        messenger.showSnackBar(
                           const SnackBar(content: Text("Mengirim undangan..."), duration: Duration(seconds: 1))
                        );

                        try {
                           // 4. Calc Next Occurrence Date (Dart Weekday: 1=Mon, 7=Sun)
                           final now = DateTime.now();
                           
                           // Converting DB day (0=Sun) to Dart day (7=Sun)
                           int targetDayVal = (schedule.dayOfWeek == 0) ? 7 : schedule.dayOfWeek;
                           int currentDayVal = now.weekday; // 1-7
                           
                           // Calculate difference
                           int daysToAdd = (targetDayVal - currentDayVal + 7) % 7;
                           
                           // Check Time
                           final parts = schedule.timeStart.split(':');
                           final hour = int.parse(parts[0]);
                           final minute = int.parse(parts[1]);

                           // If same day, check if time has passed
                           if (daysToAdd == 0) {
                             final timeNow = now.hour * 60 + now.minute;
                             final timeMass = hour * 60 + minute;
                             if (timeNow > timeMass) {
                               daysToAdd = 7; // Move to next week
                             }
                           }
                           
                           final scheduleDate = DateTime(now.year, now.month, now.day + daysToAdd, hour, minute);

                           // 5. Call Service
                           await _radarService.createPersonalRadar(
                             targetUserId: selectedFriend['id'].toString(),
                             churchId: schedule.churchId,
                             churchName: widget.churchData['name'] ?? 'Gereja Ini',
                             scheduleTime: scheduleDate,
                             message: "Mengajak misa bersama.", // Default Message
                           );

                           if (mounted) {
                             messenger.showSnackBar(SnackBar(
                               content: Text("Undangan dikirim ke ${selectedFriend['full_name'] ?? 'Teman'}!"),
                               backgroundColor: Colors.green,
                             ));
                           }

                        } catch (e) {
                           if (mounted) {
                             messenger.showSnackBar(SnackBar(content: Text("Gagal: $e")));
                           }
                        }
                      },
                    ),
                    const SizedBox(height: 40),
                  ] 
                  
                  // --- STEP 2: PUBLIC RADAR FORM ---
                  else ...[
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setModalState(() => showForm = false);
                          },
                        ),
                        const SizedBox(width: 12),
                        Text("Buat Radar Misa", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                     Padding(
                       padding: const EdgeInsets.only(left: 32), // Align with title
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             "${schedule.dayName}, ${schedule.timeStart}",
                             style: GoogleFonts.outfit(color: kPrimaryBrand, fontWeight: FontWeight.bold, fontSize: 16),
                           ),
                           if (schedule.language != null)
                            Text(schedule.language!, style: GoogleFonts.outfit(color: kTextSecondary, fontSize: 14)),
                         ],
                       ),
                     ),
                    const SizedBox(height: 24),
                    
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: "Catatan (Opsional)",
                        hintText: "Contoh: Kumpul di parkiran depan...",
                        filled: true,
                        fillColor: kSurfaceCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          
                          setModalState(() => isSubmitting = true);
                          try {
                            await _radarService.createRadarFromSchedule(
                              scheduleId: schedule.id,
                              notes: notesController.text,
                            );
                            if (!mounted) return;
                            navigator.pop(); // Close Modal
                            messenger.showSnackBar(const SnackBar(
                              content: Text("Radar berhasil dibuat! Teman-temanmu akan diberitahu."),
                              backgroundColor: Colors.green,
                            ));
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (!mounted) return;
                            messenger.showSnackBar(SnackBar(content: Text("Gagal: $e")));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryBrand,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Buat Radar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildRadarOption({
    required IconData icon, 
    required Color color, 
    required String title, 
    required String subtitle,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Correctly accessing church data
    final name = widget.churchData['name'] ?? "Gereja";
    final address = widget.churchData['address'] ?? "Alamat tidak tersedia";
    final imageUrl = widget.churchData['image_url'];
    final socialUrl = widget.churchData['social_media_url'];
    final webUrl = widget.churchData['website_url'];

    return Scaffold(
      backgroundColor: kBackgroundMain, 
      body: CustomScrollView(
        slivers: [
          // 1. HEADER IMAGE (Expandable)
          SliverAppBar(
            expandedHeight: 250,
            backgroundColor: kBackgroundMain,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: kBackgroundMain,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: imageUrl != null 
                ? SafeNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fallbackColor: kSurfaceCard,
                  )
                : Container(
                    color: kSurfaceCard, 
                    child: const Icon(Icons.church, size: 64, color: Colors.grey)
                  ),
            ),
          ),

          // 2. CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & ADDRESS
                  Text(
                    name,
                    style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: kTextPrimary)
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Icon(Icons.location_on_outlined, size: 20, color: kTextSecondary),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Text(
                           address, 
                           style: GoogleFonts.outfit(fontSize: 14, color: kTextSecondary, height: 1.4),
                         )
                       ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ACTION BUTTONS
                  Row(
                    children: [
                       Expanded(child: _buildActionButton(Icons.map, "Peta", _launchMap)),
                       const SizedBox(width: 12),
                       Expanded(child: _buildActionButton(Icons.public, "Website", () => _launchExternal(webUrl ?? socialUrl))),
                    ],
                  ),
                  const SizedBox(height: 32),

                  
                  // --- SCHEDULE LIST ---
                  Text(
                    "Jadwal Misa",
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: kTextPrimary),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading)
                     const Padding(
                       padding: EdgeInsets.only(top: 20),
                       child: Center(child: CircularProgressIndicator(color: kPrimaryBrand)),
                     )
                  else if (_schedulesByDay.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: kSurfaceCard, borderRadius: BorderRadius.circular(12)),
                        child: Center(
                          child: Text("Jadwal belum tersedia", style: GoogleFonts.outfit(color: kTextSecondary)),
                        ),
                      )
                  else
                     // Render Schedule Groups
                     ..._schedulesByDay.entries.map((entry) {
                       return Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           // Day Header
                           Padding(
                             padding: const EdgeInsets.only(bottom: 12.0),
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: kTextPrimary.withValues(alpha: 0.05),
                                 borderRadius: BorderRadius.circular(8)
                               ),
                               child: Text(
                                 entry.key, 
                                 style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: kTextPrimary)
                               ),
                             ),
                           ),
                           
                           // Grid of Cards
                           GridView.builder(
                             physics: const NeverScrollableScrollPhysics(),
                             shrinkWrap: true,
                             itemCount: entry.value.length,
                             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                               crossAxisCount: 2,
                               childAspectRatio: 2.2,
                               crossAxisSpacing: 12,
                               mainAxisSpacing: 12,
                             ),
                             itemBuilder: (context, index) {
                               return _buildScheduleCard(entry.value[index]);
                             },
                           ),
                           const SizedBox(height: 24),
                         ],
                       );
                     }),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: kPrimaryBrand, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryBrand,
        side: const BorderSide(color: kPrimaryBrand),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildScheduleCard(Schedule s) {
    // Format "07:00:00" -> "07:00"
    final time = s.timeStart.length > 5 ? s.timeStart.substring(0, 5) : s.timeStart;
    final label = s.language ?? "Umum";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCreateRadarModal(s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Time & Language
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        time,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryBrand,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
