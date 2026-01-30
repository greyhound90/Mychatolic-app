import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/profile/pages/edit_profile_page.dart';
import 'package:mychatolic_app/features/auth/pages/verification_page.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/models/profile.dart';
import 'package:mychatolic_app/features/settings/pages/change_password_page.dart';

class SettingsPage extends StatefulWidget {
  final Profile profile;

  const SettingsPage({super.key, required this.profile});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
    return result?.isEmpty == true ? null : result;
  }

  Widget _buildStatusChip({required bool verified}) {
    final color = verified ? Colors.green : Colors.orange;
    final label = verified ? "Verified" : "Unverified";
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isVerified)
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text("Kirim ulang verifikasi email"),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      if (user.email == null || user.email!.isEmpty) {
                        _showSnack("Email tidak tersedia");
                        return;
                      }
                      await _supabase.auth.resend(
                        type: OtpType.signup,
                        email: user.email!,
                      );
                      _showSnack("Email verifikasi dikirim");
                    } catch (e) {
                      _showSnack("Gagal kirim verifikasi: $e");
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text("Ganti email"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newEmail = await _showTextInputDialog(
                    title: "Ganti Email",
                    hint: "nama@email.com",
                    keyboardType: TextInputType.emailAddress,
                  );
                  if (newEmail == null) return;
                  if (!_isValidEmail(newEmail)) {
                    _showSnack("Format email tidak valid");
                    return;
                  }
                  try {
                    await _supabase.auth.updateUser(
                      UserAttributes(email: newEmail),
                    );
                    _showSnack("Cek email untuk konfirmasi perubahan");
                    if (mounted) setState(() {});
                  } catch (e) {
                    _showSnack("Gagal ganti email: $e");
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
            SnackBar(content: Text("Gagal keluar: $e")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF5F5F5);
    const dangerColor = Color(0xFFE74C3C);
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? "-";
    final isEmailVerified = user?.emailConfirmedAt != null;

    // Determine Logic for Verification Tile
    String statusLabel;
    Widget trailingWidget;
    String subtitleText;

    switch (widget.profile.verificationStatus) {
      case AccountStatus.verified_catholic:
      case AccountStatus.verified_pastoral:
        statusLabel = "Terverifikasi";
        subtitleText = "Status: Terverifikasi";
        trailingWidget = const Icon(Icons.verified, color: Colors.blue);
        break;
      case AccountStatus.pending:
        statusLabel = "Menunggu";
        subtitleText = "Status: Menunggu Verifikasi";
        trailingWidget = Text(
          "Menunggu",
          style: GoogleFonts.outfit(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        );
        break;
      case AccountStatus.rejected:
        statusLabel = "Ditolak";
        subtitleText = "Status: Verifikasi Ditolak";
        trailingWidget = const Icon(Icons.chevron_right, color: Colors.grey);
        break;
      default:
        statusLabel = "Belum";
        subtitleText = "Status: Belum Terverifikasi";
        trailingWidget = const Icon(Icons.chevron_right, color: Colors.grey);
    }

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
              title: "Verifikasi Akun",
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
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.email_outlined, color: Color(0xFF0088CC), size: 20),
                ),
                title: Text(
                  "Email",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  "$email • ${isEmailVerified ? "Terverifikasi" : "Belum terverifikasi"}",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: _buildStatusChip(verified: isEmailVerified),
                onTap: () {
                  if (user == null) {
                    _showSnack("User tidak ditemukan");
                    return;
                  }
                  _showEmailActionsSheet(
                    user: user,
                    isVerified: isEmailVerified,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // SECTION: KEAMANAN
            _buildSectionHeader("KEAMANAN"),
            _buildListTile(
              icon: Icons.lock_outline,
              title: "Ubah Kata Sandi",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
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
                    color: dangerColor.withOpacity(0.1),
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
                onTap: _handleLogout,
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
    String? subtitle,
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
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              )
            : null,
        trailing:
            trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
