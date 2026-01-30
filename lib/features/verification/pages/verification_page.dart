
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart'; // Ensure UserRole, AccountStatus enums are accessible
import 'package:mychatolic_app/services/profile_service.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  // Services
  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  // Loading State
  bool _isLoading = true;
  bool _isSubmitting = false;

  // User State
  String? _status; // from AccountStatus enum name
  UserRole _userRole = UserRole.umat;

  // Form State (Location)
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;

  // Data Lists for Dropdowns
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];

  // File Uploads
  File? _ktpFile;
  File? _baptismFile;
  File? _taskFile; // For Clergy

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch Profile Data
      //    We use a direct query to get raw data for simplicity and precision here
      final profileData = await _supabase
          .from('profiles')
          .select('role, verification_status, country_id, diocese_id, church_id')
          .eq('id', userId)
          .single();
      
      // Parse Role
      final roleStr = profileData['role']?.toString() ?? 'umat';
      try {
        _userRole = UserRole.values.firstWhere(
            (e) => e.name.toLowerCase() == roleStr.toLowerCase(),
            orElse: () => UserRole.umat);
      } catch (_) {
        _userRole = UserRole.umat;
      }

      // Parse Status
      _status = profileData['verification_status']?.toString() ?? 'unverified';

      // 2. Fetch Countries List (Always available)
      final countriesRes = await _supabase
          .from('countries')
          .select('id, name')
          .order('name', ascending: true);
      
      final countriesList = List<Map<String, dynamic>>.from(countriesRes);

      // 3. Pre-fill & Cascade Logic
      final initialCountryId = profileData['country_id']?.toString();
      final initialDioceseId = profileData['diocese_id']?.toString();
      final initialChurchId = profileData['church_id']?.toString();
      
      List<Map<String, dynamic>> diocesesList = [];
      List<Map<String, dynamic>> churchesList = [];

      if (initialCountryId != null) {
          final res = await _supabase
              .from('dioceses')
              .select('id, name')
              .eq('country_id', initialCountryId)
              .order('name', ascending: true);
          diocesesList = List<Map<String, dynamic>>.from(res);
      }

      if (initialDioceseId != null) {
          final res = await _supabase
             .from('churches')
             .select('id, name')
             .eq('diocese_id', initialDioceseId)
             .order('name', ascending: true);
          churchesList = List<Map<String, dynamic>>.from(res);
      }

      if (mounted) {
        setState(() {
          _countries = countriesList;
          _dioceses = diocesesList;
          _churches = churchesList;
          
          _selectedCountryId = initialCountryId;
          _selectedDioceseId = initialDioceseId;
          _selectedChurchId = initialChurchId;
          
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint("Verification Page Init Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOCATION LOGIC ---

  Future<void> _onCountryChanged(String? val) async {
    if (val == null) return;
    setState(() {
      _selectedCountryId = val;
      _selectedDioceseId = null; 
      _selectedChurchId = null;
      _dioceses = [];
      _churches = [];
    });
    
    // Fetch Dioceses
    try {
      final res = await _supabase
          .from('dioceses')
          .select('id, name')
          .eq('country_id', val)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
           _dioceses = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint("Fetch Dioceses Error: $e");
    }
  }

  Future<void> _onDioceseChanged(String? val) async {
    if (val == null) return;
    setState(() {
      _selectedDioceseId = val;
      _selectedChurchId = null; 
      _churches = []; 
    });
    
    // Fetch Churches
    try {
      final res = await _supabase
          .from('churches')
          .select('id, name')
          .eq('diocese_id', val)
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
           _churches = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      debugPrint("Fetch Churches Error: $e");
    }
  }

  // --- UPLOAD LOGIC ---

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
         if (type == 'ktp') _ktpFile = File(picked.path);
         if (type == 'baptism') _baptismFile = File(picked.path);
         if (type == 'task') _taskFile = File(picked.path);
      });
    }
  }

  Future<void> _submitForms() async {
    // 1. Validations
    if (_ktpFile == null) {
       _showSnack("Mohon upload Foto Identitas (KTP)", isError: true);
       return;
    }
    if (_baptismFile == null) {
       _showSnack("Mohon upload Sertifikat Baptis", isError: true);
       return;
    }
    if (_selectedChurchId == null) {
       _showSnack("Mohon lengkapi data Paroki Anda", isError: true);
       return;
    }
    
    // Clergy Check
    bool isClergy = [UserRole.pastor, UserRole.bruder, UserRole.suster, UserRole.katekis].contains(_userRole);
    if (isClergy && _taskFile == null) {
       _showSnack("Mohon lampirkan Surat Tugas / Tarekat", isError: true);
       return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // 2. Upload Files
      String ktpUrl = await _uploadToStorage(_ktpFile!, userId, 'ktp');
      String baptismUrl = await _uploadToStorage(_baptismFile!, userId, 'baptism');
      String? taskUrl;
      if (isClergy && _taskFile != null) {
         taskUrl = await _uploadToStorage(_taskFile!, userId, 'task');
      }
      
      // 3. Resolve Names (Optional, but good for flat-table access)
      String? countryName = _countries.firstWhere((e) => e['id'] == _selectedCountryId, orElse: () => {})['name'];
      String? dioceseName = _dioceses.firstWhere((e) => e['id'] == _selectedDioceseId, orElse: () => {})['name'];
      String? churchName = _churches.firstWhere((e) => e['id'] == _selectedChurchId, orElse: () => {})['name'];

      // 4. Update Database
      await _supabase.from('profiles').update({
        'verification_ktp_url': ktpUrl,
        'baptism_cert_url': baptismUrl,
        'task_letter_url': taskUrl, // Column might not exist in schema yet, ensure explicit if verified
        'country_id': _selectedCountryId,
        'diocese_id': _selectedDioceseId,
        'church_id': _selectedChurchId,
        'country': countryName,
        'diocese': dioceseName,
        'parish': churchName,
        'verification_status': 'pending', // Enum: AccountStatus.pending
        'verification_submitted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
         setState(() {
           _status = 'pending';
           _isSubmitting = false;
         });
         _showSnack("Dokumen berhasil dikirim. Menunggu verifikasi admin.");
      }

    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      _showSnack("Gagal mengirim data: $e", isError: true);
    }
  }

  Future<String> _uploadToStorage(File file, String userId, String type) async {
     final ext = file.path.split('.').last;
     final path = '${userId}_${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';
     try {
       // Using 'verification-docs' bucket as per spec
       await _supabase.storage.from('verification-docs').upload(path, file);
       return _supabase.storage.from('verification-docs').getPublicUrl(path);
     } catch (e) {
       // Fallback for demo if buckets missing
       debugPrint("Storage Upload Error: $e");
       throw Exception("Storage Error: $e");
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

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Verifikasi Akun",
          style: GoogleFonts.outfit(
            color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildBodyBasedOnStatus(),
      ),
    );
  }

  Widget _buildBodyBasedOnStatus() {
     // 1. VERIFIED STATE
     if (_status == 'verified_catholic' || _status == 'verified_pastoral') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const SizedBox(height: 60),
               const Icon(Icons.check_circle_rounded, size: 100, color: Color(0xFF2ECC71)),
               const SizedBox(height: 24),
               Text(
                 "Akun Terverifikasi",
                 style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 12),
               Text(
                 "Selamat! Data Anda telah diverifikasi oleh admin.\nAnda mendapatkan badge 100% Katolik.",
                 textAlign: TextAlign.center,
                 style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 16),
               ),
            ],
          ),
        );
     }

     // 2. PENDING STATE
     if (_status == 'pending') {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               const SizedBox(height: 60),
               const Icon(Icons.hourglass_top_rounded, size: 100, color: Color(0xFFF39C12)),
               const SizedBox(height: 24),
               Text(
                 "Sedang Ditinjau",
                 style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 12),
               Text(
                 "Dokumen Anda sedang dalam proses verifikasi.\nMohon tunggu 1x24 jam.",
                 textAlign: TextAlign.center,
                 style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 16),
               ),
            ],
          ),
        );
     }

     // 3. UNVERIFIED / REJECTED (INPUT FORM)
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9)),
            ),
            child: Row(
               children: [
                 const Icon(Icons.shield_outlined, color: Color(0xFF0088CC)),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Text(
                     "Lengkapi dokumen untuk mendapatkan akses fitur komunitas penuh.",
                     style: GoogleFonts.outfit(
                       color: const Color(0xFF0277BD),
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 )
               ],
            ),
          ),
          const SizedBox(height: 24),

          // SECTION 1: LOKASI
          _buildSectionHeader("1. Data Paroki / Lokasi Gereja"),
          const SizedBox(height: 12),
          _buildDropdown("Negara", _countries, _selectedCountryId, _onCountryChanged),
          const SizedBox(height: 12),
          _buildDropdown("Keuskupan", _dioceses, _selectedDioceseId, _onDioceseChanged, enabled: _selectedCountryId != null),
          const SizedBox(height: 12),
          _buildDropdown("Paroki / Gereja", _churches, _selectedChurchId, (val) => setState(() => _selectedChurchId = val), enabled: _selectedDioceseId != null),

          const SizedBox(height: 24),
          
          // SECTION 2: DOKUMEN WAJIB
          _buildSectionHeader("2. Dokumen Wajib"),
          const SizedBox(height: 12),
          _buildUploadCard("Foto KTP", _ktpFile, () => _pickImage('ktp')),
          const SizedBox(height: 12),
          _buildUploadCard("Sertifikat Baptis", _baptismFile, () => _pickImage('baptism')),

          // SECTION 3: CLERGY ONLY
          if ([UserRole.pastor, UserRole.suster, UserRole.bruder].contains(_userRole)) ...[
             const SizedBox(height: 24),
             _buildSectionHeader("3. Khusus Klerus/Biarawan"),
             const SizedBox(height: 12),
             _buildUploadCard("Surat Tugas / Tarekat", _taskFile, () => _pickImage('task')),
          ],

          // SUBMIT BUTTON
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForms,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("Kirim Data Verifikasi", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 40),
       ],
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

  Widget _buildDropdown(
    String label, 
    List<Map<String, dynamic>> items, 
    String? value, 
    Function(String?) onChanged,
    {bool enabled = true}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
         const SizedBox(height: 6),
         Container(
           padding: const EdgeInsets.symmetric(horizontal: 16),
           decoration: BoxDecoration(
             color: enabled ? Colors.grey[50] : Colors.grey[200],
             border: Border.all(color: Colors.grey[300]!),
             borderRadius: BorderRadius.circular(8),
           ),
           child: DropdownButtonHideUnderline(
             child: DropdownButton<String>(
               isExpanded: true,
               value: items.any((i) => i['id'] == value) ? value : null,
               hint: Text(enabled ? "Pilih $label" : "Pilih sebelumnya...", style: GoogleFonts.outfit(color: Colors.grey)),
               icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
               items: items.map((e) => DropdownMenuItem(
                 value: e['id'].toString(),
                 child: Text(e['name'].toString(), style: GoogleFonts.outfit()),
               )).toList(),
               onChanged: enabled ? onChanged : null,
             ),
           ),
         )
      ],
    );
  }

  Widget _buildUploadCard(String label, File? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: file != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11), // -1 for border
              child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded, size: 36, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(label, style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
      ),
    );
  }
}
