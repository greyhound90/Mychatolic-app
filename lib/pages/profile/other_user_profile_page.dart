import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OtherUserProfilePage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const OtherUserProfilePage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final name = userData['name']?.toString() ?? 'Profil';
    final parish = userData['parish']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (parish != null) ...[
              const SizedBox(height: 8),
              Text(
                parish,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
