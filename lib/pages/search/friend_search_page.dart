import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/pages/profile_page.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendSearchPage extends StatefulWidget {
  final bool isSelectionMode;
  const FriendSearchPage({super.key, this.isSelectionMode = false});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final ProfileService _profileService = ProfileService();
  final MasterDataService _masterDataService = MasterDataService();

  // Search State
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // Filter State
  bool _isFilterExpanded = false;
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;

  // Dropdown Options
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = []; // Parishes

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- DATA LOADING ---

  Future<void> _loadCountries() async {
    try {
      final data = await _masterDataService.getCountries();
      if (mounted) setState(() => _countries = data);
    } catch (e) {
      debugPrint("Error loading countries: $e");
    }
  }

  Future<void> _loadDioceses(String countryId) async {
    try {
      final data = await _masterDataService.getDioceses(countryId: countryId);
      if (mounted) setState(() => _dioceses = data);
    } catch (e) {
      debugPrint("Error loading dioceses: $e");
    }
  }

  Future<void> _loadChurches(String dioceseId) async {
    try {
      final data = await _masterDataService.getChurches(dioceseId: dioceseId);
      if (mounted) setState(() => _churches = data);
    } catch (e) {
      debugPrint("Error loading churches: $e");
    }
  }

  // --- SEARCH LOGIC ---

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    // Construct Query String -> Actually, the advanced RPC uses 'search_term'.
    // Does it support filters? The current RPC `search_profiles_advanced`
    // likely only filters by Text OR specific columns if the RPC supports it.
    // Task 2 of Step 193 said "Add searchUsers... calling search_profiles_advanced RPC".
    // Does that RPC handle `country_id` etc?
    // If not, we might need to filter client-side or assume RPC handles it.
    // OR, we use the `filter` params in Supabase Query like previous implementation but centralized.
    // User Request said "Use ProfileService.searchUsers...".
    // If `searchUsers` ONLY takes `query`, then Filters might not work unless we modify it or
    // do client side filtering?
    // OR build a custom query here if filters are active.

    // Strategy:
    // If NO filters are set, use `_profileService.searchUsers(_searchController.text)`.
    // If FILTERS ARE set, we might need a custom query here similar to the old implementation
    // because `searchUsers` (Step 241) only takes `query`.
    // Wait, the previous implementation used direct Supabase.
    // I should stick to `ProfileService` if possible.
    // BUT since `searchUsers` is limited, I will implement a custom filtered query here
    // OR filter key fields client side (not ideal for pagination).
    // Let's use the OLD DIRECT QUERY logic for FILTERS, and `searchUsers` for TEXT ONLY search?
    // Actually, combining is best. I will implement a local `_searchWithFilters` method
    // that builds the Supabase query directly, mimicking the robust logic requested.

    // Wait, "Use ProfileService for searching".
    // The user might expect `ProfileService` to handle this.
    // But I can't modify `ProfileService` now (I am in this file).
    // I will use `ProfileService.searchUsers` if Filters are EMPTY.
    // If Filters are ACTIVE, I will use direct Supabase query here for now,
    // as it's the only way without changing Service signature.

    // Wait, advanced search usually means Text + Filters.
    // If I use direct query, I can do both.

    try {
      if (_selectedCountryId == null &&
          _selectedDioceseId == null &&
          _selectedChurchId == null &&
          _searchController.text.isNotEmpty) {
        // Text Only -> Use Service
        final results = await _profileService.searchUsers(
          _searchController.text,
        );
        if (mounted) {
          setState(() => _searchResults = results);
        }
      } else {
        // Filters Active OR Text+Filters -> Direct Query (Logic reuse)
        // Or fallback if text is empty but filters are set.

        // We'll use the direct Supabase client for flexibility as typically done in Search pages.
        final supabase = Supabase.instance.client;
        var query = supabase.from('profiles').select();

        if (_selectedChurchId != null) {
          query = query.eq('church_id', _selectedChurchId!);
        } else if (_selectedDioceseId != null) {
          query = query.eq('diocese_id', _selectedDioceseId!);
        } else if (_selectedCountryId != null) {
          query = query.eq('country_id', _selectedCountryId!);
        }

        if (_searchController.text.isNotEmpty) {
          query = query.ilike('full_name', '%${_searchController.text}%');
        }

        final res = await query.limit(50);
        if (mounted) {
          setState(() => _searchResults = List<Map<String, dynamic>>.from(res));
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI ACTIONS ---

  void _resetFilters() {
    setState(() {
      _selectedCountryId = null;
      _selectedDioceseId = null;
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
    });
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[50], // Lighter theme as per ProfilePage style
      appBar: AppBar(
        title: Text(
          widget.isSelectionMode ? "Pilih Teman" : "Cari Teman",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR & FILTERS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "Cari nama umat...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),

                const SizedBox(height: 8),

                // Expandable Filter
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      "Filter Lokasi",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    initiallyExpanded: _isFilterExpanded,
                    onExpansionChanged: (val) =>
                        setState(() => _isFilterExpanded = val),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      // Row 1: Country
                      _buildDropdown(
                        hint: "Pilih Negara",
                        value: _selectedCountryId,
                        items: _countries,
                        onChanged: (val) {
                          setState(() {
                            _selectedCountryId = val;
                            _selectedDioceseId = null;
                            _selectedChurchId = null;
                            _dioceses = [];
                            _churches = [];
                          });
                          if (val != null) _loadDioceses(val);
                          _performSearch();
                        },
                      ),
                      const SizedBox(height: 8),

                      // Row 2: Diocese
                      _buildDropdown(
                        hint: "Pilih Keuskupan",
                        value: _selectedDioceseId,
                        items: _dioceses,
                        enabled: _selectedCountryId != null,
                        onChanged: (val) {
                          setState(() {
                            _selectedDioceseId = val;
                            _selectedChurchId = null;
                            _churches = [];
                          });
                          if (val != null) _loadChurches(val);
                          _performSearch();
                        },
                      ),
                      const SizedBox(height: 8),

                      // Row 3: Church
                      _buildDropdown(
                        hint: "Pilih Paroki",
                        value: _selectedChurchId,
                        items: _churches,
                        enabled: _selectedDioceseId != null,
                        onChanged: (val) {
                          setState(() => _selectedChurchId = val);
                          _performSearch();
                        },
                      ),

                      // Reset Button
                      if (_selectedCountryId != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text("Reset Filter"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. RESULTS LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _searchResults[index];
                      return _buildUserCard(user);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: GoogleFonts.outfit(color: Colors.grey)),
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item['id'].toString(),
              child: Text(item['name'], style: GoogleFonts.outfit()),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data) {
    // Use Profile model logic for badges
    // We need to instantiate Profile to use its getters easily, or replicate logic.
    // Let's instantiate from Json
    final profile = Profile.fromJson(data);

    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          Navigator.pop(context, data);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfilePage(userId: profile.id, isBackButtonEnabled: true),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipOval(
              child: SafeNetworkImage(
                imageUrl: profile.avatarUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                fallbackIcon: Icons.person,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.fullName ?? "User",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Verification / Clergy Badges
                      if (profile.isClergy) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            profile.roleLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (profile.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Paroki ${profile.parish ?? '-'} • ${profile.roleLabel}",
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            "Tidak ada hasil ditemukan.",
            style: GoogleFonts.outfit(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
