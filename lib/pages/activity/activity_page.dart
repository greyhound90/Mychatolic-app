import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/core/app_colors.dart';
import 'package:mychatolic_app/widgets/safe_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors
          .primaryBrand, // Using Primary Brand as BG for this page if desired, or scaffold BG
      appBar: AppBar(
        title: const Text(
          "Aktivitas",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('notifications')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .map(
              (list) => list
                  .where((n) => n['user_id'] == _supabase.auth.currentUser?.id)
                  .toList(),
            ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Belum ada aktivitas baru.",
                    style: TextStyle(color: Colors.white38),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: notifications.length,
            separatorBuilder: (context, index) =>
                const Divider(color: Colors.white12),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final actorId = notif['actor_id'];

              // Note: Ideally, we should join 'profiles' via Supabase Select query.
              // For simplicity in StreamBuilder without complex joins, we fetch actor profile individually
              // or rely on a view. Here I will use a simple FutureBuilder for the actor specifically (not most optimized but standard for rapid dev).
              // Better approach: Create a DB View 'notifications_with_profiles'.

              return FutureBuilder<Map<String, dynamic>?>(
                future: _supabase
                    .from('profiles')
                    .select()
                    .eq('id', actorId)
                    .maybeSingle(),
                builder: (context, actorSnap) {
                  final actorData = actorSnap.data;
                  final actorName = actorData?['full_name'] ?? "Seseorang";
                  final actorAvatar = actorData?['avatar_url'];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.black26,
                      child: SafeNetworkImage(
                        imageUrl: actorAvatar,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(24),
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.person,
                        iconColor: Colors.white54,
                        fallbackColor: AppColors.surfaceDark,
                      ),
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: "$actorName ",
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          TextSpan(
                            text:
                                notif['message'] ?? "berinteraksi dengan Anda.",
                          ),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      notif['created_at'] != null
                          ? timeago.format(
                              DateTime.parse(notif['created_at']),
                              locale: 'id',
                            )
                          : "-",
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    trailing: notif['type'] == 'follow'
                        ? ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              minimumSize: const Size(60, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text("Ikuti Balik"),
                          )
                        : null, // Could be post preview image for likes
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
