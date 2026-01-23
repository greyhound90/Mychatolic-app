import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/services/social_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final SocialService _socialService = SocialService();
  final TextEditingController _contentController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  bool _isSending = false;
  String _statusMessage = "Kirim"; // Untuk feedback visual (Mengompresi/Mengirim)
  
  // Location Stubs
  String? _countryId; 
  String? _dioceseId;
  String? _churchId;
  String? _locationName; // Untuk display di Chip

  @override
  void initState() {
    super.initState();
    _fetchUserDefaultLocation();
  }

  void _fetchUserDefaultLocation() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
       try {
          final data = await Supabase.instance.client
              .from('profiles')
              .select('country_id, diocese_id, church_id, churches(name)')
              .eq('id', user.id)
              .maybeSingle();
          
          if (data != null && mounted) {
             setState(() {
               _countryId = data['country_id']?.toString();
               _dioceseId = data['diocese_id']?.toString();
               _churchId = data['church_id']?.toString();
               
               // Ambil nama gereja untuk display
               if (data['churches'] != null) {
                 _locationName = data['churches']['name'];
               }
             });
          }
       } catch (e) {
         // ignore silent error
       }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
    }
  }

  // LOGIKA KOMPRESI PINTAR
  Future<File> _processImage(File file) async {
    setState(() => _statusMessage = "Mengompresi...");
    
    // 1. Cek Settingan User
    final prefs = await SharedPreferences.getInstance();
    final bool isHighQuality = prefs.getBool('high_quality_upload') ?? false;

    // 2. Tentukan Target (HD vs Hemat)
    // HD: Min 2048px, Quality 88%
    // Hemat: Min 1920px, Quality 70%
    final int minWidth = isHighQuality ? 2048 : 1920;
    final int quality = isHighQuality ? 88 : 70;

    try {
      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = "${dir.absolute.path}/temp_${DateTime.now().millisecondsSinceEpoch}.jpg";
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: minWidth,
        minHeight: minWidth, // Ratio tetap terjaga, ini hanya batas bound
        quality: quality,
      );

      return result != null ? File(result.path) : file;
    } catch (e) {
      debugPrint("Gagal kompresi, pakai file asli: $e");
      return file;
    }
  }

  Future<void> _sendPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imageFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tulis sesuatu atau pilih gambar")));
       return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = "Memproses...";
    });

    try {
      // Data Validation: Ensure IDs are proper NULLs if empty
      String? cleanId(String? id) => (id == null || id.trim().isEmpty || id == 'null') ? null : id;

      final validCountryId = cleanId(_countryId);
      final validDioceseId = cleanId(_dioceseId);
      final validChurchId = cleanId(_churchId);

      String? imageUrl;
      
      // 1. Upload Image (With Smart Compression)
      if (_imageFile != null) {
         final File readyFile = await _processImage(_imageFile!);
         
         setState(() => _statusMessage = "Mengupload...");
         try {
            imageUrl = await _socialService.uploadPostImage(readyFile);
         } catch (e) {
            throw "Gagal upload gambar: $e";
         }
      }

      // 2. Create Post
      setState(() => _statusMessage = "Posting...");
      await _socialService.createPost(
        content: content,
        imageUrl: imageUrl, 
        type: _imageFile != null ? 'photo' : 'text',
        countryId: validCountryId,
        dioceseId: validDioceseId,
        churchId: validChurchId,
      );

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Postingan berhasil dibuat!")));
         Navigator.pop(context, true); // Return success
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        // Handle Database Errors (RLS, Types, etc.)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal Posting (Database): ${e.message}\nDetails: ${e.details ?? ''}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    } on StorageException catch (e) {
      if (mounted) {
        // Handle Storage Errors
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Gagal Posting (Storage): ${e.message}"),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        // Generic Errors
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Terjadi kesalahan: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted && _isSending) { // Only reset if still on screen and not success popped
        setState(() {
          _isSending = false;
          _statusMessage = "Kirim";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Buat Postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: kTextTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isSending 
                   ? Row(
                       children: [
                         const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                         const SizedBox(width: 8),
                         Text(_statusMessage, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                       ],
                     )
                   : Text("Kirim", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(20),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // USER LOCATION CHIP
             if (_locationName != null)
               Padding(
                 padding: const EdgeInsets.only(bottom: 12),
                 child: Chip(
                   avatar: const Icon(Icons.location_on, size: 16, color: Colors.white),
                   label: Text(_locationName!, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12)),
                   backgroundColor: kPrimary.withValues(alpha: 0.8),
                   deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                   onDeleted: () {
                     setState(() {
                       _churchId = null;
                       _dioceseId = null;
                       _countryId = null;
                       _locationName = null;
                     });
                   },
                 ),
               ),

             // INPUT TEXT
             TextField(
               controller: _contentController,
               maxLines: 5,
               autofocus: true,
               decoration: InputDecoration(
                 hintText: "Apa yang anda pikirkan?",
                 hintStyle: GoogleFonts.outfit(color: kTextMeta, fontSize: 18),
                 border: InputBorder.none,
               ),
               style: GoogleFonts.outfit(fontSize: 18, color: kTextTitle),
             ),
             
             const SizedBox(height: 20),
             
             // IMAGE PREVIEW
             if (_imageFile != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, width: double.infinity, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _imageFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    )
                  ],
                ),
           ],
         ),
      ),
      bottomNavigationBar: Container(
         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
         decoration: BoxDecoration(
           color: Colors.white,
           border: Border(top: BorderSide(color: Colors.grey[200]!)),
         ),
         child: SafeArea(
           child: Row(
             children: [
               Text("Tambahkan ke postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: kTextTitle)),
               const Spacer(),
               IconButton(
                 onPressed: _pickImage,
                 icon: const Icon(Icons.image_outlined, color: kPrimary, size: 28),
               ),
             ],
           ),
         ),
      ),
    );
  }
}
