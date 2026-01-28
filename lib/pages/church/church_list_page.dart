import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/church/pages/church_detail_page.dart';
import 'package:mychatolic_app/services/master_data_service.dart'; // Import
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/core/theme.dart';

class ChurchListPage extends StatefulWidget {
  const ChurchListPage({super.key});

  @override
  State<ChurchListPage> createState() => _ChurchListPageState();
}

class _ChurchListPageState extends State<ChurchListPage> {
  final _supabase = Supabase.instance.client;
  final MasterDataService _masterService = MasterDataService(); // Initialize
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Filters (Changed to String? for UUID support)
  String? _selectedCountryId;
  String? _countryName;

  String? _selectedDioceseId;
  String? _dioceseName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- MODAL SELECTION LOGIC ---
  void _showSupabaseSelectionModal({
    required String title,
    required String tableName,
    required String columnName,
    required Function(String id, String name)
    onSelected, // Changed ID to String
    String? filterColumn,
    dynamic filterValue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    "Pilih $title",
                    style: GoogleFonts.outfit(
                      color: kTextTitle,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Future Builder for Data
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchData(tableName, filterColumn, filterValue),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: kPrimary,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "Error: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final data = snapshot.data;
                        if (data == null || data.isEmpty) {
                          return Center(
                            child: Text(
                              "Data tidak ditemukan",
                              style: GoogleFonts.outfit(color: kTextMeta),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: data.length,
                          separatorBuilder: (context, index) =>
                              const Divider(color: Color(0xFFEEEEEE)),
                          itemBuilder: (ctx, index) {
                            final item = data[index];
                            final name = item[columnName] ?? 'Unknown';
                            final id = item['id']
                                .toString(); // Ensure ID is string

                            return ListTile(
                              title: Text(
                                name,
                                style: GoogleFonts.outfit(color: kTextTitle),
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                              onTap: () {
                                onSelected(id, name);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchData(
    String table,
    String? filterCol,
    dynamic filterVal,
  ) async {
    try {
      if (table == 'countries') {
        final list = await _masterService.fetchCountries();
        return list.map((e) => {'id': e.id, 'name': e.name}).toList();
      } else if (table == 'dioceses') {
        // We know filterVal is country_id
        final list = await _masterService.fetchDioceses(filterVal.toString());
        return list.map((e) => {'id': e.id, 'name': e.name}).toList();
      } else if (table == 'churches') {
        // Wait, fetchChurches needs dioceseId. Assuming usage in _openChurchFilter if it existed.
        // But _openDioceseFilter uses dioceses table.
        // It seems `_fetchData` is only used for `_openCountryFilter` and `_openDioceseFilter` currently.
        return [];
      }
      return [];
    } catch (e) {
      debugPrint("Service Fetch Error: $e");
      return [];
    }
  }

  // --- FILTER ACTIONS ---
  void _openCountryFilter() {
    _showSupabaseSelectionModal(
      title: "Negara",
      tableName: "countries",
      columnName: "name",
      onSelected: (String id, String name) {
        setState(() {
          _selectedCountryId = id;
          _countryName = name;
          // Reset dioceses when country changes
          _selectedDioceseId = null;
          _dioceseName = null;
        });
      },
    );
  }

  void _openDioceseFilter() {
    if (_selectedCountryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Negara terlebih dahulu")),
      );
      return;
    }
    _showSupabaseSelectionModal(
      title: "Keuskupan",
      tableName: "dioceses",
      columnName: "name",
      filterColumn: "country_id",
      filterValue: _selectedCountryId,
      onSelected: (String id, String name) {
        setState(() {
          _selectedDioceseId = id;
          _dioceseName = name;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Enforce Light Theme for this page as requested
    return Theme(
      data: MyCatholicTheme.lightTheme.copyWith(
        scaffoldBackgroundColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Strict White
        appBar: const MyCatholicAppBar(title: "Cari Paroki & Stasi"),
        body: CustomScrollView(
          slivers: [
            // 1. FILTER HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SEARCH BAR ---
                    TextField(
                      controller: _searchController,
                      style: GoogleFonts.outfit(color: kTextTitle),
                      decoration: InputDecoration(
                        hintText: "Cari nama gereja...",
                        hintStyle: GoogleFonts.outfit(color: Colors.grey),
                        filled: true,
                        fillColor: kBackground,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: kPrimary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- CASCADING DROPDOWNS ---
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterButton(
                            _countryName ?? "Semua Negara",
                            _openCountryFilter,
                            isActive: _selectedCountryId != null,
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_right_rounded,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterButton(
                            _dioceseName ?? "Semua Keuskupan",
                            _openDioceseFilter,
                            isActive: _selectedDioceseId != null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. LIST RESULTS
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _buildQueryStream(),
              builder: (context, snapshot) {
                // LOADING STATE
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: kPrimary),
                    ),
                  );
                }

                // DATA RESOLUTION (REAL ONLY)
                List<Map<String, dynamic>> sourceData = [];

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  // If no data, show empty state immediately
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.church_outlined,
                            size: 48,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Tidak ada gereja ditemukan",
                            style: GoogleFonts.outfit(color: kTextMeta),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  sourceData = snapshot.data!;
                }

                // Local Search Filtering (Client-side for Search Bar text only)
                final filteredChurches = sourceData.where((c) {
                  final name = (c['name'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredChurches.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Pencarian tidak ditemukan",
                            style: GoogleFonts.outfit(color: kTextMeta),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildChurchCard(filteredChurches[index]),
                    );
                  }, childCount: filteredChurches.length),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _buildQueryStream() {
    // 1. Use a local final variable
    final dioceseId = _selectedDioceseId;

    // 2. Use separate return statements

    if (dioceseId != null) {
      // If filter exists, return the filtered stream chain
      return _supabase
          .from('churches')
          .stream(primaryKey: ['id'])
          .eq('diocese_id', dioceseId)
          .order('name', ascending: true);
    } else {
      // If no filter, return the standard stream
      return _supabase
          .from('churches')
          .stream(primaryKey: ['id'])
          .order('name', ascending: true);
    }
  }

  Widget _buildFilterButton(
    String label,
    VoidCallback onTap, {
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? kPrimary.withValues(alpha: 0.1)
              : kBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? kPrimary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isActive ? kPrimary : kTextTitle,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isActive ? kPrimary : kTextMeta,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChurchCard(Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      color: kBackground,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChurchDetailPage(churchData: data),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SafeNetworkImage(
                imageUrl: data['image_url'],
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(12),
                fallbackIcon: Icons.church,
                iconColor: kPrimary,
                fallbackColor: Colors.white,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? "Gereja",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kTextTitle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['address'] ?? "Alamat belum tersedia",
                      style: GoogleFonts.outfit(
                        color: kTextMeta,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
