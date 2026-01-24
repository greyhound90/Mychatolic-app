import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy Data
    final List<Map<String, dynamic>> notifications = [
      {
        "user": "Bagas",
        "avatar": null,
        "type": "like",
        "message": "Menyukai postinganmu",
        "time": "2m lalu",
        "isRead": false,
      },
      {
        "user": "Tania",
        "avatar": null,
        "type": "comment",
        "message": "Mengomentari: 'Amin, semoga berkah.'",
        "time": "5m lalu",
        "isRead": false,
      },
      {
        "user": "Kevin",
        "avatar": null,
        "type": "like",
        "message": "Menyukai postinganmu",
        "time": "15m lalu",
        "isRead": true,
      },
      {
        "user": "Suster Maria",
        "avatar": null,
        "type": "comment",
        "message": "Mengomentari: 'Luar biasa, tetap semangat pelayanan.'",
        "time": "1j lalu",
        "isRead": true,
      },
      {
        "user": "Romo Yohanes",
        "avatar": null,
        "type": "like",
        "message": "Menyukai postinganmu",
        "time": "2j lalu",
        "isRead": true,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF2C225B), // Deep Royal Purple
      appBar: AppBar(
        title: const Text(
          "Aktivitas Umat",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2C225B),
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        itemCount: notifications.length,
        padding: const EdgeInsets.symmetric(vertical: 10),
        separatorBuilder: (context, index) =>
            const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final item = notifications[index];
          final isLike = item['type'] == 'like';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            tileColor: item['isRead']
                ? Colors.transparent
                : const Color(0xFF3D3270).withValues(alpha: 0.5),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFFF9F1C),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2C225B),
                child: Text(
                  item['user'][0],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.white),
                children: [
                  TextSpan(
                    text: item['user'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: " "),
                  TextSpan(
                    text: isLike ? "menyukai postinganmu" : "mengomentari: ",
                  ),
                  if (!isLike)
                    TextSpan(
                      text: item['message'].toString().replaceAll(
                        "Mengomentari: ",
                        "",
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  isLike
                      ? Icons.local_fire_department_rounded
                      : Icons.chat_bubble,
                  size: 18,
                  color: isLike ? const Color(0xFFFF9F1C) : Colors.blueAccent,
                ),
                const SizedBox(height: 4),
                Text(
                  item['time'],
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
