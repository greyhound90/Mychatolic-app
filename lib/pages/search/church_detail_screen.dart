import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
// Import Chat Detail Page
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';

class ChurchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> churchData;

  const ChurchDetailScreen({super.key, required this.churchData});

  @override
  State<ChurchDetailScreen> createState() => _ChurchDetailScreenState();
}

class _ChurchDetailScreenState extends State<ChurchDetailScreen> {
  final _supabase = Supabase.instance.client;
  static const Color _brandBlue = Color(0xFF0088CC);

  // State: Map of "Schedule Time ISO String" -> "Chat Group ID"
  // If a schedule time exists in this map, it means the user has joined it.
  Map<String, String> _joinedRadars = {};
  @override
  void initState() {
    super.initState();
    _fetchJoinedStatus();
  }

  // --- 1. FETCH STATUS ---
  Future<void> _fetchJoinedStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      // Query active radars for this user & current church
      final response = await _supabase
          .from('radars')
          .select('schedule_time, chat_group_id')
          .eq('user_id', user.id)
          .eq('church_id', widget.churchData['id'])
          .eq('status', 'active'); // Only active sessions

      final Map<String, String> fetched = {};

      // We expect a List of Maps
      for (var item in (response as List<dynamic>)) {
        final timeIso = item['schedule_time'] as String;
        final chatId = item['chat_group_id'] as String?;
        if (chatId != null) {
          fetched[timeIso] = chatId;
        }
      }

