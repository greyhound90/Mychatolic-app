import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/pages/main_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 1. State Variables
  int _currentStep = 1;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isCatechumen = false;
  String? _selectedRole;
  final List<String> _roles = ["Umat", "Imam", "Biarawan/wati", "Katekis"];

  // 2. Controllers
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _sukuController = TextEditingController();

  // Location Controllers
  final _countryController = TextEditingController();
  final _dioceseController = TextEditingController();
  final _parishController = TextEditingController();

  // Location IDs (UUIDs as Strings)
  String? _selectedCountryId;
  String? _selectedDioceseId;
  String?
  _selectedParishId; // Optional if you need it locally, but we wont save it to profiles based on mismatch rules

  // 3. Helper Methods
  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 4) {
        setState(() => _currentStep++);
      } else {
        // Submit Logic would go here
        _submitRegistration();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 1: // Account Info
        if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
          _showError("Email dan Password wajib diisi");
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          _showError("Password tidak sama");
          return false;
        }
        return true;
      case 2: // Personal Info
        if (_nameController.text.isEmpty || _dobController.text.isEmpty) {
          _showError("Nama dan Tanggal Lahir wajib diisi");
          return false;
        }
        return true;
      case 3: // Location
        // Validation logic - at least Country is usually required
        if (_selectedCountryId == null) {
          _showError("Negara wajib dipilih");
          return false;
        }
        return true;
      case 4: // Role
        if (_selectedRole == null) {
          _showError("Pilih peran anda");
          return false;
        }
        return true;
      default:
        return false;
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface:
                  Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Simple format: DD/MM/YYYY
      String formattedDate =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _dobController.text = formattedDate;
      });
    }
  }

  Future<void> _submitRegistration() async {
    // 1. Final Validation
    if (!_validateCurrentStep()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final role = _selectedRole?.toLowerCase() ?? 'umat';

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Sign Up
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': role, // Metadata
          'is_catechumen': _isCatechumen, // Metadata
        },
      );

      final user = res.user;

      if (user != null) {
        // 3. Prepare Data for Profiles Table
        final dbDate = _formatDateForDB(_dobController.text);

        // Insert Profile Data
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
          'birth_date': dbDate,
          'role': role,
          'ethnicity': _sukuController.text.trim(),
          'country_id': _selectedCountryId,
          'diocese_id': _selectedDioceseId,
          'church_id': _selectedParishId,
          'is_catechumen': _isCatechumen,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 4. Success
        if (mounted) {
          Navigator.pop(context); // Close Loading
          _showSuccessDialog();
        }
      } else {
        // Should rarely happen unless email confirmation is ON and required strictly before login
        if (mounted) Navigator.pop(context);
        _showError(
          "Registrasi berhasil, silakan cek email untuk verifikasi (jika diperlukan).",
        );
      }
    } on AuthException catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(e.message);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError("Terjadi kesalahan: $e");
    }
  }

  String? _formatDateForDB(String uiDate) {
    // Input: DD/MM/YYYY -> Output: YYYY-MM-DD
    try {
      final parts = uiDate.split('/');
      if (parts.length != 3) return null;
      return "${parts[2]}-${parts[1]}-${parts[0]}";
    } catch (_) {
      return null;
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Registrasi Berhasil"),
          content: const Text("Selamat bergabung di MyCatholic!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                // Navigate to Home
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              },
              child: const Text("Masuk Aplikasi"),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;

    // Safety check for null colors from theme
    final borderColor = theme.dividerColor;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bodyColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;

    final double progress = _currentStep / 4;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Premium Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.scaffoldBackgroundColor,
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ],
              ),
            ),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                // TOP BAR
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: bodyColor),
                        onPressed: _prevStep,
                      ),
                      const Spacer(),
                      Text(
                        "Langkah $_currentStep dari 4",
                        style: GoogleFonts.outfit(
                          color: metaColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // PROGRESS BAR
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: borderColor,
                  color: primaryColor,
                  minHeight: 4,
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          _getStepTitle(),
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStepSubtitle(),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: bodyColor,
                          ),
                        ),

                        const SizedBox(height: 30),

                        _buildStepContent(theme),

                        const SizedBox(height: 40),

                        // ACTION BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _nextStep,
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
                                gradient: LinearGradient(
                                  colors: [secondaryColor, primaryColor],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: Text(
                                  _currentStep == 4
                                      ? "DAFTAR SEKARANG"
                                      : "LANJUT",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Login Link
                        if (_currentStep == 1) ...[
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Sudah punya akun? ",
                                style: GoogleFonts.outfit(color: bodyColor),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  "MASUK",
                                  style: GoogleFonts.outfit(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return "Buat Akun";
      case 2:
        return "Data Diri";
      case 3:
        return "Lokasi";
      case 4:
        return "Peran & Iman";
      default:
        return "";
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 1:
        return "Masukkan kredensial akun anda.";
      case 2:
        return "Beritahu kami tentang diri anda.";
      case 3:
        return "Dimana anda bergereja?";
      case 4:
        return "Pilih peran pelayanan anda.";
      default:
        return "";
    }
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(theme);
      case 2:
        return _buildStep2(theme);
      case 3:
        return _buildStep3(theme);
      case 4:
        return _buildStep4(theme);
      default:
        return Container();
    }
  }

  Widget _buildStep1(ThemeData theme) {
    return Column(
      children: [
        _buildTextField(
          "Email",
          "Masukkan email",
          _emailController,
          Icons.email_outlined,
          theme,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          "No. Handphone",
          "08xxxxxxxxxx",
          _phoneController,
          Icons.phone_android_rounded,
          theme,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          "Password",
          "Buat password",
          _passwordController,
          Icons.lock_outline,
          theme,
          isObscure: true,
          toggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          isPasswordVisible: !_obscurePassword,
        ),
        const SizedBox(height: 20),
        _buildTextField(
          "Konfirmasi Password",
          "Ulangi password",
          _confirmPasswordController,
          Icons.lock_outline,
          theme,
          isObscure: true,
          toggleObscure: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          isPasswordVisible: !_obscureConfirm,
        ),
      ],
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Column(
      children: [
        _buildTextField(
          "Nama Lengkap",
          "Sesuai KTP",
          _nameController,
          Icons.person_outline,
          theme,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: _buildTextField(
              "Tanggal Lahir",
              "DD/MM/YYYY",
              _dobController,
              Icons.calendar_today,
              theme,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField(
          "Suku",
          "Contoh: Batak, Jawa",
          _sukuController,
          Icons.people_outline,
          theme,
        ),
      ],
    );
  }

  Widget _buildStep3(ThemeData theme) {
    return Column(
      children: [
        // NEGARA
        _buildDropdownField(
          "Negara",
          "Pilih Negara",
          _countryController,
          theme,
          onTap: () {
            _showSupabaseSelectionModal(
              title: "Negara",
              tableName: "countries",
              columnName: "name",
              theme: theme,
              onSelected: (id, name) {
                setState(() {
                  _selectedCountryId = id; // UUID String
                  _countryController.text = name;

                  // Reset Children
                  _selectedDioceseId = null;
                  _dioceseController.clear();
                  _selectedParishId = null;
                  _parishController.clear();
                });
              },
            );
          },
        ),
        const SizedBox(height: 20),

        // KEUSKUPAN
        _buildDropdownField(
          "Keuskupan",
          "Pilih Keuskupan",
          _dioceseController,
          theme,
          onTap: () {
            if (_selectedCountryId == null) {
              _showError("Pilih negara terlebih dahulu");
              return;
            }
            _showSupabaseSelectionModal(
              title: "Keuskupan",
              tableName: "dioceses",
              columnName: "name",
              filterColumn: "country_id",
              filterValue: _selectedCountryId, // Passing UUID String filter
              theme: theme,
              onSelected: (id, name) {
                setState(() {
                  _selectedDioceseId = id; // UUID String
                  _dioceseController.text = name;

                  // Reset Child
                  _selectedParishId = null;
                  _parishController.clear();
                });
              },
            );
          },
        ),
        const SizedBox(height: 20),

        // PAROKI
        _buildDropdownField(
          "Paroki",
          "Pilih Paroki",
          _parishController,
          theme,
          onTap: () {
            if (_selectedDioceseId == null) {
              _showError("Pilih negara dan keuskupan terlebih dahulu");
              return;
            }
            _showSupabaseSelectionModal(
              title: "Paroki",
              tableName: "churches",
              columnName: "name",
              filterColumn: "diocese_id",
              filterValue: _selectedDioceseId, // Passing UUID String filter
              theme: theme,
              onSelected: (id, name) {
                setState(() {
                  _selectedParishId = id; // UUID String
                  _parishController.text = name;
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep4(ThemeData theme) {
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final cardColor = theme.cardColor;
    final borderColor = theme.dividerColor; // Used for border color
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PILIH PERAN",
          style: GoogleFonts.outfit(
            color: metaColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _roles.map((role) => _buildRoleCard(role, theme)).toList(),
        ),
        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _isCatechumen,
                onChanged: (val) =>
                    setState(() => _isCatechumen = val ?? false),
                activeColor: theme.primaryColor,
                checkColor: Colors.white,
                side: BorderSide(color: metaColor),
              ),
              Expanded(
                child: Text(
                  "Saya adalah calon katekumen / sedang belajar agama Katolik.",
                  style: GoogleFonts.outfit(color: titleColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard(String role, ThemeData theme) {
    bool isSelected = _selectedRole == role;
    final primaryColor = theme.primaryColor;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : theme.dividerColor,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Text(
          role,
          style: GoogleFonts.outfit(
            color: isSelected
                ? Colors.white
                : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
    ThemeData theme, {
    bool isObscure = false,
    VoidCallback? toggleObscure,
    bool? isPasswordVisible,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: metaColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText:
              isObscure &&
              (isPasswordVisible == false || isPasswordVisible == null),
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              color: metaColor.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, color: metaColor, size: 20),
            suffixIcon: toggleObscure != null
                ? IconButton(
                    icon: Icon(
                      (isPasswordVisible ?? false)
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: metaColor,
                      size: 20,
                    ),
                    onPressed: toggleObscure,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String hint,
    TextEditingController controller,
    ThemeData theme, {
    VoidCallback? onTap,
  }) {
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: metaColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap:
              onTap ??
              () {
                // Fallback default
                _showError("Feature not ready");
              },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
                    style: GoogleFonts.outfit(
                      color: controller.text.isEmpty
                          ? metaColor.withValues(alpha: 0.5)
                          : theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: metaColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSupabaseSelectionModal({
    required String title,
    required String tableName,
    required String columnName,
    // Callback returns string ID now (for UUIDs)
    required Function(String id, String name) onSelected,
    required ThemeData theme,
    String? filterColumn,
    dynamic filterValue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // Allow full height
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    "Pilih $title",
                    style: GoogleFonts.outfit(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Field (Visual Only for now)
                  TextField(
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.cardColor,
                      hintText: "Cari $title...",
                      hintStyle: GoogleFonts.outfit(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: theme.dividerColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Future Builder for Data
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchData(tableName, filterColumn, filterValue),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "Error: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Text(
                              "Data tidak ditemukan",
                              style: GoogleFonts.outfit(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data!;

                        return ListView.separated(
                          controller: scrollController,
                          itemCount: data.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: theme.dividerColor),
                          itemBuilder: (ctx, index) {
                            final item = data[index];
                            return ListTile(
                              title: Text(
                                item[columnName] ?? 'Unknown',
                                style: GoogleFonts.outfit(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              onTap: () {
                                // Pass ID as String (UUID)
                                onSelected(
                                  item['id'].toString(),
                                  item[columnName],
                                );
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        );
                      },
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

  Future<List<Map<String, dynamic>>> _fetchData(
    String table,
    String? filterCol,
    dynamic filterVal,
  ) async {
    try {
      var query = Supabase.instance.client.from(table).select();
      if (filterCol != null && filterVal != null) {
        query = query.eq(filterCol, filterVal);
      }
      if (table == 'churches') {
        query = query.eq('type', 'parish');
      }
      return await query;
    } catch (e) {
      debugPrint("Supabase Fetch Error: $e");
      return [];
    }
  }
}
