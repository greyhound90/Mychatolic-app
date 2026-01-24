import 'package:flutter/material.dart';
import 'package:mychatolic_app/bible/core/design_tokens.dart';

class ErrorStateView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Coba lagi'),
              ),
          ],
        ),
      ),
    );
  }
}
