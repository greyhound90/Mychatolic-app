import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/presentation/widgets/app_components.dart';

class ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ThemeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip(label: label, selected: selected, onTap: onTap);
  }
}
