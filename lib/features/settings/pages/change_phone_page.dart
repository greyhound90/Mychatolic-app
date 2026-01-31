import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/widgets/app_text_field.dart';

class ChangePhonePage extends StatefulWidget {
  final String? currentPhone;
  final bool autoSendOtp;

  const ChangePhonePage({
    super.key,
    this.currentPhone,
    this.autoSendOtp = false,
  });

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    if (widget.currentPhone != null && widget.currentPhone!.isNotEmpty) {
      _phoneController.text = widget.currentPhone!;
    }
    if (widget.autoSendOtp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOtp());
    }
  }

  String _normalizePhone(String input) {
    var value = input.trim().replaceAll(' ', '');
    if (value.isEmpty) return value;
    if (value.startsWith('+')) return value;
    if (value.startsWith('0')) {
      return '+62${value.substring(1)}';
    }
    if (value.startsWith('62')) {
      return '+$value';
    }
    return '+$value';
  }

  bool _isSmsProviderIssue(String message) {
    final msg = message.toLowerCase();
    return msg.contains('sms') ||
        msg.contains('provider') ||
        msg.contains('twilio') ||
        msg.contains('not enabled');
  }

  Future<void> _sendOtp() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    final phone = _normalizePhone(_phoneController.text);
    if (phone.isEmpty) {
      setState(() => _errorMessage = "Nomor HP wajib diisi.");
      return;
    }
    setState(() => _isSending = true);
    try {
      await _supabase.auth.updateUser(UserAttributes(phone: phone));
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _infoMessage = "OTP dikirim ke $phone";
      });
    } catch (e) {
      final message = e.toString();
      if (_isSmsProviderIssue(message)) {
        setState(() {
          _infoMessage =
              "Verifikasi SMS belum diaktifkan di server. Silakan konfigurasi provider SMS di Supabase Auth.";
        });
      } else {
        setState(() => _errorMessage = "Gagal mengirim OTP: $e");
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _errorMessage = null);
    final phone = _normalizePhone(_phoneController.text);
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = "Masukkan kode OTP yang valid.");
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.phoneChange,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nomor HP terverifikasi.")),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = "Gagal verifikasi OTP: $e");
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Nomor HP",
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
                    "Gunakan format internasional (+62...).",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_infoMessage != null) ...[
                    AppCard(
                      color: AppColors.primary.withOpacity(0.08),
                      borderColor: AppColors.primary.withOpacity(0.3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _infoMessage!,
                              style: GoogleFonts.outfit(
                                color: AppColors.primary,
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
                    label: "Nomor HP",
                    hint: "+62xxxxxxxxxx",
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    fillColor: AppColors.surface,
                    borderColor: AppColors.border,
                    focusBorderColor: AppColors.primary,
                    textColor: AppColors.text,
                    hintColor: AppColors.textMuted,
                    labelColor: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: _isSending ? "Mengirim..." : "Kirim OTP",
                      isLoading: _isSending,
                      onPressed: _isSending ? null : _sendOtp,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeOut,
                    child: _otpSent
                        ? Column(
                            key: const ValueKey('otp'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppTextField(
                                label: "Kode OTP",
                                hint: "Masukkan 6 digit",
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                fillColor: AppColors.surface,
                                borderColor: AppColors.border,
                                focusBorderColor: AppColors.primary,
                                textColor: AppColors.text,
                                hintColor: AppColors.textMuted,
                                labelColor: AppColors.textMuted,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: AppPrimaryButton(
                                  label: _isVerifying
                                      ? "Memverifikasi..."
                                      : "Verifikasi",
                                  isLoading: _isVerifying,
                                  onPressed: _isVerifying ? null : _verifyOtp,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
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
