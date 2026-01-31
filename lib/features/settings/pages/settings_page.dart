import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/auth/pages/verification_page.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/features/settings/pages/change_password_page.dart';
import 'package:mychatolic_app/features/settings/pages/account_security_page.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';
import 'package:mychatolic_app/providers/locale_provider.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  final Profile profile;

  const SettingsPage({super.key, required this.profile});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _analyticsEnabled = true;
  bool _analyticsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsPref();
  }

  Future<void> _loadAnalyticsPref() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('analytics_enabled') ?? true;
    if (!mounted) return;
    setState(() {
      _analyticsEnabled = enabled;
      _analyticsLoaded = true;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppSnackBar.showInfo(context, message);
  }

  Future<void> _showLanguageSheet(LocaleProvider localeProvider) async {
    final t = AppLocalizations.of(context)!;
    final current = localeProvider.localeCode ?? 'system';
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  t.settingsLanguageTitle,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  t.settingsLanguageSubtitle,
                  style: GoogleFonts.outfit(),
                ),
              ),
              RadioListTile<String>(
                value: 'system',
                groupValue: current,
                onChanged: (value) async {
                  await localeProvider.setLocaleCode(null);
                  if (mounted) Navigator.pop(ctx);
                },
                title: Text(t.settingsLanguageSystem),
              ),
              RadioListTile<String>(
                value: 'id',
                groupValue: current,
                onChanged: (value) async {
                  await localeProvider.setLocaleCode('id');
                  if (mounted) Navigator.pop(ctx);
                },
                title: Text(t.settingsLanguageIndonesian),
              ),
              RadioListTile<String>(
                value: 'en',
                groupValue: current,
                onChanged: (value) async {
                  await localeProvider.setLocaleCode('en');
                  if (mounted) Navigator.pop(ctx);
                },
                title: Text(t.settingsLanguageEnglish),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleAnalytics(bool value) async {
    if (!_analyticsLoaded) return;
    setState(() => _analyticsEnabled = value);
    if (!value) {
      AnalyticsService.instance.track(
        AnalyticsEvents.analyticsOptOut,
        props: const {'enabled': false},
      );
      await AnalyticsService.instance.flush();
    }
    AnalyticsService.instance.setEnabled(value);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<String?> _showTextInputDialog({
    required String title,
    required String hint,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final t = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue ?? "");
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(t.commonSave),
          ),
        ],
      ),
    );
    return result?.isEmpty == true ? null : result;
  }

  Widget _buildStatusChip({required bool verified}) {
    final colors = Theme.of(context).colorScheme;
    final color = verified ? colors.secondary : colors.error;
    final t = AppLocalizations.of(context)!;
    final label =
        verified ? t.profileVerified : t.profileNotVerified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showEmailActionsSheet({
    required User user,
    required bool isVerified,
  }) async {
    final t = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isVerified)
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: Text(t.settingsEmailResend),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      if (user.email == null || user.email!.isEmpty) {
                        _showSnack(t.settingsEmailNotAvailable);
                        return;
                      }
                      await _supabase.auth.resend(
                        type: OtpType.signup,
                        email: user.email!,
                      );
                      _showSnack(t.settingsEmailSent);
                    } catch (e) {
                      _showSnack(t.commonErrorGeneric);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: Text(t.settingsChangeEmail),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newEmail = await _showTextInputDialog(
                    title: t.settingsChangeEmailTitle,
                    hint: t.settingsEmailHint,
                    keyboardType: TextInputType.emailAddress,
                  );
                  if (newEmail == null) return;
                  if (!_isValidEmail(newEmail)) {
                    _showSnack(t.settingsInvalidEmail);
                    return;
                  }
                  try {
                    await _supabase.auth.updateUser(
                      UserAttributes(email: newEmail),
                    );
                    _showSnack(t.settingsEmailSent);
                    if (mounted) setState(() {});
                  } catch (e) {
                    _showSnack(t.commonErrorGeneric);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final t = AppLocalizations.of(context)!;
    // Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.settingsLogoutConfirmTitle),
        content: Text(t.settingsLogoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t.settingsLogoutButton,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.auth.signOut();
        if (mounted) {
          // Remove all routes and go to Login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.settingsLogoutFailed(e.toString()))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bgColor = theme.scaffoldBackgroundColor;
    final surface = colors.surface;
    final border = theme.dividerColor;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final textMuted = colors.onSurface.withOpacity(0.5);
    final primary = colors.primary;
    final dangerColor = colors.error;
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? "-";
    final isEmailVerified = user?.emailConfirmedAt != null;

    // Determine Logic for Verification Tile
    Widget trailingWidget;
    String subtitleText;

    switch (widget.profile.verificationStatus) {
      case AccountStatus.verified_catholic:
      case AccountStatus.verified_pastoral:
        subtitleText = t.settingsVerificationStatus(t.profileVerified);
        trailingWidget = Icon(Icons.verified, color: primary);
        break;
      case AccountStatus.pending:
        subtitleText = t.settingsVerificationStatus(t.profileTrustPending);
        trailingWidget = Text(
          t.settingsVerificationPendingShort,
          style: GoogleFonts.outfit(
            color: colors.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        );
        break;
      case AccountStatus.rejected:
        subtitleText = t.settingsVerificationStatus(t.profileTrustUnverified);
        trailingWidget = Icon(Icons.chevron_right, color: textMuted);
        break;
      default:
        subtitleText = t.settingsVerificationStatus(t.profileNotVerified);
        trailingWidget = Icon(Icons.chevron_right, color: textMuted);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          t.settingsTitle,
          style: GoogleFonts.outfit(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: t.commonBack,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // SECTION: AKUN
            _buildSectionHeader(t.settingsAccountSection),
            _buildListTile(
              icon: Icons.edit_outlined,
              title: t.profileEdit,
              onTap: () async {
               final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
                // If edit page returns true (updated), we might want to pop or standardly reload?
                // But SettingsPage receives 'profile' from parent. 
                // Ideally parent should refresh, or we just rely on parent's state. 
                // For now just navigate.
                if (result == true && mounted) {
                  Navigator.pop(context, true); // Pass specific signal if needed
                }
              },
            ),
            _buildListTile(
              icon: Icons.verified_user_outlined,
              title: t.settingsVerifyAccount,
              subtitle: subtitleText,
              trailing: trailingWidget,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerificationPage(profile: widget.profile),
                  ),
                );
              },
            ),

            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: border.withOpacity(0.8)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: textSecondary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(Icons.email_outlined, color: textSecondary, size: 20),
                ),
                title: Text(
                  t.emailLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                subtitle: Text(
                  "$email • ${isEmailVerified ? t.profileVerified : t.profileNotVerified}",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                trailing: _buildStatusChip(verified: isEmailVerified),
                onTap: () {
                  if (user == null) {
                    _showSnack(t.settingsUserNotFound);
                    return;
                  }
                  _showEmailActionsSheet(
                    user: user,
                    isVerified: isEmailVerified,
                  );
                },
              ),
            ),
            _buildListTile(
              icon: Icons.security_outlined,
              title: t.settingsSecurityTitle,
              subtitle: t.settingsAccountSecuritySubtitle,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountSecurityPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // SECTION: KEAMANAN
            _buildSectionHeader(t.settingsSecuritySection),
            _buildListTile(
              icon: Icons.lock_outline,
              title: t.settingsChangePassword,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                );
              },
            ),
            _buildListTile(
              icon: Icons.block_outlined,
              title: t.settingsBlockedUsers,
              onTap: () {
                // Navigate to Blocked Users
              },
            ),

            const SizedBox(height: 24),

            // SECTION: UMUM
            _buildSectionHeader(t.settingsGeneralSection),
            _buildListTile(
              icon: Icons.language_outlined,
              title: t.settingsLanguageTitle,
              subtitle: t.settingsLanguageSubtitle,
              onTap: () => _showLanguageSheet(localeProvider),
              trailing: Text(
                localeProvider.localeCode == 'id'
                    ? t.settingsLanguageIndonesian
                    : localeProvider.localeCode == 'en'
                        ? t.settingsLanguageEnglish
                        : t.settingsLanguageSystem,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildSwitchTile(
              icon: Icons.analytics_outlined,
              title: t.settingsAnalyticsTitle,
              subtitle: t.settingsAnalyticsSubtitle,
              value: _analyticsEnabled,
              onChanged: _toggleAnalytics,
            ),
            _buildListTile(
              icon: Icons.info_outline,
              title: t.settingsAbout,
              onTap: () {},
            ),
            _buildListTile(
              icon: Icons.help_outline,
              title: t.settingsHelp,
              onTap: () {},
            ),

            const SizedBox(height: 40),

            // SECTION: LOGOUT
            Container(
              color: surface,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dangerColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, color: dangerColor, size: 20),
                ),
                title: Text(
                  t.settingsLogout,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dangerColor,
                  ),
                ),
                onTap: _handleLogout,
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                t.settingsVersion("1.0.0"),
                style: GoogleFonts.outfit(color: textMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    final textMuted = colors.onSurface.withOpacity(0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textMuted,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = colors.surface;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final textMuted = colors.onSurface.withOpacity(0.5);
    final border = theme.dividerColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withOpacity(0.8)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textSecondary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: textSecondary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: textSecondary,
                ),
              )
            : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: textMuted),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = colors.surface;
    final textPrimary = colors.onSurface;
    final textSecondary = colors.onSurface.withOpacity(0.7);
    final border = theme.dividerColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border.withOpacity(0.8)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: textSecondary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: textSecondary, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: textSecondary,
                ),
              )
            : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}
