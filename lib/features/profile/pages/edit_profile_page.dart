
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/services/profile_service.dart';
import 'package:mychatolic_app/services/location_service.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ProfileService _profileService = ProfileService();
  final LocationService _locationService = LocationService();
  final _supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedChurchId;
  
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _dioceses = [];
  List<Map<String, dynamic>> _churches = [];

  bool _showAge = false;
  bool _showEthnicity = false;
  bool _isLoading = true;
  bool _isSaving = false;

  File? _newAvatarFile;
  File? _newBannerFile;
  String? _currentAvatarUrl;
  String? _currentBannerUrl;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _profileService.fetchUserProfile(userId);
      final profile = data['profile'] as Profile;
      final countries = await _locationService.getCountries();

      if (mounted) {
        setState(() {
          _nameController.text = profile.fullName ?? "";
          _bioController.text = profile.bio ?? "";
          _currentAvatarUrl = profile.avatarUrl;
          _currentBannerUrl = profile.bannerUrl;
          _showAge = profile.showAge;
          _showEthnicity = profile.showEthnicity;
          
          _countries = countries;
          
          _selectedCountryId = profile.countryId;
          _selectedDioceseId = profile.dioceseId;
          _selectedChurchId = profile.churchId;
        });
        
        if (_selectedCountryId != null) await _loadDioceses(_selectedCountryId!);
        if (_selectedDioceseId != null) await _loadChurches(_selectedDioceseId!);
        
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadDioceses(String countryId) async {
    final list = await _locationService.getDioceses(countryId);
    if(mounted) setState(() => _dioceses = list);
  }
  
  Future<void> _loadChurches(String dioceseId) async {
    final list = await _locationService.getChurches(dioceseId);
    if(mounted) setState(() => _churches = list);
  }

  Future<void> _pickImage(bool isBanner) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        if (isBanner) {
          _newBannerFile = File(picked.path);
        } else {
          _newAvatarFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      String? avatarUrl = _currentAvatarUrl;
      if (_newAvatarFile != null) {
        avatarUrl = await _profileService.uploadAvatar(_newAvatarFile!);
      }
      
      String? bannerUrl = _currentBannerUrl;
      if (_newBannerFile != null) {
        bannerUrl = await _profileService.uploadBanner(_newBannerFile!);
      }
      
      String? countryName = _countries.firstWhere((e) => e['id'] == _selectedCountryId, orElse: () => {})['name'];
      String? dioceseName = _dioceses.firstWhere((e) => e['id'] == _selectedDioceseId, orElse: () => {})['name'];
      String? parishName = _churches.firstWhere((e) => e['id'] == _selectedChurchId, orElse: () => {})['name'];

      await _profileService.updateProfile(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        country: countryName,
        diocese: dioceseName,
        parish: parishName,
        countryId: _selectedCountryId,
        dioceseId: _selectedDioceseId,
        churchId: _selectedChurchId,
        showAge: _showAge,
        showEthnicity: _showEthnicity,
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil diperbarui!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0088CC);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Edit Profil", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text("Simpan", style: GoogleFonts.outfit(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER (BANNER & AVATAR EDITOR)
            SizedBox(
              height: 250, // Height to accommodate banner + overlap avatar
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // BANNER AREA
                  GestureDetector(
                    onTap: () => _pickImage(true),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                         color: Colors.grey[300],
                         image: _newBannerFile != null 
                            ? DecorationImage(image: FileImage(_newBannerFile!), fit: BoxFit.cover)
                            : (_currentBannerUrl != null 
                                ? DecorationImage(image: NetworkImage(_currentBannerUrl!), fit: BoxFit.cover)
                                : null)
                      ),
                      child: Stack(
                        children: [
                           if (_newBannerFile == null && _currentBannerUrl == null)
                             const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 40)),
                           
                           // Edit Banner Button
                           Positioned(
                             bottom: 10,
                             right: 10,
                             child: Container(
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                               child: const Icon(Icons.edit, color: Colors.white, size: 18),
                             ),
                           )
                        ],
                      ),
                    ),
                  ),
                  
                  // AVATAR AREA (Overlapping)
                  Positioned(
                    top: 130, // 180 (Banner) - 50 (Radius)
                    left: 0, 
                    right: 0,
                    child: Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                )
                              ]
                            ),
                            child: ClipOval(
                              child: _newAvatarFile != null
                                  ? Image.file(_newAvatarFile!, fit: BoxFit.cover)
                                  : SafeNetworkImage(imageUrl: _currentAvatarUrl ?? '', fit: BoxFit.cover, fallbackIcon: Icons.person),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _pickImage(false),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. FORM FIELDS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Informasi Dasar"),
                  const SizedBox(height: 16),
                  _buildTextField("Nama Lengkap", _nameController),
                  const SizedBox(height: 16),
                  _buildTextField("Bio", _bioController, maxLines: 3),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle("Lokasi & Gereja"),
                  const SizedBox(height: 16),
                  _buildDropdown("Negara", _countries, _selectedCountryId, (val) {
                      setState(() {
                         _selectedCountryId = val;
                         _selectedDioceseId = null;
                         _selectedChurchId = null;
                         _dioceses = [];
                         _churches = []; 
                      });
                      if (val != null) _loadDioceses(val);
                  }),
                  const SizedBox(height: 12),
                  _buildDropdown("Keuskupan", _dioceses, _selectedDioceseId, (val) {
                      setState(() {
                         _selectedDioceseId = val;
                         _selectedChurchId = null;
                         _churches = [];
                      });
                      if (val != null) _loadChurches(val);
                  }, enabled: _selectedCountryId != null),
                  const SizedBox(height: 12),
                  _buildDropdown("Paroki / Gereja", _churches, _selectedChurchId, (val) => setState(() => _selectedChurchId = val), enabled: _selectedDioceseId != null),

                  const SizedBox(height: 24),
                  _buildSectionTitle("Privasi"),
                  _buildSwitch("Tampilkan Usia", _showAge, (val) => setState(()=> _showAge = val)),
                  _buildSwitch("Tampilkan Suku", _showEthnicity, (val) => setState(()=> _showEthnicity = val)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0088CC)));
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.outfit(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<Map<String, dynamic>> items, String? value, Function(String?) onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(label, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: enabled ? Colors.grey[700] : Colors.grey[400])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items.any((i) => i['id'] == value) ? value : null,
              hint: Text(enabled ? "Pilih $label" : "Pilih sebelumnya...", style: GoogleFonts.outfit(color: Colors.grey)),
              items: items.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['name'].toString(), style: GoogleFonts.outfit()))).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87)),
        Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0088CC)),
      ],
    );
  }
}
