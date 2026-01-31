import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:mychatolic_app/core/widgets/app_text_field.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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
  bool _stepForward = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

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
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
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
    final birthDate = _formatDateForDB(_dobController.text);
    final termsAcceptedAt = DateTime.now().toIso8601String();

    final userMetadata = <String, dynamic>{
      'full_name': name,
      'baptism_name': baptismName,
      'role': roleDB,
      'is_catechumen': _isCatechumen,
      'marital_status': maritalDB,
      'gender': null,
      'profile_filled': true,
      'terms_accepted_at': termsAcceptedAt,
    };

    if (birthDate != null) {
      userMetadata['birth_date'] = birthDate;
    }
    if (_ethnicityController.text.trim().isNotEmpty) {
      userMetadata['ethnicity'] = _ethnicityController.text.trim();
    }
    if (_selectedCountry?['id'] != null) {
      userMetadata['country_id'] = _selectedCountry!['id'];
    }
    if (_selectedDiocese?['id'] != null) {
      userMetadata['diocese_id'] = _selectedDiocese!['id'];
    }
    if (_selectedParish?['id'] != null) {
      userMetadata['church_id'] = _selectedParish!['id'];
    }

    try {
      // 1. Sign Up
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      AppLogger.logError("Register Error", error: e);
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
      AppLogger.logError("Error fetching countries", error: e);
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
      AppLogger.logError("Error fetching dioceses", error: e);
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
      AppLogger.logError("Error fetching churches", error: e);
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
    if (mounted) {
      setState(() => _errorMessage = message);
    }
    AppSnackBar.showError(context, message);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Registrasi Berhasil",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Text(
            "Akun Anda telah dibuat. Silakan verifikasi email terlebih dahulu, lalu login kembali.",
            style: GoogleFonts.outfit(color: AppColors.textBody),
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
                  color: AppColors.primary, 
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
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
    bool isReadOnly = false,
    VoidCallback? onTap,
  }) {
    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AppTextField(
            label: label,
            hint: hint,
            controller: controller,
            icon: icon,
            isObscure: isObscure,
            onToggleObscure: toggleObscure,
            keyboardType: keyboardType,
            readOnly: isReadOnly,
            onTap: onTap,
            isFocused: isFocused,
            fillColor: AppColors.surface,
            borderColor: AppColors.border,
            focusBorderColor: AppColors.primary,
            textColor: AppColors.text,
            hintColor: AppColors.textMuted,
            labelColor: AppColors.textMuted,
            iconColor: AppColors.textMuted,
            shadow: AppShadows.level1,
            focusShadow: AppShadows.level2,
          );
        },
      ),
    );
  }

  void _openMaritalStatusSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _maritalStatusMap.keys.length,
            separatorBuilder: (_, __) => Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final key = _maritalStatusMap.keys.elementAt(index);
              final selected = key == _maritalStatus;
              return ListTile(
                title: Text(
                  key,
                  style: GoogleFonts.outfit(color: AppColors.text),
                ),
                trailing: selected
                    ? Icon(Icons.check_circle, color: AppColors.success)
                    : null,
                onTap: () {
                  setState(() => _maritalStatus = key);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
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
            color: AppColors.textMuted,
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
          dropdownBuilder: (context, selectedItem) {
            final text = selectedItem?['name']?.toString() ?? '';
            return Text(
              text,
              style: GoogleFonts.outfit(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            );
          },
          selectedItem: selectedItem,
          onChanged: onChanged,
          enabled: enabled,
          // 3. Logic pembanding
          compareFn: (i1, i2) => i1['id'] == i2['id'],
          // 4. GANTI 'dropdownDecoratorProps' MENJADI 'decoratorProps'
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? AppColors.surface : AppColors.surfaceAlt,
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          // 5. Config Popup
          popupProps: PopupProps.modalBottomSheet(
            showSearchBox: true,
            itemBuilder: (context, item, isSelected, isHighlighted) {
              return ListTile(
                tileColor: isHighlighted
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.transparent,
                title: Text(
                  item['name']?.toString() ?? '',
                  style: GoogleFonts.outfit(
                    color: AppColors.text,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            },
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: "Cari $label...",
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            modalBottomSheetProps: const ModalBottomSheetProps(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Pilih $label",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
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
          isObscure: _obscurePassword,
          toggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Konfirmasi Password",
          hint: "Ulangi password",
          controller: _confirmPassController,
          icon: Icons.lock_outline,
          isObscure: _obscureConfirm,
          toggleObscure: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
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
                    useMaterial3: true,
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.surface,
                      onSurface: AppColors.text,
                    ),
                    dialogBackgroundColor: AppColors.surface,
                    dialogTheme: DialogThemeData(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: AppColors.surface,
                      surfaceTintColor: Colors.transparent,
                      headerBackgroundColor: AppColors.surface,
                      headerForegroundColor: AppColors.text,
                      dividerColor: AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      dayForegroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.white;
                        }
                        if (states.contains(MaterialState.disabled)) {
                          return AppColors.textMuted;
                        }
                        return AppColors.text;
                      }),
                      dayBackgroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.primary;
                        }
                        return Colors.transparent;
                      }),
                      yearForegroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.text;
                        }
                        return AppColors.textMuted;
                      }),
                      yearBackgroundColor:
                          MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppColors.primary.withOpacity(0.20);
                        }
                        return Colors.transparent;
                      }),
                      todayForegroundColor:
                          const MaterialStatePropertyAll(AppColors.primary),
                      todayBorder: const BorderSide(
                          color: AppColors.primary, width: 1.2),
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
        
        // STATUS PERNIKAHAN PICKER (Dark premium bottom sheet)
        Text(
          "STATUS PERNIKAHAN",
          style: GoogleFonts.outfit(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openMaritalStatusSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _maritalStatus ?? "Pilih Status Pernikahan",
                      style: GoogleFonts.outfit(
                        color: _maritalStatus == null
                            ? AppColors.textMuted
                            : AppColors.text,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
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
            color: AppColors.textMuted,
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
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary,
              labelStyle: GoogleFonts.outfit(
                color: isSelected ? Colors.white : AppColors.text,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: CheckboxListTile(
            value: _isCatechumen,
            onChanged: (val) {
              setState(() => _isCatechumen = val ?? false);
            },
            activeColor: AppColors.primary,
            title: Text(
              "Saya calon katekumen / sedang belajar agama Katolik",
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textBody),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 20),
        
        // T&C CHECKBOX
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                checkColor: Colors.white,
                side: BorderSide(
                  color: AppColors.textMuted.withOpacity(0.9),
                  width: 1.4,
                ),
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _agreedToTerms = val ?? false;
                  });
                }
              ),
              Expanded(
                child: Text(
                  "Saya menyetujui S&K dan bersedia data iman saya diverifikasi.",
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.primary),
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
        stepContent = Theme(
          data: Theme.of(context).copyWith(
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(
                color: AppColors.textMuted.withOpacity(0.9),
                width: 1.4,
              ),
              checkColor: const MaterialStatePropertyAll(Colors.white),
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
            ),
          ),
          child: _buildStep4(),
        );
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _AuthBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (_currentStep > 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.text),
                          onPressed: () {
                            setState(() {
                              _stepForward = false;
                              _currentStep--;
                            });
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.text),
                          onPressed: () => Navigator.pop(context),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      8,
                      24,
                      24 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StepHeader(currentStep: _currentStep),
                        const SizedBox(height: 16),
                        _AuthCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeOut,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SizeTransition(
                                      sizeFactor: animation,
                                      axisAlignment: -1,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _errorMessage == null
                                    ? const SizedBox.shrink()
                                    : AppCard(
                                        key: ValueKey(_errorMessage),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        color: AppColors.danger.withOpacity(0.08),
                                        borderColor:
                                            AppColors.danger.withOpacity(0.35),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: AppColors.danger),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: GoogleFonts.outfit(
                                                  color: AppColors.danger,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                              if (_errorMessage != null)
                                const SizedBox(height: 14),
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textBody,
                                ),
                              ),
                              const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) {
                              final beginOffset =
                                  _stepForward ? const Offset(0.12, 0) : const Offset(-0.12, 0);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: beginOffset,
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey(_currentStep),
                              child: stepContent,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: AppSecondaryButton(
                                    label: _currentStep > 1 ? "KEMBALI" : "BATAL",
                                    onPressed: () {
                                      if (_currentStep > 1) {
                                        setState(() {
                                          _stepForward = false;
                                          _currentStep--;
                                        });
                                      } else {
                                        Navigator.pop(context);
                                      }
                                    },
                                    borderColor: AppColors.border,
                                    foregroundColor: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeOut,
                                    child: AppPrimaryButton(
                                      key: ValueKey(_isLoading),
                                      label: _isLoading
                                          ? "Memproses..."
                                          : _currentStep == 4
                                              ? "DAFTAR"
                                              : "LANJUT",
                                      isLoading: _isLoading,
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              if (_currentStep < 4) {
                                                if (_validateCurrentStep()) {
                                                  setState(() {
                                                    _stepForward = true;
                                                    _currentStep++;
                                                  });
                                                }
                                              } else {
                                                await _submitRegistration();
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  final Widget child;

  const _AuthBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.background,
                AppColors.surfaceAlt,
                AppColors.background,
              ],
            ),
          ),
        ),
        Positioned(
          top: -70,
          right: -30,
          child: _Blob(
            size: 180,
            color: AppColors.primary.withOpacity(0.10),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _Blob(
            size: 170,
            color: AppColors.primaryMuted.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: 140,
          left: 20,
          child: _Blob(
            size: 90,
            color: AppColors.primary.withOpacity(0.06),
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;

  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      color: AppColors.surface,
      borderColor: AppColors.border,
      shadow: AppShadows.level2,
      child: child,
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int currentStep;

  const _StepHeader({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const labels = ["Akun", "Data", "Lokasi", "Peran"];
    return _StepDots(
      currentStep: currentStep,
      labels: labels,
    );
  }
}

class _StepDots extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const _StepDots({required this.currentStep, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(labels.length, (index) {
            final step = index + 1;
            final isActive = currentStep == step;
            final isDone = currentStep > step;
            final color = isActive || isDone
                ? AppColors.primary
                : AppColors.border;
            final opacity = isActive ? 1.0 : (isDone ? 0.7 : 0.35);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: isActive ? 14 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(opacity),
                borderRadius: BorderRadius.circular(999),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            labels[currentStep - 1],
            key: ValueKey(currentStep),
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
