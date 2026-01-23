import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mass_schedule.dart';
import '../services/radar_service.dart';
import '../services/schedule_service.dart';

class CreateRadarScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? editRadarId;

  const CreateRadarScreen({super.key, this.initialData, this.editRadarId});

  @override
  State<CreateRadarScreen> createState() => _CreateRadarScreenState();
}

class _CreateRadarScreenState extends State<CreateRadarScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RadarService _radarService = RadarService();
  final ScheduleService _scheduleService = ScheduleService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  bool _isSubmitting = false;

  bool _isLoadingCountries = true;
  bool _isLoadingDioceses = false;
  bool _isLoadingChurches = false;
  bool _isLoadingSchedules = false;

  int _maxParticipants = 50;
  bool _allowMemberInvite = true;
  bool _requireHostApproval = false;

  List<_SelectOption> _countries = [];
  List<_SelectOption> _dioceses = [];
  List<_SelectOption> _churches = [];

  _SelectOption? _selectedCountry;
  _SelectOption? _selectedDiocese;
  _SelectOption? _selectedChurch;

  List<MassSchedule> _schedules = [];
  MassSchedule? _selectedSchedule;
  DateTime? _scheduleTime;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_rebuild);
    _applyInitialData();
    _loadCountries();
  }

  void _applyInitialData() {
    final data = widget.initialData;
    if (data == null) return;

    int? parseInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    bool? parseBool(Object? v) {
      if (v == null) return null;
      if (v is bool) return v;
      final s = v.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 't' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'f' || s == 'no') return false;
      return null;
    }

    DateTime? parseDateTime(Object? v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return DateTime.tryParse(s);
    }

    final title = (data['title'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    final churchId = (data['church_id'] ?? '').toString();
    final churchName = (data['church_name'] ?? '').toString();
    final initialEventTime = parseDateTime(
      data['event_time'] ??
          data['eventTime'] ??
          data['schedule_time'] ??
          data['scheduleTime'],
    );
    final maxParticipants = parseInt(
      data['max_participants'] ?? data['maxParticipants'],
    );
    final allowMemberInvite = parseBool(
      data['allow_member_invite'] ?? data['allowMemberInvite'],
    );
    final requireHostApproval = parseBool(
      data['require_host_approval'] ?? data['requireHostApproval'],
    );

    if (title.trim().isNotEmpty) _titleController.text = title;
    if (description.trim().isNotEmpty && description != 'null') {
      _descController.text = description;
    }
    if (maxParticipants != null && maxParticipants >= 2) {
      _maxParticipants = maxParticipants;
    }
    if (allowMemberInvite != null) {
      _allowMemberInvite = allowMemberInvite;
    }
    if (requireHostApproval != null) {
      _requireHostApproval = requireHostApproval;
    }

    if (widget.editRadarId != null && initialEventTime != null) {
      _scheduleTime = initialEventTime.toLocal();
    }

    if (churchId.trim().isEmpty) return;

    _selectedChurch = _SelectOption(
      id: churchId,
      title: churchName.trim().isNotEmpty ? churchName.trim() : 'Gereja',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSchedules(churchId, resetScheduleTime: widget.editRadarId == null);
      _hydrateLocationPickerFromChurchId(churchId);
    });
  }

  Future<void> _hydrateLocationPickerFromChurchId(String churchId) async {
    try {
      final response = await _supabase
          .from('churches')
          .select(
            'id, name, diocese_id, dioceses:diocese_id(id, name, country_id, countries:country_id(id, name, flag_emoji))',
          )
          .eq('id', churchId)
          .single();

      final churchRow = Map<String, dynamic>.from(response as Map);
      final diocese = churchRow['dioceses'] is Map
          ? Map<String, dynamic>.from(churchRow['dioceses'] as Map)
          : null;
      final country = diocese != null && diocese['countries'] is Map
          ? Map<String, dynamic>.from(diocese['countries'] as Map)
          : null;

      final countryId = country?['id']?.toString();
      final countryName = (country?['name'] ?? '').toString().trim();
      final flagEmoji = (country?['flag_emoji'] ?? '').toString().trim();
      final countryTitle = [
        flagEmoji,
        countryName,
      ].where((s) => s.isNotEmpty).join(' ');

      final dioceseId = diocese?['id']?.toString();
      final dioceseName = (diocese?['name'] ?? '').toString().trim();

      final resolvedChurchName = (churchRow['name'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        if (countryId != null && countryTitle.isNotEmpty) {
          _selectedCountry = _SelectOption(id: countryId, title: countryTitle);
        }
        if (dioceseId != null && dioceseName.isNotEmpty) {
          _selectedDiocese = _SelectOption(id: dioceseId, title: dioceseName);
        }
        if (_selectedChurch != null &&
            _selectedChurch!.title == 'Gereja' &&
            resolvedChurchName.isNotEmpty) {
          _selectedChurch = _SelectOption(
            id: _selectedChurch!.id,
            title: resolvedChurchName,
          );
        }
      });

      if (countryId != null) await _loadDioceses(countryId);
      if (dioceseId != null) await _loadChurches(dioceseId);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          "[RADAR UI] Failed to hydrate location picker from church_id: $e\n$st",
        );
      }
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_rebuild);
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return !_isSubmitting &&
        _selectedChurch != null &&
        _titleController.text.trim().isNotEmpty &&
        _scheduleTime != null;
  }

  Future<void> _loadCountries() async {
    setState(() => _isLoadingCountries = true);
    try {
      final response = await _supabase
          .from('countries')
          .select('id, name, flag_emoji')
          .order('name', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        _countries = list
            .map(
              (e) => _SelectOption(
                id: e['id'].toString(),
                title: [
                  (e['flag_emoji'] ?? '').toString().trim(),
                  (e['name'] ?? '').toString().trim(),
                ].where((s) => s.isNotEmpty).join(' '),
              ),
            )
            .toList();
        _isLoadingCountries = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR UI] Failed to load countries: $e\n$st");
      }
      if (!mounted) return;
      setState(() {
        _countries = [];
        _isLoadingCountries = false;
      });
    }
  }

  Future<void> _loadDioceses(String countryId) async {
    setState(() {
      _isLoadingDioceses = true;
      _dioceses = [];
    });

    try {
      final response = await _supabase
          .from('dioceses')
          .select('id, name')
          .eq('country_id', countryId)
          .order('name', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        _dioceses = list
            .map(
              (e) => _SelectOption(
                id: e['id'].toString(),
                title: e['name'].toString(),
              ),
            )
            .toList();
        _isLoadingDioceses = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR UI] Failed to load dioceses: $e\n$st");
      }
      if (!mounted) return;
      setState(() {
        _dioceses = [];
        _isLoadingDioceses = false;
      });
    }
  }

  Future<void> _loadChurches(String dioceseId) async {
    setState(() {
      _isLoadingChurches = true;
      _churches = [];
    });

    try {
      final response = await _supabase
          .from('churches')
          .select('id, name')
          .eq('diocese_id', dioceseId)
          .order('name', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      if (!mounted) return;
      setState(() {
        _churches = list
            .map(
              (e) => _SelectOption(
                id: e['id'].toString(),
                title: e['name'].toString(),
              ),
            )
            .toList();
        _isLoadingChurches = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR UI] Failed to load churches: $e\n$st");
      }
      if (!mounted) return;
      setState(() {
        _churches = [];
        _isLoadingChurches = false;
      });
    }
  }

  Future<void> _loadSchedules(
    String churchId, {
    bool resetScheduleTime = true,
  }) async {
    setState(() {
      _isLoadingSchedules = true;
      _schedules = [];
      _selectedSchedule = null;
      if (resetScheduleTime) _scheduleTime = null;
    });

    try {
      final schedules = await _scheduleService.fetchSchedules(
        churchId: churchId,
      );
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _isLoadingSchedules = false;
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR UI] Failed to load schedules: $e\n$st");
      }
      if (!mounted) return;
      setState(() {
        _schedules = [];
        _isLoadingSchedules = false;
      });
    }
  }

  Future<_SelectOption?> _pickOption({
    required String title,
    required List<_SelectOption> options,
  }) async {
    return showModalBottomSheet<_SelectOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OptionPickerSheet(title: title, options: options),
    );
  }

  Future<void> _pickCountry() async {
    if (_isLoadingCountries) return;
    if (_countries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data negara belum tersedia")),
      );
      return;
    }

    final picked = await _pickOption(
      title: "Pilih Negara",
      options: _countries,
    );
    if (picked == null) return;

    setState(() {
      _selectedCountry = picked;
      _selectedDiocese = null;
      _selectedChurch = null;
      _dioceses = [];
      _churches = [];
      _schedules = [];
      _selectedSchedule = null;
      _scheduleTime = null;
    });

    await _loadDioceses(picked.id);
  }

  Future<void> _pickDiocese() async {
    if (_selectedCountry == null) return;
    if (_isLoadingDioceses) return;
    if (_dioceses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data keuskupan belum tersedia")),
      );
      return;
    }

    final picked = await _pickOption(
      title: "Pilih Keuskupan",
      options: _dioceses,
    );
    if (picked == null) return;

    setState(() {
      _selectedDiocese = picked;
      _selectedChurch = null;
      _churches = [];
      _schedules = [];
      _selectedSchedule = null;
      _scheduleTime = null;
    });

    await _loadChurches(picked.id);
  }

  Future<void> _pickChurch() async {
    if (_selectedDiocese == null) return;
    if (_isLoadingChurches) return;
    if (_churches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data gereja belum tersedia")),
      );
      return;
    }

    final picked = await _pickOption(title: "Pilih Gereja", options: _churches);
    if (picked == null) return;

    setState(() {
      _selectedChurch = picked;
    });

    await _loadSchedules(picked.id);
  }

  String _dayName(int dayInt) {
    if (dayInt == 0 || dayInt == 7) return "Minggu";
    const days = ["-", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
    if (dayInt >= 1 && dayInt <= 6) return days[dayInt];
    return "Hari $dayInt";
  }

  String _timeHHmm(String timeStart) {
    final parts = timeStart.split(':');
    if (parts.length < 2) return timeStart;
    final hh = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    return "$hh:$mm";
  }

  String _scheduleLabel(MassSchedule schedule) {
    return "${_dayName(schedule.dayOfWeek)} ${_timeHHmm(schedule.timeStart)}";
  }

  DateTime _nextOccurrence(MassSchedule schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var weekday = schedule.dayOfWeek;
    if (weekday == 0) weekday = 7;
    if (weekday < 1 || weekday > 7) weekday = today.weekday;

    final timeParts = schedule.timeStart.split(':');
    final hour = int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '') ?? 0;
    final minute = int.tryParse(timeParts.length > 1 ? timeParts[1] : '') ?? 0;

    final daysToAdd = (weekday - today.weekday + 7) % 7;
    final baseDate = today.add(Duration(days: daysToAdd));
    var candidate = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      hour,
      minute,
    );
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  void _onScheduleChipSelected(MassSchedule schedule) {
    final next = _nextOccurrence(schedule);
    setState(() {
      _selectedSchedule = schedule;
      _scheduleTime = next;
    });
  }

  Future<void> _pickManualScheduleTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduleTime ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduleTime != null
          ? TimeOfDay(hour: _scheduleTime!.hour, minute: _scheduleTime!.minute)
          : TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedSchedule = null;
      _scheduleTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_selectedChurch == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih gereja dulu")));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Judul ajakan wajib diisi")));
      return;
    }
    if (_scheduleTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Pilih jadwal misa dulu")));
      return;
    }

    final scheduleTime = _scheduleTime!;
    if (!scheduleTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Waktu misa harus di masa depan")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final scheduleTimeUtcIso = scheduleTime.toUtc().toIso8601String();

      final isEditMode = widget.editRadarId != null;
      if (isEditMode) {
        await _radarService.updateRadar(
          id: widget.editRadarId!,
          updates: {
            'title': _titleController.text.trim(),
            'description': _descController.text.trim(),
            'church_id': _selectedChurch!.id,
            'church_name': _selectedChurch!.title,
            'event_time': scheduleTimeUtcIso,
            'max_participants': _maxParticipants,
            'allow_member_invite': _allowMemberInvite,
            'require_host_approval': _requireHostApproval,
          },
          changeDescription: "Update Informasi Event",
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perubahan berhasil disimpan")),
        );
        Navigator.pop(context, true);
      } else {
        await _radarService.createPublicRadar(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          churchId: _selectedChurch!.id,
          churchName: _selectedChurch!.title,
          scheduleTimeUtcIso: scheduleTimeUtcIso,
          maxParticipants: _maxParticipants,
          allowMemberInvite: _allowMemberInvite,
          requireHostApproval: _requireHostApproval,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Radar berhasil diterbitkan")),
        );
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR UI] Submit failed: $e\n$st");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Gagal membuat radar")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.outfit(color: Colors.grey[700], height: 1.3),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _selectionTile({
    required String label,
    required String placeholder,
    required _SelectOption? value,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
    IconData icon = Icons.place_outlined,
  }) {
    final title = value?.title;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: ListTile(
        onTap: enabled ? onTap : null,
        leading: Icon(icon),
        title: Text(
          title?.isNotEmpty == true ? title! : placeholder,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _gradientButton({
    required String text,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final colors = enabled
        ? const [Color(0xFF0088CC), Color(0xFF00BFA6)]
        : [Colors.grey.shade400, Colors.grey.shade400];

    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool get _isEditMode => widget.editRadarId != null;

  bool get _isRepostMode => widget.initialData != null && !_isEditMode;

  String get _pageTitle {
    if (_isEditMode) return "Edit Radar Misa";
    if (_isRepostMode) return "Terbitkan Ulang Radar";
    return "Buat Radar Misa Publik";
  }

  String get _submitButtonText {
    if (_isEditMode) return "Simpan Perubahan";
    return _isRepostMode ? "Terbitkan Ulang" : "Terbitkan Radar";
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Lokasi Misa",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          title: "Mau Misa di Mana?",
          subtitle:
              "Pilih lokasi secara berurutan untuk mendapatkan church_id yang valid.",
          child: Column(
            children: [
              _selectionTile(
                label: "Negara",
                placeholder: "Pilih negara",
                value: _selectedCountry,
                enabled: !_isLoadingCountries,
                loading: _isLoadingCountries,
                onTap: _pickCountry,
                icon: Icons.public,
              ),
              const SizedBox(height: 10),
              _selectionTile(
                label: "Keuskupan",
                placeholder: _selectedCountry == null
                    ? "Pilih negara dulu"
                    : "Pilih keuskupan",
                value: _selectedDiocese,
                enabled: _selectedCountry != null && !_isLoadingDioceses,
                loading: _isLoadingDioceses,
                onTap: _pickDiocese,
                icon: Icons.account_balance,
              ),
              const SizedBox(height: 10),
              _selectionTile(
                label: "Gereja",
                placeholder: _selectedDiocese == null
                    ? "Pilih keuskupan dulu"
                    : "Pilih gereja",
                value: _selectedChurch,
                enabled: _selectedDiocese != null && !_isLoadingChurches,
                loading: _isLoadingChurches,
                onTap: _pickChurch,
                icon: Icons.church,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(String scheduleTimeText) {
    return _sectionCard(
      title: "Pilih Jadwal",
      subtitle: "Jadwal diambil otomatis dari database setelah gereja dipilih.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedChurch == null)
            Text(
              "Pilih gereja dulu untuk melihat jadwal misa.",
              style: GoogleFonts.outfit(color: Colors.grey[700]),
            )
          else if (_isLoadingSchedules)
            const LinearProgressIndicator(minHeight: 2)
          else if (_schedules.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Jadwal misa tidak tersedia untuk gereja ini.",
                  style: GoogleFonts.outfit(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickManualScheduleTime,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text("Atur manual tanggal & jam"),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _schedules.map((s) {
                final selected = _selectedSchedule?.id == s.id;
                return ChoiceChip(
                  label: Text(_scheduleLabel(s)),
                  selected: selected,
                  onSelected: (_) => _onScheduleChipSelected(s),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Waktu terpilih: $scheduleTimeText",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_selectedChurch != null)
                  TextButton(
                    onPressed: _pickManualScheduleTime,
                    child: const Text("Ubah"),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(thickness: 1, height: 1, color: Color(0xFFEAEAEA)),
        const SizedBox(height: 14),
        Text(
          "Pengaturan Tambahan",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          title: "Pengaturan Acara",
          subtitle: "Atur kuota dan perizinan peserta sebelum diterbitkan.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.group_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Kuota Peserta",
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    "$_maxParticipants orang",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0088CC),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _maxParticipants.toDouble(),
                min: 2,
                max: 200,
                divisions: 198,
                label: _maxParticipants.toString(),
                onChanged: (v) => setState(() => _maxParticipants = v.round()),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _allowMemberInvite,
                onChanged: (v) => setState(() => _allowMemberInvite = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Izinkan Peserta Mengundang Teman",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  "Jika aktif, peserta lain bisa mengajak teman mereka",
                  style: GoogleFonts.outfit(color: Colors.grey[700]),
                ),
              ),
              SwitchListTile(
                value: _requireHostApproval,
                onChanged: (v) => setState(() => _requireHostApproval = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Butuh Persetujuan Host",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  "Jika aktif, peserta baru harus Anda setujui dulu",
                  style: GoogleFonts.outfit(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return _sectionCard(
      title: "Detail Ajakan",
      subtitle: "Beri judul yang jelas agar orang lain mudah tertarik.",
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: "Judul (wajib)",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0088CC),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: "Catatan (opsional)",
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF0088CC),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheduleTimeText = _scheduleTime == null
        ? "Belum dipilih"
        : DateFormat('EEE, dd MMM yyyy • HH:mm').format(_scheduleTime!);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _pageTitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: AbsorbPointer(
        absorbing: _isSubmitting,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLocationSection(),
            const SizedBox(height: 14),
            _buildScheduleSection(scheduleTimeText),
            const SizedBox(height: 14),
            _buildSettingsSection(),
            const SizedBox(height: 14),
            _buildDetailsSection(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: _gradientButton(
            text: _submitButtonText,
            enabled: _canSubmit,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}

class _SelectOption {
  final String id;
  final String title;

  const _SelectOption({required this.id, required this.title});
}

class _OptionPickerSheet extends StatefulWidget {
  final String title;
  final List<_SelectOption> options;

  const _OptionPickerSheet({required this.title, required this.options});

  @override
  State<_OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends State<_OptionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<_SelectOption> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filtered = widget.options);
      return;
    }
    setState(() {
      _filtered = widget.options
          .where((o) => o.title.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: "Cari...",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        "Tidak ada hasil.",
                        style: GoogleFonts.outfit(color: Colors.grey[700]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final opt = _filtered[index];
                        return ListTile(
                          title: Text(
                            opt.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, opt),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
