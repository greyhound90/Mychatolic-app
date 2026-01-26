
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/services/radar_service.dart';
import 'package:mychatolic_app/widgets/secure_image_loader.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CreatePersonalRadarPage extends StatefulWidget {
  final Profile targetUser;

  const CreatePersonalRadarPage({super.key, required this.targetUser});

  @override
  State<CreatePersonalRadarPage> createState() =>
      _CreatePersonalRadarPageState();
}

class _CreatePersonalRadarPageState extends State<CreatePersonalRadarPage> {
  final RadarService _radarService = RadarService();
  final _supabase = Supabase.instance.client;

  // Colors Palette
  final Color _primaryColor = const Color(0xFF0088CC);
  final Color _bgColor = const Color(0xFFF5F5F5);
  final Color _textColor = const Color(0xFF000000);
  final Color _labelColor = const Color(0xFF555555);

  // --- Location State ---
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;
  String? _selectedChurchName;
  
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];

  // --- Schedule State ---
  DateTime? _selectedDate;
  String? _selectedScheduleStr; 
  TimeOfDay? _selectedTime; 

  List<Map<String, dynamic>> _availableSchedules = []; 
  bool _isLoadingSchedule = false;

  final TextEditingController _noteController = TextEditingController();
  
  // Loading State
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchCountries();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // --- DATA FETCHING (CASCADING LOCATION) ---

  Future<void> _fetchCountries() async {
    try {
      final response = await _supabase
          .from('countries')
          .select('id, name')
          .order('name', ascending: true);
      
      if (mounted) {
        setState(() {
          _countries = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching countries: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onCountryChanged(String? val) async {
    if (val == null) return;
    setState(() {
      _selectedCountryId = val;
      _selectedDioceseId = null;
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
      _resetSchedule();
    });

    final response = await _supabase
        .from('dioceses')
        .select('id, name')
        .eq('country_id', val)
        .order('name', ascending: true);

    if (mounted) {
      setState(() {
        _dioceses = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _onDioceseChanged(String? val) async {
    if (val == null) return;
    setState(() {
      _selectedDioceseId = val;
      _selectedChurchId = null;
      _churches = [];
      _resetSchedule();
    });

    final response = await _supabase
        .from('churches')
        .select('id, name')
        .eq('diocese_id', val)
        .order('name', ascending: true);

    if (mounted) {
      setState(() {
        _churches = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _onChurchChanged(String? val) async {
    if (val == null) return;
    final churchName = _churches.firstWhere((c) => c['id'] == val)['name'];
    
    setState(() {
      _selectedChurchId = val;
      _selectedChurchName = churchName;
      _resetSchedule();
    });
    
    // If Date already picked, fetch schedule immediately
    if (_selectedDate != null) {
      _fetchMassSchedulesForDate(val, _selectedDate!);
    }
  }
  
  void _resetSchedule() {
    _availableSchedules = [];
    _selectedScheduleStr = null;
    _selectedTime = null;
  }

  // --- SCHEDULE LOGIC (SMART SELECT) ---
  
  Future<void> _onDateSelected(DateTime picked) async {
    setState(() => _selectedDate = picked);
    if (_selectedChurchId != null) {
       await _fetchMassSchedulesForDate(_selectedChurchId!, picked);
    }
  }

  Future<void> _fetchMassSchedulesForDate(String churchId, DateTime date) async {
    setState(() {
      _isLoadingSchedule = true;
      _selectedScheduleStr = null;
      _selectedTime = null;
      _availableSchedules = [];
    });

    try {
      int dayNumber = date.weekday; 

      final response = await _supabase
          .from('mass_schedules')
          .select('start_time, title, language') 
          .eq('church_id', churchId)
          .eq('day_number', dayNumber)
          .order('start_time', ascending: true);

      List<Map<String, dynamic>> schedules = [];
      for (var row in response) {
        String rawTime = row['start_time'].toString(); 
        String title = row['title'] ?? "Misa";
        String lang = row['language'] ?? "";
        
        String displayTime = rawTime;
        if (rawTime.length >= 5) displayTime = rawTime.substring(0, 5);

        schedules.add({
           'raw_time': rawTime,
           'display': "$displayTime - $title ${lang.isNotEmpty ? '($lang)' : ''}",
           'hour': int.parse(rawTime.split(':')[0]),
           'minute': int.parse(rawTime.split(':')[1]),
        });
      }

      if (mounted) {
        setState(() {
          _availableSchedules = schedules;
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schedule: $e");
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  // --- ACTIONS ---

  Future<void> _submitInvitation() async {
    if (_selectedChurchId == null) {
      _showSnack("Mohon pilih gereja terlebih dahulu", isError: true);
      return;
    }
    if (_selectedDate == null) {
      _showSnack("Mohon pilih tanggal misa", isError: true);
      return;
    }
    if (_selectedTime == null) {
       _showSnack("Mohon pilih jam misa", isError: true);
       return;
    }

    setState(() => _isSubmitting = true);

    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    try {
      await _radarService.createPersonalRadar(
        targetUserId: widget.targetUser.id,
        churchId: _selectedChurchId!,
        churchName: _selectedChurchName ?? "Gereja",
        scheduleTime: dateTime,
        message: _noteController.text.trim().isNotEmpty 
            ? _noteController.text.trim()
            : "Mengajak Anda Misa bersama",
      );

      if (mounted) {
        _showSnack("Undangan dikirim ke ${widget.targetUser.fullName}", isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnack("Gagal mengirim undangan: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  // --- NEW UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    if(_isLoading) {
        return Scaffold(
          backgroundColor: _bgColor,
          body: const Center(child: CircularProgressIndicator()),
        );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          "Ajak Misa",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 2. HEADER BANNER TARGET USER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: SecureImageLoader(
                        imageUrl: widget.targetUser.avatarUrl ?? '',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mengajak",
                            style: GoogleFonts.outfit(
                              color: _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.targetUser.fullName ?? "User",
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "untuk Misa bersama",
                            style: GoogleFonts.outfit(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.church_rounded, color: _primaryColor.withValues(alpha: 0.5), size: 32)
                  ],
                ),
              ),
            ),
            
            // 3. MAIN FORM CONTAINER
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOCATION SECTION
                    _buildSectionHeader("Lokasi Gereja"),
                    const SizedBox(height: 16),
                    _buildStyledDropdown("Negara", Icons.public, _countries, _selectedCountryId, _onCountryChanged),
                    const SizedBox(height: 16),
                    _buildStyledDropdown("Keuskupan", Icons.holiday_village_outlined, _dioceses, _selectedDioceseId, _onDioceseChanged, enabled: _selectedCountryId != null),
                    const SizedBox(height: 16),
                    _buildStyledDropdown("Paroki / Gereja", Icons.church_outlined, _churches, _selectedChurchId, _onChurchChanged, enabled: _selectedDioceseId != null),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // SCHEDULE SECTION
                    _buildSectionHeader("Jadwal Misa"),
                    const SizedBox(height: 16),
                    
                    // Date Picker Input
                    InkWell(
                      onTap: () async {
                         final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(primary: _primaryColor),
                                ),
                                child: child!,
                              );
                            }
                         );
                         if (picked != null) _onDateSelected(picked);
                      },
                      child: IgnorePointer(
                        child: TextField(
                          controller: TextEditingController(text: _selectedDate != null ? DateFormat('EEEE, d MMMM y', 'id').format(_selectedDate!) : ""),
                          decoration: _inputDecoration("Pilih Tanggal Misa", Icons.calendar_today_outlined),
                          style: GoogleFonts.outfit(color: _textColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                     // Schedule Dropdown
                    if (_selectedDate == null)
                       Container()
                    else if (_selectedChurchId == null)
                       _buildInfoBox("Pilih gereja di atas terlebih dahulu", false)
                    else if (_isLoadingSchedule)
                       const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                    else if (_availableSchedules.isEmpty)
                       _buildInfoBox("Tidak ada jadwal Misa tercatat pada tanggal ini. Silakan pilih tanggal lain.", true)
                    else
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           border: Border.all(color: Colors.grey.shade300),
                           borderRadius: BorderRadius.circular(12),
                         ),
                         child: DropdownButtonHideUnderline(
                           child: DropdownButton<String>(
                             isExpanded: true,
                             value: _selectedScheduleStr,
                             hint: Row(
                               children: [
                                 Icon(Icons.access_time_outlined, color: _primaryColor, size: 20),
                                 const SizedBox(width: 12),
                                 Text("Pilih Jam Misa", style: GoogleFonts.outfit(color: _labelColor)),
                               ],
                             ),
                             items: _availableSchedules.map((sch) {
                                return DropdownMenuItem<String>(
                                   value: sch['display'],
                                   child: Text(sch['display'], style: GoogleFonts.outfit(color: _textColor)),
                                );
                             }).toList(),
                             onChanged: (val) {
                                final selectedData = _availableSchedules.firstWhere((s) => s['display'] == val);
                                setState(() {
                                   _selectedScheduleStr = val;
                                   _selectedTime = TimeOfDay(hour: selectedData['hour'], minute: selectedData['minute']);
                                });
                             },
                           ),
                         ),
                       ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),

                    // NOTES SECTION
                    _buildSectionHeader("Pesan (Opsional)"),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(color: _textColor),
                      decoration: _inputDecoration("Tulis pesan tambahan...", Icons.notes_outlined).copyWith(
                        hintText: "Contoh: Ketemuan di lobby depan gereja ya...",
                      ),
                    ),

                    const SizedBox(height: 32),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitInvitation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Kirim Undangan",
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: _labelColor),
      prefixIcon: Icon(icon, color: _primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
    );
  }
  
  Widget _buildInfoBox(String msg, bool isWarning) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
           color: isWarning ? Colors.orange.shade50 : Colors.blue.shade50, 
           borderRadius: BorderRadius.circular(8),
           border: Border.all(color: isWarning ? Colors.orange.shade200 : Colors.blue.shade200)
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: isWarning ? Colors.orange.shade800 : Colors.blue.shade800, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg, 
                 style: GoogleFonts.outfit(color: isWarning ? Colors.orange.shade900 : Colors.blue.shade900, fontSize: 13)
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStyledDropdown(
    String label,
    IconData icon,
    List<Map<String, dynamic>> items, 
    String? value, 
    Function(String?) onChanged,
    {bool enabled = true}
  ) {
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(
         color: enabled ? Colors.white : Colors.grey[50], 
         border: Border.all(color: Colors.grey.shade300),
         borderRadius: BorderRadius.circular(12),
       ),
       child: DropdownButtonHideUnderline(
         child: DropdownButton<String>(
           isExpanded: true,
           value: items.any((i) => i['id'] == value) ? value : null,
           hint: Row(
             children: [
               Icon(icon, color: enabled ? _primaryColor : Colors.grey, size: 20),
               const SizedBox(width: 12),
               Text(enabled ? "Pilih $label" : "Pilih sebelumnya...", style: GoogleFonts.outfit(color: _labelColor)),
             ],
           ),
           icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
           items: items.map((e) => DropdownMenuItem(
             value: e['id'].toString(),
             child: Text(e['name'].toString(), style: GoogleFonts.outfit(color: _textColor)),
           )).toList(),
           onChanged: enabled ? onChanged : null,
         ),
       ),
    );
  }
}
