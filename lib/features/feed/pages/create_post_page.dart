
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychatolic_app/services/post_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({Key? key}) : super(key: key);

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final PostService _postService = PostService();
  final TextEditingController _captionController = TextEditingController();
  
  // State
  int _selectedMode = 0; // 0 = Foto, 1 = Tulisan
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    
    // Validasi
    if (_selectedMode == 0) {
      // Mode Foto
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih foto terlebih dahulu")));
        return;
      }
    } else {
      // Mode Tulisan
      if (caption.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tulis sesuatu...")));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await _postService.createPost(
        caption: caption,
        imageFile: _selectedMode == 0 ? _selectedImage : null,
        type: _selectedMode == 0 ? 'photo' : 'text',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil diposting!")));
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal posting: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Buat Postingan", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isLoading ? null : _submitPost,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0088CC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text("Post", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. SWITCHER (Foto vs Tulisan)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildSwitchOption(0, "Foto", Icons.camera_alt),
                  _buildSwitchOption(1, "Tulisan", Icons.text_fields),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                     if (_selectedMode == 0) _buildPhotoMode() else _buildTextMode(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption(int index, String label, IconData icon) {
    final bool isSelected = _selectedMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? const Color(0xFF0088CC) : Colors.grey),
              const SizedBox(width: 8),
              Text(
                label, 
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF0088CC) : Colors.grey
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Preview Area
        GestureDetector(
          onTap: () => _pickImage(ImageSource.gallery),
          child: AspectRatio(
            aspectRatio: 4 / 5, // Force Portrait 4:5
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                image: _selectedImage != null 
                    ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                    : null
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey[400]),
                         const SizedBox(height: 12),
                         Text("Ketuk untuk pilih foto (4:5)", style: GoogleFonts.outfit(color: Colors.grey[500]))
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                               setState(() => _selectedImage = null);
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.5),
                              radius: 16,
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        )
                      ],
                    ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Caption Input
        TextField(
          controller: _captionController,
          maxLines: 4,
          style: GoogleFonts.outfit(fontSize: 16),
          decoration: InputDecoration(
            hintText: "Tulis caption menarik...",
            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
            border: InputBorder.none,
            filled: true,
            fillColor: Colors.grey[50], // Very subtle bg
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0088CC), width: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextMode() {
    return Container(
      width: double.infinity,
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE3F2FD), // Light Blue
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: TextField(
          controller: _captionController,
          maxLines: null,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: "Apa yang sedang kamu pikirkan?",
            hintStyle: GoogleFonts.outfit(color: Colors.black26),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
