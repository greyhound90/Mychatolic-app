import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/models/bible_model.dart';

class VerseItem extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final Color secondaryTextColor;
  final Color selectionColor;
  final bool isSelected;
  final VoidCallback onTap;

  const VerseItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.secondaryTextColor,
    required this.selectionColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = _colorFromHex(verse.highlightColor);
    final backgroundColor =
        highlightColor ?? (isSelected ? selectionColor : null);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                verse.verse.toString(),
                style: GoogleFonts.outfit(
                  fontSize: fontSize - 4,
                  fontWeight: FontWeight.w700,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  verse.content,
                  style: GoogleFonts.merriweather(
                    fontSize: fontSize,
                    height: lineHeight,
                    color: textColor,
                  ),
                ),
              ),
              if (verse.note != null && verse.note!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 16,
                  color: secondaryTextColor,
                ),
              ],
              if (verse.isBookmarked) ...[
                const SizedBox(width: 6),
                Icon(Icons.bookmark, size: 16, color: secondaryTextColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color? _colorFromHex(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) return null;
  final intColor = int.tryParse(hex, radix: 16);
  if (intColor == null) return null;
  return Color(intColor);
}
