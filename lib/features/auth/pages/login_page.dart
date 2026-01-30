import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/pages/main_page.dart';
import 'package:mychatolic_app/features/auth/pages/register_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/auth/pages/forgot_password_page.dart';

const Color _kBg = Color(0xFF121212);
const Color _kSurface = Color(0xFF1C1C1C);
const Color _kBorder = Color(0xFF2A2A2A);
const Color _kText = Color(0xFFFFFFFF);
const Color _kTextSecondary = Color(0xFFBBBBBB);
const Color _kTextMuted = Color(0xFF9E9E9E);
const Color _kPrimary = Color(0xFF0088CC);
const Color _kPrimaryDark = Color(0xFF007AB8);
const Color _kError = Color(0xFFE74C3C);

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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Validation
    if (email.isEmpty || !email.contains('@')) {
      _showError("Format email tidak valid");
      return;
    }
    if (password.isEmpty) {
      _showError("Masukkan password anda");
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
           _showError("Email belum diverifikasi. Cek inbox Anda.");
         }
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
          _showError("Data profil korup. Silakan daftar ulang.");
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }

    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains("invalid login credentials")) {
        msg = "Email atau sandi salah.";
      }
      if (mounted) _showError(msg);
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("SocketException")) {
           _showError("Periksa koneksi internet.");
        } else {
           _showError("Terjadi kesalahan: $e");
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: _kError,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBannedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kSurface,
        title: Text(
          "Akses Ditolak",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: _kText,
          ),
        ),
        content: Text(
          "Akun Anda telah dinonaktifkan/ditangguhkan. Harap hubungi admin paroki untuk info lebih lanjut.",
          style: GoogleFonts.outfit(color: _kTextSecondary),
        ),
          actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Tutup", style: GoogleFonts.outfit(color: _kPrimary)),
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
    final emailText = _emailController.text.trim();
    final showEmailHelper = emailText.isNotEmpty && !emailText.contains('@');

    return Scaffold(
      backgroundColor: _kBg,
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
                                      color: _kSurface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _kBorder,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _kPrimary.withOpacity(0.25),
                                          blurRadius: 26,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.church_rounded,
                                      size: 42,
                                      color: _kPrimary,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _kPrimary,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kPrimary.withOpacity(0.25),
                                            blurRadius: 14,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        "MyChatolic",
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
                              "Selamat Datang Kembali",
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _kText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Masuk untuk melanjutkan perjalanan imanmu",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: _kTextSecondary,
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
                              _buildTextField(
                                label: "Email",
                                hint: "Masukkan email",
                                controller: _emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                focusNode: _emailFocus,
                                helperText: showEmailHelper
                                    ? "Format email belum valid"
                                    : null,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 18),
                              _buildTextField(
                                label: "Password",
                                hint: "Masukkan password",
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
                                    "Lupa Password?",
                                    style: GoogleFonts.outfit(
                                      color: _kPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.resolveWith(
                                      (states) => states.contains(MaterialState.disabled)
                                          ? _kPrimary.withOpacity(0.6)
                                          : _kPrimary,
                                    ),
                                    shape: MaterialStateProperty.all(
                                      const StadiumBorder(),
                                    ),
                                    elevation: MaterialStateProperty.all(0),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.96,
                                            end: 1.0,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _isLoading
                                        ? Row(
                                            key: const ValueKey('loading'),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                          Colors.white),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                "Memproses...",
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            "MASUK",
                                            key: const ValueKey('label'),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Divider(color: _kBorder, thickness: 0.6),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Belum punya akun? ",
                                    style: GoogleFonts.outfit(
                                      color: _kTextSecondary,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const RegisterPage()),
                                      );
                                    },
                                    child: Text(
                                      "DAFTAR",
                                      style: GoogleFonts.outfit(
                                        color: _kPrimary,
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
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: _kTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? _kPrimary : _kBorder,
              width: 1.2,
            ),
            boxShadow: [
              if (isFocused)
                BoxShadow(
                  color: _kPrimary.withOpacity(0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscure,
            keyboardType: keyboardType,
            focusNode: focusNode,
            onChanged: onChanged,
            style: GoogleFonts.outfit(
              color: _kText,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: _kTextMuted),
              prefixIcon: Icon(
                icon,
                color: isFocused ? _kPrimary : _kTextSecondary,
              ),
              suffixIcon: toggleObscure != null
                  ? IconButton(
                      icon: Icon(
                        isObscure ? Icons.visibility_off : Icons.visibility,
                        color: _kTextSecondary,
                      ),
                      onPressed: toggleObscure,
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: _kError,
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
                _kBg,
                _kSurface,
                _kBg,
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -40,
          child: _Blob(
            size: 180,
            color: _kPrimary.withOpacity(0.12),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: _Blob(
            size: 160,
            color: _kPrimaryDark.withOpacity(0.10),
          ),
        ),
        Positioned(
          top: 140,
          left: 20,
          child: _Blob(
            size: 90,
            color: _kPrimary.withOpacity(0.08),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
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
