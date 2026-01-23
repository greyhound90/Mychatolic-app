import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FinalPhotoCaptionPage extends StatefulWidget {
  final File imageFile;

  const FinalPhotoCaptionPage({super.key, required this.imageFile});

  @override
  State<FinalPhotoCaptionPage> createState() => _FinalPhotoCaptionPageState();
}

class _FinalPhotoCaptionPageState extends State<FinalPhotoCaptionPage> {
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;
  
  // Design Constants
  static const Color bgNavy = Color(0xFF0B1121);
  static const Color accentIndigo = Color(0xFF6366F1);

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _sharePost() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Not logged in")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload Image
      final String fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('post_images')
          .upload(fileName, widget.imageFile);

      final String imageUrl = Supabase.instance.client.storage
          .from('post_images')
          .getPublicUrl(fileName);

      // 2. Insert Post Row
      await Supabase.instance.client.from('posts').insert({
        'user_id': user.id,
        'image_url': imageUrl,
        'caption': _captionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post shared successfully!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgNavy,
      appBar: AppBar(
        backgroundColor: bgNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("New Post", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _sharePost,
            child: _isUploading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accentIndigo))
              : Text("Share", style: GoogleFonts.outfit(color: accentIndigo, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Row: Thumbnail + Caption Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12))
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail (4:5 Ratio)
                  Container(
                    width: 70,
                    height: 87.5, // 70 * 1.25
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      image: DecorationImage(image: FileImage(widget.imageFile), fit: BoxFit.cover),
                      borderRadius: BorderRadius.circular(4)
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Caption Input
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: "Write a caption...",
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            // Additional settings (Tag People, Add Location, etc. - Visual Only for now)
            _buildSettingItem(Icons.person_outline, "Tag People"),
            _buildSettingItem(Icons.location_on_outlined, "Add Location"),
            _buildSettingItem(Icons.music_note_outlined, "Add Music"),
            
            // Footer Info
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Your post will be shared to your followers and on the main feed.", 
                style: GoogleFonts.outfit(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12))
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.white24)
        ],
      ),
    );
  }
}
