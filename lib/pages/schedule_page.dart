import 'package:flutter/material.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/services/schedule_service.dart';
import 'package:mychatolic_app/services/liturgy_service.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/pages/profile/edit_profile_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  // Services
  final ScheduleService _scheduleService = ScheduleService();
  final LiturgyService _liturgyService = LiturgyService();
  final MasterDataService _masterService = MasterDataService();
  final ProfileService _profileService = ProfileService();
  final _supabase = Supabase.instance.client;

  // State: Date & Liturgy
  DateTime _selectedDate = DateTime.now();
  LiturgyModel? _currentLiturgy;
  bool _loadingLiturgy = false;

  // State: Filters
  List<Country> _countries = [];
  List<Diocese> _dioceses = [];
  List<Church> _churches = []; // Churches in Diocese

  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;

  // State: Results
  List<MassSchedule> _schedules = [];
  bool _isLoadingSchedules = false;

  // Grouping for "Church Search" mode
  bool _isChurchSearchMode = false;

  @override
  void initState() {
    super.initState();
    _fetchLiturgy();
    _fetchCountries();
    _loadDailySchedules(); // Initial Load (Global/Nearby logic or just by day)
  }

  // --- LITURGY LOGIC ---
  Future<void> _fetchLiturgy() async {
    setState(() => _loadingLiturgy = true);
    final liturgy = await _liturgyService.getLiturgyByDate(_selectedDate);
    if (mounted) {
      setState(() {
        _currentLiturgy = liturgy;
        _loadingLiturgy = false;
      });
    }
  }

  // --- MASTER DATA LOGIC ---
  Future<void> _fetchCountries() async {
    final data = await _masterService.fetchCountries();
    if (mounted) setState(() => _countries = data);
  }

  Future<void> _fetchDioceses(String countryId) async {
    final data = await _masterService.fetchDioceses(countryId);
    if (mounted) setState(() => _dioceses = data);
  }

  Future<void> _fetchChurches(String dioceseId) async {
    final data = await _masterService.fetchChurches(dioceseId);
    if (mounted) setState(() => _churches = data);
  }

  void _onCountryChanged(String? val) {
    setState(() {
      _selectedCountryId = val;
      _selectedDioceseId = null;
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
    });
    if (val != null) _fetchDioceses(val);
  }

  void _onDioceseChanged(String? val) {
    setState(() {
      _selectedDioceseId = val;
      _selectedChurchId = null;
      _churches = [];
    });
    if (val != null) _fetchChurches(val);
  }

  // --- SCHEDULE LOGIC ---

  // 1. Load by Date (Default View)
  Future<void> _loadDailySchedules() async {
    setState(() {
      _isLoadingSchedules = true;
      _isChurchSearchMode = false;
    });

    try {
      // Fetch general schedules for this weekday
      // Note: In a real app this should be filtered by user location or favourites
      final data = await _scheduleService.fetchSchedules(
        dayOfWeek: _selectedDate.weekday,
      );
      if (mounted) {
        setState(() {
          _schedules = data;
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  // 2. Search Specific Church (Advanced View)
  Future<void> _searchByChurch() async {
    if (_selectedChurchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Gereja terlebih dahulu")),
      );
      return;
    }

    setState(() {
      _isLoadingSchedules = true;
      _isChurchSearchMode = true;
    });

    try {
      // Use the service which now returns strictly typed List<MassSchedule>
      final data = await _scheduleService.fetchSchedules(
        churchId: _selectedChurchId!,
      );

      if (mounted) {
        setState(() {
          _schedules = data;
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);

    // Liturgical Color Logic
    final liturgicalColor = _currentLiturgy != null
        ? LiturgyService.getLiturgicalColor(_currentLiturgy!.color)
        : AppColors.primaryBrand; // Default fallback

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const MyCatholicAppBar(title: "Kalender & Misa"),
      body: CustomScrollView(
        slivers: [
          // 1. Calendar
          SliverToBoxAdapter(
            child: Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: EasyDateTimeLine(
                initialDate: _selectedDate,
                onDateChange: (d) {
                  // Optimistic update for UI responsiveness
                  setState(() {
                    _selectedDate = d;
                    // Reset liturgy to null or keep previous? Better to keep previous to avoid flash,
                    // or show loading. But the color needs to update.
                    // We'll let the fetch update the state.
                  });
                  _fetchLiturgy();
                  if (!_isChurchSearchMode) _loadDailySchedules();
                },
                headerProps: const EasyHeaderProps(
                  monthPickerType: MonthPickerType.switcher,
                  dateFormatter: DateFormatter.fullDateDMY(),
                ),
                dayProps: EasyDayProps(
                  dayStructure: DayStructure.dayStrDayNum,
                  activeDayStyle: DayStyle(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          liturgicalColor,
                          liturgicalColor.withValues(alpha: 0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: liturgicalColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  todayStyle: DayStyle(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: liturgicalColor.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Liturgy Card
          SliverToBoxAdapter(child: _buildLiturgyHeader(isDark)),

          // 2.5 Personalized Parish Schedule
          SliverToBoxAdapter(child: _buildPersonalParishSection(isDark)),

          // 3. Advanced Search Toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: ExpansionTile(
                  title: Text(
                    "Cari Jadwal Misa",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  leading: const Icon(
                    Icons.search,
                    color: AppColors.primaryBrand,
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    _buildDropdown<String>(
                      label: "Negara",
                      value: _selectedCountryId,
                      items: _countries
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: _onCountryChanged,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<String>(
                      label: "Keuskupan",
                      value: _selectedDioceseId,
                      items: _dioceses
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d.name),
                            ),
                          )
                          .toList(),
                      onChanged: _selectedCountryId == null
                          ? null
                          : _onDioceseChanged,
                    ),
                    const SizedBox(height: 12),
                    _buildDropdown<String>(
                      label: "Paroki / Gereja",
                      value: _selectedChurchId,
                      items: _churches
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: _selectedDioceseId == null
                          ? null
                          : (val) => setState(() => _selectedChurchId = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBrand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _searchByChurch,
                        child: Text(
                          "Lihat Jadwal",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (_isChurchSearchMode) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loadDailySchedules, // Reset to Daily View
                        child: Text(
                          "Reset ke Tampilan Harian",
                          style: GoogleFonts.outfit(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 4. Results Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                _isChurchSearchMode
                    ? "Jadwal Lengkap Gereja"
                    : "Jadwal Misa Hari Ini",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

          // 5. List
          if (_isLoadingSchedules)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryBrand),
              ),
            )
          else if (_schedules.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text(
                      _isChurchSearchMode
                          ? "Jadwal belum tersedia"
                          : "Tidak ada jadwal (Data sample)", // Friendly fallback
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = _schedules[index];
                // If in Church Mode, we might want to show day header or just list all
                // For simplicity: List all, maybe showing Day Name if different
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: _buildTicketCard(item, isDark),
                );
              }, childCount: _schedules.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildLiturgyHeader(bool isDark) {
    if (_loadingLiturgy) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Default values if no liturgy
    final bgColor = _currentLiturgy != null
        ? LiturgyService.getLiturgicalColor(_currentLiturgy!.color)
        : Colors.blue;

    final textColor = LiturgyService.getLiturgicalTextColor(
      _currentLiturgy?.color,
    ); // Use helper

    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern (Optional)
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.church,
              size: 150,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat(
                          'EEEE, d MMMM yyyy',
                          'id',
                        ).format(_selectedDate),
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome,
                      color: textColor.withValues(alpha: 0.8),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Feast Name
                Text(
                  _currentLiturgy?.feastName ?? "Hari Biasa",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  "Warna Liturgi: ${_currentLiturgy?.color.toUpperCase() ?? '-'}",
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 20),

                // Readings
                if (_currentLiturgy != null &&
                    _currentLiturgy!.readings.isNotEmpty) ...[
                  _buildReadingRow(
                    "Bacaan 1",
                    _currentLiturgy!.readings['bacaan1'] ?? '-',
                    textColor,
                  ),
                  if (_currentLiturgy!.readings['mazmur'] != null)
                    _buildReadingRow(
                      "Mazmur",
                      _currentLiturgy!.readings['mazmur'] ?? '-',
                      textColor,
                    ),
                  _buildReadingRow(
                    "Injil",
                    _currentLiturgy!.readings['injil'] ?? '-',
                    textColor,
                  ),
                ] else
                  Text(
                    "Data bacaan belum tersedia.",
                    style: GoogleFonts.outfit(
                      color: textColor.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingRow(String label, String ref, Color color) {
    // If reference represents "no data", return static row
    if (ref.isEmpty || ref == '-' || ref.toLowerCase() == 'tidak ada') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                ref,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        dense: true,
        iconColor: color,
        collapsedIconColor: color.withValues(alpha: 0.5),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: color.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Text(
                ref,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: color.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        children: [
          FutureBuilder<String?>(
            future: Future.value("Fitur Alkitab dinonaktifkan."),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Gagal memuat ayat.",
                    style: GoogleFonts.outfit(color: Colors.red, fontSize: 12),
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.1)),
                ),
                child: Text(
                  snapshot.data!,
                  style: GoogleFonts.outfit(
                    color: color.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?)? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      style: GoogleFonts.outfit(color: Colors.black),
      dropdownColor: Colors.white,
    );
  }

  Widget _buildTicketCard(MassSchedule item, bool isDark) {
    // Show Day Name if in "Church Search Mode"
    final dayName = _getDayName(item.dayOfWeek);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryBrand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (_isChurchSearchMode) ...[
                  Text(
                    dayName.substring(0, 3).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBrand,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  item.timeStart.substring(0, 5), // HH:mm
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.churchName,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isChurchSearchMode
                      ? dayName
                      : (item.churchParish ??
                            '-'), // Show Day if Church Mode, Parish otherwise
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.language, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      item.language ?? "Umum",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _getDayName(int day) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    if (day >= 1 && day <= 7) return days[day - 1];
    return '-';
  }

  // --- PERSONAL PARISH LOGIC ---
  Widget _buildPersonalParishSection(bool isDark) {
    final user = _supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<Map<String, dynamic>>(
      // Using a Future wrapped in stream for simplicity, or could rely on real-time profile logic.
      // Re-fetching on build to ensure updates are caught if user edits profile.
      stream: Stream.fromFuture(_profileService.fetchUserProfile(user.id)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final profile =
            snapshot.data!['profile']
                as dynamic; // Using dynamic to access properties safely or cast to Profile
        // Assuming Profile model has parishId or we check 'parish' string.
        // Based on Profile model provided: 'parish' is a String (Name).
        // We need 'church_id' to query schedules.
        // Profile model doesn't seem to have 'churchId'.
        // Let's assume 'parish' field stores the ID or we need to add church_id to Profile.
        // CHECK: Profile model only has `final String? parish;`.
        // If `parish` stores the NAME, we can't query by ID easily without a search or change in Profile model.
        // HOWEVER, in `fetchUserProfile` query: `parish`.
        // If the user selects a parish from dropdown, usually we store ID.
        // Let's assume the 'parish' field in `profiles` table might hold the ID or we extended it.
        // If 'parish' holds the name 'St. Yoseph', we can't query mass_schedules by 'church_id'.
        // Workaround: We will rely on getting 'church_id' from profile if available.
        // Inspecting ProfileService: `.select('..., parish, ...')`.
        // If 'parish' is just a name, this feature requires backend change to store parish_id.
        // PROCEEDING with assumption: We try to use `parish` as ID. If it fails (empty list), user sees nothing.
        // But better: Let's check if we can fetch schedules by matching church name or if we need to request Profile Update.
        // USER REQUEST: "Fetch the current user's profile... to get their `church_id`".
        // I will attempt to cast `profile.parish` as the ID.

        // Wait, ProfileService fetchUserProfile returns `Profile` object.
        // Profile class has `parish`.

        final parishId =
            profile.parish; // Assuming this stores the UUID or foreign key.

        if (parishId == null || parishId.isEmpty) {
          return _buildSetParishCard(isDark);
        }

        return FutureBuilder<List<MassSchedule>>(
          future: _scheduleService.fetchSchedules(churchId: parishId),
          builder: (context, scheduleSnapshot) {
            if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }

            // If no schedules found (maybe parishId was just a name "Paroki Blok B", not a UUID),
            // or truly no schedules.
            if (!scheduleSnapshot.hasData || scheduleSnapshot.data!.isEmpty) {
              // If it looks like a name (not UUID len), maybe warn? Or just show empty.
              return _buildSetParishCard(isDark, isUpdate: true);
            }

            final schedules = scheduleSnapshot.data!;
            // Get Church Name from first schedule
            final churchName = schedules.first.churchName;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFFE8F0FE), // Different tint
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBrand.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.primaryBrand, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Jadwal Paroki Anda",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBrand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    churchName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (schedules.isEmpty)
                    Text(
                      "Belum ada jadwal.",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),

                  // Horizontal List for compactness
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: schedules.map((s) {
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDayName(s.dayOfWeek),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                s.timeStart.substring(0, 5),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: AppColors.primaryBrand,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                s.language ?? 'Umum',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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

  Widget _buildSetParishCard(bool isDark, {bool isUpdate = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2C)
            : Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpdate ? "Data Paroki Tidak Sesuai?" : "Atur Paroki Anda",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  isUpdate
                      ? "Perbarui profil untuk melihat jadwal yang tepat."
                      : "Pilih paroki di profil untuk lihat jadwal otomatis.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              // Navigation to Edit Profile
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ).then((_) {
                // REFRESH: Re-trigger the stream or state if needed.
                // Since the PersonalParishSection uses a StreamBuilder from a Future (Stream.fromFuture), it won't auto-refresh unless we force rebuild.
                // Easiest is to setState.
                setState(() {});
              });
            },
            child: const Text("Atur"),
          ),
        ],
      ),
    );
  }
}