      if (mounted) {
        setState(() {
          _joinedRadars = fetched;
        });
      }
    } catch (e) {
      debugPrint("Error fetching joined status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final church = widget.churchData;
    final String name = church['name'] ?? 'Nama Gereja';
    final String address = church['address'] ?? 'Alamat tidak tersedia';
    final String imageUrl = church['image_url'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 1. Header with Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: _brandBlue,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SafeNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fallbackIcon: Icons.church,
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black26,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 2. Info & Map Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Map Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _launchMap(address),
                      icon: const Icon(Icons.map, color: _brandBlue),
                      label: Text(
                        "Lihat di Peta",
                        style: GoogleFonts.outfit(color: _brandBlue),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _brandBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const Divider(height: 40, thickness: 1),
                  Text(
                    "Jadwal Misa",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Mass Schedules Builder
          SliverToBoxAdapter(child: _buildMassScheduleList()),

          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildMassScheduleList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('mass_schedules')
          .select()
          .eq('church_id', widget.churchData['id'])
          .order('time_start', ascending: true) // Initial order
          .asStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("Gagal memuat jadwal."),
            ),
          );
        }

        final schedules = snapshot.data ?? [];
        if (schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Belum ada jadwal misa.",
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
          );
        }

        // Grouping by Day Name
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var s in schedules) {
          final day = s['day_name'] ?? 'Lainnya';
          if (!grouped.containsKey(day)) grouped[day] = [];
          grouped[day]!.add(s);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: grouped.entries.map((entry) {
              return _buildDayGroup(entry.key, entry.value);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDayGroup(String dayName, List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              dayName,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Grid or Wrap of Times
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              final timeString =
                  item['time_start']?.toString().substring(0, 5) ??
                  "00:00"; // Take HH:mm
              final lang = item['language'] ?? 'ID';

              // --- 2. CHECK STATUS LOGIC ---
              // We need to calculate the exact DateTime key to match our _joinedRadars keys
              final nextMassDate = _getNextMassDate(dayName, timeString);
              final isoKey = nextMassDate?.toIso8601String();
              final isJoined =
                  (isoKey != null && _joinedRadars.containsKey(isoKey));
              final chatGroupId = isJoined ? _joinedRadars[isoKey] : null;

              final boxColor = isJoined ? _brandBlue : Colors.white;
              final borderColor = isJoined
                  ? _brandBlue
                  : _brandBlue.withValues(alpha: 0.3);
              final textColor = isJoined ? Colors.white : _brandBlue;
              final subTextColor = isJoined ? Colors.white70 : Colors.grey;

              return InkWell(
                onTap: () {
                  // Navigate to Chat IF joined
                  if (isJoined && chatGroupId != null) {
                    _openChat(chatGroupId, dayName, timeString);
                  } else {
                    _handleJoinRadar(dayName, timeString);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: boxColor, // FILL COLOR if joined
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _brandBlue.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        children: [
                          Text(
                            timeString,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isJoined ? "Joined" : "$lang",
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isJoined ? Icons.chat_bubble : Icons.add_circle,
                        color: textColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- LOGIC ---

  void _openChat(String chatId, String dayName, String timeString) {
    final churchName = widget.churchData['name'] ?? 'Gereja';
    final groupName =
        "Misa $dayName $timeString - $churchName"; // Reconstruct name locally or fetch

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SocialChatDetailPage(
          chatId: chatId,
          opponentProfile: {
            'full_name': groupName,
            'avatar_url':
                "https://id.pinterest.com/herlambanggunaw/gambar-gereja/",
            'is_group': true,
          },
        ),
      ),
    ).then((_) {
      // --- 3. REFRESH ON RETURN ---
      _fetchJoinedStatus();
    });
  }

  Future<void> _handleJoinRadar(String dayName, String timeString) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login terlebih dahulu.")),
      );
      return;
    }

    // 1. Calculate Date
    DateTime? nextMassDate = _getNextMassDate(dayName, timeString);
    if (nextMassDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format hari/jam tidak valid.")),
      );
      return;
    }

    // Formatting for Group Name: "Misa Minggu 08:00 - Katedral"
    // Use widget.churchData['name']
    final churchName = widget.churchData['name'] ?? 'Gereja';
    final groupName = "Misa $dayName $timeString - $churchName";
    final eventDateIso = nextMassDate.toIso8601String();

    // Loading Feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String chatId = '';

      // 2. CHECK EXISTING GROUP
      // Find chat where is_group=true, group_name matches, event_date matches.
      final existingChat = await _supabase
          .from('social_chats')
          .select()
          .eq('is_group', true)
          .eq('group_name', groupName)
          .eq('event_date', eventDateIso)
          .maybeSingle();

      if (existingChat != null) {
        chatId = existingChat['id'];
      } else {
        // 3. CREATE NEW GROUP
        final avatarUrl =
            "https://id.pinterest.com/herlambanggunaw/gambar-gereja/";

        final newChat = await _supabase
            .from('social_chats')
            .insert({
              'is_group': true,
              'group_name': groupName,
              'event_date': eventDateIso,
              'group_avatar': avatarUrl, // As requested
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        chatId = newChat['id'];
      }

      // 4. JOIN CHAT (Chat Members)
      await _supabase.from('chat_members').upsert({
        'chat_id': chatId,
        'user_id': user.id,
        'joined_at': DateTime.now().toIso8601String(),
      }, onConflict: 'chat_id, user_id');

      // 5. INSERT RADAR (Update with chat_group_id)
      final existingRadar = await _supabase
          .from('radars')
          .select()
          .eq('user_id', user.id)
          .eq('church_id', widget.churchData['id'])
          .eq('schedule_time', eventDateIso)
          .maybeSingle();

      if (existingRadar == null) {
        final expiresAt = nextMassDate
            .add(const Duration(hours: 24))
            .toIso8601String();
        await _supabase.from('radars').insert({
          'user_id': user.id,
          'church_id': widget.churchData['id'],
          'schedule_time': eventDateIso,
          'expires_at': expiresAt,
          'status': 'active',
          'chat_group_id': chatId, // NEW FIELD
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Berhasil bergabung ke Radar & Grup Misa!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Membuka Grup Misa..."),
              backgroundColor: _brandBlue,
            ),
          );
        }
      }

      if (mounted) Navigator.pop(context); // Close loading

      // Refresh status immediately so UI updates even if we come back
      await _fetchJoinedStatus();

      // 6. NAVIGATE TO SOGIAL CHAT DETAIL PAGE
      if (mounted) {
        _openChat(chatId, dayName, timeString);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("Error join radar group: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal bergabung: $e")));
      }
    }
  }

  DateTime? _getNextMassDate(String dayNameIndo, String timeString) {
    try {
      int targetWeekday = 0;
      switch (dayNameIndo.toLowerCase()) {
        case 'senin':
          targetWeekday = DateTime.monday;
          break;
        case 'selasa':
          targetWeekday = DateTime.tuesday;
          break;
        case 'rabu':
          targetWeekday = DateTime.wednesday;
          break;
        case 'kamis':
          targetWeekday = DateTime.thursday;
          break;
        case 'jumat':
          targetWeekday = DateTime.friday;
          break;
        case 'sabtu':
          targetWeekday = DateTime.saturday;
          break;
        case 'minggu':
          targetWeekday = DateTime.sunday;
          break;
        default:
          return null;
      }

      final now = DateTime.now();
      int currentWeekday = now.weekday;

      int daysToAdd = (targetWeekday - currentWeekday + 7) % 7;
      if (daysToAdd == 0) {
        final timeParts = timeString.split(':');
        final massTimeToday = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        if (massTimeToday.isBefore(now)) {
          daysToAdd = 7;
        }
      }

      final targetDate = now.add(Duration(days: daysToAdd));
      final timeParts = timeString.split(':');

      return DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchMap(String address) async {
    final query = Uri.encodeComponent(address);
    final googleMapUrl =
        "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(googleMapUrl))) {
      await launchUrl(Uri.parse(googleMapUrl));
    }
  }
}
