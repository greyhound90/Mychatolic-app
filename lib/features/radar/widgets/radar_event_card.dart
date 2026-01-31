import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class RadarEventCard extends StatelessWidget {
  final RadarEvent item;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;

  const RadarEventCard({
    super.key,
    required this.item,
    required this.currentUserId,
    this.onTap,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final creator = item.creatorProfile;
    final isHost = item.creatorId == currentUserId;
    final effectiveJoin = isHost ? null : onJoin;
    final churchName = item.churchName;
    final DateTime eventTime = item.eventTimeLocal;
    final String title = item.title;
    final String desc = item.description;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Creator & Time
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    ClipOval(
                      child: SafeNetworkImage(
                        imageUrl: creator?.avatarUrl ?? '',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creator?.fullName ?? 'Umat',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            "Membuat ajakan baru",
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeago.format(
                        item.createdAtUtc?.toLocal() ?? DateTime.now(),
                        locale: 'en_short',
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.grey.shade100),

              // Body: Event Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0088CC).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0088CC).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('MMM').format(eventTime).toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF0088CC),
                            ),
                          ),
                          Text(
                            DateFormat('dd').format(eventTime),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0088CC),
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(eventTime),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0088CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  churchName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              desc,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer: Action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: effectiveJoin ?? onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0088CC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      effectiveJoin != null ? "Ikut Misa" : "Lihat Detail",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
