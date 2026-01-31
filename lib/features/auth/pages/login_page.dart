import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:mychatolic_app/pages/main_page.dart';
import 'package:mychatolic_app/features/auth/pages/register_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/auth/pages/forgot_password_page.dart';
import 'package:mychatolic_app/core/widgets/app_text_field.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';
import 'package:mychatolic_app/core/ui/app_snackbar.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_events.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ---------------------------------------------------------------------------
  // 2. CONTROLLERS & STATE
  // ---------------------------------------------------------------------------
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) HapticFeedback.lightImpact();
      if (mounted) setState(() {});
    });
    _passwordFocus.addListener(() {
      if (_passwordFocus.hasFocus) HapticFeedback.lightImpact();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 3. LOGIC (EMPTY FOR NOW)
  // ---------------------------------------------------------------------------
  Future<void> _handleLogin() async {
    final t = AppLocalizations.of(context)!;
    if (mounted) {
      setState(() => _errorMessage = null);
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validation
    if (email.isEmpty || !email.contains('@')) {
      _showError(t.emailInvalidFormat);
      return;
    }
    if (password.isEmpty) {
      _showError(t.loginPasswordRequired);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Supabase Login
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;

      if (user == null) {
        throw const AuthException("Login gagal, silahkan coba lagi.");
      }

      // 3. SECURITY CHECKS (CRITICAL)
      // Checks MUST be ordered: Email Verified -> Profile Exists -> Status Banned

      // TAHAP A: Email Check
      if (user.emailConfirmedAt == null) {
         await Supabase.instance.client.auth.signOut();
         if (mounted) {
           _showError(t.loginEmailUnverified);
         }
         AnalyticsService.instance.track(
           AnalyticsEvents.authLoginFailed,
           props: const {'reason': 'email_unverified'},
         );
         return;
      }

      // TAHAP B: Profile Check (Anti-Zombie)
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, verification_status, role, profile_filled')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          _showError(t.loginProfileCorrupt);
        }
        return;
      }

      // TAHAP C: Status Check
      final String status = profile['verification_status'] ?? 'pending';
      if (status == 'rejected' || status == 'banned') {
         await Supabase.instance.client.auth.signOut();
         if (mounted) {
           _showBannedDialog();
         }
         AnalyticsService.instance.track(
           AnalyticsEvents.authLoginFailed,
           props: const {'reason': 'banned'},
         );
         return;
      }

      // TAHAP D: Profile Completion Check
      final bool profileFilled = profile['profile_filled'] == true;
      if (!profileFilled) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EditProfilePage()),
          );
        }
        return;
      }
      
      // 4. Success -> Navigation
      if (mounted) {
        AnalyticsService.instance.track(AnalyticsEvents.authLoginSuccess);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }

    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains("invalid login credentials")) {
        msg = t.loginInvalidCredentials;
        AnalyticsService.instance.track(
          AnalyticsEvents.authLoginFailed,
          props: const {'reason': 'invalid_credentials'},
        );
      } else {
        AnalyticsService.instance.track(
          AnalyticsEvents.authLoginFailed,
          props: const {'reason': 'auth_error'},
        );
      }
      if (mounted) _showError(msg);
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("SocketException")) {
           _showError(t.loginNetworkError);
           AnalyticsService.instance.track(
             AnalyticsEvents.authLoginFailed,
             props: const {'reason': 'network'},
           );
        } else {
           _showError(t.loginUnknownError(e.toString()));
           AnalyticsService.instance.track(
             AnalyticsEvents.authLoginFailed,
             props: const {'reason': 'unknown'},
           );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
    AppSnackBar.showError(context, message);
  }

  void _showBannedDialog() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          t.loginBannedTitle,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        content: Text(
          t.loginBannedMessage,
          style: GoogleFonts.outfit(color: AppColors.textBody),
        ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.commonClose, style: GoogleFonts.outfit(color: AppColors.primary)),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final emailText = _emailController.text.trim();
    final showEmailHelper = emailText.isNotEmpty && !emailText.contains('@');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: _AuthBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AnimatedEntrance(
                        delay: const Duration(milliseconds: 60),
                        child: Column(
                          children: [
                            Hero(
                              tag: 'auth-logo',
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 86,
                                    height: 86,
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.18),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.church_rounded,
                                      size: 42,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.2),
                                            blurRadius: 14,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        t.appName,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              t.loginTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.loginSubtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _AnimatedEntrance(
                        delay: const Duration(milliseconds: 120),
                        child: _AuthCard(
                          child: Column(
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
                              _buildTextField(
                                label: t.emailLabel,
                                hint: t.emailHint,
                                controller: _emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                focusNode: _emailFocus,
                                helperText: showEmailHelper
                                    ? t.emailInvalidFormat
                                    : null,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 18),
                              _buildTextField(
                                label: t.passwordLabel,
                                hint: t.passwordHint,
                                controller: _passwordController,
                                icon: Icons.lock_outline,
                                isObscure: _obscurePassword,
                                toggleObscure: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                                focusNode: _passwordFocus,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    t.loginForgotPassword,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeOut,
                                  child: AppPrimaryButton(
                                    key: ValueKey(_isLoading),
                                    label: _isLoading ? t.loginProcessing : t.loginButton,
                                    isLoading: _isLoading,
                                    onPressed:
                                        _isLoading ? null : _handleLogin,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Divider(color: AppColors.border, thickness: 0.6),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 2,
                                children: [
                                  Text(
                                    t.loginNoAccount,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.textBody,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const RegisterPage()),
                                      );
                                    },
                                    child: Text(
                                      t.loginGoToRegister,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. HELPER COMPONENTS
  // ---------------------------------------------------------------------------
  
  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isObscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    String? helperText,
    ValueChanged<String>? onChanged,
  }) {
    final isFocused = focusNode?.hasFocus ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: label,
          hint: hint,
          controller: controller,
          icon: icon,
          isObscure: isObscure,
          onToggleObscure: toggleObscure,
          keyboardType: keyboardType,
          focusNode: focusNode,
          onChanged: onChanged,
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
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
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
          top: -80,
          right: -40,
          child: _Blob(
            size: 180,
            color: AppColors.primary.withOpacity(0.10),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _Blob(
            size: 160,
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

class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedEntrance({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(curved);
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
