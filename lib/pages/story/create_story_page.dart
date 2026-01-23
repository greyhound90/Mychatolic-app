import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mychatolic_app/models/story_model.dart';
import 'package:mychatolic_app/services/story_service.dart';

class CreateStoryPage extends StatefulWidget {
  final File? imageFile;

  const CreateStoryPage({super.key, this.imageFile});

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final StoryService _storyService = StoryService();
  final TextEditingController _captionController = TextEditingController();

  File? _selectedFile;
  MediaType _mediaType = MediaType.image;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.imageFile != null) {
      _selectedFile = widget.imageFile;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);

    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = MediaType.image;
      });
    }
  }

  Future<void> _uploadStory() async {
    if (_selectedFile == null) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _storyService.uploadStory(
        file: _selectedFile!,
        mediaType: _mediaType,
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story berhasil dibagikan!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload story: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetSelection() {
    if (widget.imageFile == null) {
      setState(() {
        _selectedFile = null;
        _captionController.clear();
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFile == null) return _buildEmptyState();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Prevent reshaping, rely on Stack
      body: Stack(
        children: [
          // LAYER 1: Full Screen Image (Interactive)
          // Positioned.fill ensures it takes whole screen space
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(
                _selectedFile!,
                fit: BoxFit.cover, // STRICT: Cover to fill screen (no black bars in default view)
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // LAYER 2: Top Nav (Close Button)
          // SafeArea top only
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close Button
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45, // Transparent black
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _resetSelection,
                      ),
                    ),
                    // Optional: You could put other tools here (crop, stickers)
                  ],
                ),
              ),
            ),
          ),

          // LAYER 3: Bottom Caption Input
          // SafeArea bottom only
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Moves up with keyboard
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54, // Semi-transparent black background for legibility
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // TextField
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 100),
                        child: TextField(
                          controller: _captionController,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                          maxLines: null, // Auto grow
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: "Tulis keterangan...",
                            hintStyle: GoogleFonts.outfit(color: Colors.white60),
                            border: InputBorder.none, // No border as requested
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Send Button
                    GestureDetector(
                      onTap: _isLoading ? null : _uploadStory,
                      child: Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0088CC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // LAYER 4: Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54, // Cover everything
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Buat Cerita", style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPickerButton(Icons.camera_alt, "Kamera", ImageSource.camera),
                const SizedBox(width: 40),
                _buildPickerButton(Icons.photo_library, "Galeri", ImageSource.gallery),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerButton(IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => _pickImage(source),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
              color: Colors.white10,
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }
}
