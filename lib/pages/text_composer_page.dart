import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class TextComposerPage extends StatefulWidget {
  const TextComposerPage({super.key});

  @override
  State<TextComposerPage> createState() => _TextComposerPageState();
}

class _TextComposerPageState extends State<TextComposerPage> {
  // State
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  File? _selectedImage;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  // User Data
  String? _userAvatar;

  @override
  void initState() {
    super.initState();
    _loadUserAvatar();
    // Auto-focus keyboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadUserAvatar() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _userAvatar = user.userMetadata?['avatar_url'];
      });
    }
  }

  // --- LOGIC ---

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  bool get _canSubmit {
    return _textController.text.trim().isNotEmpty || _selectedImage != null;
  }

  Future<void> _submitPost() async {
    if (!_canSubmit) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Anda belum login")));
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (_selectedImage != null) {
        // --- TEXT POST WITH ATTACHMENT ---
        final String fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('post_images')
            .upload(fileName, _selectedImage!);

        final String imageUrl = Supabase.instance.client.storage
            .from('post_images')
            .getPublicUrl(fileName);

        await Supabase.instance.client.from('posts').insert({
          'user_id': user.id,
          'image_url': imageUrl,
          'caption': _textController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // --- PURE TEXT POST ---
        await Supabase.instance.client.from('text_posts').insert({
          'user_id': user.id,
          'content': _textController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil memposting!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF000000); // Pitch Black
    // const Color surfaceColor = Color(0xFF16181C);

    return Scaffold(
      backgroundColor: bgDark,
      // Custom AppBar within SafeArea
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(60, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "Batal",
                      style: GoogleFonts.outfit(fontSize: 16),
                    ),
                  ),

                  // Submit Button (Pill Gradient)
                  Opacity(
                    opacity: (_canSubmit && !_isUploading) ? 1.0 : 0.5,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFFA855F7),
                          ], // Indigo -> Purple
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ElevatedButton(
                        onPressed: (_canSubmit && !_isUploading)
                            ? _submitPost
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                "Posting",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // 2. INPUT AREA
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 12),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF1E293B),
                        child: SafeNetworkImage(
                          imageUrl: _userAvatar,
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.circular(22),
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.person,
                          iconColor: Colors.white54,
                          fallbackColor: const Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    // Input & Media
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TextField (Animated Font Size)
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: _selectedImage != null ? 18 : 22,
                              height: 1.3,
                            ),
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              onChanged: (_) => setState(() {}),
                              maxLines: null,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: _selectedImage != null ? 18 : 22,
                                height: 1.3,
                              ),
                              decoration: InputDecoration(
                                hintText: "Apa yang sedang terjadi?",
                                hintStyle: GoogleFonts.outfit(
                                  color: Colors.white30,
                                  fontSize: _selectedImage != null ? 18 : 22,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Animated Media Preview
                          AnimatedSize(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOutCubic,
                            child: _selectedImage != null
                                ? Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      maxHeight: 450,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          child: Image.file(
                                            _selectedImage!,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        // Remove Button
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () => setState(
                                              () => _selectedImage = null,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.6,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white24,
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. TOOLBAR (Above Keyboard)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
                color: bgDark,
              ),
              child: Row(
                children: [
                  _buildToolbarIcon(Icons.image_outlined, () => _pickImage()),
                  const SizedBox(width: 24),
                  _buildToolbarIcon(Icons.gif_box_outlined, () {}),
                  const SizedBox(width: 24),
                  _buildToolbarIcon(Icons.poll_outlined, () {}),
                  const SizedBox(width: 24),
                  _buildToolbarIcon(Icons.location_on_outlined, () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: const Color(0xFF6366F1), size: 26),
    );
  }
}
