class NotificationItem {
  final String id;
  final String type; // 'like', 'comment', 'consilium'
  final String? actorName;
  final String? actorAvatar;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime createdAt;
  final String? relatedId; // Post ID or Request ID

  NotificationItem({
    required this.id,
    required this.type,
    this.actorName,
    this.actorAvatar,
    required this.title,
    this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      type: json['type'] as String,
      actorName: json['actor_name'] as String?,
      actorAvatar: json['actor_avatar'] as String?,
      title: json['title'] as String,
      body: json['body'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      relatedId: json['related_id'] as String?,
    );
  }
}
