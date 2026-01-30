import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ---------------------------------------------------------------------------
  // 1. CONST COLOR PALETTE
  // ---------------------------------------------------------------------------
  static const Color kPrimaryColor = Color(0xFF0088CC);
  static const Color kSecondaryColor = Color(0xFF007AB8);
  static const Color kBackgroundColor = Color(0xFFFFFFFF);
  static const Color kInputFillColor = Color(0xFFF5F5F5);
  static const Color kBorderColor = Color(0xFF9E9E9E);
  static const Color kSuccessColor = Color(0xFF2ECC71);
  static const Color kErrorColor = Color(0xFFE74C3C);

  // ---------------------------------------------------------------------------
  // 2. CONTROLLERS
  // ---------------------------------------------------------------------------
  // Akun
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();
  
  // Data Diri
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baptismNameController = TextEditingController(); // NEW
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _ethnicityController = TextEditingController(); // Suku
  final TextEditingController _phoneController = TextEditingController();

  // ---------------------------------------------------------------------------
  // 3. STATE VARIABLES
  // ---------------------------------------------------------------------------
  int _currentStep = 1;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  // Marital Status (NEW: Strict 2 options)
  String? _maritalStatus; 
  final Map<String, String> _maritalStatusMap = {
    'Belum Pernah Menikah': 'single', // Updated label
    'Cerai Mati': 'widowed',
  };

  // Role Selection
  String? _selectedRole;
  bool _isCatechumen = false;
  
  // Agreement (NEW)
  bool _agreedToTerms = false;
  
  // Mapping Label UI -> Value Database
  final Map<String, String> _roleMap = {
    'Umat': 'umat',
    'Imam': 'pastor',
    'Biarawan/wati': 'bruder',
    'Katekis': 'katekis',
  };

  // Location Objects (for DropdownSearch)
  Map<String, dynamic>? _selectedCountry;
  Map<String, dynamic>? _selectedDiocese;
  Map<String, dynamic>? _selectedParish;

  // ---------------------------------------------------------------------------
  // 4. LIFECYCLE METHODS
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    _nameController.dispose();
    _baptismNameController.dispose();
    _dobController.dispose();
    _ethnicityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 5. LOGIC METHODS
  // ---------------------------------------------------------------------------

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1:
        if (_emailController.text.trim().isEmpty || 
            _passwordController.text.trim().isEmpty) {
          _showError("Email dan Password wajib diisi");
          return false;
        }
        if (_passwordController.text != _confirmPassController.text) {
          _showError("Password tidak sama");
          return false;
        }
        if (_passwordController.text.length < 6) {
           _showError("Password minimal 6 karakter");
           return false;
        }
        return true;
      case 2:
        if (_nameController.text.trim().isEmpty) {
          _showError("Nama Lengkap wajib diisi");
          return false;
        }
        // Baptism name is optional
        if (_dobController.text.trim().isEmpty) {
          _showError("Tanggal Lahir wajib diisi");
          return false;
        }
        if (_maritalStatus == null) {
          _showError("Status Pernikahan wajib dipilih");
          return false;
        }
        return true;
      case 3:
        if (_selectedCountry == null) {
          _showError("Negara wajib dipilih");
          return false;
        }
        return true;
      case 4:
        if (_selectedRole == null) {
          _showError("Pilih peran pelayanan anda");
          return false;
        }
        if (!_agreedToTerms) {
          _showError("Anda harus menyetujui Syarat & Ketentuan");
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitRegistration() async {
    if (!_validateCurrentStep()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final baptismName = _baptismNameController.text.trim();
    final roleUI = _selectedRole ?? 'Umat';
    final roleDB = _roleMap[roleUI] ?? 'umat';
    final maritalDB = _maritalStatusMap[_maritalStatus ?? ''] ?? 'single';

    try {
      // 1. Sign Up
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'baptism_name': baptismName, // Added to metadata
          'role': roleDB,
          'is_catechumen': _isCatechumen,
          'marital_status': maritalDB, 
        },
      );

      final user = res.user;

      if (user != null) {
        // 2. Update Profile
        final birthDate = _formatDateForDB(_dobController.text);
        
        await _supabase.from('profiles').update({
          'birth_date': birthDate,
          'ethnicity': _ethnicityController.text.trim(),
          'country_id': _selectedCountry?['id'],
          'diocese_id': _selectedDiocese?['id'],
          'church_id': _selectedParish?['id'],
          'marital_status': maritalDB, // Ensure stored in profile too
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
           _showError("Cek email anda untuk verifikasi akun.");
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      debugPrint("Register Error: $e");
      if (mounted) _showError("Terjadi kesalahan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Location Fetchers ---

  Future<List<Map<String, dynamic>>> _fetchCountries(String filter) async {
    try {
      var query = _supabase.from('countries').select('id, name');
      if (filter.isNotEmpty) {
        query = query.ilike('name', '%$filter%');
      }
      final data = await query.order('name', ascending: true).limit(100);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetching countries: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDioceses(String filter) async {
    if (_selectedCountry == null) return [];
    try {
      var query = _supabase.from('dioceses')
          .select('id, name')
          .eq('country_id', _selectedCountry!['id']);
      
      if (filter.isNotEmpty) {
        query = query.ilike('name', '%$filter%');
      }
      final data = await query.order('name', ascending: true).limit(100);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetching dioceses: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchParishes(String filter) async {
    if (_selectedDiocese == null) return [];
    try {
      var query = _supabase.from('churches')
          .select('id, name')
          .eq('diocese_id', _selectedDiocese!['id']);
      
      if (filter.isNotEmpty) {
        query = query.ilike('name', '%$filter%');
      }
      final data = await query.order('name', ascending: true).limit(100);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetching churches: $e");
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 6. HELPER METHODS
  // ---------------------------------------------------------------------------

  String? _formatDateForDB(String uiDate) {
    try {
      final parts = uiDate.split('/');
      if (parts.length != 3) return null;
      return "${parts[2]}-${parts[1]}-${parts[0]}";
    } catch (_) {
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message, 
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: kErrorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Registrasi Berhasil",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          content: Text(
            "Akun anda telah dibuat. Silakan masuk kembali.",
            style: GoogleFonts.outfit(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Back to Login Page
              },
              child: Text(
                "Masuk Aplikasi",
                style: GoogleFonts.outfit(
                  color: kPrimaryColor, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 7. UI WIDGET METHODS
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    bool isReadOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: kBorderColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: IgnorePointer(
            ignoring: isReadOnly && onTap != null,
            child: TextField(
              controller: controller,
              obscureText: isObscure,
              keyboardType: keyboardType,
              readOnly: isReadOnly,
              style: GoogleFonts.outfit(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: kInputFillColor,
                contentPadding: const EdgeInsets.all(16),
                hintText: hint,
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
                prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryColor),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String hint,
    required Map<String, dynamic>? selectedItem,
    required bool enabled,
    required Future<List<Map<String, dynamic>>> Function(String) onFind,
    required Function(Map<String, dynamic>?) onChanged,
    Key? key,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: kBorderColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownSearch<Map<String, dynamic>>(
          key: key,
          // 1. GANTI 'asyncItems' MENJADI 'items'
          items: (filter, loadProps) => onFind(filter),
          // 2. Tampilan item
          itemAsString: (item) => item['name']?.toString() ?? '',
          selectedItem: selectedItem,
          onChanged: onChanged,
          enabled: enabled,
          // 3. Logic pembanding
          compareFn: (i1, i2) => i1['id'] == i2['id'],
          // 4. GANTI 'dropdownDecoratorProps' MENJADI 'decoratorProps'
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? kInputFillColor : Colors.grey[200],
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                 borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          // 5. Config Popup
          popupProps: PopupProps.modalBottomSheet(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: "Cari $label...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            modalBottomSheetProps: const ModalBottomSheetProps(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Pilih $label",
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 8. STEP BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildStep1() {
    return Column(
      children: [
        _buildTextField(
          label: "Email",
          hint: "Masukkan email anda",
          controller: _emailController,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Password",
          hint: "Minimal 6 karakter",
          controller: _passwordController,
          icon: Icons.lock_outline,
          isObscure: true,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Konfirmasi Password",
          hint: "Ulangi password",
          controller: _confirmPassController,
          icon: Icons.lock_outline,
          isObscure: true,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: "Nama Lengkap",
          hint: "Sesuai dengan KTP",
          controller: _nameController,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Nama Baptis (Opsional)",
          hint: "Masukkan nama baptis jika ada",
          controller: _baptismNameController,
          icon: Icons.water_drop_outlined,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Tanggal Lahir",
          hint: "DD/MM/YYYY",
          controller: _dobController,
          icon: Icons.calendar_today,
          isReadOnly: true,
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: kPrimaryColor,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
              });
            }
          },
        ),
        const SizedBox(height: 20),
        
        // STATUS PERNIKAHAN DROPDOWN (Manual Implementation for simple choice)
        Text(
          "STATUS PERNIKAHAN",
          style: GoogleFonts.outfit(
            color: kBorderColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kInputFillColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _maritalStatus,
              hint: Text("Pilih Status Pernikahan", style: GoogleFonts.outfit(color: Colors.grey)),
              isExpanded: true,
              items: _maritalStatusMap.keys.map((String key) {
                return DropdownMenuItem<String>(
                  value: key, // Store the Label as value to match Map keys, logic handles conversion
                  child: Text(key, style: GoogleFonts.outfit(color: Colors.black87)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _maritalStatus = newValue;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildTextField(
          label: "Suku / Etnis",
          hint: "Contoh: Batak, Jawa, Chinese",
          controller: _ethnicityController,
          icon: Icons.people_outline,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        _buildLocationDropdown(
          label: "Negara",
          hint: "Pilih Negara",
          selectedItem: _selectedCountry,
          enabled: true,
          onFind: _fetchCountries,
          onChanged: (data) {
            setState(() {
              _selectedCountry = data;
              _selectedDiocese = null;
              _selectedParish = null;
            });
          },
        ),
        const SizedBox(height: 20),
        _buildLocationDropdown(
          key: ValueKey('diocese_${_selectedCountry?['id']}'),
          label: "Keuskupan",
          hint: "Pilih Keuskupan",
          selectedItem: _selectedDiocese,
          enabled: _selectedCountry != null,
          onFind: _fetchDioceses,
          onChanged: (data) {
            setState(() {
              _selectedDiocese = data;
              _selectedParish = null;
            });
          },
        ),
        const SizedBox(height: 20),
        _buildLocationDropdown(
          key: ValueKey('parish_${_selectedDiocese?['id']}'),
          label: "Gereja Paroki",
          hint: "Pilih Gereja Paroki",
          selectedItem: _selectedParish,
          enabled: _selectedDiocese != null,
          onFind: _fetchParishes,
          onChanged: (data) {
            setState(() {
              _selectedParish = data;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PILIH PERAN",
          style: GoogleFonts.outfit(
            color: kBorderColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: _roleMap.keys.map((role) {
            final isSelected = _selectedRole == role;
            return ChoiceChip(
              label: Text(role),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedRole = selected ? role : null;
                });
              },
              backgroundColor: kInputFillColor,
              selectedColor: kPrimaryColor,
              labelStyle: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kInputFillColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            value: _isCatechumen,
            onChanged: (val) {
              setState(() => _isCatechumen = val ?? false);
            },
            activeColor: kPrimaryColor,
            title: Text(
              "Saya calon katekumen / sedang belajar agama Katolik",
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 20),
        
        // T&C CHECKBOX
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
             border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
             children: [
               Checkbox(
                 value: _agreedToTerms,
                 activeColor: kPrimaryColor,
                 onChanged: (val) {
                   setState(() {
                     _agreedToTerms = val ?? false;
                   });
                 }
               ),
               Expanded(
                 child: Text(
                   "Saya menyetujui S&K dan bersedia data iman saya diverifikasi.",
                   style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue[900]),
                 ),
               )
             ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 9. MAIN BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Determine title & subtitle based on step
    String title = "";
    String subtitle = "";
    Widget stepContent = const SizedBox();

    switch (_currentStep) {
      case 1:
        title = "Buat Akun";
        subtitle = "Mulai perjalanan iman anda sekarang.";
        stepContent = _buildStep1();
        break;
      case 2:
        title = "Data Diri";
        subtitle = "Beritahu kami sedikit tentang anda.";
        stepContent = _buildStep2();
        break;
      case 3:
        title = "Lokasi";
        subtitle = "Dimana anda bergereja saat ini?";
        stepContent = _buildStep3();
        break;
      case 4:
        title = "Peran & Status";
        subtitle = "Bagaimana anda melayani gereja?";
        stepContent = _buildStep4();
        break;
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Back Button & Step Counter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep > 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () {
                      setState(() => _currentStep--);
                    },
                  )
                  else
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(
                    "Langkah $_currentStep dari 4",
                    style: GoogleFonts.outfit(
                      color: kBorderColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Progress Bar
            LinearProgressIndicator(
              value: _currentStep / 4,
              backgroundColor: kInputFillColor,
              color: kSuccessColor,
              minHeight: 4,
            ),

            // Main Content Scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Render Steps Here
                    stepContent,
                    
                    const SizedBox(height: 40),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                              if (_currentStep < 4) {
                                if (_validateCurrentStep()) {
                                  setState(() => _currentStep++);
                                }
                              } else {
                                await _submitRegistration();
                              }
                            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [kSecondaryColor, kPrimaryColor],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _currentStep == 4 ? "DAFTAR SEKARANG" : "LANJUT",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
