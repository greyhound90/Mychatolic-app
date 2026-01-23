class RadarChangeLog {
  final String id;
  final String radarId;
  final String changeType;
  final String description;
  final DateTime createdAtUtc;

  const RadarChangeLog({
    required this.id,
    required this.radarId,
    required this.changeType,
    required this.description,
    required this.createdAtUtc,
  });

  DateTime get createdAtLocal => createdAtUtc.toLocal();

  factory RadarChangeLog.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw.toString())?.toUtc()
        : null;

    return RadarChangeLog(
      id: (json['id'] ?? '').toString(),
      radarId: (json['radar_id'] ?? json['radarId'] ?? '').toString(),
      changeType: (json['change_type'] ?? json['changeType'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdAtUtc:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'radar_id': radarId,
      'change_type': changeType,
      'description': description,
      'created_at': createdAtUtc.toUtc().toIso8601String(),
    };
  }

  RadarChangeLog copyWith({
    String? id,
    String? radarId,
    String? changeType,
    String? description,
    DateTime? createdAtUtc,
  }) {
    return RadarChangeLog(
      id: id ?? this.id,
      radarId: radarId ?? this.radarId,
      changeType: changeType ?? this.changeType,
      description: description ?? this.description,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }
}
