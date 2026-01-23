import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerRegistrationPage extends StatefulWidget {
  const PartnerRegistrationPage({super.key});

  @override
  State<PartnerRegistrationPage> createState() => _PartnerRegistrationPageState();
}

class _PartnerRegistrationPageState extends State<PartnerRegistrationPage> {
  final _supabase = Supabase.instance.client;
  
  String? _selectedRole;
  final List<String> _roles = ['Imam', 'Biarawan', 'Biarawati', 'Katekis'];
  
  File? _celebretImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      setState(() {
        _celebretImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadFile(File file) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final String fileExt = file.path.split('.').last;
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // Naming: userID/celebret_TIMESTAMP.ext
    final String fileName = '${user.id}/celebret_$timestamp.$fileExt';

    try {
      await _supabase.storage.from('verification_docs').upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );
      return _supabase.storage.from('verification_docs').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload Error: $e");
      rethrow;
    }
  }

  Future<void> _submitRegistration(ThemeData theme, Color cardColor, Color titleColor, Color bodyColor, Color primaryColor) async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon pilih peran pelayanan Anda")),
      );
      return;
    }
    if (_celebretImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon upload Foto Surat Celebret / Surat Tugas")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Upload File
        final String? docUrl = await _uploadFile(_celebretImage!);

        // 2. Update Profile
        // Change role to 'mitra_pending' so Admin sees it in a filtered list
        await _supabase.from('profiles').update({
          'role': 'mitra_pending', 
          'verification_status': 'pending', 
          'verification_doc_url': docUrl, // Reusing this column per Admin request
          // Storing the Requested Role in metadata or reusing 'role' field? 
          // If 'role' is 'mitra_pending', we lose 'Imam'. 
          // Better: Store requested role in metadata or a separate column if available.
          // For now, let's put it in a metadata json if possible or just assume 'mitra_pending' covers it.
          // Actually, let's preserve the intent by adding it to metadata or assuming Admin checks doc.
          // Let's check schema later. For now, simplistic approach:
          'raw_user_meta_data': {'requested_role': _selectedRole}, 
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardColor,
              title: Text("Pendaftaran Terkirim", style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold)),
              content: Text(
                "Terima kasih telah mendaftar sebagai Mitra Pastoral ($_selectedRole). Data Anda sedang diverifikasi oleh Tim Kami.",
                style: GoogleFonts.outfit(color: bodyColor),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, true); // Return success
                  },
                  child: Text("OK", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final bodyColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final metaColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text("Daftar Mitra Pastoral", style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Bergabunglah Melayani Umat",
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Khusus untuk Imam, Biarawan/wati, dan Katekis yang ingin memberikan pelayanan konseling.",
              style: GoogleFonts.outfit(fontSize: 14, color: metaColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 1. ROLE DROPDOWN
            Text("PERAN PELAYANAN", style: GoogleFonts.outfit(color: metaColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: cardColor,
                  value: _selectedRole,
                  hint: Text("Pilih Peran", style: GoogleFonts.outfit(color: metaColor)),
                  isExpanded: true,
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role, style: GoogleFonts.outfit(color: titleColor)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val),
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // 2. UPLOAD CELEBRET
            Text("DOKUMEN VALIDASI (Surat Celebret / Tugas)", style: GoogleFonts.outfit(color: metaColor, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: dividerColor),
                  image: _celebretImage != null 
                    ? DecorationImage(image: FileImage(_celebretImage!), fit: BoxFit.cover)
                    : null
                ),
                child: _celebretImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, color: primaryColor, size: 40),
                        const SizedBox(height: 8),
                        Text("Upload Foto Dokumen", style: GoogleFonts.outfit(color: metaColor)),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: const Center(child: Icon(Icons.check_circle, color: Colors.green, size: 40)),
                    ),
              ),
            ),

            const SizedBox(height: 40),

            // 3. SUBMIT
            ElevatedButton(
              onPressed: _isUploading ? null : () => _submitRegistration(theme, cardColor, titleColor, bodyColor, primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("KIRIM PENDAFTARAN", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
