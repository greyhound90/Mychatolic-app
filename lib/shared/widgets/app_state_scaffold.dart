import 'package:flutter/material.dart';

class AppStateScaffold extends StatelessWidget {
  final bool loading;
  final Object? error;
  final Widget child;
  final String? title;
  final VoidCallback? onRetry;

  const AppStateScaffold({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
    this.title,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: 12),
              Text(
                "Memuat...",
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      final message = error is String ? error as String : "Terjadi kesalahan.";
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: title != null
            ? AppBar(
                title: Text(title!),
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
              )
            : null,
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.6),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colors.error, size: 32),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                      ),
                      child: Text(
                        "Coba lagi",
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}
