import 'package:flutter/material.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/services/schedule_service.dart';
import 'package:mychatolic_app/services/liturgy_service.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/services/check_in_service.dart';
import 'package:mychatolic_app/features/radar/widgets/check_in_components.dart';

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
  final CheckInService _checkInService = CheckInService();
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
  
  // --- HELPER LOGIC: CHECK ACTIVE MASS ---
  bool _isMassActive(String timeStart) {
    // Only active if the selected date is TODAY
    final now = DateTime.now();
    if (_selectedDate.year != now.year || _selectedDate.month != now.month || _selectedDate.day != now.day) {
      return false;
    }

    try {
      final parts = timeStart.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final massTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // Active Window: 30 mins BEFORE start until 60 mins AFTER start
      final startWindow = massTime.subtract(const Duration(minutes: 30));
      final endWindow = massTime.add(const Duration(minutes: 60));
      
      return now.isAfter(startWindow) && now.isBefore(endWindow);
    } catch (e) {
      return false; 
    }
  }
  
  Future<void> _handleCheckIn(String churchId, String scheduleId) async {
    // UPDATED: Use MassCheckInWizard in pre-filled mode
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (_) => MassCheckInWizard(initialChurchId: churchId, initialScheduleId: scheduleId),
    );
    
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Berhasil Check-in! Lihat status di Radar Misa."))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bgColor = theme.scaffoldBackgroundColor;
    final surface = colors.surface;
    final border = theme.dividerColor;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final textMuted = colors.onSurface.withOpacity(0.5);

    // Liturgical Color Logic
    final liturgicalColor = _currentLiturgy != null
        ? LiturgyService.getLiturgicalColor(_currentLiturgy!.color)
        : colors.primary; // Default fallback

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const MyCatholicAppBar(title: "Kalender & Misa"),
      body: CustomScrollView(
        slivers: [
          // 1. Calendar
          SliverToBoxAdapter(
            child: Container(
              color: surface,
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
                      color: liturgicalColor.withValues(alpha: 0.22),
                      border: Border.all(
                        color: liturgicalColor.withValues(alpha: 0.9),
                        width: 1.6,
                      ),
                    ),
                    dayNumStyle: GoogleFonts.outfit(
                      color: _litText(liturgicalColor),
                      fontWeight: FontWeight.bold,
                    ),
                    dayStrStyle: GoogleFonts.outfit(
                      color: _litText(liturgicalColor).withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  todayStyle: DayStyle(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: liturgicalColor.withValues(alpha: 0.9),
                        width: 1.6,
                      ),
                    ),
                    dayNumStyle: GoogleFonts.outfit(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    dayStrStyle: GoogleFonts.outfit(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  inactiveDayStyle: DayStyle(
                    dayNumStyle: GoogleFonts.outfit(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    dayStrStyle: GoogleFonts.outfit(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  disabledDayStyle: DayStyle(
                    dayNumStyle: GoogleFonts.outfit(
                      color: textMuted,
                    ),
                    dayStrStyle: GoogleFonts.outfit(
                      color: textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Liturgy Card
          SliverToBoxAdapter(child: _buildLiturgyHeader()),

          // 2.5 Personalized Parish Schedule
          SliverToBoxAdapter(child: _buildPersonalParishSection()),

          // 3. Advanced Search Toggle
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: border.withValues(alpha: 0.6)),
                ),
                color: surface,
                child: ExpansionTile(
                  title: Text(
                    "Cari Jadwal Misa",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  leading: Icon(
                    Icons.search,
                    color: colors.primary,
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
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _searchByChurch,
                        child: Text(
                          "Lihat Jadwal",
                          style: GoogleFonts.outfit(
                            color: colors.onPrimary,
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
                          style: GoogleFonts.outfit(color: colors.error),
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
                  color: textPrimary,
                ),
              ),
            ),
          ),

          // 5. List
          if (_isLoadingSchedules)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: colors.primary),
              ),
            )
          else if (_schedules.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 60, color: textMuted),
                    const SizedBox(height: 10),
                    Text(
                      _isChurchSearchMode
                          ? "Jadwal belum tersedia"
                          : "Tidak ada jadwal (Data sample)", // Friendly fallback
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: textSecondary),
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
                  child: _buildTicketCard(item),
                );
              }, childCount: _schedules.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildLiturgyHeader() {
    if (_loadingLiturgy) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Default values if no liturgy
    final bgColor = _currentLiturgy != null
        ? LiturgyService.getLiturgicalColor(_currentLiturgy!.color)
        : Theme.of(context).colorScheme.primary;

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
                        color: _litBg(bgColor),
                        border: Border.all(color: _litBorder(bgColor)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        DateFormat(
                          'EEEE, d MMMM yyyy',
                          'id',
                        ).format(_selectedDate),
                        style: GoogleFonts.outfit(
                          color: _litText(bgColor),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome,
                      color: _litText(bgColor).withValues(alpha: 0.8),
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
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = theme.dividerColor;
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.outfit(
          color: colors.onSurface.withOpacity(0.7),
        ),
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      style: GoogleFonts.outfit(color: colors.onSurface),
      dropdownColor: colors.surface,
    );
  }

  Color _litBg(Color c) => c.withOpacity(0.14);
  Color _litBorder(Color c) => c.withOpacity(0.55);
  Color _litText(Color c) =>
      (c.computeLuminance() > 0.65) ? const Color(0xFF121212) : Colors.white;

  Color _litChipBg(Color c) {
    final lum = c.computeLuminance();
    if (lum > 0.8) return c.withOpacity(0.18);
    if (lum < 0.08) return Colors.black.withOpacity(0.45);
    return _litBg(c);
  }

  Color _litChipBorder(Color c) {
    final lum = c.computeLuminance();
    if (lum > 0.8) return c.withOpacity(0.6);
    if (lum < 0.08) return const Color(0xFF555555);
    return _litBorder(c);
  }

  Color _litChipText(Color c) {
    final lum = c.computeLuminance();
    if (lum > 0.8) return const Color(0xFF121212);
    if (lum < 0.08) return Colors.white;
    return _litText(c);
  }

  Widget _buildTicketCard(MassSchedule item) {
    // Show Day Name if in "Church Search Mode"
    final dayName = _getDayName(item.dayOfWeek);
    final isActive = _isMassActive(item.timeStart);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final litColor = _currentLiturgy != null
        ? LiturgyService.getLiturgicalColor(_currentLiturgy!.color)
        : colors.primary;
    final litLabel = (_currentLiturgy?.color ?? "Liturgi").toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.onSurface.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: litColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // JAM / STATUS CONTAINER
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colors.secondary.withOpacity(0.12)
                          : colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(color: colors.secondary, width: 1.4)
                          : Border.all(
                              color: colors.primary.withOpacity(0.4),
                              width: 1,
                            ),
                    ),
                    child: Column(
                      children: [
                        if (_isChurchSearchMode) ...[
                          Text(
                            dayName.substring(0, 3).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? colors.secondary
                                  : colors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          item.timeStart.substring(0, 5), // HH:mm
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? colors.secondary
                                : colors.primary,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.churchName,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _litChipBg(litColor),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: _litChipBorder(litColor)),
                              ),
                              child: Text(
                                litLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _litChipText(litColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _isChurchSearchMode
                              ? dayName
                              : (item.churchParish ?? '-'),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.language,
                                size: 12, color: textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              item.language ?? "Umum",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // CHECK-IN BUTTON (If Active)
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _handleCheckIn(item.churchId, item.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(
                          "Check-in",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    )
                ],
              ),
            ),
          ),
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
  Widget _buildPersonalParishSection() {
    final user = _supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<Profile>(
      // Using a Future wrapped in stream for simplicity, or could rely on real-time profile logic.
      // Re-fetching on build to ensure updates are caught if user edits profile.
      stream: Stream.fromFuture(_profileService.fetchUserProfile(user.id)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final profile = snapshot.data!;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final surface = colors.surface;
        final border = theme.dividerColor;
        final textPrimary = colors.onSurface;
        final textSecondary = colors.onSurface.withOpacity(0.7);
        final textMuted = colors.onSurface.withOpacity(0.5);
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
          return _buildSetParishCard();
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
              return _buildSetParishCard(isUpdate: true);
            }

            final schedules = scheduleSnapshot.data!;
            // Get Church Name from first schedule
            final churchName = schedules.first.churchName;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Jadwal Paroki Anda",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
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
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (schedules.isEmpty)
                    Text(
                      "Belum ada jadwal.",
                      style: GoogleFonts.outfit(color: textMuted),
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
                            color: surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border.withOpacity(0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withValues(alpha: 0.2),
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
                                  color: textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                s.timeStart.substring(0, 5),
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                s.language ?? 'Umum',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: textMuted,
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

  Widget _buildSetParishCard({bool isUpdate = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = colors.surface;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpdate ? "Data Paroki Tidak Sesuai?" : "Atur Paroki Anda",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  isUpdate
                      ? "Perbarui profil untuk melihat jadwal yang tepat."
                      : "Pilih paroki di profil untuk lihat jadwal otomatis.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.secondary,
              foregroundColor: colors.onPrimary,
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
