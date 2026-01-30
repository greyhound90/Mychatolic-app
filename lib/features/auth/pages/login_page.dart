import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/pages/main_page.dart';
import 'package:mychatolic_app/features/auth/pages/register_page.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/auth/pages/forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ---------------------------------------------------------------------------
  // 1. CONSTATNS
  // ---------------------------------------------------------------------------
  static const Color kPrimaryColor = Color(0xFF0088CC);
  static const Color kSecondaryColor = Color(0xFF007AB8);
  static const Color kBackgroundColor = Color(0xFFFFFFFF);
  static const Color kInputFillColor = Color(0xFFF5F5F5);
  static const Color kErrorColor = Color(0xFFE74C3C); // Added specifically as requested

  // ---------------------------------------------------------------------------
  // 2. CONTROLLERS & STATE
  // ---------------------------------------------------------------------------
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
        backgroundColor: kErrorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBannedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Akses Ditolak", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text("Akun Anda telah dinonaktifkan/ditangguhkan. Harap hubungi admin paroki untuk info lebih lanjut.", style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Tutup", style: GoogleFonts.outfit(color: kPrimaryColor)),
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
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // HEADER
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.church_rounded,
                    size: 40,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Selamat Datang Kembali",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Masuk untuk melanjutkan perjalanan imanmu",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                // FORM
                _buildTextField(
                  label: "Email",
                  hint: "Masukkan email",
                  controller: _emailController,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: "Password",
                  hint: "Masukkan password",
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  isObscure: _obscurePassword,
                  toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                ),

                // Forgot Password
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
                        color: kPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimaryColor, kSecondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "MASUK",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // FOOTER
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Belum punya akun? ",
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: Text(
                        "DAFTAR",
                        style: GoogleFonts.outfit(
                          color: kPrimaryColor,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(
             color: Colors.black87,
             fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: kInputFillColor,
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.black26),
            prefixIcon: Icon(icon, color: Colors.grey),
            suffixIcon: toggleObscure != null
                ? IconButton(
                    icon: Icon(
                      isObscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: toggleObscure,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
