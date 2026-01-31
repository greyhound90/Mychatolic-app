import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mychatolic_app/l10n/gen/app_localizations.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/services/schedule_service.dart';
import 'package:mychatolic_app/services/liturgy_service.dart';
import 'package:mychatolic_app/services/master_data_service.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/ui/app_state_view.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

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
  bool _pendingDayTrack = false;

  // State: Filters
  List<Country> _countries = [];
  List<Diocese> _dioceses = [];
  List<Church> _churches = []; // Churches in Diocese

  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;
  String? _userChurchId;

  // State: Results
  List<MassSchedule> _schedules = [];
  bool _isLoadingSchedules = false;
  String? _scheduleError;
  String? _liturgyError;

  // Grouping for "Church Search" mode
  bool _isChurchSearchMode = false;
  final GlobalKey _searchSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadUserChurchId();
    _fetchLiturgy();
    _fetchCountries();
    _loadDailySchedules(); // Initial Load (Global/Nearby logic or just by day)
  }

  Future<void> _loadLiturgy() async {
    await _fetchLiturgy();
  }

  Future<void> _loadSchedules() async {
    if (_isChurchSearchMode) {
      await _searchByChurch();
    } else {
      await _loadDailySchedules();
    }
  }

  Future<void> _loadUserChurchId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final profile = await _profileService.fetchUserProfile(user.id);
      _userChurchId = profile.churchId;
    } catch (_) {}
  }

  // --- LITURGY LOGIC ---
  Future<void> _fetchLiturgy() async {
    final t = AppLocalizations.of(context)!;
    safeSetState(() {
      _loadingLiturgy = true;
      _liturgyError = null;
    });
    final cacheKey = _scheduleCacheKey(churchId: _selectedChurchId);
    final cached = await _readScheduleCache(cacheKey);
    if (cached?.liturgy != null) {
      safeSetState(() {
        _currentLiturgy = cached!.liturgy;
        _loadingLiturgy = false;
      });
    }
    try {
      final liturgy = await _liturgyService.getLiturgyByDate(_selectedDate);
      safeSetState(() {
        _currentLiturgy = liturgy ?? _currentLiturgy;
        _loadingLiturgy = false;
      });
      if (liturgy != null) {
        await _writeScheduleCache(cacheKey, liturgy: liturgy);
      }
      if (_pendingDayTrack) {
        AnalyticsService.instance.track(
          AnalyticsEvents.scheduleDayChange,
          props: {
            'has_liturgy': liturgy != null,
            'liturgy_color': (liturgy?.color ?? 'unknown').toString().toLowerCase(),
          },
        );
        _pendingDayTrack = false;
      }
    } catch (e, st) {
      AppLogger.logError("Fetch Liturgy Error", error: e, stackTrace: st);
      safeSetState(() {
        _loadingLiturgy = false;
        _liturgyError = mapErrorMessage(e);
      });
      if (_pendingDayTrack) {
        AnalyticsService.instance.track(
          AnalyticsEvents.scheduleDayChange,
          props: {
            'has_liturgy': false,
            'liturgy_color': 'unknown',
            'error_code': AnalyticsService.errorCode(e),
          },
        );
        _pendingDayTrack = false;
      }
      if (cached?.liturgy != null && mounted) {
        AppSnackBar.showInfo(context, t.scheduleCachedLiturgyShown);
      }
    }
  }

  // --- MASTER DATA LOGIC ---
  Future<void> _fetchCountries() async {
    try {
      final data = await _masterService.fetchCountries();
      safeSetState(() => _countries = data);
    } catch (e, st) {
      AppLogger.logError("Fetch Countries Error", error: e, stackTrace: st);
    }
  }

  Future<void> _fetchDioceses(String countryId) async {
    try {
      final data = await _masterService.fetchDioceses(countryId);
      safeSetState(() => _dioceses = data);
    } catch (e, st) {
      AppLogger.logError("Fetch Dioceses Error", error: e, stackTrace: st);
    }
  }

  Future<void> _fetchChurches(String dioceseId) async {
    try {
      final data = await _masterService.fetchChurches(dioceseId);
      safeSetState(() => _churches = data);
    } catch (e, st) {
      AppLogger.logError("Fetch Churches Error", error: e, stackTrace: st);
    }
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

  String _scheduleCacheKey({String? churchId}) {
    final localeTag =
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final cacheChurchId = churchId ?? _userChurchId ?? 'global';
    return 'schedule:$cacheChurchId:$dateKey:$localeTag';
  }

  Map<String, dynamic> _scheduleToCache(MassSchedule schedule) {
    return {
      'id': schedule.id,
      'church_id': schedule.churchId,
      'day_number': schedule.dayOfWeek,
      'start_time': schedule.timeStart,
      'language': schedule.language,
      'churches': {
        'name': schedule.churchName,
        'parish': schedule.churchParish,
      },
    };
  }

  Map<String, dynamic> _liturgyToCache(LiturgyModel liturgy) {
    return {
      'date': liturgy.date.toIso8601String().split('T')[0],
      'color': liturgy.color,
      'feast_name': liturgy.feastName,
      'readings': liturgy.readings,
    };
  }

  Future<_ScheduleCache?> _readScheduleCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final schedulesRaw = decoded['schedules'];
      final List<MassSchedule> schedules = [];
      if (schedulesRaw is List) {
        for (final item in schedulesRaw) {
          if (item is Map<String, dynamic>) {
            schedules.add(MassSchedule.fromJson(item));
          } else if (item is Map) {
            schedules.add(MassSchedule.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      LiturgyModel? liturgy;
      final liturgyRaw = decoded['liturgy'];
      if (liturgyRaw is Map<String, dynamic>) {
        liturgy = LiturgyModel.fromJson(liturgyRaw);
      } else if (liturgyRaw is Map) {
        liturgy = LiturgyModel.fromJson(Map<String, dynamic>.from(liturgyRaw));
      }

      return _ScheduleCache(schedules: schedules, liturgy: liturgy);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeScheduleCache(
    String key, {
    List<MassSchedule>? schedules,
    LiturgyModel? liturgy,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> payload = {};
      final existingRaw = prefs.getString(key);
      if (existingRaw != null && existingRaw.isNotEmpty) {
        final decoded = jsonDecode(existingRaw);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      }

      if (schedules != null) {
        payload['schedules'] = schedules.map(_scheduleToCache).toList();
      }
      if (liturgy != null) {
        payload['liturgy'] = _liturgyToCache(liturgy);
      }
      payload['updated_at'] = DateTime.now().toIso8601String();

      await prefs.setString(key, jsonEncode(payload));
    } catch (_) {}
  }

  // --- SCHEDULE LOGIC ---

  // 1. Load by Date (Default View)
  Future<void> _loadDailySchedules() async {
    final t = AppLocalizations.of(context)!;
    safeSetState(() {
      _isLoadingSchedules = true;
      _isChurchSearchMode = false;
      _scheduleError = null;
    });

    AnalyticsService.instance.track(
      AnalyticsEvents.scheduleRefresh,
      props: {'mode': 'daily'},
    );

    final cacheKey = _scheduleCacheKey();
    final cached = await _readScheduleCache(cacheKey);
    final hasCache = cached != null;
    if (cached != null) {
      safeSetState(() {
        _schedules = cached.schedules;
        if (cached.liturgy != null) _currentLiturgy = cached.liturgy;
        _isLoadingSchedules = false;
      });
    }

    try {
      // Fetch general schedules for this weekday
      // Note: In a real app this should be filtered by user location or favourites
      final data = await _scheduleService.fetchSchedules(
        dayOfWeek: _selectedDate.weekday,
      );
      safeSetState(() {
        _schedules = data;
        _isLoadingSchedules = false;
      });
      await _writeScheduleCache(
        cacheKey,
        schedules: data,
        liturgy: _currentLiturgy,
      );
    } catch (e, st) {
      AppLogger.logError("Load Daily Schedules Error", error: e, stackTrace: st);
      safeSetState(() {
        _isLoadingSchedules = false;
        if (!hasCache) {
          _scheduleError = mapErrorMessage(e);
        }
      });
      AnalyticsService.instance.track(
        AnalyticsEvents.scheduleRefresh,
        props: {
          'mode': 'daily',
          'error_code': AnalyticsService.errorCode(e),
        },
      );
      if (hasCache && mounted) {
        AppSnackBar.showInfo(
          context,
          t.scheduleCachedScheduleShown,
        );
      }
    }
  }

  // 2. Search Specific Church (Advanced View)
  Future<void> _searchByChurch() async {
    final t = AppLocalizations.of(context)!;
    if (_selectedChurchId == null) {
      AppSnackBar.showInfo(context, t.schedulePickChurchFirst);
      return;
    }

    safeSetState(() {
      _isLoadingSchedules = true;
      _isChurchSearchMode = true;
      _scheduleError = null;
    });

    AnalyticsService.instance.track(
      AnalyticsEvents.scheduleRefresh,
      props: {'mode': 'church'},
    );

    final cacheKey = _scheduleCacheKey(churchId: _selectedChurchId);
    final cached = await _readScheduleCache(cacheKey);
    final hasCache = cached != null;
    if (cached != null) {
      safeSetState(() {
        _schedules = cached.schedules;
        if (cached.liturgy != null) _currentLiturgy = cached.liturgy;
        _isLoadingSchedules = false;
      });
    }

    try {
      // Use the service which now returns strictly typed List<MassSchedule>
      final data = await _scheduleService.fetchSchedules(
        churchId: _selectedChurchId!,
      );

      safeSetState(() {
        _schedules = data;
        _isLoadingSchedules = false;
      });
      await _writeScheduleCache(
        cacheKey,
        schedules: data,
        liturgy: _currentLiturgy,
      );
    } catch (e, st) {
      AppLogger.logError("Search Error", error: e, stackTrace: st);
      safeSetState(() {
        _isLoadingSchedules = false;
        if (!hasCache) {
          _scheduleError = mapErrorMessage(e);
        }
      });
      AnalyticsService.instance.track(
        AnalyticsEvents.scheduleRefresh,
        props: {
          'mode': 'church',
          'error_code': AnalyticsService.errorCode(e),
        },
      );
      if (hasCache && mounted) {
        AppSnackBar.showInfo(
          context,
          t.scheduleCachedScheduleShown,
        );
      }
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
    final t = AppLocalizations.of(context)!;
    // UPDATED: Use MassCheckInWizard in pre-filled mode
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (_) => MassCheckInWizard(initialChurchId: churchId, initialScheduleId: scheduleId),
    );
    
    if (result == true && mounted) {
      AppSnackBar.showSuccess(
        context,
        t.scheduleCheckInSuccess,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: MyCatholicAppBar(title: t.scheduleTitle),
      body: Builder(
        builder: (context) {
          try {
            return _buildScheduleBody(context);
          } catch (e, st) {
            AppLogger.logError("SchedulePage build error",
                error: e, stackTrace: st);
            return AppStateView(
              state: AppViewState.error,
              error: AppError(
                title: t.scheduleLoadErrorTitle,
                message: t.scheduleLoadErrorMessage,
                raw: e,
                st: st,
              ),
              onRetry: () {
                _loadLiturgy();
                _loadSchedules();
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildScheduleBody(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final textMuted = colors.onSurface.withOpacity(0.5);
    final palette = _resolvePalette(colors);
    final isWhite = _isWhiteLiturgy();
    final accentForWhite = palette.accent;
    final calendarSemantics =
        "${t.scheduleCalendarLabel}: ${_formatSelectedDate(context)}, ${t.scheduleLiturgyColor(_liturgyLabel(_currentLiturgy?.color))}";

    final showLoading = _isLoadingSchedules && _schedules.isEmpty;
    final showError = _scheduleError != null && _schedules.isEmpty;
    final showEmpty = !_isLoadingSchedules && _schedules.isEmpty && _scheduleError == null;

    return CustomScrollView(
      slivers: [
        // 1. Calendar
        SliverToBoxAdapter(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Positioned(
                    left: 6,
                    top: 2,
                    child: Text(
                      t.scheduleCalendarLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildLiturgyChip(palette),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Semantics(
                      container: true,
                      label: calendarSemantics,
                      child: EasyDateTimeLine(
                        initialDate: _selectedDate,
                        onDateChange: (d) {
                          setState(() {
                            _selectedDate = d;
                            _pendingDayTrack = true;
                          });
                          _loadLiturgy();
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
                              color:
                                  isWhite ? palette.base : palette.accent,
                              border: Border.all(
                                color: isWhite
                                    ? accentForWhite.withOpacity(0.6)
                                    : palette.border,
                                width: 1.4,
                              ),
                              boxShadow: isWhite
                                  ? [
                                      BoxShadow(
                                        color: accentForWhite.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            dayNumStyle: GoogleFonts.outfit(
                              color: isWhite
                                  ? const Color(0xFF121212)
                                  : palette.onAccent,
                              fontWeight: FontWeight.bold,
                            ),
                            dayStrStyle: GoogleFonts.outfit(
                              color: isWhite
                                  ? const Color(0xFF121212)
                                      .withOpacity(0.85)
                                  : palette.onAccent.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          todayStyle: DayStyle(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: palette.accent.withOpacity(0.9),
                                width: 1.4,
                              ),
                              color: palette.tint,
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
                ],
              ),
            ),
          ),
        ),

        // 1.5 Liturgy Legend
        SliverToBoxAdapter(
          child: _buildLiturgyLegend(colors),
        ),

        // 2. Liturgy Card
        SliverToBoxAdapter(child: _buildLiturgyHeader()),

        // 2.5 Personalized Parish Schedule
        SliverToBoxAdapter(child: _buildPersonalParishSection()),

        // 3. Advanced Search Toggle
        SliverToBoxAdapter(
          child: Padding(
            key: _searchSectionKey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                title: Text(
                  t.scheduleSearchTitle,
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
                    label: t.registerCountryLabel,
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
                    label: t.registerDioceseLabel,
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
                    label: t.registerParishLabel,
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
                        t.scheduleSearchButton,
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
                        t.scheduleResetDaily,
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
                  ? t.scheduleResultsChurch
                  : t.scheduleResultsToday,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
        ),

        if (_scheduleError != null && _schedules.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildScheduleInlineError(_scheduleError!, colors),
          ),

        if (showLoading)
          SliverToBoxAdapter(
            child: _buildScheduleLoadingState(colors, textSecondary),
          )
        else if (showError)
          SliverToBoxAdapter(
            child: _buildScheduleErrorState(colors, _scheduleError),
          )
        else if (showEmpty)
          SliverToBoxAdapter(
            child: _buildScheduleEmptyState(
              colors: colors,
              textSecondary: textSecondary,
              textMuted: textMuted,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = _schedules[index];
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
    );
  }

  Widget _buildScheduleLoadingState(
    ColorScheme colors,
    Color textSecondary,
  ) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 12),
            Text(
              t.scheduleLoading,
              style: GoogleFonts.outfit(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleErrorState(ColorScheme colors, String? message) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: AppCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 28),
            const SizedBox(height: 8),
            Text(
              message ?? t.scheduleLoadErrorTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: colors.onSurface),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: t.scheduleRetry,
                onPressed: _loadSchedules,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleInlineError(String message, ColorScheme colors) {
    final t = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.error.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadSchedules,
              child: Text(
                t.scheduleRetry,
                style: GoogleFonts.outfit(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleEmptyState({
    required ColorScheme colors,
    required Color textSecondary,
    required Color textMuted,
  }) {
    final t = AppLocalizations.of(context)!;
    final title =
        _isChurchSearchMode ? t.scheduleEmptyTitleChurch : t.scheduleEmptyTitleDaily;
    final message = _isChurchSearchMode
        ? t.scheduleEmptyMessageChurch
        : t.scheduleEmptyMessageDaily;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy, size: 60, color: textMuted),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            if (_isChurchSearchMode)
              AppPrimaryButton(
                label: t.scheduleResetDaily,
                onPressed: _loadDailySchedules,
              )
            else
              AppSecondaryButton(
                label: t.scheduleSearchChurchButton,
                onPressed: _scrollToSearchSection,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiturgyChip(LiturgicalPalette palette) {
    final label = _liturgyLabel(_currentLiturgy?.color);
    final isWhite = _isWhiteLiturgy();
    return AnimatedContainer(
      key: ValueKey(label),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isWhite ? palette.chipBg : palette.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.border,
          width: isWhite ? 1.2 : 1,
        ),
        boxShadow: [
          if (isWhite)
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: palette.accent.withOpacity(0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: palette.dot,
              shape: BoxShape.circle,
              border: isWhite ? Border.all(color: palette.border) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: palette.onAccent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiturgyLegend(ColorScheme colors) {
    final t = AppLocalizations.of(context)!;
    final items = [
      {"label": t.scheduleLegendWhite, "code": "white"},
      {"label": t.scheduleLegendRed, "code": "red"},
      {"label": t.scheduleLegendGreen, "code": "green"},
      {"label": t.scheduleLegendPurple, "code": "purple"},
      {"label": t.scheduleLegendRose, "code": "rose"},
      {"label": t.scheduleLegendBlack, "code": "black"},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: items.map((item) {
          final palette = LiturgyService.paletteFor(
            item["code"] ?? '',
            brightness: Theme.of(context).brightness,
          );
          final isWhite = (item["code"] ?? '') == 'white';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.dot,
                  shape: BoxShape.circle,
                  border: isWhite
                      ? Border.all(color: palette.border)
                      : Border.all(color: palette.border.withOpacity(0.35)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item["label"] ?? '',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: colors.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _retryAll() {
    _loadLiturgy();
    _loadSchedules();
  }

  void _scrollToSearchSection() {
    final ctx = _searchSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatSelectedDate(BuildContext context) {
    const pattern = 'EEEE, d MMMM yyyy';
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    try {
      return DateFormat(pattern, localeTag).format(_selectedDate);
    } catch (_) {
      try {
        return DateFormat(pattern, 'id_ID').format(_selectedDate);
      } catch (_) {
        try {
          return DateFormat(pattern, 'id').format(_selectedDate);
        } catch (_) {
          return DateFormat(pattern).format(_selectedDate);
        }
      }
    }
  }

  // --- UI COMPONENTS ---
  Widget _buildLiturgyHeader() {
    final t = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final palette = _resolvePalette(colors);
    final accent = palette.accent;
    final isWhite = _isWhiteLiturgy();
    final readingColor =
        isWhite ? textPrimary : accent;

    if (_loadingLiturgy) {
      return _buildLiturgyCard(
        palette: palette,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.scheduleLiturgyLoading,
                style: GoogleFonts.outfit(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentLiturgy == null) {
      return _buildLiturgyCard(
        palette: palette,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.scheduleLiturgyMissing,
                    style: GoogleFonts.outfit(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_liturgyError != null) ...[
              const SizedBox(height: 6),
              Text(
                _liturgyError!,
                style: GoogleFonts.outfit(color: textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loadLiturgy,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                ),
                child: Text(
                  t.scheduleRetry,
                  style: GoogleFonts.outfit(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildLiturgyCard(
      palette: palette,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.church,
              size: 140,
              color: accent.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWhite
                            ? const Color(0xFFF5F5F5)
                            : accent,
                        border: Border.all(
                          color: isWhite
                              ? const Color(0xFFE6E6E6)
                              : palette.border,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatSelectedDate(context),
                        style: GoogleFonts.outfit(
                          color: isWhite
                              ? const Color(0xFF121212)
                              : palette.onAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome,
                      color: isWhite
                          ? accent.withOpacity(0.7)
                          : accent.withOpacity(0.8),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _currentLiturgy?.feastName ?? t.scheduleFeastFallback,
                    key: ValueKey(_currentLiturgy?.feastName ?? t.scheduleFeastFallback),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.scheduleLiturgyColor(
                          _liturgyLabel(_currentLiturgy?.color),
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_currentLiturgy!.readings.isNotEmpty) ...[
                  _buildReadingRow(
                    t.scheduleReadingLabel1,
                    _currentLiturgy!.readings['bacaan1'] ?? '-',
                    readingColor,
                  ),
                  if (_currentLiturgy!.readings['mazmur'] != null)
                    _buildReadingRow(
                      t.scheduleReadingLabelPsalm,
                      _currentLiturgy!.readings['mazmur'] ?? '-',
                      readingColor,
                    ),
                  _buildReadingRow(
                    t.scheduleReadingLabelGospel,
                    _currentLiturgy!.readings['injil'] ?? '-',
                    readingColor,
                  ),
                ] else
                  Text(
                    t.scheduleReadingUnavailable,
                    style: GoogleFonts.outfit(
                      color: textSecondary,
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

  Widget _buildLiturgyCard({
    required LiturgicalPalette palette,
    required Widget child,
  }) {
    return AppCard(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.zero,
      color: palette.tint,
      borderColor: palette.border,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 10,
            bottom: 10,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: palette.accent.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildReadingRow(String label, String ref, Color color) {
    final t = AppLocalizations.of(context)!;
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
                  color: color.withOpacity(0.8),
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
        collapsedIconColor: color.withOpacity(0.5),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: color.withOpacity(0.8),
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
                  decorationColor: color.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
        children: [
          FutureBuilder<String?>(
            future: Future.value(t.scheduleBibleDisabled),
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
                    t.scheduleReadingError,
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
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.1)),
                ),
                child: Text(
                  snapshot.data!,
                  style: GoogleFonts.outfit(
                    color: color.withOpacity(0.9),
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

  LiturgicalPalette _resolvePalette(ColorScheme colors) {
    final theme = Theme.of(context);
    final palette = LiturgyService.paletteFor(
      _currentLiturgy?.color ?? '',
      brightness: theme.brightness,
    );
    if (_currentLiturgy == null) {
      final accent = colors.primary;
      return palette.copyWith(
        base: accent,
        accent: accent,
        tint: accent.withOpacity(0.12),
        border: accent.withOpacity(0.45),
        onAccent: colors.onPrimary,
        chipBg: accent.withOpacity(0.12),
        chipText: colors.onPrimary,
        dot: accent,
      );
    }
    return palette;
  }

  bool _isWhiteLiturgy() {
    final code = _currentLiturgy?.color.trim().toLowerCase();
    return code == 'white' || code == 'gold' || code == 'putih';
  }

  String _liturgyLabel(String? code) {
    switch (code?.trim().toLowerCase()) {
      case 'white':
      case 'gold':
      case 'putih':
        return 'PUTIH';
      case 'red':
      case 'merah':
        return 'MERAH';
      case 'green':
      case 'hijau':
        return 'HIJAU';
      case 'purple':
      case 'ungu':
        return 'UNGU';
      case 'rose':
      case 'pink':
      case 'merah muda':
        return 'ROSE';
      case 'black':
      case 'hitam':
        return 'HITAM';
      default:
        return 'LITURGI';
    }
  }

  Widget _buildTicketCard(MassSchedule item) {
    final t = AppLocalizations.of(context)!;
    // Show Day Name if in "Church Search Mode"
    final dayName = _getDayName(context, item.dayOfWeek);
    final isActive = _isMassActive(item.timeStart);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final palette = _resolvePalette(colors);
    final isWhite = _isWhiteLiturgy();
    final litColor = palette.accent;
    final litLabel = _liturgyLabel(_currentLiturgy?.color);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.onSurface.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
          Positioned(
            left: 16,
            top: 16,
            bottom: 16,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: litColor,
                borderRadius: BorderRadius.circular(6),
                border:
                    isWhite ? Border.all(color: palette.border) : null,
                boxShadow: isWhite
                    ? [
                        BoxShadow(
                          color: palette.accent.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 4),
                // JAM / STATUS CONTAINER
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            color:
                                isActive ? colors.secondary : colors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        item.timeStart.substring(0, 5), // HH:mm
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isActive ? colors.secondary : colors.primary,
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
                              color: palette.chipBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              litLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: palette.chipText,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.chipBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                t.scheduleActiveLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: palette.chipText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _isChurchSearchMode ? dayName : (item.churchParish ?? '-'),
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
                          Icon(Icons.language, size: 12, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            item.language ?? t.scheduleLanguageGeneral,
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
                        t.scheduleCheckInButton,
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
          ],
        ),
      ),
    );
  }

  String _getDayName(BuildContext context, int day) {
    if (day < 1 || day > 7) return '-';
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final base = DateTime(2024, 1, 1 + (day - 1));
    try {
      return DateFormat('EEEE', localeTag).format(base);
    } catch (_) {
      try {
        return DateFormat('EEEE', 'id_ID').format(base);
      } catch (_) {
        return DateFormat('EEEE').format(base);
      }
    }
  }

  // --- PERSONAL PARISH LOGIC ---
  Widget _buildPersonalParishSection() {
    final t = AppLocalizations.of(context)!;
    final user = _supabase.auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<Profile>(
      // Using a Future wrapped in stream for simplicity, or could rely on real-time profile logic.
      // Re-fetching on build to ensure updates are caught if user edits profile.
      stream: Stream.fromFuture(_profileService.fetchUserProfile(user.id)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildParishPlaceholder(message: t.scheduleParishLoading);
        }
        if (snapshot.hasError) {
          return _buildParishErrorCard(
            message: t.scheduleParishLoadError,
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) {
          return _buildParishPlaceholder(message: t.scheduleParishEmpty);
        }

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

        final parishId = profile.churchId;

        if (parishId == null || parishId.isEmpty) {
          return _buildSetParishCard();
        }

        return FutureBuilder<List<MassSchedule>>(
          future: _scheduleService.fetchSchedules(churchId: parishId),
          builder: (context, scheduleSnapshot) {
            if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
              return _buildParishPlaceholder(
                message: t.scheduleParishScheduleLoading,
              );
            }

            if (scheduleSnapshot.hasError) {
              return _buildParishErrorCard(
                message: t.scheduleParishScheduleError,
                onRetry: () => setState(() {}),
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
                  color: colors.primary.withOpacity(0.35),
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
                          t.scheduleParishHeader,
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
                      t.scheduleParishEmptySchedule,
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
                                color: theme.shadowColor.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDayName(context, s.dayOfWeek),
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
                                s.language ?? t.scheduleLanguageGeneral,
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

  Widget _buildParishPlaceholder({required String message}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: colors.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishErrorCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.outfit(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.primary),
              ),
              child: Text(
                t.scheduleRetry,
                style: GoogleFonts.outfit(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetParishCard({bool isUpdate = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = colors.surface;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final t = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.secondary.withOpacity(0.45)),
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
                  isUpdate ? t.scheduleParishSetupTitleUpdate : t.scheduleParishSetupTitle,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  isUpdate
                      ? t.scheduleParishSetupMessageUpdate
                      : t.scheduleParishSetupMessage,
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
            child: Text(t.scheduleParishSetupAction),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCache {
  final List<MassSchedule> schedules;
  final LiturgyModel? liturgy;

  const _ScheduleCache({
    required this.schedules,
    this.liturgy,
  });
}
