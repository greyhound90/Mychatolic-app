import 'package:flutter/material.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/ui/app_state_view.dart';

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
    if (loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const AppStateView(state: AppViewState.loading),
      );
    }

    if (error != null) {
      final message = error is String ? error as String : "Terjadi kesalahan.";
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: title != null
            ? AppBar(
                title: Text(title!),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
              )
            : null,
        body: AppStateView(
          state: AppViewState.error,
          error: AppError(title: "Gagal memuat", message: message, raw: error),
          onRetry: onRetry,
        ),
      );
    }

    return child;
  }
}
