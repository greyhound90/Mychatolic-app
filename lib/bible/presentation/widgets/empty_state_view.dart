import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';

class EmptyStateView extends StatelessWidget {
  final String message;

  const EmptyStateView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
