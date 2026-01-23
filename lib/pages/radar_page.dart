import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/radar_event_card.dart';
import 'package:mychatolic_app/pages/radar_detail_page.dart';
import 'package:mychatolic_app/pages/create_radar_screen.dart';
import 'package:mychatolic_app/pages/radars/radar_chat_page.dart';
import 'package:mychatolic_app/pages/radars/invite_inbox_page.dart';

class RadarPage extends StatefulWidget {
  const RadarPage({super.key});

  @override
  State<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends State<RadarPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RadarService _radarService = RadarService();
  final String _myUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  static const int _pageSize = 10;
  List<Map<String, dynamic>> _publicRadars = [];
  bool _isLoadingPublic = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshPublicRadars();
  }

  void _refreshPublicRadars() {
    _loadRadars(refresh: true);
  }

  Future<void> _loadRadars({bool refresh = false}) async {
    if (_isLoadingPublic || _isLoadingMore) return;
    if (refresh) {
      _currentPage = 0;
      _hasMoreData = true;
    }
    if (!_hasMoreData) return;

    setState(() {
      if (_currentPage == 0) {
        _isLoadingPublic = true;
      } else {
        _isLoadingMore = true;
      }
    });

    final pageToLoad = _currentPage;
    try {
      final radars = await _radarService.fetchPublicRadars(
        page: pageToLoad,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (pageToLoad == 0) {
          _publicRadars = radars;
        } else {
          _publicRadars.addAll(radars);
        }
        _hasMoreData = radars.length >= _pageSize;
        if (_hasMoreData) {
          _currentPage = pageToLoad + 1;
        }
        _isLoadingPublic = false;
        _isLoadingMore = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR PAGE] Fetch public radars failed: $e\n$st");
      }
      if (!mounted) return;
      setState(() {
        _isLoadingPublic = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoadingMore || _isLoadingPublic || !_hasMoreData) return;
    _loadRadars();
  }

  Future<void> _openRadarDetail(Map<String, dynamic> radar) async {
    final event = RadarEvent.fromJson(radar);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RadarDetailPage(event: event, radarData: radar),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _refreshPublicRadars();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin(Map<String, dynamic> radar) async {
    final radarId = (radar['id'] ?? '').toString();
    final title = (radar['title'] ?? 'Grup Radar').toString();

    if (radarId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Radar tidak valid")));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bergabung ke grup..."),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final outcome = await _radarService.joinRadar(radarId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).removeCurrentSnackBar();

      if (outcome.isPending) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permintaan join terkirim")),
        );
        _refreshPublicRadars();
        return;
      }

      final chatRoomId =
          outcome.chatRoomId ?? await _radarService.prepareChatForRadar(radarId);
      if (!mounted) return;

      if (chatRoomId != null && chatRoomId.trim().isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RadarChatPage(chatRoomId: chatRoomId, title: title),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil bergabung. Grup chat belum siap.")),
        );
      }

      _refreshPublicRadars();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR PAGE] Join failed: $e\n$st");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal bergabung"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[50], // Slightly off-white for better card contrast
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Radar Misa",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Undangan Masuk",
            icon: const Icon(Icons.mail_outlined, color: Colors.black87),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteInboxPage()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: kPrimary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Agenda Saya"),
            Tab(text: "Misa Publik Terbaru"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyAgendaTab(), _buildPublicRadarTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'radar_fab',
        onPressed: _onFabPressed,
        backgroundColor: kPrimary,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: Text(
          "Buat Radar",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _onFabPressed() async {
    // ROLE GUARD
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();

        final role = (profile['role'] ?? '').toString().trim().toLowerCase();
        if (role != 'umat' && role != 'katekumen') {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                "Akses Dibatasi",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              content: const Text("Fitur ini khusus untuk Umat & Katekumen."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal memverifikasi akses.")),
        );
        return;
      }
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateRadarScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      _tabController.animateTo(1);
      _refreshPublicRadars();
    }
  }

  // --- TABS ---

  Widget _buildMyAgendaTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _radarService.fetchMyRadars(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RadarListSkeleton();
        }

        final agendas = (snapshot.data ?? [])
            .where((e) => e['status'] != 'declined')
            .toList();

        if (agendas.isEmpty) {
          return const _RadarEmptyState(
            message: "Belum ada agenda misa.",
            icon: Icons.event_busy,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: agendas.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = agendas[index];
              final churchName =
                  item['location_name'] ??
                  item['churches']?['name'] ??
                  'Gereja';
              final parsed = DateTime.tryParse(item['schedule_time'] ?? '');
              final time = parsed?.toLocal() ?? DateTime.now();
              final isPast = time.isBefore(DateTime.now());
              final isMine =
                  (item['creator_id']?.toString() ?? '') == _myUserId;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? 'Agenda Misa',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "$churchName • ${DateFormat('dd MMM HH:mm').format(time)}",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (item['status'] == 'active')
                      Text(
                        "Status: Terjadwal",
                        style: GoogleFonts.outfit(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      Text(
                        "Status: ${item['status']}",
                        style: GoogleFonts.outfit(color: Colors.orange),
                      ),
                    if (isPast && isMine) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateRadarScreen(
                                  initialData: {
                                    'title': (item['title'] ?? '').toString(),
                                    'description': (item['description'] ?? '')
                                        .toString(),
                                    'church_id': (item['church_id'] ?? '')
                                        .toString(),
                                    'church_name':
                                        (item['church_name'] ??
                                                item['location_name'] ??
                                                churchName)
                                            .toString(),
                                  },
                                ),
                              ),
                            );
                            if (!mounted) return;
                            if (result == true) {
                              _refreshPublicRadars();
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("Buat Lagi"),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPublicRadarTab() {
    return RefreshIndicator(
      onRefresh: () => _loadRadars(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: _isLoadingPublic && _publicRadars.isEmpty
            ? const _RadarListSkeleton()
            : _publicRadars.isEmpty
            ? const _RadarEmptyState(
                icon: Icons.event_busy,
                message:
                    "Belum ada ajakan misa publik.\nJadilah yang pertama membuatnya!",
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _publicRadars.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index >= _publicRadars.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final item = _publicRadars[index];
                  return RadarEventCard(
                    item: item,
                    onTap: () => _openRadarDetail(item),
                    onJoin: () => _handleJoin(item),
                    currentUserId: _myUserId,
                  );
                },
              ),
      ),
    );
  }
}

// --- WIDGETS ---

class _RadarListSkeleton extends StatelessWidget {
  const _RadarListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _RadarEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _RadarEmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
