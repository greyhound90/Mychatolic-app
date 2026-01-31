import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/core/widgets/app_card.dart';

enum SecurityStatus { verified, unverified, pending, unknown }

class SecurityStatusChip extends StatelessWidget {
  final SecurityStatus status;
  final String? label;

  const SecurityStatusChip({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color text;
    String textLabel;

    switch (status) {
      case SecurityStatus.verified:
        bg = const Color(0xFFEAF8F0);
        text = const Color(0xFF2ECC71);
        textLabel = label ?? "Terverifikasi";
        break;
      case SecurityStatus.unverified:
        bg = const Color(0xFFFDEDEC);
        text = const Color(0xFFE74C3C);
        textLabel = label ?? "Belum";
        break;
      case SecurityStatus.pending:
        bg = const Color(0xFFEAF2FB);
        text = AppColors.primary;
        textLabel = label ?? "Pending";
        break;
      case SecurityStatus.unknown:
        bg = AppColors.surfaceAlt;
        text = AppColors.textMuted;
        textLabel = label ?? "Tidak diketahui";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: text.withOpacity(0.25)),
      ),
      child: Text(
        textLabel,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

class SecurityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? footer;

  const SecurityTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: onTap,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textMuted, size: 20),
            ),
            title: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textBody,
                    ),
                  )
                : null,
            trailing: trailing,
          ),
          if (footer != null) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}
