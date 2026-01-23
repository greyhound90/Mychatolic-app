import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReaderThemeMode { light, sepia, dark }

class SettingsSheet extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final ReaderThemeMode mode;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ReaderThemeMode> onModeChanged;

  const SettingsSheet({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.mode,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tampilan',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: 'Ukuran Huruf'),
          Slider(
            value: fontSize,
            min: 14,
            max: 28,
            divisions: 14,
            label: fontSize.toStringAsFixed(0),
            onChanged: onFontSizeChanged,
          ),
          const SizedBox(height: 8),
          _SectionLabel(label: 'Jarak Baris'),
          Slider(
            value: lineHeight,
            min: 1.2,
            max: 2.2,
            divisions: 10,
            label: lineHeight.toStringAsFixed(1),
            onChanged: onLineHeightChanged,
          ),
          const SizedBox(height: 8),
          _SectionLabel(label: 'Mode'),
          Wrap(
            spacing: 8,
            children: ReaderThemeMode.values.map((value) {
              final isSelected = value == mode;
              return ChoiceChip(
                label: Text(_labelForMode(value)),
                selected: isSelected,
                onSelected: (_) => onModeChanged(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
      ),
    );
  }
}

String _labelForMode(ReaderThemeMode mode) {
  switch (mode) {
    case ReaderThemeMode.light:
      return 'Light';
    case ReaderThemeMode.sepia:
      return 'Sepia';
    case ReaderThemeMode.dark:
      return 'Dark';
  }
}
