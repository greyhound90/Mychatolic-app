import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/widgets/app_text_field.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';

class ChangeEmailPage extends StatefulWidget {
  final String currentEmail;

  const ChangeEmailPage({super.key, required this.currentEmail});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        widget.currentEmail == "-" ? "" : widget.currentEmail;
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);
    final newEmail = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!_isValidEmail(newEmail)) {
      _showError("Format email tidak valid.");
      return;
    }
    if (password.isEmpty) {
      _showError("Masukkan password untuk konfirmasi.");
      return;
    }

    final currentEmail = _supabase.auth.currentUser?.email;
    if (currentEmail == null) {
      _showError("Email pengguna tidak ditemukan.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signInWithPassword(
        email: currentEmail,
        password: password,
      );
      await _supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        "Email baru perlu verifikasi. Cek inbox Anda.",
      );
      Navigator.pop(context);
    } catch (e) {
      _showError("Gagal ganti email: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Ganti Email",
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Email baru akan membutuhkan verifikasi ulang.",
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
                  AppTextField(
                    label: "Email Baru",
                    hint: "nama@email.com",
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    fillColor: AppColors.surface,
                    borderColor: AppColors.border,
                    focusBorderColor: AppColors.primary,
                    textColor: AppColors.text,
                    hintColor: AppColors.textMuted,
                    labelColor: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: "Password Saat Ini",
                    hint: "Masukkan password",
                    controller: _passwordController,
                    isObscure: true,
                    fillColor: AppColors.surface,
                    borderColor: AppColors.border,
                    focusBorderColor: AppColors.primary,
                    textColor: AppColors.text,
                    hintColor: AppColors.textMuted,
                    labelColor: AppColors.textMuted,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: _isLoading ? "Memproses..." : "Simpan",
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleSubmit,
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
}
