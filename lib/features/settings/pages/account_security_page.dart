import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/features/settings/pages/change_email_page.dart';
import 'package:mychatolic_app/features/settings/pages/change_phone_page.dart';
import 'package:mychatolic_app/features/settings/pages/change_password_page.dart';
import 'package:mychatolic_app/features/settings/widgets/security_tile.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  bool _loading = true;
  String? _error;
  bool _resendLoading = false;
  bool _globalLogoutLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    AnalyticsService.instance.track(AnalyticsEvents.settingsSecurityOpen);
  }

  Future<void> _loadUser() async {
    safeSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _supabase.auth.getUser();
      _user = response.user ?? _supabase.auth.currentUser;
    } catch (e) {
      _error = "Gagal memuat data akun.";
      _user = _supabase.auth.currentUser;
    } finally {
      safeSetState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.showInfo(context, message);
  }

  Future<void> _resendEmailVerification(String email) async {
    safeSetState(() => _resendLoading = true);
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
      _showSnack("Email verifikasi telah dikirim.");
    } catch (e) {
      try {
        await _supabase.auth.resetPasswordForEmail(email);
        _showSnack("Email dikirim. Silakan cek inbox Anda.");
      } catch (_) {
        _showSnack("Gagal mengirim verifikasi: $e");
      }
    } finally {
      safeSetState(() => _resendLoading = false);
    }
  }

  Future<void> _logoutAllDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout Semua Perangkat"),
        content:
            const Text("Anda akan keluar dari semua perangkat termasuk ini."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "Logout",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    safeSetState(() => _globalLogoutLoading = true);
    try {
      await _supabase.auth.signOut(scope: SignOutScope.global);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      _showSnack("Gagal logout semua perangkat: $e");
    } finally {
      safeSetState(() => _globalLogoutLoading = false);
    }
  }

  SecurityStatus _emailStatus(User user) {
    return user.emailConfirmedAt != null
        ? SecurityStatus.verified
        : SecurityStatus.unverified;
  }

  SecurityStatus _phoneStatus(User user) {
    final phone = user.phone;
    if (phone == null || phone.isEmpty) {
      return SecurityStatus.unknown;
    }
    return user.phoneConfirmedAt != null
        ? SecurityStatus.verified
        : SecurityStatus.unverified;
  }

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) return "-";
    try {
      final parsed = DateTime.parse(value).toLocal();
      return DateFormat("dd MMM yyyy, HH:mm").format(parsed);
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.text;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Keamanan Akun",
          style: GoogleFonts.outfit(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(
              child: AppCard(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Memuat keamanan akun...",
                      style: GoogleFonts.outfit(color: AppColors.textBody),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  if (_error != null)
                    AppCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: AppColors.danger.withOpacity(0.08),
                      borderColor: AppColors.danger.withOpacity(0.3),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.outfit(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadUser,
                            child: Text(
                              "Coba Lagi",
                              style: GoogleFonts.outfit(
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_user == null)
                    AppCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Icon(Icons.person_off, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text(
                            "User tidak ditemukan. Silakan login kembali.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _buildEmailCard(_user!),
                    _buildPhoneCard(_user!),
                    _buildPasswordCard(),
                    _buildSessionCard(_user!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmailCard(User user) {
    final emailValue = user.email;
    final emailDisplay = emailValue ?? "-";
    final status = _emailStatus(user);
    return SecurityTile(
      icon: Icons.email_outlined,
      title: "Email",
      subtitle: emailDisplay,
      trailing: SecurityStatusChip(status: status),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status == SecurityStatus.verified
                ? "Email sudah terverifikasi."
                : "Email belum terverifikasi.",
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (status != SecurityStatus.verified)
                SizedBox(
                  height: 42,
                  child: AppSecondaryButton(
                    label: _resendLoading
                        ? "Mengirim..."
                        : "Kirim Ulang Verifikasi",
                    onPressed: _resendLoading
                        ? null
                        : () {
                            if (emailValue == null || emailValue.isEmpty) {
                              _showSnack("Email tidak tersedia.");
                              return;
                            }
                            _resendEmailVerification(emailValue);
                          },
                    borderColor: AppColors.primary.withOpacity(0.3),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              SizedBox(
                height: 42,
                child: AppPrimaryButton(
                  label: "Ganti Email",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangeEmailPage(currentEmail: emailDisplay),
                      ),
                    ).then((_) => _loadUser());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCard(User user) {
    final phoneValue = user.phone;
    final phoneDisplay =
        (phoneValue != null && phoneValue.isNotEmpty) ? phoneValue : "-";
    final status = _phoneStatus(user);
    return SecurityTile(
      icon: Icons.phone_outlined,
      title: "Nomor HP",
      subtitle: phoneDisplay,
      trailing: SecurityStatusChip(status: status),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status == SecurityStatus.verified
                ? "Nomor sudah terverifikasi."
                : status == SecurityStatus.unverified
                    ? "Nomor belum terverifikasi."
                    : "Nomor belum ditambahkan.",
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                height: 42,
                child: AppSecondaryButton(
                  label: "Tambah/Ganti Nomor",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangePhonePage(currentPhone: phoneValue),
                      ),
                    ).then((_) => _loadUser());
                  },
                  borderColor: AppColors.primary.withOpacity(0.3),
                  foregroundColor: AppColors.primary,
                ),
              ),
              if (status == SecurityStatus.unverified &&
                  user.phone != null &&
                  user.phone!.isNotEmpty)
                SizedBox(
                  height: 42,
                  child: AppPrimaryButton(
                    label: "Verifikasi Nomor",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangePhonePage(
                            currentPhone: phoneValue,
                            autoSendOtp: true,
                          ),
                        ),
                      ).then((_) => _loadUser());
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    return SecurityTile(
      icon: Icons.lock_outline,
      title: "Password",
      subtitle: "Terakhir diperbarui: -",
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
      footer: SizedBox(
        height: 42,
        child: AppPrimaryButton(
          label: "Ganti Password",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSessionCard(User user) {
    final lastSignIn = _formatDateTime(user.lastSignInAt);
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sesi",
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Last sign-in: $lastSignIn",
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: AppSecondaryButton(
              label: _globalLogoutLoading
                  ? "Memproses..."
                  : "Logout Semua Perangkat",
              onPressed: _globalLogoutLoading ? null : _logoutAllDevices,
              borderColor: AppColors.danger.withOpacity(0.3),
              foregroundColor: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
