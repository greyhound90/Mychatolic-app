
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/verification/pages/verification_page.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    // Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Keluar Akun"),
        content: const Text("Apakah Anda yakin ingin keluar dari aplikasi?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Keluar",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
       // Perform Sign Out
       try {
         await Supabase.instance.client.auth.signOut();
         if (context.mounted) {
            // Remove all routes and go to Login
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
         }
       } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Gagal keluar: $e")),
            );
          }
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F5F5);
    const primaryColor = Color(0xFF0088CC);
    const dangerColor = Color(0xFFE74C3C);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Pengaturan",
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            // SECTION: AKUN
            _buildSectionHeader("AKUN"),
            _buildListTile(
              icon: Icons.edit_outlined,
              title: "Edit Profil",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
              },
            ),
            _buildListTile(
              icon: Icons.verified_user_outlined,
              title: "Status Verifikasi",
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "Unverified",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationPage()),
                );
              },
            ),

            const SizedBox(height: 24),

            // SECTION: KEAMANAN
            _buildSectionHeader("KEAMANAN"),
            _buildListTile(
              icon: Icons.lock_outline,
              title: "Ubah Kata Sandi",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Fitur Ubah Kata Sandi (Coming Soon)")),
                );
              },
            ),
            _buildListTile(
              icon: Icons.block_outlined,
              title: "Pengguna yang Diblokir",
              onTap: () {
                // Navigate to Blocked Users
              },
            ),

            const SizedBox(height: 24),

            // SECTION: UMUM
            _buildSectionHeader("UMUM"),
            _buildListTile(
              icon: Icons.info_outline,
              title: "Tentang Aplikasi",
              onTap: () {},
            ),
            _buildListTile(
              icon: Icons.help_outline,
              title: "Bantuan & Dukungan",
              onTap: () {},
            ),

            const SizedBox(height: 40),

            // SECTION: LOGOUT
            Container(
              color: Colors.white,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: dangerColor, size: 20),
                ),
                title: Text(
                  "Keluar",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: dangerColor,
                  ),
                ),
                onTap: () => _handleLogout(context),
              ),
            ),
            
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Versi 1.0.0",
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1), // Divider effect
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0088CC), size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
