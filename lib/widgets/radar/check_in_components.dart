import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/services/check_in_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';

const Color kPrimaryBlue = Color(0xFF0088CC);

// -----------------------------------------------------------------------------
// 1. Mass Check-In Form (Single Page - No Steps)
// -----------------------------------------------------------------------------
class MassCheckInWizard extends StatefulWidget {
  final String? initialChurchId;
  final String? initialScheduleId;

  const MassCheckInWizard({
    super.key,
    this.initialChurchId,
    this.initialScheduleId,
  });

  @override
  State<MassCheckInWizard> createState() => _MassCheckInWizardState();
}

class _MassCheckInWizardState extends State<MassCheckInWizard> {
  final _supabase = Supabase.instance.client;
  final CheckInService _service = CheckInService();

  bool _isLoading = false;
  
  // Data: Location
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];
  
  bool _loadingCountries = false;
  bool _loadingDioceses = false;
  bool _loadingChurches = false;

  String? _selectedCountryId;
  String? _selectedCountryName;
  
  String? _selectedDioceseId;
  String? _selectedDioceseName;
  
  String? _selectedChurchId;
  String? _selectedChurchName;

  // Data: Schedule
  List<Map<String, dynamic>> _schedules = [];
  bool _loadingSchedules = false;
  String? _selectedScheduleId;
  Map<String, dynamic>? _selectedScheduleData; 
  
  // Manual
  bool _isManualSchedule = false;
  TimeOfDay? _manualTime;

  // Privacy
  String _visibility = 'PUBLIC';

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (widget.initialChurchId != null) {
      await _handlePrefilledInit();
    } else {
      await _fetchCountries();
    }
  }

  Future<void> _handlePrefilledInit() async {
    setState(() => _isLoading = true);
    try {
      _selectedChurchId = widget.initialChurchId;
      final res = await _supabase.from('churches').select('name').eq('id', _selectedChurchId!).maybeSingle();
      if (res != null) {
         _selectedChurchName = res['name'];
      }
      
      // Auto expand schedules
      await _fetchSchedules();

      if (widget.initialScheduleId != null) {
        _selectedScheduleId = widget.initialScheduleId;
        final sch = await _supabase.from('mass_schedules').select('*').eq('id', _selectedScheduleId!).maybeSingle();
        if(sch != null) _selectedScheduleData = sch;
      }
    } catch (e) {
      debugPrint("Pre-fill error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- API ---

  Future<void> _fetchCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final res = await _supabase.from('countries').select('id, name').order('name');
      if (mounted) {
        setState(() {
          _countries = List<Map<String, dynamic>>.from(res);
          final indo = _countries.firstWhere((c) => c['name'].toString().contains("Indonesia"), orElse: () => {});
          if(indo.isNotEmpty) {
             _selectedCountryId = indo['id'];
             _selectedCountryName = indo['name'];
             _fetchDioceses(_selectedCountryId!);
          }
        });
      }
    } catch (e) {
      debugPrint("Err countries: $e");
    } finally {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  Future<void> _fetchDioceses(String countryId) async {
    setState(() => _loadingDioceses = true);
    try {
      final res = await _supabase.from('dioceses').select('id, name').eq('country_id', countryId).order('name');
      if (mounted) setState(() => _dioceses = List<Map<String, dynamic>>.from(res));
    } catch (e) {
       debugPrint("Err dioceses: $e");
    } finally {
       if (mounted) setState(() => _loadingDioceses = false);
    }
  }

  Future<void> _fetchChurches(String dioceseId) async {
    setState(() => _loadingChurches = true);
    try {
      final res = await _supabase.from('churches').select('id, name').eq('diocese_id', dioceseId).order('name');
      if (mounted) setState(() => _churches = List<Map<String, dynamic>>.from(res));
    } catch (e) {
       debugPrint("Err churches: $e");
    } finally {
       if (mounted) setState(() => _loadingChurches = false);
    }
  }

  Future<void> _fetchSchedules() async {
    if (_selectedChurchId == null) return;
    setState(() => _loadingSchedules = true);
    try {
      final weekday = DateTime.now().weekday; 
      
      final res = await _supabase.from('mass_schedules')
          .select('id, day_number, start_time, language') 
          .eq('church_id', _selectedChurchId!)
          .eq('day_number', weekday)
          .order('start_time', ascending: true);
      
      if (mounted) setState(() => _schedules = List<Map<String, dynamic>>.from(res));
    } catch (e) {
       debugPrint("Err schedules: $e");
    } finally {
       if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  // --- LOGIC ---

  void _resetSelection(int level) {
      if (level == 1) { 
        _selectedDioceseId = null; _selectedDioceseName = null; _dioceses = [];
        _selectedChurchId = null; _selectedChurchName = null; _churches = [];
        _selectedScheduleId = null; _schedules = []; _selectedScheduleData = null;
        _isManualSchedule = false; _manualTime = null;
      }
      if (level == 2) { 
        _selectedChurchId = null; _selectedChurchName = null; _churches = [];
        _selectedScheduleId = null; _schedules = []; _selectedScheduleData = null;
        _isManualSchedule = false; _manualTime = null;
      }
      if (level == 3) {
        _selectedScheduleId = null; _schedules = []; _selectedScheduleData = null;
        _isManualSchedule = false; _manualTime = null;
      }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) {
      setState(() {
        _manualTime = t;
        _selectedScheduleId = null; 
        _selectedScheduleData = null;
        _isManualSchedule = true;
      });
    }
  }

  Future<void> _submitCheckIn() async {
    if (_selectedChurchId == null) return;
    
    // Safety check again
    if (_isManualSchedule && _manualTime == null) return;

    // Determine correct mass DateTime
    DateTime selectedMassDateTime;
    final now = DateTime.now();

    if (_isManualSchedule && _manualTime != null) {
      selectedMassDateTime = DateTime(now.year, now.month, now.day, _manualTime!.hour, _manualTime!.minute);
    } else if (_selectedScheduleData != null) {
      // Parse start_time from DB "HH:mm:ss"
      try {
        final timeStr = _selectedScheduleData!['start_time'].toString();
        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        selectedMassDateTime = DateTime(now.year, now.month, now.day, h, m);
      } catch (e) {
          selectedMassDateTime = now;
      }
    } else {
       selectedMassDateTime = now; 
    }

    setState(() => _isLoading = true);
    try {
      await _service.checkIn(
        churchId: _selectedChurchId!,
        scheduleId: _isManualSchedule ? null : _selectedScheduleId, 
        visibility: _visibility,
        selectedMassTime: selectedMassDateTime
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isFormValid() {
    bool locationValid = _selectedChurchId != null;
    bool scheduleValid = _selectedScheduleId != null || (_isManualSchedule && _manualTime != null);
    return locationValid && scheduleValid;
  }
  
  void _showPicker(String title, List<Map<String, dynamic>> items, Function(Map<String, dynamic>) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchablePicker(title: title, items: items, onSelect: onSelect),
    );
  }

  String _getDayName(int d) {
    const days = ['-', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    if (d > 0 && d <= 7) return days[d];
    return '';
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // Slightly taller
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              margin: const EdgeInsets.only(bottom: 20)
            )
          ),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Check-in Misa", style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
              if (widget.initialChurchId == null)
                 IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ],
          ),
          const Divider(),
          
          // SCROLLABLE FORM
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- SECTION 1: LOCATION ---
                  _buildSectionTitle("1. Lokasi Gereja"),
                  
                  _buildPickerInput(
                     label: "Negara",
                     value: _selectedCountryName,
                     isLoading: _loadingCountries,
                     onTap: () {
                       _showPicker("Pilih Negara", _countries, (item) {
                          setState(() {
                            _selectedCountryId = item['id'];
                            _selectedCountryName = item['name'];
                            _resetSelection(1);
                          });
                          _fetchDioceses(_selectedCountryId!);
                       });
                     }
                  ),
                  const SizedBox(height: 12),
                   _buildPickerInput(
                     label: "Keuskupan",
                     value: _selectedDioceseName,
                     isLoading: _loadingDioceses, 
                     isEnabled: _selectedCountryId != null,
                     onTap: () {
                        _showPicker("Pilih Keuskupan", _dioceses, (item) {
                           setState(() {
                             _selectedDioceseId = item['id'];
                             _selectedDioceseName = item['name'];
                             _resetSelection(2);
                           });
                           _fetchChurches(_selectedDioceseId!);
                        });
                     }
                   ),
                   const SizedBox(height: 12),
                   _buildPickerInput(
                     label: "Gereja / Paroki",
                     value: _selectedChurchName,
                     isLoading: _loadingChurches,
                     isEnabled: _selectedDioceseId != null,
                     onTap: () {
                        _showPicker("Pilih Gereja", _churches, (item) {
                           setState(() {
                             _selectedChurchId = item['id'];
                             _selectedChurchName = item['name'];
                             _resetSelection(3); // Reset schedule
                           });
                           _fetchSchedules();
                        });
                     }
                   ),

                   const SizedBox(height: 24),
                   const Divider(thickness: 1),
                   const SizedBox(height: 24),

                   // --- SECTION 2: SCHEDULE ---
                   Opacity(
                     opacity: _selectedChurchId == null ? 0.4 : 1.0,
                     child: AbsorbPointer(
                       absorbing: _selectedChurchId == null,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            _buildSectionTitle("2. Jadwal Misa"),
                            if (_selectedChurchId != null) ...[
                               Text("${_getDayName(DateTime.now().weekday)} ini di $_selectedChurchName", 
                                 style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
                               const SizedBox(height: 12),
                            ],
                            
                            if (_loadingSchedules) 
                               const Center(child: CircularProgressIndicator())
                            else if (_schedules.isEmpty && _selectedChurchId != null)
                               Text("Tidak ada jadwal hari ini. Gunakan manual.", style: GoogleFonts.outfit(color: Colors.red))
                            else
                               Wrap(
                                 spacing: 8,
                                 runSpacing: 8,
                                 children: _schedules.map((s) {
                                    final start = (s['start_time'] ?? '00:00').toString().substring(0, 5);
                                    final selected = _selectedScheduleId == s['id'];
                                    return ChoiceChip(
                                      label: Text(start, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black)),
                                      selected: selected,
                                      selectedColor: kPrimaryBlue,
                                      onSelected: (bool v) {
                                         setState(() {
                                           _selectedScheduleId = v ? s['id'] : null;
                                           _selectedScheduleData = v ? s : null;
                                           _isManualSchedule = false;
                                         });
                                      },
                                    );
                                 }).toList(),
                               ),
                            
                            const SizedBox(height: 12),
                            // Manual Option
                             GestureDetector(
                               onTap: () {
                                  setState(() { _isManualSchedule = true; _selectedScheduleId = null; _selectedScheduleData = null; });
                                  _pickTime();
                               },
                               child: Container(
                                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                 decoration: BoxDecoration(
                                   border: Border.all(color: _isManualSchedule ? kPrimaryBlue : Colors.grey[300]!, width: _isManualSchedule ? 2 : 1),
                                   borderRadius: BorderRadius.circular(12),
                                   color: _isManualSchedule ? kPrimaryBlue.withOpacity(0.05) : Colors.white
                                 ),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text(
                                       (_manualTime != null && _isManualSchedule)
                                           ? "Manual: ${_manualTime!.format(context)}"
                                           : "Pilih Jam Manual / Lainnya", 
                                       style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: _isManualSchedule ? kPrimaryBlue : Colors.black)
                                     ),
                                     if (_manualTime != null && _isManualSchedule)
                                        const Icon(Icons.edit, size: 16, color: kPrimaryBlue)
                                     else
                                        const Icon(Icons.access_time)
                                   ],
                                 ),
                               ),
                            )
                         ],
                       ),
                     ),
                   ),

                   const SizedBox(height: 24),
                   const Divider(thickness: 1),
                   const SizedBox(height: 24),

                   // --- SECTION 3: PRIVACY ---
                   Opacity(
                     opacity: !_isFormValid() ? 0.4 : 1.0, 
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _buildSectionTitle("3. Privasi Check-in"),
                         // Privacy chips or row
                         Row(
                           children: [
                             _privacyChip('Publik', 'PUBLIC', Icons.public),
                             const SizedBox(width: 8),
                             _privacyChip('Pengikut', 'FOLLOWERS', Icons.group),
                             const SizedBox(width: 8),
                             _privacyChip('Privat', 'PRIVATE', Icons.lock),
                           ],
                         )
                       ],
                     ),
                   ),
                   
                   const SizedBox(height: 80), // Space for button FAB
                ],
              ),
            ),
          ),
          
          // FOOTER: SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_isLoading || !_isFormValid()) ? null : _submitCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                disabledBackgroundColor: Colors.grey[300]
              ),
              child: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("Check-in Mass", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _privacyChip(String label, String value, IconData icon) {
    final selected = _visibility == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _visibility = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kPrimaryBlue : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? kPrimaryBlue : Colors.transparent)
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.grey[700]))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerInput({
    required String label,
    required String? value,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: (isLoading || !isEnabled) ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: isEnabled ? Colors.white : Colors.grey[100],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(label, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                   Text(
                    value ?? "Pilih...",
                    style: GoogleFonts.outfit(
                      color: value != null ? Colors.black87 : Colors.grey,
                      fontSize: 16,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.normal
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.arrow_drop_down, color: Colors.grey)
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Search Picker (Reused)
// -----------------------------------------------------------------------------
class _SearchablePicker extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>) onSelect;

  const _SearchablePicker({
    required this.title,
    required this.items,
    required this.onSelect,
  });

  @override
  State<_SearchablePicker> createState() => _SearchablePickerState();
}

class _SearchablePickerState extends State<_SearchablePicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredItems = widget.items.where((i) {
        final name = (i['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: "Cari...",
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(child: Text("Tidak ditemukan", style: GoogleFonts.outfit(color: Colors.grey)))
                : ListView.separated(
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return ListTile(
                        title: Text(item['name'] ?? '-', style: GoogleFonts.outfit()),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          widget.onSelect(item);
                          Navigator.pop(context);
                        },
                        trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Active Mass Card (Redesign Check Out Button)
// -----------------------------------------------------------------------------
class ActiveMassCard extends StatelessWidget {
  final Map<String, dynamic> checkInData;
  final VoidCallback onCheckOut;

  const ActiveMassCard({super.key, required this.checkInData, required this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    final churchName = checkInData['churches']?['name'] ?? 'Gereja';
    final timeStr = checkInData['mass_time'] ?? checkInData['check_in_time'];
    final time = timeStr != null ? DateFormat('HH:mm').format(DateTime.parse(timeStr).toLocal()) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
           colors: [Color(0xFF0088CC), Color(0xFF005580)],
           begin: Alignment.topLeft, end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
           BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.church_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text("Sedang Misa Sekarang", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              
              // TASK: REDESIGNED CHECK OUT BUTTON
              OutlinedButton.icon(
                onPressed: onCheckOut, 
                style: OutlinedButton.styleFrom(
                   foregroundColor: Colors.white,
                   side: const BorderSide(color: Colors.redAccent, width: 2), // Red Thick Border
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   backgroundColor: Colors.white, 
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                ),
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                label: Text("SELESAI MISA", style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(churchName, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text("Mulai pukul $time • Jangan lupa matikan HP", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Community Presence List
// -----------------------------------------------------------------------------
class CommunityPresenceList extends StatefulWidget {
  final String churchId;
  const CommunityPresenceList({super.key, required this.churchId});

  @override
  State<CommunityPresenceList> createState() => _CommunityPresenceListState();
}

class _CommunityPresenceListState extends State<CommunityPresenceList> {
  final CheckInService _service = CheckInService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final data = await _service.fetchActiveUsers(widget.churchId);
      if (mounted) setState(() => _users = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfile(Map<String, dynamic> user) {
     final name = user['full_name'] ?? 'Umat';
     showModalBottomSheet(
       context: context,
       builder: (ctx) => Container(
         padding: const EdgeInsets.all(24),
         height: 300, 
         width: double.infinity,
         child: Column(
           children: [
             CircleAvatar(
               radius: 40, 
               backgroundImage: (user['avatar_url'] != null) ? NetworkImage(user['avatar_url']) : null,
               child: (user['avatar_url'] == null) ? const Icon(Icons.person, size: 40) : null,
             ),
             const SizedBox(height: 16),
             Text(name, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
             Text("Sedang misa bersama Anda", style: GoogleFonts.outfit(color: Colors.grey)),
             const SizedBox(height: 16),
             
             ElevatedButton(
               onPressed: () async {
                 Navigator.pop(ctx);
                 try {
                    final targetId = user['id'];
                    await _service.initiateGreeting(targetId, name, "Gereja ini");
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sapaan terkirim ke $name! 👋")));
                 } catch(e) {
                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyapa."))); 
                 }
               },
               style: ElevatedButton.styleFrom(
                 backgroundColor: kPrimaryBlue,
                 foregroundColor: Colors.white,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
               ),
               child: const Text("Sapa 👋"),
             )
           ],
         ),
       )
     );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.symmetric(vertical: 12),
           child: Text("Umat yang hadir (${_users.length})", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.grey[800])),
         ),
         SizedBox(
           height: 70,
           child: ListView.separated(
             scrollDirection: Axis.horizontal,
             itemCount: _users.length,
             separatorBuilder: (_,__) => const SizedBox(width: 12),
             itemBuilder: (context, index) {
                final u = _users[index]['profiles'] ?? {};
                return InkWell(
                  onTap: () => _showProfile(u),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20, 
                        backgroundImage: (u['avatar_url'] != null) ? NetworkImage(u['avatar_url']) : null,
                        child: (u['avatar_url'] == null) ? const Icon(Icons.person, size: 20) : null,
                      ),
                      const SizedBox(height: 4),
                      Text((u['full_name'] ?? 'User').toString().split(' ')[0], style: GoogleFonts.outfit(fontSize: 10))
                    ],
                  ),
                );
             },
           ),
         )
      ],
    );
  }
}
