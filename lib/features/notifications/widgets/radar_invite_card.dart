
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';

class RadarInviteCard extends StatelessWidget {
  final Map<String, dynamic> invite;
  final Function(bool) onRespond;
  final bool isLoading;

  const RadarInviteCard({
    super.key,
    required this.invite,
    required this.onRespond,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Extract Data safely
    final creatorProfile = invite['profiles'] ?? {}; // From creator_id join
    // Note: The structure from fetchRadarInvites has event details at top level or nested?
    // Looking at fetchRadarInvites implementation:
    // select('..., event:radar_events!inner(*, profiles:creator_id(*))')
    // And map: ...event, schedule_time: ..., user_id: creator_id
    // But 'profiles' is inside 'event'.
    
    // Let's inspect the map logic in RadarService.fetchRadarInvites carefully.
    // It returns: ...event map, plus schedule_time, location_name.
    // The event map contains 'profiles' (creator).
    
    final senderProfile = invite['profiles'] ?? {}; // This might be nested inside 'event' if not flattened
    // Wait, fetchRadarInvites returns: List<Map>.from(response).map((row) { final event = ...; return { ...event, ... }; })
    // In Supabase query: event:radar_events!inner(*, profiles:creator_id(*))
    // So 'event' has 'profiles'.
    // If we flatten 'event' into the result map, then 'profiles' is at the top level of the result map.
    // So `invite['profiles']` should be correct for Creator Profile.

    final String fullName = senderProfile['full_name'] ?? 'Seseorang';
    final String avatarUrl = senderProfile['avatar_url'] ?? '';
    
    final String churchName = invite['church_name'] ?? 'Gereja'; // Flattened from event
    final String? eventTimeStr = invite['event_time'];
    DateTime? eventTime;
    if (eventTimeStr != null) {
      eventTime = DateTime.tryParse(eventTimeStr);
    }
    
    final String description = invite['description'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: SafeNetworkImage(
                  imageUrl: avatarUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: " mengajak Anda Misa di "),
                          TextSpan(
                            text: churchName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0088CC),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Time
                    if (eventTime != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEEE, d MMM • HH:mm', 'id')
                                .format(eventTime.toLocal()),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    // Message/Description
                    if (description.isNotEmpty && description != "Misa Bersama") 
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '"$description"',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Row(
            children: [
              // Decline
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : () => onRespond(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Tolak",
                    style: GoogleFonts.outfit(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Accept
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => onRespond(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0088CC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    "Terima",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
