import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/profile.dart';

class VerificationPage extends StatefulWidget {
  final Profile profile; // Pass the current profile
  const VerificationPage({super.key, required this.profile});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  // Files State
  File? _identityFile;
  File? _baptismFile;
  File? _chrismFile;
  File? _assignmentFile; // For Clergy

  bool _isSubmitting = false;

  // ---------------------------------------------------------------------------
  // LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(String type, ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Compress slightly
        maxWidth: 1024,   // Limit size
      );
      
      if (picked != null) {
        setState(() {
          if (type == 'identity') _identityFile = File(picked.path);
          if (type == 'baptism') _baptismFile = File(picked.path);
          if (type == 'chrism') _chrismFile = File(picked.path);
          if (type == 'assignment') _assignmentFile = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showSnack("Gagal mengambil gambar: $e", isError: true);
    }
  }

  void _removeImage(String type) {
    setState(() {
      if (type == 'identity') _identityFile = null;
      if (type == 'baptism') _baptismFile = null;
      if (type == 'chrism') _chrismFile = null;
      if (type == 'assignment') _assignmentFile = null;
    });
  }

  Future<String?> _uploadFile(File file, String userId, String prefix) async {
    try {
      final String fileExt = file.path.split('.').last;
      final String fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final String fullPath = '$userId/$fileName';

      await _supabase.storage
          .from('verification_docs')
          .upload(fullPath, file);

      final String publicUrl = _supabase.storage
          .from('verification_docs')
          .getPublicUrl(fullPath);
          
      return publicUrl;
    } catch (e) {
      debugPrint("Upload failed for $prefix: $e");
      return null;
    }
  }

  Future<void> _submitRequiredDocuments() async {
    setState(() => _isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "User tidak terautentikasi.";

      final Map<String, dynamic> updates = {
         'verification_status': 'pending',
      };

      // 1. UMAT Logic
      if (widget.profile.role == UserRole.umat) {
         if (_identityFile == null || _baptismFile == null) {
            throw "Mohon lengkapi dokumen wajib.";
         }

         // Upload parallel
         final results = await Future.wait([
            _uploadFile(_identityFile!, user.id, 'ktp'),
            _uploadFile(_baptismFile!, user.id, 'baptis'),
            _chrismFile != null ? _uploadFile(_chrismFile!, user.id, 'krisma') : Future.value(null),
         ]);

         if (results[0] == null || results[1] == null) throw "Gagal upload dokumen wajib.";

         updates['verification_document_url'] = results[0];
         updates['baptism_document_url'] = results[1];
         if (results[2] != null) updates['chrism_document_url'] = results[2];
      }
      
      // 2. CLERGY Logic
      else if (widget.profile.isClergy) {
        if (_assignmentFile == null) throw "Surat tugas wajib diupload.";
        
        final url = await _uploadFile(_assignmentFile!, user.id, 'surat_tugas');
        if (url == null) throw "Gagal upload surat tugas.";
        
        updates['assignment_letter_url'] = url;
      }

      await _supabase.from('profiles').update(updates).eq('id', user.id);

      if (mounted) {
        _showSuccessDialog();
      }

    } catch (e) {
      debugPrint("Error submitting verification: $e");
      if (mounted) {
        _showSnack("Gagal mengirim dokumen: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Dokumen Terkirim", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          "Dokumen Anda telah kami terima. Mohon tunggu verifikasi dari admin paroki.",
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Back to Profile
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILDER
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final role = widget.profile.role;
    final isClergy = widget.profile.isClergy;
    final isCatechumen = role == UserRole.katekumen;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Lengkapi Dokumen",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER INFO
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCatechumen ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCatechumen ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5)
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCatechumen ? Icons.check_circle_outline : Icons.info_outline, 
                    color: isCatechumen ? Colors.green : Colors.orange
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCatechumen
                          ? "Halo! Sebagai Katekumen, Anda tidak perlu mengunggah dokumen verifikasi saat ini. Silakan lanjutkan pembelajaran iman Anda."
                          : "Upload dokumen resmi untuk verifikasi akun Anda. Data aman dan hanya dilihat oleh Admin.",
                      style: GoogleFonts.outfit(
                        color: isCatechumen ? Colors.green[900] : Colors.orange[900], 
                        fontSize: 13
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // CASE 1: KATEKUMEN -> Show Nothing / Return Button
            // -----------------------------------------------------------------
            if (isCatechumen) ...[
               const SizedBox(height: 20),
               SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Kembali ke Profil", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                ),
               ),
            ]

            // -----------------------------------------------------------------
            // CASE 2: UMAT -> 3 SLOTS
            // -----------------------------------------------------------------
            else if (role == UserRole.umat) ...[
              _buildUploadCard(
                label: "KTP / SIM / Kartu Pelajar (Wajib)",
                file: _identityFile,
                type: 'identity',
              ),
              const SizedBox(height: 20),
              _buildUploadCard(
                label: "Surat Baptis (Wajib)",
                file: _baptismFile,
                type: 'baptism',
              ),
              const SizedBox(height: 20),
              _buildUploadCard(
                label: "Surat Krisma (Opsional)",
                file: _chrismFile,
                type: 'chrism',
              ),
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _identityFile == null || _baptismFile == null) 
                      ? null 
                      : _submitRequiredDocuments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "AJUKAN VERIFIKASI",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                          ),
                        ),
                ),
              ),
            ]

            // -----------------------------------------------------------------
            // CASE 3: CLERGY -> 1 SLOT
            // -----------------------------------------------------------------
            else if (isClergy) ...[
              _buildUploadCard(
                label: "Surat Tugas / Penugasan Resmi (Wajib)",
                file: _assignmentFile,
                type: 'assignment',
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _assignmentFile == null) 
                      ? null 
                      : _submitRequiredDocuments,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "AJUKAN VERIFIKASI",
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white
                          ),
                        ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String label,
    required File? file,
    required String type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              // Preview Area
              GestureDetector(
                onTap: file == null ? () => _showPickerOptions(type) : null,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    color: Colors.grey[50],
                    image: file != null
                        ? DecorationImage(
                            image: FileImage(file),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: file == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.blue[300]),
                            const SizedBox(height: 8),
                            Text(
                              "Tap untuk upload foto",
                              style: GoogleFonts.outfit(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              
              // Actions (Only show if file exists)
              if (file != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showPickerOptions(type),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Ganti"),
                      ),
                      TextButton.icon(
                        onPressed: () => _removeImage(type),
                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                        label: const Text("Hapus", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Ambil Foto Dari",
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("Kamera"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(type, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("Galeri"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(type, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
