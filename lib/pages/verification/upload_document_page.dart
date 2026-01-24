import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class UploadDocumentPage extends StatefulWidget {
  const UploadDocumentPage({super.key});

  @override
  State<UploadDocumentPage> createState() => _UploadDocumentPageState();
}

class _UploadDocumentPageState extends State<UploadDocumentPage> {
  final _supabase = Supabase.instance.client;
  File? _baptismImage;
  File? _confirmationImage;
  bool _isUploading = false;

  // Theme Colors
  static const Color bgDarkPurple = Color(0xFF1E1235);
  static const Color cardPurple = Color(0xFF352453);
  static const Color accentOrange = Color(0xFFFF9F1C);

  Future<void> _pickImage(bool isBaptism) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        if (isBaptism) {
          _baptismImage = File(pickedFile.path);
        } else {
          _confirmationImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<String?> _uploadFile(File file, String docType) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final String fileExt = file.path.split('.').last;
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String fileName = '${user.id}/${docType}_$timestamp.$fileExt';

    try {
      await _supabase.storage
          .from('verification_docs')
          .upload(
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

  Future<void> _submitVerification() async {
    if (_baptismImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon upload Foto Surat Baptis")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Upload Files
        final String? baptismUrl = await _uploadFile(_baptismImage!, 'baptism');
        String? chrismUrl;
        if (_confirmationImage != null) {
          chrismUrl = await _uploadFile(_confirmationImage!, 'chrism');
        }

        // 2. Prepare Update Data
        final updates = {
          'verification_status': 'pending',
          'verification_doc_url': baptismUrl,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (chrismUrl != null) {
          updates['chrism_cert_url'] = chrismUrl;
        }

        // 3. Update Profile
        await _supabase.from('profiles').update(updates).eq('id', user.id);

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardPurple,
              title: const Text(
                "Berhasil Terkirim!",
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                "Dokumen Anda sedang ditinjau oleh tim kami. Status Anda kini 'Pending'.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close Dialog
                    Navigator.pop(
                      context,
                      true,
                    ); // Return to Profile with success flag
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: accentOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDarkPurple,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Verifikasi Iman",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Upload Dokumen Sakramen",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Untuk mendapatkan status Verified, mohon lampirkan bukti surat baptis Katolik Anda.",
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // UPLOAD BOX 1: BAPTIS
            _buildUploadBox(
              label: "Foto Surat Baptis (Wajib)",
              file: _baptismImage,
              onTap: () => _pickImage(true),
            ),

            const SizedBox(height: 16),

            // UPLOAD BOX 2: KRISMA
            _buildUploadBox(
              label: "Foto Surat Krisma (Opsional)",
              file: _confirmationImage,
              onTap: () => _pickImage(false),
            ),

            const SizedBox(height: 40),

            // SUBMIT BUTTON
            ElevatedButton(
              onPressed: _isUploading ? null : _submitVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: accentOrange.withValues(alpha: 0.5),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "KIRIM VERIFIKASI",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox({
    required String label,
    required File? file,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardPurple,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white24,
                style: BorderStyle.solid,
              ),
              image: file != null
                  ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                  : null,
            ),
            child: file == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        color: accentOrange.withValues(alpha: 0.8),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Ketuk untuk Upload",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black26,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.greenAccent,
                      size: 40,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
