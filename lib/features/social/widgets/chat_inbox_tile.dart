import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mychatolic_app/core/design_tokens.dart';
import 'package:mychatolic_app/l10n/gen/app_localizations.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class ChatInboxTile extends StatelessWidget {
  final Map<String, dynamic> chatData;
  final Map<String, dynamic>? partnerProfile;
  final String previewText;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLeaveGroup;
  final bool isOnline;

  const ChatInboxTile({
    super.key,
    required this.chatData,
    required this.partnerProfile,
    required this.previewText,
    required this.unreadCount,
    required this.onTap,
    required this.onDelete,
    this.onLeaveGroup,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isGroup = chatData['is_group'] == true;
    final updatedAt = chatData['updated_at'];
    final time = updatedAt != null
        ? timeago.format(DateTime.parse(updatedAt), locale: 'id')
        : '';
    final name = isGroup
        ? (chatData['group_name'] ?? 'Grup').toString()
        : (partnerProfile?['full_name'] ?? 'User').toString();
    final avatarUrl = isGroup
        ? (chatData['group_avatar_url'] ?? chatData['avatar_url'])
        : partnerProfile?['avatar_url'];
    final isUnread = unreadCount > 0;

    return Dismissible(
      key: ValueKey(chatData['id']),
      background: _SwipeBackground(
        icon: Icons.delete,
        label: t.chatDeleteConfirm,
        color: AppColors.danger,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: isGroup
          ? _SwipeBackground(
              icon: Icons.exit_to_app,
              label: t.chatLeaveGroup,
              color: Colors.orange,
              alignment: Alignment.centerRight,
            )
          : const SizedBox.shrink(),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _confirmDelete(context, t);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          if (!isGroup) return false;
          if (onLeaveGroup == null) {
            await _showInfo(context, t.chatLeaveUnavailable);
            return false;
          }
          _confirmLeave(context, t);
          return false;
        }
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onTap,
          onLongPress: () => _confirmDelete(context, t),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color:
                    isUnread ? AppColors.primary.withOpacity(0.25) : AppColors.border,
              ),
              boxShadow: AppShadows.level1,
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceAlt,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SafeNetworkImage(
                          imageUrl: avatarUrl,
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          fallbackIcon: isGroup ? Icons.groups : Icons.person,
                        ),
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isUnread ? AppColors.textBody : AppColors.textMuted,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isUnread) _UnreadBadge(count: unreadCount),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppLocalizations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chatDeleteTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(t.chatDeleteMessage, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.chatDeleteCancel, style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.chatDeleteConfirm, style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  Future<void> _confirmLeave(BuildContext context, AppLocalizations t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chatLeaveGroupTitle, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(t.chatLeaveGroupMessage, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.chatDeleteCancel, style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.chatLeaveGroupConfirm, style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) onLeaveGroup?.call();
  }

  Future<void> _showInfo(BuildContext context, String message) async {
    final t = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.commonInfo, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.commonOk, style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        display,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) Icon(icon, color: color),
          if (isLeft) const SizedBox(width: 8),
          Text(label, style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600)),
          if (!isLeft) const SizedBox(width: 8),
          if (!isLeft) Icon(icon, color: color),
        ],
      ),
    );
  }
}
