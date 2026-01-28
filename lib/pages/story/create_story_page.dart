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

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await _storyService.uploadStory(
        file: _selectedFile!,
        mediaType: _mediaType,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Story berhasil dibagikan!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal upload story: $e"),
            backgroundColor: Colors.red,
          ),
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
      backgroundColor: Colors.black, // Black background for letterbox
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // LAYER 1: Image container with BoxFit.contain (Letterbox)
          Positioned.fill(
             child: Container(
               color: Colors.black,
               alignment: Alignment.center,
               child: Image.file(
                 _selectedFile!,
                 fit: BoxFit.contain, // Ensure full image is visible
               ),
             ),
          ),
          
          // LAYER 2: Close Button (Clean UI)
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: _resetSelection,
                  ),
                ),
              ),
            ),
          ),

          // LAYER 3: Bottom Control (Caption & Share)
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              color: Colors.transparent, // Let gradient usually handle, but here transparent
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Transparent TextField
                    Expanded(
                      child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20)
                         ),
                         child: TextField(
                          controller: _captionController,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            hintText: "Review & Caption...",
                            hintStyle: GoogleFonts.outfit(color: Colors.white70),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // SHARE BUTTON
                    GestureDetector(
                      onTap: _isLoading ? null : _uploadStory,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : Row(
                              children: [
                                Text("Post", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 12)
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE (VIEWFINDER MODE) ---
  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Close Button (Top Left)
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(context), 
                icon: const Icon(Icons.close, color: Colors.white, size: 32)
              ),
            )
          ),

          // Controls (Bottom)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(bottom: 50, top: 20, left: 24, right: 24),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gallery Picker (Left)
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2)
                      ),
                      child: const Center(child: Icon(Icons.photo_library, color: Colors.white, size: 20)),
                    ),
                  ),

                  // Shutter Button (Center - Camera)
                  GestureDetector(
                    onTap: () => _pickImage(ImageSource.camera),
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 6),
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Spacer for right side balance
                  const SizedBox(width: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
