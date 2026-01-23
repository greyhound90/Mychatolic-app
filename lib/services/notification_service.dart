import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mychatolic_app/main.dart';
import 'package:mychatolic_app/models/radar_event.dart';
import 'package:mychatolic_app/pages/social_chat_detail_page.dart';
import 'package:mychatolic_app/services/social_service.dart';
import 'package:mychatolic_app/pages/post_detail_screen.dart';

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;

  Future<void> init() async {
    _initFuture ??= _initInternal();
    return _initFuture!;
  }

  Future<void> _initInternal() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones();

    // 2. Android Initialization Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Initialization Settings
    // Note: onDidReceiveLocalNotification is deprecated/removed in newer versions.
    // Use onDidReceiveNotificationResponse in initialize() instead.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // 4. Initialize Plugin
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        _handleNotificationTap(response.payload);
      },
    );

    try {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[NOTIF] Failed to request Android notifications permission: $e",
        );
      }
    }
  }

  void _handleNotificationTap(String? payload) async {
    if (kDebugMode) {
      debugPrint("Notification Tapped: $payload");
    }
    if (payload == null) return;

    final navigator = MyChatolicApp.navigatorKey.currentState;
    if (navigator == null) return;

    if (payload.startsWith("chat:")) {
      // Format: "chat:USER_ID" or "chat:CHAT_ID"
      // Assuming payload is opponent ID for simplicity based on request
      final userId = payload.split(":")[1];

      navigator.push(
        MaterialPageRoute(
          builder: (_) => SocialChatDetailPage(
            chatId: "temp", // Let page handle or find chat
            opponentProfile: {
              'id': userId,
              'full_name': 'Chat',
              'avatar_url': null,
            },
          ),
        ),
      );
    } else if (payload.startsWith("post:")) {
      // Format: "post:POST_ID"
      final postId = payload.split(":")[1];

      try {
        // Fetch post data first
        final post = await SocialService().fetchPostById(postId);
        if (post != null) {
          navigator.push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Error navigating to post: $e");
        }
      }
    }
  }

  Future<void> scheduleMassReminder(
    String churchName,
    String dayName,
    String timeStr,
  ) async {
    // Input format example: "17:00"
    try {
      await init();

      final parts = timeStr.split(':');
      if (parts.length < 2) return;

      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      // Calculate Notification Time (Today or Tomorrow)
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      // Candidate time: Today at HH:mm
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Subtract 1 Hour for the reminder itself (Notify before mass starts)
      scheduledDate = scheduledDate.subtract(const Duration(hours: 1));

      // Check if this time has already passed
      if (scheduledDate.isBefore(now)) {
        // If passed, schedule for tomorrow same time
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // Define Notification Details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'mass_reminder_channel',
            'Pengingat Misa',
            channelDescription: 'Notifikasi 1 jam sebelum misa dimulai',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      // Schedule Notif
      // ID uses a simple random/time-based integer to avoid collisions but allow multiple reminders
      final int notificationId = DateTime.now().millisecondsSinceEpoch
          .remainder(100000);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Misa Segera Dimulai',
        'Siap-siap ke $churchName jam $timeStr ($dayName)',
        scheduledDate,
        platformDetails,
        // REQUIRED PARAMETER: AndroidScheduleMode (replaces androidAllowWhileIdle)
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      debugPrint(
        "Notification Scheduled at $scheduledDate (ID: $notificationId)",
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error scheduling notification: $e");
      }
    }
  }

  Future<void> scheduleRadarReminder(RadarEvent event) async {
    await init();

    int notificationIdForRadar(String radarId) {
      var h = 0;
      for (final c in radarId.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff;
      }
      return h % 100000;
    }

    final nowUtc = DateTime.now().toUtc();
    if (!event.eventTimeUtc.isAfter(nowUtc)) {
      if (kDebugMode) {
        debugPrint(
          "[RADAR REMINDER] Event already in the past, skip scheduling.",
        );
      }
      return;
    }

    final reminderUtc = event.eventTimeUtc.subtract(const Duration(hours: 1));
    final id = notificationIdForRadar(event.id);

    const androidDetails = AndroidNotificationDetails(
      'radar_reminder_channel',
      'Pengingat Radar Misa',
      channelDescription: 'Notifikasi 1 jam sebelum misa dimulai',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.cancel(id);

      // If the reminder time has already passed but event is still upcoming,
      // show it immediately as a "starting soon" nudge.
      if (!reminderUtc.isAfter(nowUtc)) {
        await flutterLocalNotificationsPlugin.show(
          id,
          'Misa Sebentar Lagi',
          'Misa di ${event.churchName} akan dimulai segera.',
          platformDetails,
        );
        return;
      }

      final scheduledDate = tz.TZDateTime.from(reminderUtc, tz.local);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'Pengingat Misa',
        'Misa di ${event.churchName} akan dimulai dalam 1 jam.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      if (kDebugMode) {
        debugPrint("[RADAR REMINDER] Scheduled at $scheduledDate (id=$id)");
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[RADAR REMINDER ERROR] $e\n$st");
      }
      throw Exception("Gagal mengatur pengingat");
    }
  }

  // Real-time Notification Listener
  void listenToMyNotifications() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      supabase
          .channel('public:notifications:${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user.id,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              if (newRecord.isNotEmpty) {
                final title = newRecord['title'] ?? 'Notifikasi Baru';
                final body = newRecord['body'] ?? '';
                final notificationId =
                    DateTime.now().millisecondsSinceEpoch % 100000;

                const AndroidNotificationDetails androidDetails =
                    AndroidNotificationDetails(
                      'app_notifications',
                      'Notifikasi Aplikasi',
                      channelDescription: 'Notifikasi umum dari aplikasi',
                      importance: Importance.max,
                      priority: Priority.high,
                      icon: '@mipmap/ic_launcher',
                    );

                const NotificationDetails platformDetails = NotificationDetails(
                  android: androidDetails,
                );

                flutterLocalNotificationsPlugin.show(
                  notificationId,
                  title,
                  body,
                  platformDetails,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error listening to notifications: $e");
      }
    }
  }
}
