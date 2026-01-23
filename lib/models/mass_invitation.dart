class MassInvitation {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String churchName;
  final DateTime scheduleTime;
  final String? message;
  final String status;
  final DateTime createdAt;

  MassInvitation({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.churchName,
    required this.scheduleTime,
    this.message,
    required this.status,
    required this.createdAt,
  });

  factory MassInvitation.fromJson(Map<String, dynamic> json) {
    // Handle nested sender profile data safely
    final senderData = json['sender'];
    final Map<String, dynamic> senderMap = (senderData is Map<String, dynamic>) ? senderData : {};

    return MassInvitation(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: senderMap['full_name']?.toString() ?? 'Teman',
      senderAvatar: senderMap['avatar_url']?.toString(),
      churchName: json['church_name']?.toString() ?? 'Gereja',
      scheduleTime: DateTime.tryParse(json['schedule_time']?.toString() ?? '') ?? DateTime.now(),
      message: json['message']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
