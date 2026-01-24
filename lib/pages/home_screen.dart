import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/widgets/post_card.dart';
import 'package:mychatolic_app/pages/notification_screen.dart';
import 'package:mychatolic_app/pages/create_post_screen.dart';
import 'package:mychatolic_app/pages/radar_page.dart';
import 'package:mychatolic_app/pages/radar_detail_page.dart';
import 'package:mychatolic_app/pages/radars/radar_chat_page.dart';
import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/radar_event_card.dart';
// Filter dependencies
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final SocialService _socialService = SocialService();
  final MasterDataService _masterService = MasterDataService();
  final RadarService _radarService = RadarService();
  final String _myUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  List<UserPost> _posts = [];
  bool _isLoading = false;

  List<RadarEvent> _publicRadars = [];
  bool _isLoadingRadars = false;

  // Filter State
  Country? _selectedCountry;
  Diocese? _selectedDiocese;
  Church? _selectedChurch;

  @override
  void initState() {
    super.initState();
    refreshPosts();
    refreshPublicRadars();
  }

  Future<void> refreshPosts() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // Logic: Pass filter params if you extended fetchPosts.
      // For now, fetching all (or you can add params to fetchPosts later)
      // fetchPosts(churchId: _selectedChurch?.id, ...)
      final List<UserPost> posts = await _socialService.fetchPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("[HOME] Error loading posts: $e");
    }
  }

  Future<void> refreshPublicRadars() async {
    if (mounted) setState(() => _isLoadingRadars = true);
    try {
      final radars = await _radarService.fetchPublicRadars();
      if (!mounted) return;
      setState(() {
        _publicRadars = radars.take(3).toList();
        _isLoadingRadars = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingRadars = false);
      debugPrint("[HOME] Error loading public radars: $e");
    }
  }

  Future<void> refreshHome() async {
    await Future.wait([refreshPublicRadars(), refreshPosts()]);
  }

  Future<void> _openRadarDetail(RadarEvent event) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RadarDetailPage(event: event, radarData: event.toJson()),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      refreshPublicRadars();
    }
  }

  Future<void> _handleJoin(RadarEvent event) async {
    final radarId = event.id;
    final title = event.title;

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
        refreshPublicRadars();
        return;
      }

      final chatRoomId =
          outcome.chatRoomId ??
          await _radarService.prepareChatForRadar(radarId);
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
          const SnackBar(
            content: Text("Berhasil bergabung. Grup chat belum siap."),
          ),
        );
      }

      refreshPublicRadars();
    } catch (e, st) {
      debugPrint("[HOME] Join failed: $e\n$st");
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

  void _showLocationFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Lokasi",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFilterItem<Country>(
                  "Negara",
                  _selectedCountry?.name,
                  () => _showSelectionSheet<Country>(
                    context,
                    "Pilih Negara",
                    () => _masterService.fetchCountries(),
                    (item) => item.name,
                    (item) => null,
                    (selected) {
                      setModalState(() {
                        _selectedCountry = selected;
                        _selectedDiocese = null;
                        _selectedChurch = null;
                      });
                    },
                  ),
                ),
                _buildFilterItem<Diocese>(
                  "Keuskupan",
                  _selectedDiocese?.name,
                  () {
                    if (_selectedCountry == null) return;
                    _showSelectionSheet<Diocese>(
                      context,
                      "Pilih Keuskupan",
                      () => _masterService.fetchDioceses(_selectedCountry!.id),
                      (item) => item.name,
                      (item) => null,
                      (selected) {
                        setModalState(() {
                          _selectedDiocese = selected;
                          _selectedChurch = null;
                        });
                      },
                    );
                  },
                ),
                _buildFilterItem<Church>("Gereja", _selectedChurch?.name, () {
                  if (_selectedDiocese == null) return;
                  _showSelectionSheet<Church>(
                    context,
                    "Pilih Gereja",
                    () => _masterService.fetchChurches(_selectedDiocese!.id),
                    (item) => item.name,
                    (item) => item.address,
                    (selected) {
                      setModalState(() {
                        _selectedChurch = selected;
                      });
                    },
                  );
                }),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      refreshHome();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Terapkan",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterItem<T>(String label, String? value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? "Pilih $label",
                style: GoogleFonts.outfit(
                  color: value != null ? Colors.black : Colors.grey,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionSheet<T>(
    BuildContext context,
    String title,
    Future<List<T>> Function() fetch,
    String Function(T) getName,
    String? Function(T) getSubtitle,
    Function(T) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _SearchableSelectionSheet<T>(
        title: title,
        fetch: fetch,
        getName: getName,
        getSubtitle: getSubtitle,
        onSelect: onSelect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0088CC),
        elevation: 0,
        centerTitle: false,
        title: Text(
          "MyCatholic",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // Filter Icon
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 20,
              ),
              tooltip: "Filter Lokasi",
              onPressed: _showLocationFilter,
            ),
          ),

          // Notifications
          IconButton(
            icon: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 28,
            ),
            tooltip: "Notifikasi",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshHome,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Radar Misa (Public)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Radar Misa Publik Terbaru",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RadarPage()),
                        );
                      },
                      child: Text(
                        "Lihat semua",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0088CC),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoadingRadars)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_publicRadars.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      "Belum ada radar publik.",
                      style: GoogleFonts.outfit(color: Colors.grey[700]),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _publicRadars[index];
                  return RadarEventCard(
                    item: item,
                    currentUserId: _myUserId,
                    onTap: () => _openRadarDetail(item),
                    onJoin: () => _handleJoin(item),
                  );
                }, childCount: _publicRadars.length),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Post Stream
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_posts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(
                    child: Text(
                      "Belum ada postingan.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return PostCard(
                    post: _posts[index],
                    socialService: _socialService,
                  );
                }, childCount: _posts.length),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ), // Bottom padding
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_screen_fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
          if (result == true) {
            refreshPosts();
          }
        },
        backgroundColor: const Color(0xFF0088CC),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}

// Helper Class for Filter Selection
class _SearchableSelectionSheet<T> extends StatefulWidget {
  final String title;
  final Future<List<T>> Function() fetch;
  final String Function(T) getName;
  final String? Function(T) getSubtitle;
  final Function(T) onSelect;
  const _SearchableSelectionSheet({
    required this.title,
    required this.fetch,
    required this.getName,
    required this.getSubtitle,
    required this.onSelect,
  });
  @override
  State<_SearchableSelectionSheet<T>> createState() =>
      _SearchableSelectionSheetState<T>();
}

class _SearchableSelectionSheetState<T>
    extends State<_SearchableSelectionSheet<T>> {
  List<T> _items = [];
  List<T> _filteredItems = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      final data = await widget.fetch();
      if (mounted) {
        setState(() {
          _items = data;
          _filteredItems = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    setState(() {
      _filteredItems = q.isEmpty
          ? _items
          : _items
                .where(
                  (i) =>
                      widget.getName(i).toLowerCase().contains(q.toLowerCase()),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: _filter,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Cari...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredItems.length,
                    itemBuilder: (ctx, i) {
                      final item = _filteredItems[i];
                      final sub = widget.getSubtitle(item);
                      return ListTile(
                        title: Text(widget.getName(item)),
                        subtitle: sub != null
                            ? Text(
                                sub,
                                style: const TextStyle(color: Colors.grey),
                              )
                            : null,
                        onTap: () {
                          widget.onSelect(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
