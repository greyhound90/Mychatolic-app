class RadarInvite {
  final String id;
  final String radarId;
  final String inviterId;
  final String inviteeId;
  final String status;
  final DateTime createdAtUtc;

  const RadarInvite({
    required this.id,
    required this.radarId,
    required this.inviterId,
    required this.inviteeId,
    required this.status,
    required this.createdAtUtc,
  });

  DateTime get createdAtLocal => createdAtUtc.toLocal();

  factory RadarInvite.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString())?.toUtc()
        : null;

    return RadarInvite(
      id: (json['id'] ?? '').toString(),
      radarId: (json['radar_id'] ?? json['radarId'] ?? '').toString(),
      inviterId: (json['inviter_id'] ?? json['inviterId'] ?? '').toString(),
      inviteeId: (json['invitee_id'] ?? json['inviteeId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAtUtc:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'radar_id': radarId,
      'inviter_id': inviterId,
      'invitee_id': inviteeId,
      'status': status,
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  RadarInvite copyWith({
    String? id,
    String? radarId,
    String? inviterId,
    String? inviteeId,
    String? status,
    DateTime? createdAtUtc,
  }) {
    return RadarInvite(
      id: id ?? this.id,
      radarId: radarId ?? this.radarId,
      inviterId: inviterId ?? this.inviterId,
      inviteeId: inviteeId ?? this.inviteeId,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }
}
