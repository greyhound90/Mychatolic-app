import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/app_colors.dart';

class CreateStoryPage extends StatefulWidget {
  final File imageFile;

  const CreateStoryPage({
    super.key,
    required this.imageFile,
  });

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  final _supabase = Supabase.instance.client;
  
  bool _isUploading = false;
  
  // UX State
  String _text = '';
  Offset _textPos = const Offset(50, 200);
  bool _isEditing = false;
  final double _fontSize = 28.0;
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _textController.text = _text;
    });
  }

  void _stopEditing() {
    setState(() {
      _isEditing = false;
      _text = _textController.text.trim();
    });
  }

  Future<void> _uploadStory() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Upload Image
      final fileExt = widget.imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = '$myId/$fileName';

      await _supabase.storage.from('stories').upload(
            path,
            widget.imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage.from('stories').getPublicUrl(path);

      // 2. Insert DB Record
      // Determine if we need to save caption. 
      // User hasn't explicitly asked to change schema, but wants the text on the image.
      // Usually "caption" is enough.
      
      final payload = {
        'user_id': myId,
        'media_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
        // 'caption': _text, // Uncomment if schema has caption
      };

      await _supabase.from('stories').insert(payload);

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Story berhasil diposting!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        debugPrint("Upload Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal upload: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // Prevent image resize when keyboard opens
      body: Stack(
        children: [
          // LAYER 1: Interactive Image
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  widget.imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // LAYER 2: Draggable Text (Display Mode)
          if (!_isEditing && _text.isNotEmpty)
            Positioned(
              left: _textPos.dx,
              top: _textPos.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _textPos += details.delta;
                  });
                },
                onTap: _startEditing,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
                  child: Text(
                    _text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // LAYER 3: Overlay Editor (Editing Mode)
          if (_isEditing)
            Positioned.fill(
              child: GestureDetector(
                onTap: _stopEditing, // Tap outside to close
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: IntrinsicWidth( // Just to keep width reasonable
                      child: TextField(
                        controller: _textController,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: _fontSize + 4, // Slightly larger when editing
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: null,
                        decoration: InputDecoration.collapsed(
                          hintText: "Ketik teks...",
                          hintStyle: GoogleFonts.outfit(color: Colors.white54),
                        ),
                        onSubmitted: (_) => _stopEditing(),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // LAYER 4: Controls (Hidden during editing)
          if (!_isEditing) ...[
            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),

            // Text Tool Button ("Aa")
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: _startEditing,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.text_fields_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),

            // Send Button
            Positioned(
              bottom: 30,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'story_fab',
                onPressed: _isUploading ? null : _uploadStory,
                backgroundColor: AppColors.primaryBrand,
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
