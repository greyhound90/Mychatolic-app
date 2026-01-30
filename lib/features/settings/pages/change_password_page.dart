import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isLoading = false;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleChangePassword() async {
    final currentPassword = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnack("Semua field wajib diisi");
      return;
    }
    if (newPassword.length < 8) {
      _showSnack("Password baru minimal 8 karakter");
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnack("Konfirmasi password tidak sama");
      return;
    }

    final email = _supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      _showSnack("Email user tidak ditemukan");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _showSnack("Password berhasil diubah");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack("Gagal ubah password: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final surface = colors.surface;
    final border = theme.dividerColor;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Ubah Kata Sandi",
          style: GoogleFonts.outfit(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInput(
              label: "Password Saat Ini",
              controller: _currentController,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              surface: surface,
              border: border,
              primary: colors.primary,
            ),
            const SizedBox(height: 12),
            _buildInput(
              label: "Password Baru",
              controller: _newController,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              surface: surface,
              border: border,
              primary: colors.primary,
            ),
            const SizedBox(height: 12),
            _buildInput(
              label: "Konfirmasi Password Baru",
              controller: _confirmController,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              surface: surface,
              border: border,
              primary: colors.primary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleChangePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colors.onPrimary,
                          ),
                        ),
                      )
                    : Text(
                        "Simpan",
                        style: GoogleFonts.outfit(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required Color textPrimary,
    required Color textSecondary,
    required Color surface,
    required Color border,
    required Color primary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border.withOpacity(0.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border.withOpacity(0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary),
            ),
          ),
          style: GoogleFonts.outfit(color: textPrimary),
        ),
      ],
    );
  }
}
