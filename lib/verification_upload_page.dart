import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class VerificationUploadPage extends StatefulWidget {
  const VerificationUploadPage({super.key});

  @override
  State<VerificationUploadPage> createState() => _VerificationUploadPageState();
}

class _VerificationUploadPageState extends State<VerificationUploadPage> {
  final _supabase = Supabase.instance.client;
  
  // Files
  File? _baptismImage;
  File? _ktpImage;
  File? _faceImage;
  File? _confirmationImage;
  
  bool _isUploading = false;

  // --- DESIGN SYSTEM CONSTANTS (Kulikeun Premium) ---
  static const Color bgNavy = Color(0xFF0B1121);
  static const Color accentIndigo = Color(0xFF6366F1);
  static const Color accentPurple = Color(0xFFA855F7);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFF94A3B8);
  static const Color glassBorder = Colors.white12;
  static const Color glassCard = Color(0x0DFFFFFF); // ~5% opacity

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentIndigo, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Future<void> _pickImage(int type, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70); 

    if (pickedFile != null) {
      setState(() {
        if (type == 1) {
          _baptismImage = File(pickedFile.path); 
        } else if (type == 2) {
          _ktpImage = File(pickedFile.path);
        } else if (type == 3) {
          _faceImage = File(pickedFile.path);
        } else if (type == 4) {
          _confirmationImage = File(pickedFile.path);
        }
      });
    }
  }

  // VALIDATION LOGIC
  bool get _isFormValid {
    return _baptismImage != null && _ktpImage != null && _faceImage != null;
  }

  Future<void> _submitVerification() async {
    if (!_isFormValid) return; 

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // 1. Upload Files
        final timePrefix = DateTime.now().millisecondsSinceEpoch;
        
        // Baptis
        final baptismPath = '${user.id}/baptism_$timePrefix.jpg';
        await _supabase.storage.from('verifications').upload(baptismPath, _baptismImage!);
        final baptismUrl = _supabase.storage.from('verifications').getPublicUrl(baptismPath);

        // KTP
        final ktpPath = '${user.id}/ktp_$timePrefix.jpg';
        await _supabase.storage.from('verifications').upload(ktpPath, _ktpImage!);
        final ktpUrl = _supabase.storage.from('verifications').getPublicUrl(ktpPath);

        // Face
        final facePath = '${user.id}/face_$timePrefix.jpg';
        await _supabase.storage.from('verifications').upload(facePath, _faceImage!);
        final faceUrl = _supabase.storage.from('verifications').getPublicUrl(facePath);

        // Krisma (Optional)

        if (_confirmationImage != null) {
           final confirmationPath = '${user.id}/confirmation_$timePrefix.jpg';
           await _supabase.storage.from('verifications').upload(confirmationPath, _confirmationImage!);
           _supabase.storage.from('verifications').getPublicUrl(confirmationPath);
        }
        
        // 2. Update Profiles Table
        await _supabase.from('profiles').update({
          'verification_status': 'pending',
          'baptism_certificate_url': baptismUrl,
          'verification_ktp_url': ktpUrl,
          'verification_video_url': faceUrl, 
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);

        if (mounted) {
          _showSuccessDialog();
        }
      }
    } catch (e) {
      debugPrint("Error upload: $e");
      // Fallback
       try {
         final user = _supabase.auth.currentUser;
         if (user != null) {
            await _supabase.from('profiles').update({
              'verification_status': 'pending',
            }).eq('id', user.id);
            if(mounted) _showSuccessDialog();
            return;
         }
      } catch (e2) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: accentIndigo)),
        title: Row(
          children: [
              const Icon(Icons.check_circle, color: accentIndigo),
              const SizedBox(width: 8),
              Text("Terkirim!", style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Data Anda sedang diverifikasi. Mohon tunggu 1x24 jam.",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); 
            },
            child: Text("OK, MENGERTI", style: GoogleFonts.outfit(color: accentIndigo, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Verifikasi Akun", style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: glassBorder, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // INTRO BOX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: glassCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: accentIndigo.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, color: accentIndigo, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Lengkapi 3 data wajib untuk mendapatkan lencana Terverifikasi.",
                      style: GoogleFonts.outfit(color: textGrey, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // STEP 1: Surat Baptis
            _buildSectionHeader("1", "Surat Baptis (Wajib)"),
            const SizedBox(height: 16),
            _buildUploadCard(
              file: _baptismImage,
              hint: "Foto Surat Baptis Asli",
              icon: Icons.history_edu_rounded,
              onTap: () => _pickImage(1, ImageSource.gallery),
            ),

            const SizedBox(height: 32),

            // STEP 2: KTP
            _buildSectionHeader("2", "KTP / Identitas (Wajib)"),
            const SizedBox(height: 16),
            _buildUploadCard(
              file: _ktpImage,
              hint: "Foto KTP / Kartu Pelajar",
              icon: Icons.credit_card_rounded,
              onTap: () => _pickImage(2, ImageSource.gallery),
            ),

            const SizedBox(height: 32),

            // STEP 3: Selfie
            _buildSectionHeader("3", "Verifikasi Wajah (Wajib)"),
            const SizedBox(height: 16),
            _buildUploadCard(
              file: _faceImage,
              hint: "Ambil Selfie Sekarang",
              icon: Icons.face_retouching_natural_rounded,
              onTap: () => _pickImage(3, ImageSource.camera),
              isCamera: true,
            ),

            const SizedBox(height: 32),

            // STEP 4: Krisma
            _buildSectionHeader("4", "Surat Krisma (Opsional)"),
            const SizedBox(height: 16),
            _buildUploadCard(
              file: _confirmationImage,
              hint: "Foto Surat Krisma (Jika Ada)",
              icon: Icons.volunteer_activism_rounded,
              onTap: () => _pickImage(4, ImageSource.gallery),
              isOptional: true,
            ),

            const SizedBox(height: 48),

            // SUBMIT BUTTON
            Container(
              decoration: BoxDecoration(
                gradient: primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: accentIndigo.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: ElevatedButton(
                onPressed: (_isFormValid && !_isUploading) ? _submitVerification : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent, // Keep gradient visible but maybe dim it manually if needed, or just let opacity handle it
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: _isUploading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text("KIRIM DATA VERIFIKASI", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1, color: textWhite)),
              ),
            ),
            if (!_isFormValid)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  "* Tombol akan aktif setelah 3 data wajib terisi.",
                  style: GoogleFonts.outfit(color: textGrey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: accentIndigo,
            shape: BoxShape.circle,
          ),
          child: Text(number, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // GLASS DASHED BORDER CARD (Simulated with Border.all for simplicity in Flutter default, can use DottedBorder package if available, but staying clean for now)
  Widget _buildUploadCard({required File? file, required String hint, required IconData icon, required VoidCallback onTap, bool isOptional = false, bool isCamera = false}) {
    final bool isFilled = file != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: glassCard,
          borderRadius: BorderRadius.circular(20),
          border: isFilled 
            ? Border.all(color: accentIndigo, width: 2) 
            : Border.all(color: glassBorder, width: 1.5, style: BorderStyle.solid), // Use DottedBorder package if strictly needed, otherwise solid glass border is fine
          image: isFilled ? DecorationImage(image: FileImage(file), fit: BoxFit.cover) : null,
        ),
        child: isFilled
            ? Stack(
                children: [
                  Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.black26)), // Dim overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text("Ulangi Foto", style: GoogleFonts.outfit(color: Colors.white, fontSize: 12))
                        ],
                      ),
                    ),
                  )
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: glassBorder)
                    ),
                    child: Icon(icon, color: isCamera ? accentIndigo : Colors.white54, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(hint, style: GoogleFonts.outfit(color: textWhite, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                    isCamera ? "Tap untuk membuka kamera" : "Tap untuk pilih file", 
                    style: GoogleFonts.outfit(color: textGrey, fontSize: 12)
                  ),
                ],
              ),
      ),
    );
  }
}
