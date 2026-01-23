import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class EditPostPage extends StatefulWidget {
  final UserPost post;

  const EditPostPage({super.key, required this.post});

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _captionController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.post.caption);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _savePost() async {
    setState(() => _isLoading = true);

    try {
      final newCaption = _captionController.text.trim();
      
      await _supabase
          .from('posts')
          .update({'caption': newCaption}) 
          .eq('id', widget.post.id);

      if (mounted) {
        final updatedPost = widget.post.copyWith(caption: newCaption);
        Navigator.pop(context, updatedPost); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan perubahan: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Postingan", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _savePost,
              child: Text("Simpan", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.post.imageUrls.isNotEmpty) ...[
               Container(
                 constraints: const BoxConstraints(maxHeight: 300),
                 width: double.infinity,
                 child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SafeNetworkImage(imageUrl: widget.post.imageUrls.first, fit: BoxFit.cover,),
                 ),
               ),
               const SizedBox(height: 16),
            ],
            
            TextField(
              controller: _captionController,
              maxLines: null,
              decoration: InputDecoration(
                hintText: "Tulis sesuatu...",
                border: InputBorder.none,
                hintStyle: GoogleFonts.outfit(color: Colors.grey),
              ),
              style: GoogleFonts.outfit(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
