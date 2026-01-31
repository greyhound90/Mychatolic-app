import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/widgets/app_text_field.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

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
  String? _errorMessage;

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.showSuccess(context, message);
  }

  Future<void> _handleChangePassword() async {
    setState(() => _errorMessage = null);
    final currentPassword = _currentController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = "Semua field wajib diisi");
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorMessage = "Password baru minimal 8 karakter");
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = "Konfirmasi password tidak sama");
      return;
    }

    final email = _supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _errorMessage = "Email user tidak ditemukan");
      return;
    }

    setState(() => _isLoading = true);
    AnalyticsService.instance.track(AnalyticsEvents.settingsChangePasswordAttempt);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _showSnack("Password berhasil diubah");
      AnalyticsService.instance.track(AnalyticsEvents.settingsChangePasswordSuccess);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      AnalyticsService.instance.track(
        AnalyticsEvents.settingsChangePasswordFail,
        props: {'error_code': AnalyticsService.errorCode(e)},
      );
      setState(() => _errorMessage = "Gagal ubah password: $e");
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Ubah Kata Sandi",
          style: GoogleFonts.outfit(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Gunakan password yang kuat dan mudah diingat.",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) ...[
                    AppCard(
                      color: AppColors.danger.withOpacity(0.08),
                      borderColor: AppColors.danger.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.danger),
                          const SizedBox(width: 8),
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
                    const SizedBox(height: 12),
                  ],
                  _buildInput(
                    label: "Password Saat Ini",
                    controller: _currentController,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: "Password Baru",
                    controller: _newController,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    label: "Konfirmasi Password Baru",
                    controller: _confirmController,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: _isLoading ? "Memproses..." : "Simpan",
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleChangePassword,
                    ),
                  ),
                ],
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
  }) {
    return AppTextField(
      label: label,
      hint: label,
      controller: controller,
      isObscure: true,
      fillColor: AppColors.surface,
      borderColor: AppColors.border,
      focusBorderColor: AppColors.primary,
      textColor: AppColors.text,
      hintColor: AppColors.textMuted,
      labelColor: AppColors.textMuted,
    );
  }
}
