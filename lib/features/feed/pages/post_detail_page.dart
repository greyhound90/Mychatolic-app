
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/user_post.dart';
import 'package:mychatolic_app/features/feed/widgets/post_card.dart';

class PostDetailPage extends StatelessWidget {
  final UserPost post;

  const PostDetailPage({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text("Postingan", style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            PostCard(post: post),
          ],
        ),
      ),
    );
  }
}
