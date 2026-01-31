import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/models/article.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: CustomScrollView(
        slivers: [
          // 1. App Bar Image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: article.imageUrl != null
                  ? SafeNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: kPrimary,
                      child: const Center(
                        child: Icon(
                          Icons.church,
                          size: 64,
                          color: Colors.white30,
                        ),
                      ),
                    ),
            ),
          ),

          // 2. Content Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  if (article.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: kSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: kSecondary.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        article.category!.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: kSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Title
                  Text(
                    article.title,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: kTextTitle,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Date
                  Text(
                    timeago.format(article.createdAt, locale: 'en'),
                    style: GoogleFonts.outfit(color: kTextMeta, fontSize: 14),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Content
                  Text(
                    article.content ?? "No content available.",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: kTextBody,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
