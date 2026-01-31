import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/providers/theme_provider.dart';
import 'package:mychatolic_app/widgets/my_catholic_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Privacy State (Directly linked to Supabase is_age_visible, is_ethnicity_visible)
  bool _showAge = false;
  bool _showEthnicity = false;
  bool _isLoading = true;

  // Upload Quality State
  bool _isHighQualityUpload = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isHighQualityUpload = prefs.getBool('high_quality_upload') ?? false;
      });
    }
  }

  Future<void> _toggleUploadQuality(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_quality_upload', value);
    if (mounted) {
      setState(() {
        _isHighQualityUpload = value;
      });
    }
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('is_age_visible, is_ethnicity_visible')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _showAge = response['is_age_visible'] ?? false;
          _showEthnicity = response['is_ethnicity_visible'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error loading settings: $e");
    }
  }

  Future<void> _togglePrivacy(String key, bool value) async {
    // Optimistic Update
    setState(() {
      if (key == 'is_age_visible') _showAge = value;
      if (key == 'is_ethnicity_visible') _showEthnicity = value;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({key: value})
          .eq('id', userId);
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          if (key == 'is_age_visible') _showAge = !value;
          if (key == 'is_ethnicity_visible') _showEthnicity = !value;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengupdate privacy: $e")));
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs
        .clear(); // Clears all local prefs including theme if needed, but safe

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MyCatholicAppBar(title: "Pengaturan"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION: TAMPILAN
            _buildSectionTitle("Tampilan", context),
            const SizedBox(height: 8),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: themeProvider.themeMode,
                onChanged: (val) =>
                    themeProvider.setThemeMode(val ?? ThemeMode.system),
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text("Ikuti Sistem", style: GoogleFonts.outfit()),
                      value: ThemeMode.system,
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text("Mode Terang", style: GoogleFonts.outfit()),
                      value: ThemeMode.light,
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    RadioListTile<ThemeMode>(
                      title: Text("Mode Gelap", style: GoogleFonts.outfit()),
                      value: ThemeMode.dark,
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // SECTION: PRIVASI
            _buildSectionTitle("Privasi", context),
            const SizedBox(height: 8),
            Card(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        _buildSwitchTile(
                          "Tampilkan Usia di Profil",
                          "Izinkan publik melihat usia anda",
                          _showAge,
                          (val) => _togglePrivacy('is_age_visible', val),
                          context,
                        ),
                        const Divider(height: 1),
                        _buildSwitchTile(
                          "Tampilkan Suku di Profil",
                          "Izinkan publik melihat suku anda",
                          _showEthnicity,
                          (val) => _togglePrivacy('is_ethnicity_visible', val),
                          context,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 32),

            // SECTION: PENGGUNAAN DATA
            _buildSectionTitle("Penggunaan Data", context),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  "Upload Kualitas Tinggi (HD)",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Gambar lebih tajam, namun memakan lebih banyak kuota data.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                value: _isHighQualityUpload,
                onChanged: _toggleUploadQuality,
                activeThumbColor: Theme.of(context).primaryColor,
                activeTrackColor: Theme.of(
                  context,
                ).primaryColor.withOpacity(0.4),
              ),
            ),

            const SizedBox(height: 32),

            // SECTION: AKUN
            _buildSectionTitle("Akun", context),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red),
                ),
                title: Text(
                  "Logout / Keluar",
                  style: GoogleFonts.outfit(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: _logout,
              ),
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "Versi Aplikasi 1.0.0",
                style: GoogleFonts.outfit(
                  color: Theme.of(context).disabledColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET HELPERS

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        color: Theme.of(context).textTheme.bodySmall?.color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    BuildContext context,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        title,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).primaryColor,
      activeTrackColor: Theme.of(context).primaryColor.withOpacity(0.4),
    );
  }
}
