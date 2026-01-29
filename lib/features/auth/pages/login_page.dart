import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/auth/pages/register_page.dart';
import 'package:mychatolic_app/pages/main_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State Variables
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // 1. Basic Empty Validation
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email dan Password tidak boleh kosong"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Strict Regex Validation
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Format email tidak valid"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user != null) {
        // GHOST BUSTER: Check if email is verified
        // Note: For newer Supabase versions, 'email_confirmed_at' is used.
        if (user.emailConfirmedAt == null) {
          // USER IS A GHOST (Unverified) -> KICK THEM OUT
          await Supabase.instance.client.auth.signOut();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text("Email belum diverifikasi. Silakan cek inbox/spam Anda."),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // USER IS CLEAN -> PROCEED
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = e.message;
      // Humanize Supabase Auth Errors (Indonesian)
      if (message.toLowerCase().contains("invalid login credentials")) {
        message = "Email atau kata sandi salah.";
      } else if (message.toLowerCase().contains("email not confirmed")) {
        message = "Email belum diverifikasi. Cek inbox Anda.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;

      String message = "Terjadi kesalahan sistem.";
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains("socketexception") ||
          errorStr.contains("network")) {
        message = "Periksa koneksi internet Anda.";
      } else if (errorStr.contains("timeout")) {
        message = "Koneksi waktu habis. Coba lagi.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal login: ${e.toString()}"),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final secondaryColor = theme.colorScheme.secondary;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final borderColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Premium Gradient Background
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // LOGO SECTION
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.2),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.church_rounded,
                            size: 64,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "MyCatholic",
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Selamat Datang Kembali",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // INPUT FORMS
                  Text(
                    "EMAIL",
                    style: GoogleFonts.outfit(
                      color: metaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _buildInputDecoration(
                      "Masukkan email anda",
                      Icons.email_outlined,
                      theme,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "PASSWORD",
                    style: GoogleFonts.outfit(
                      color: metaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration:
                        _buildInputDecoration(
                          "Masukkan password",
                          Icons.lock_outline,
                          theme,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: metaColor,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        "Lupa Password?",
                        style: GoogleFonts.outfit(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
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
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "MASUK",
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

                  const SizedBox(height: 40),

                  // DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: borderColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Atau masuk dengan",
                          style: GoogleFonts.outfit(
                            color: metaColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: borderColor)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // SOCIALS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(Icons.g_mobiledata_rounded, theme),
                      const SizedBox(width: 16),
                      _buildSocialButton(Icons.apple, theme),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // REGISTER LINK
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Belum punya akun? ",
                        style: GoogleFonts.outfit(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterPage(),
                          ),
                        ),
                        child: Text(
                          "DAFTAR",
                          style: GoogleFonts.outfit(
                            color: primaryColor,
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
    );
  }

  Widget _buildSocialButton(IconData icon, ThemeData theme) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Center(
            child: Icon(
              icon,
              color: theme.textTheme.bodyLarge?.color,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String hint,
    IconData prefixIcon,
    ThemeData theme,
  ) {
    return InputDecoration(
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
        color: (theme.textTheme.bodySmall?.color ?? Colors.grey).withValues(
          alpha: 0.5,
        ),
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: theme.textTheme.bodySmall?.color,
        size: 20,
      ),
    );
  }
}
