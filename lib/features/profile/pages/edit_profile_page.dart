import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:mychatolic_app/services/profile_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  // --- DESIGN SYSTEM CONSTANTS (Light Mode) ---
  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgMain = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF555555);
  static const Color borderLight = Color(0xFFE0E0E0);

  // Controllers - Personal
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baptismNameController = TextEditingController(); // NEW
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ethnicityController = TextEditingController();

  // Controllers - Ecclesiastical
  final TextEditingController _countryController = TextEditingController(
    text: "Indonesia",
  );
  final TextEditingController _dioceseController = TextEditingController();
  final TextEditingController _parishController = TextEditingController();

  // State Variables
  String _selectedGender = "Laki-laki";
  String _maritalStatus = "single"; // NEW
  DateTime? _selectedBirthDate;

  String? _avatarUrl;
  File? _avatarFile;

  // CASCADING FILTER STATES (UUID Strings)
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String? _selectedParishId;

  bool _isLoading = false;

  final Map<String, String> _maritalStatusOptions = {
    'single': 'Belum Pernah Menikah',
    'widowed': 'Cerai Mati',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select(
            '*, countries:country_id(name, id), dioceses:diocese_id(name, id), churches:church_id(name, id)',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? "";
          _baptismNameController.text = data['baptism_name'] ?? ""; // NEW
          _bioController.text = data['bio'] ?? "";
          _ethnicityController.text = data['ethnicity'] ?? "";
          _avatarUrl = data['avatar_url'];

          // Gender
          if (data['gender'] != null) _selectedGender = data['gender'];

          // Marital Status
          final ms = data['marital_status'];
          if (ms != null && _maritalStatusOptions.containsKey(ms)) {
            _maritalStatus = ms;
          } else {
            _maritalStatus = 'single';
          }

          // Birth Date
          if (data['birth_date'] != null) {
            _selectedBirthDate = DateTime.tryParse(data['birth_date']);
          }

          // --- LOCATION LOGIC (AUTO-FILL ID & NAME) ---
          // Country
          _selectedCountryId = data['country_id']?.toString();
          if (data['countries'] != null) {
            _countryController.text = data['countries']['name'] ?? "";
          } else {
            _countryController.text = "";
          }

          // Diocese
          _selectedDioceseId = data['diocese_id']?.toString();
          if (data['dioceses'] != null) {
            _dioceseController.text = data['dioceses']['name'] ?? "";
          } else {
            _dioceseController.text = "";
          }

          // Parish
          _selectedParishId = data['church_id']?.toString();
          if (data['churches'] != null) {
            _parishController.text = data['churches']['name'] ?? "";
          } else {
            _parishController.text = "";
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }



  // --- IMAGE PICKER ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Atur Foto Profil',
            toolbarColor: primaryBrand,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(title: 'Edit Foto'),
        ],
      );

      if (croppedFile != null) {
        setState(() => _avatarFile = File(croppedFile.path));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryBrand,
              onPrimary: Colors.white,
              surface: bgMain,
              onSurface: textPrimary,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: bgMain),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  // --- SEARCHABLE MODAL HELPER ---
  void _showSearchableSelection({
    required String title,
    required String tableName,
    required Function(Map<String, dynamic>) onSelect,
    String? filterColumn,
    dynamic filterValue,
    List<String>? dummyData,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgMain,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _SearchableListModal(
          title: title,
          tableName: tableName,
          onSelect: onSelect,
          supabase: _supabase,
          filterColumn: filterColumn,
          filterValue: filterValue,
          dummyData: dummyData,
        );
      },
    );
  }

  // --- SAVE ---
  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama Lengkap tidak boleh kosong!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? newAvatarUrl = _avatarUrl;
      final time = DateTime.now().millisecondsSinceEpoch;

      if (_avatarFile != null) {
        final path = '${user.id}/avatar_$time.jpg';
        await _supabase.storage
            .from('avatars')
            .upload(
              path,
              _avatarFile!,
              fileOptions: const FileOptions(upsert: true),
            );
        newAvatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      }

      final birthDate = _selectedBirthDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!)
          : null;

      await _profileService.updateProfile(
        userId: user.id,
        updates: {
          'full_name': _nameController.text.trim(),
          'baptism_name': _baptismNameController.text.trim(),
          'bio': _bioController.text.trim(),
          'gender': _selectedGender,
          'marital_status': _maritalStatus,
          'birth_date': birthDate,
          'ethnicity': _ethnicityController.text.trim(),
          'country_id': _selectedCountryId,
          'diocese_id': _selectedDioceseId,
          'church_id': _selectedParishId,
          'avatar_url': newAvatarUrl,
        },
      );

      // Update Auth Metadata for faster access
      await _supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profil Berhasil Diupdate!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal simpan: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        title: Text(
          "Edit Profil",
          style: GoogleFonts.outfit(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: bgMain,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: primaryBrand,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    "SIMPAN",
                    style: GoogleFonts.outfit(
                      color: primaryBrand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderLight, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 32),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Data Pribadi",
                    style: GoogleFonts.outfit(
                      color: primaryBrand,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "Nama Lengkap",
                    _nameController,
                    capitalize: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "Nama Baptis (Opsional)",
                    _baptismNameController,
                    capitalize: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "Bio / Deskripsi",
                    _bioController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Jenis Kelamin"),
                  _buildDropdown(
                    ["Laki-laki", "Perempuan"],
                    _selectedGender,
                    (val) => setState(() => _selectedGender = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Status Pernikahan"),
                  _buildMapDropdown(
                    _maritalStatusOptions,
                    _maritalStatus,
                    (val) => setState(() => _maritalStatus = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel("Tanggal Lahir"),
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  _buildTextField(
                    "Suku / Asal",
                    _ethnicityController,
                    capitalize: true,
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: borderLight, thickness: 1),
                  const SizedBox(height: 24),

                  // DOMISILI GEREJAWI
                  Text(
                    "Domisili Gerejawi",
                    style: GoogleFonts.outfit(
                      color: primaryBrand,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      "Data Gereja dapat diubah jika Anda pindah domisili.",
                      style: GoogleFonts.outfit(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // NEGARA
                  _buildSearchableField("Negara", _countryController, () {
                    _showSearchableSelection(
                      title: "Pilih Negara",
                      tableName: "countries",
                      filterColumn: null,
                      filterValue: null,
                      dummyData: [
                        "Indonesia",
                        "Timor Leste",
                        "Singapura",
                        "Malaysia",
                        "USA",
                      ],
                      onSelect: (item) {
                        setState(() {
                          _countryController.text = item['name'];
                          // Store UUID as String
                          _selectedCountryId = item['id'].toString();

                          // Reset Children
                          _dioceseController.clear();
                          _selectedDioceseId = null;
                          _parishController.clear();
                          _selectedParishId = null;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  // KEUSKUPAN
                  _buildSearchableField("Keuskupan", _dioceseController, () {
                    if (_selectedCountryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pilih Negara Terlebih Dahulu"),
                        ),
                      );
                      return;
                    }
                    _showSearchableSelection(
                      title: "Pilih Keuskupan",
                      tableName: "dioceses",
                      filterColumn: 'country_id',
                      filterValue: _selectedCountryId, // Passing UUID string
                      dummyData: [
                        "Keuskupan Agung Jakarta",
                        "Keuskupan Bandung",
                        "Keuskupan Surabaya",
                      ],
                      onSelect: (item) {
                        setState(() {
                          _dioceseController.text = item['name'];
                          // Store UUID as String
                          _selectedDioceseId = item['id'].toString();

                          // Reset Child
                          _parishController.clear();
                          _selectedParishId = null;
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 16),

                  // PAROKI
                  _buildSearchableField("Paroki", _parishController, () {
                    if (_selectedDioceseId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pilih Keuskupan Terlebih Dahulu"),
                        ),
                      );
                      return;
                    }
                    _showSearchableSelection(
                      title: "Pilih Paroki",
                      tableName: "churches",
                      filterColumn: 'diocese_id',
                      filterValue: _selectedDioceseId, // Passing UUID string
                      dummyData: ["Paroki Katedral", "Paroki Blok B"],
                      onSelect: (item) {
                        setState(() {
                          _parishController.text = item['name'];
                          _selectedParishId = item['id'].toString();
                        });
                      },
                    );
                  }),

                  const SizedBox(height: 40),
                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBrand,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              "SIMPAN PERUBAHAN",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgSurface,
              border: Border.all(color: borderLight, width: 2),
            ),
            child: ClipOval(
              child: _avatarFile != null
                  ? Image.file(_avatarFile!, fit: BoxFit.cover)
                  : SafeNetworkImage(
                      imageUrl: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? _avatarUrl
                          : "https://i.pravatar.cc/300",
                      fit: BoxFit.cover,
                      fallbackColor: bgSurface,
                      fallbackIcon: Icons.person,
                    ),
            ),
          ),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              margin: const EdgeInsets.only(right: 4, bottom: 4),
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: primaryBrand,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool capitalize = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: capitalize
              ? TextCapitalization.words
              : TextCapitalization.none,
          style: GoogleFonts.outfit(color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBrand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              readOnly: true,
              style: GoogleFonts.outfit(color: textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryBrand, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedBirthDate == null
                  ? "Pilih Tanggal"
                  : DateFormat("dd MMM yyyy").format(_selectedBirthDate!),
              style: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
            ),
            const Icon(Icons.calendar_today, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: bgMain,
          icon: const Icon(Icons.keyboard_arrow_down, color: textSecondary),
          style: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMapDropdown(
    Map<String, String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          isExpanded: true,
          dropdownColor: bgMain,
          icon: const Icon(Icons.keyboard_arrow_down, color: textSecondary),
          style: GoogleFonts.outfit(color: textPrimary, fontSize: 16),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// --- SEARCHABLE MODAL (Safe for UUIDs) ---
class _SearchableListModal extends StatefulWidget {
  final String title;
  final String tableName;
  final Function(Map<String, dynamic>) onSelect;
  final SupabaseClient supabase;
  final List<String>? dummyData;
  final String? filterColumn;
  final dynamic filterValue;

  const _SearchableListModal({
    required this.title,
    required this.tableName,
    required this.onSelect,
    required this.supabase,
    this.dummyData,
    this.filterColumn,
    this.filterValue,
  });

  @override
  State<_SearchableListModal> createState() => _SearchableListModalState();
}

class _SearchableListModalState extends State<_SearchableListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  static const Color primaryBrand = Color(0xFF0088CC);
  static const Color bgSurface = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _performSearch("");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _loading = true);
      try {
        var dbQuery = widget.supabase.from(widget.tableName).select('id, name');

        // CASCADING: Only apply filter if value is valid (Not Null)
        if (widget.filterColumn != null && widget.filterValue != null) {
          dbQuery = dbQuery.eq(widget.filterColumn!, widget.filterValue);
        }

        // SPECIAL FILTER: If table is 'churches', only show parishes
        if (widget.tableName == 'churches') {
          dbQuery = dbQuery.eq('type', 'parish');
        }

        final data = await dbQuery.ilike('name', '%$query%').limit(20);

        if (mounted) {
          setState(() => _results = List<Map<String, dynamic>>.from(data));
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            if (widget.dummyData != null) {
              _results = widget.dummyData!
                  .where(
                    (element) =>
                        element.toLowerCase().contains(query.toLowerCase()),
                  )
                  .map((e) => {'id': 'dummy-id', 'name': e}) // Dummy String ID
                  .toList();
            } else {
              _results = [];
            }
          });
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.black),
              ),
              Expanded(
                child: Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _performSearch,
            style: GoogleFonts.outfit(color: Colors.black),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              hintText: "Cari...",
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              filled: true,
              fillColor: bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBrand),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryBrand),
                  )
                : _results.isEmpty
                ? Center(
                    child: Text(
                      "Data tidak ditemukan",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: Colors.grey),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        title: Text(
                          item['name'],
                          style: GoogleFonts.outfit(color: Colors.black),
                        ),
                        onTap: () {
                          widget.onSelect(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
