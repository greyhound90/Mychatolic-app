import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/widgets/app_button.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';

class AppStateView extends StatelessWidget {
  final AppViewState state;
  final Widget? child;
  final AppError? error;
  final String? emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onRetry;

  const AppStateView({
    super.key,
    required this.state,
    this.child,
    this.error,
    this.emptyTitle,
    this.emptyMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case AppViewState.loading:
        return Center(
          child: AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  "Memuat...",
                  style: GoogleFonts.outfit(color: AppColors.textBody),
                ),
              ],
            ),
          ),
        );
      case AppViewState.error:
        return Center(
          child: AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            color: AppColors.danger.withOpacity(0.08),
            borderColor: AppColors.danger.withOpacity(0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: AppColors.danger, size: 32),
                const SizedBox(height: 8),
                Text(
                  error?.title ?? "Terjadi kesalahan",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  error?.message ?? "Coba lagi beberapa saat.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: "Coba lagi",
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case AppViewState.empty:
        return Center(
          child: AppCard(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(
                  emptyTitle ?? "Belum ada data",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  emptyMessage ?? "Data akan muncul di sini.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textBody,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppSecondaryButton(
                      label: "Coba lagi",
                      onPressed: onRetry,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case AppViewState.ready:
        return child ?? const _ReadyFallback();
    }
  }
}

class _ReadyFallback extends StatelessWidget {
  const _ReadyFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: AppColors.textMuted, size: 28),
            const SizedBox(height: 8),
            Text(
              "Konten belum tersedia",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Silakan coba lagi sebentar.",
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textBody,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
