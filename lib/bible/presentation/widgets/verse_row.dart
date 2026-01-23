import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

class VerseRow extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  final double lineHeight;
  final Color textColor;
  final bool selected;
  final bool flash;
  final bool paragraphMode;
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;

  const VerseRow({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.lineHeight,
    required this.textColor,
    required this.selected,
    required this.flash,
    required this.paragraphMode,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    final highlight = _resolveHighlight(verse.highlightColor);
    final basePadding = paragraphMode
        ? const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md)
        : const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg);
    final baseMargin = paragraphMode
        ? const EdgeInsets.symmetric(vertical: AppSpacing.xs)
        : const EdgeInsets.symmetric(vertical: AppSpacing.xs);
    final flashColor = Colors.amber.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: basePadding,
        margin: baseMargin,
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber.withValues(alpha: 0.2)
              : flash
                  ? flashColor
                  : highlight == Colors.transparent
                      ? Colors.transparent
                      : highlight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: RichText(
          text: TextSpan(
            style: ReaderTypography.verseText(
              fontSize: fontSize,
              lineHeight: lineHeight,
              color: textColor,
            ),
            children: [
              TextSpan(
                text: '${verse.verse} ',
                style: ReaderTypography.verseNumber(
                  fontSize: fontSize - 4,
                  color: textColor,
                ),
              ),
              TextSpan(text: verse.content),
            ],
          ),
        ),
      ),
    );
  }
}

Color _resolveHighlight(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.transparent;
  var value = hex.replaceAll('#', '').toUpperCase();
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return Colors.transparent;
  return Color(parsed);
}
