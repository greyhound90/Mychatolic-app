import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

class VerseActionBottomSheet extends StatelessWidget {
  final BibleVerse verse;
  final String reference;
  final VoidCallback onCopy;
  final VoidCallback onShareText;
  final VoidCallback onShareImage;
  final ValueChanged<Color> onHighlight;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final bool darkMode;

  const VerseActionBottomSheet({
    super.key,
    required this.verse,
    required this.reference,
    required this.onCopy,
    required this.onShareText,
    required this.onShareImage,
    required this.onHighlight,
    required this.onBookmark,
    required this.onNote,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkMode ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reference,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(verse.content, style: TextStyle(color: textColor)),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _ActionChip(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: onCopy,
              ),
              _ActionChip(
                icon: Icons.share_rounded,
                label: 'Share Text',
                onTap: onShareText,
              ),
              _ActionChip(
                icon: Icons.image_outlined,
                label: 'Bagikan sebagai gambar',
                onTap: onShareImage,
              ),
              _ActionChip(
                icon: Icons.bookmark_border,
                label: 'Bookmark',
                onTap: onBookmark,
              ),
              _ActionChip(
                icon: Icons.edit_note,
                label: 'Catatan',
                onTap: onNote,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Highlight', style: TextStyle(color: textColor)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _highlightPalette
                .map(
                  (color) =>
                      _ColorDot(color: color, onTap: () => onHighlight(color)),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () {
        Navigator.pop(context);
        onTap();
      },
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
    );
  }
}

const List<Color> _highlightPalette = [
  Color(0xFFFFF3B0),
  Color(0xFFCDEAC0),
  Color(0xFFBEE3F8),
  Color(0xFFFBCFE8),
];
