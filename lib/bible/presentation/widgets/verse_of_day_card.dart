import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/presentation/widgets/app_components.dart';

class VerseOfDayCard extends StatelessWidget {
  final VerseOfTheDay verse;
  final VoidCallback onRead;
  final VoidCallback onShare;
  final bool darkMode;

  const VerseOfDayCard({
    super.key,
    required this.verse,
    required this.onRead,
    required this.onShare,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = darkMode ? const Color(0xFF1C1C1C) : Colors.white;
    final textColor = darkMode ? Colors.white : const Color(0xFF1E1E1E);

    return AppCard(
      color: cardColor,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ayat Hari Ini', style: AppTypography.subtitle(textColor)),
          const SizedBox(height: AppSpacing.sm),
          Text(verse.reference, style: AppTypography.small(textColor.withValues(alpha: 0.7))),
          const SizedBox(height: AppSpacing.md),
          Text(
            verse.text,
            style: GoogleFonts.sourceSerif4(fontSize: 18, height: 1.5, color: textColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              PrimaryButton(label: 'Baca', onPressed: onRead),
              const SizedBox(width: AppSpacing.md),
              SecondaryButton(label: 'Bagikan', onPressed: onShare),
            ],
          )
        ],
      ),
    );
  }
}
