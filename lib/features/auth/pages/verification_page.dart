import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final ImagePicker _picker = ImagePicker();

  // State Variables
  bool _isLoadingProfile = true;
  bool _isSubmitting = false; // Initial loading state for profile fetch
  String? _userRole; // 'umat', 'pastor', 'katekumen', etc.
  bool _isCatechumen = false;

  // Track file paths: Key = DocType, Value = Supabase Path
  final Map<String, String?> _documents = {};
  final Map<String, bool> _uploading = {};

  // Face Verification State
  String? _faceImagePath; // Stores the Supabase path
  bool _isFaceUploading = false;

  // Document Types constants
  static const String docKtp = 'KTP / Identitas';
  static const String docBaptis = 'Surat Baptis';
  static const String docKrisma = 'Surat Krisma';
  static const String docTugas = 'Surat Tugas Resmi';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not logged in";

      final response = await Supabase.instance.client
          .from('profiles')
          .select('role, user_role') // Fetch both possible columns
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        // Prioritize 'user_role' (new schema), fallback to 'role'
        final String roleRaw =
            (response['user_role'] ?? response['role'] ?? 'umat')
                .toString()
                .toLowerCase();

        setState(() {
          _userRole = roleRaw;
          // Check if explicitly katekumen
          _isCatechumen = roleRaw == 'katekumen'; 
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memuat data profil: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- LOGIC GETTERS ---

  // Case A: UMAT (Exclude Katekumen)
  bool get _isUmatLegacy =>
      (_userRole == 'umat' || _userRole == 'umat_katolik') && !_isCatechumen;

  // Case B: CLERGY
  bool get _isClergy {
    final clergyRoles = ['pastor', 'suster', 'bruder', 'frater', 'katekis'];
    return clergyRoles.contains(_userRole);
  }

  // Determine Required Docs based on Role
  List<String> get _requiredDocs {
    if (_isCatechumen) return []; // Case C
    if (_isClergy) return [docTugas]; // Case B
    return [docKtp, docBaptis]; // Case A (Default/Umat)
  }

  // Determine Optional Docs based on Role
  List<String> get _optionalDocs {
    if (_isCatechumen || _isClergy) return [];
    return [docKrisma]; // Only Umat has optional Krisma
  }

  List<String> get _allDocTypes => [..._requiredDocs, ..._optionalDocs];

  // Validation Logic
  bool get _canSubmit {
    // 1. Check Required Docs
    for (var doc in _requiredDocs) {
      if (_documents[doc] == null) return false;
    }
    // 2. Check Mandatory Selfie (Always required except Katekumen?)
    // Logic: Katekumen doesn't need verification docs, so maybe no selfie either?
    // User Rules: "CASE C... Sembunyikan SEMUA form upload."
    if (_isCatechumen) return true; 

    if (_faceImagePath == null) return false;

    return true;
  }

  // --- UPLOAD HANDLERS ---

  Future<void> _pickAndUploadImage(String docType, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _uploading[docType] = true);

      final String? path = await _uploadToSupabase(File(image.path), docType);

      if (mounted) {
        setState(() {
          _documents[docType] = path;
          _uploading[docType] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading[docType] = false);
        _showError("Upload Gagal: $e");
      }
    }
  }

  // Face Specific Picker (Camera Only)
  Future<void> _pickAndUploadFace() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isFaceUploading = true);

      final String? path = await _uploadToSupabase(
        File(image.path),
        "Face_Selfie",
      );

      if (mounted) {
        setState(() {
          _faceImagePath = path;
          _isFaceUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFaceUploading = false);
        _showError("Upload Selfie Gagal: $e");
      }
    }
  }

  Future<String?> _uploadToSupabase(File file, String docTag) async {
    final String userId =
        Supabase.instance.client.auth.currentUser?.id ?? 'temp_user';
    final String fileExt = file.path.split('.').last;
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String safeTag = docTag.replaceAll(" ", "_").replaceAll("/", "");
    final String fileName = '$userId/${safeTag}_$timestamp.$fileExt';

    await Supabase.instance.client.storage
        .from('verification_docs')
        .upload(
          fileName,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    return fileName;
  }

  // --- SUBMIT LOGIC ---

  Future<void> _submitVerification() async {
    setState(() => _isSubmitting = true);

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) throw "User tidak ditemukan";

      // Prepare Update Data
      Map<String, dynamic> updates = {
        'verification_status': 'pending',
        'account_status': 'pending', 
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Ensure selfie is saved if present
      if (_faceImagePath != null) {
        updates['selfie_url'] = _faceImagePath;
      }

      // Map dynamic docs to columns based on what was uploaded
      if (_documents[docKtp] != null) {
        updates['ktp_url'] = _documents[docKtp];
      }
      if (_documents[docBaptis] != null) {
        updates['baptism_cert_url'] = _documents[docBaptis];
      }
      if (_documents[docKrisma] != null) {
        updates['chrism_cert_url'] = _documents[docKrisma];
      }
      if (_documents[docTugas] != null) {
        updates['assignment_letter_url'] = _documents[docTugas];
      }

      // Execute Update
      await client.from('profiles').update(updates).eq('id', user.id);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      _showError("Gagal Mengajukan: $e");
      setState(() => _isSubmitting = false);
    }
  }

  // --- UI HELPERS ---

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          "Dokumen Terkirim",
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Terima kasih. Data anda telah kami terima dan sedang dalam proses verifikasi oleh Admin.",
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Back to Profile
            },
            child: Text(
              "OK",
              style: GoogleFonts.outfit(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _removeDoc(String docType) => setState(() => _documents[docType] = null);
  void _removeFace() => setState(() => _faceImagePath = null);

  void _showImageSourcePicker(String docType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.white),
            title: Text(
              "Kamera",
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadImage(docType, ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white),
            title: Text(
              "Galeri",
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadImage(docType, ImageSource.gallery);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    // CASE C: KATEKUMEN -> No Forms, just Message
    if (_isCatechumen) {
      return _buildCatechumenView();
    }

    // CASE A & B: Standard Upload Flow
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          "Verifikasi Identitas",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text(
              _isClergy
                  ? "Mohon lampirkan Surat Tugas resmi dan Foto Selfie untuk verifikasi status klerus Anda."
                  : "Lengkapi dokumen berikut untuk mendapatkan lencana terverifikasi.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 1. Dynamic Docs List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allDocTypes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 20),
                    itemBuilder: (ctx, index) {
                      final docType = _allDocTypes[index];
                      // Determine if Optional
                      bool isOptional = _optionalDocs.contains(docType);
                      return _buildDocumentCard(
                        docType,
                        isOptional: isOptional,
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // 2. Selfie Card (Mandatory for NON-Katekumen)
                  _buildFaceVerificationCard(),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_canSubmit && !_isSubmitting)
                      ? _submitVerification
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.white10,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: _canSubmit
                          ? const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                            )
                          : null,
                      color: _canSubmit ? null : Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "AJUKAN VERIFIKASI",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _canSubmit
                                    ? Colors.white
                                    : Colors.white38,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SPECIAL VIEWS ---

  Widget _buildCatechumenView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFF8B5CF6),
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Halo Katekumen!",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Status Anda tidak memerlukan verifikasi dokumen sakramen saat ini. Silakan lanjutkan eksplorasi aplikasi.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    "KEMBALI KE BERANDA",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildDocumentCard(String docType, {bool isOptional = false}) {
    final String? uploadedPath = _documents[docType];
    final bool isUploading = _uploading[docType] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              docType.toUpperCase(),
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            if (isOptional)
              Text(
                " (OPSIONAL)",
                style: GoogleFonts.outfit(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        InkWell(
          onTap: (uploadedPath != null || isUploading)
              ? null
              : () => _showImageSourcePicker(docType),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (uploadedPath != null)
                    ? const Color(0xFF8B5CF6)
                    : Colors.white24,
                width: (uploadedPath != null) ? 2 : 1,
                style: (uploadedPath != null)
                    ? BorderStyle.solid
                    : BorderStyle.none,
              ),
            ),
            child: isUploading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                : uploadedPath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SafeNetworkImage(
                          imageUrl: Supabase.instance.client.storage
                              .from('verification_docs')
                              .getPublicUrl(uploadedPath),
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.broken_image,
                          iconColor: Colors.white24,
                          fallbackColor: Colors
                              .transparent,
                        ),
                      ),

                      // Checkmark
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _removeDoc(docType),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.upload_file,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Tap untuk unggah",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceVerificationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.face_retouching_natural,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              "VERIFIKASI WAJAH (SELFIE)",
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "*Wajib",
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Ambil foto selfie terbaru Anda secara langsung.",
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 12),

        InkWell(
          onTap: (_faceImagePath != null || _isFaceUploading)
              ? null
              : _pickAndUploadFace,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (_faceImagePath != null)
                    ? const Color(0xFF8B5CF6)
                    : Colors.white24,
                width: (_faceImagePath != null) ? 2 : 1,
                style: (_faceImagePath != null)
                    ? BorderStyle.solid
                    : BorderStyle.none,
              ),
            ),
            child: _isFaceUploading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                : _faceImagePath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SafeNetworkImage(
                          imageUrl: Supabase.instance.client.storage
                              .from('verification_docs')
                              .getPublicUrl(_faceImagePath!),
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.broken_image,
                          iconColor: Colors.white24,
                          fallbackColor: Colors.transparent,
                        ),
                      ),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: _removeFace,
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white54,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Buka Kamera",
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
