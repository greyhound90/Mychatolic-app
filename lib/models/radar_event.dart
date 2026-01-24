import 'package:mychatolic_app/models/profile.dart';

enum RadarParticipantRole { host, member, unknown }

extension RadarParticipantRoleX on RadarParticipantRole {
  String get dbValue {
    switch (this) {
      case RadarParticipantRole.host:
        return 'HOST';
      case RadarParticipantRole.member:
        return 'MEMBER';
      case RadarParticipantRole.unknown:
        return 'UNKNOWN';
    }
  }

  static RadarParticipantRole fromDb(Object? value) {
    final v = value?.toString().trim().toUpperCase();
    switch (v) {
      case 'HOST':
        return RadarParticipantRole.host;
      case 'MEMBER':
        return RadarParticipantRole.member;
      default:
        return RadarParticipantRole.unknown;
    }
  }
}

class RadarParticipant {
  final String id;
  final String radarId;
  final String userId;
  final String status; // e.g. JOINED / INVITED
  final RadarParticipantRole role; // e.g. HOST / MEMBER
  final DateTime? createdAtUtc;

  const RadarParticipant({
    required this.id,
    required this.radarId,
    required this.userId,
    required this.status,
    required this.role,
    this.createdAtUtc,
  });

  factory RadarParticipant.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(Object? v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s)?.toUtc();
    }

    return RadarParticipant(
      id: (json['id'] ?? '').toString(),
      radarId: (json['radar_id'] ?? json['radarId'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      role: RadarParticipantRoleX.fromDb(json['role']),
      createdAtUtc: parseUtc(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'radar_id': radarId,
      'user_id': userId,
      'status': status,
      'role': role.dbValue,
      'created_at': createdAtUtc?.toUtc().toIso8601String(),
    };
  }

  RadarParticipant copyWith({
    String? id,
    String? radarId,
    String? userId,
    String? status,
    RadarParticipantRole? role,
    DateTime? createdAtUtc,
  }) {
    return RadarParticipant(
      id: id ?? this.id,
      radarId: radarId ?? this.radarId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      role: role ?? this.role,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    );
  }
}

class RadarEvent {
  final String id;
  final String title;
  final String description;
  final String churchId;
  final String churchName;
  final DateTime eventTimeUtc;
  final String creatorId;
  final String visibility; // PUBLIC / PRIVATE

  final String status; // e.g. PUBLISHED / DRAFT / CANCELLED

  final int maxParticipants;
  final bool allowMemberInvite;
  final bool requireHostApproval;

  // Joins / Computed
  final int participantCount;
  final Profile? creatorProfile;

  final String? chatRoomId;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  const RadarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.churchId,
    required this.churchName,
    required this.eventTimeUtc,
    required this.creatorId,
    required this.visibility,
    required this.status,
    required this.maxParticipants,
    required this.allowMemberInvite,
    required this.requireHostApproval,
    this.participantCount = 0,
    this.creatorProfile,
    this.chatRoomId,
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  DateTime get eventTimeLocal => eventTimeUtc.toLocal();

  factory RadarEvent.fromJson(Map<String, dynamic> json) {
    DateTime parseUtcRequired(Object? v) {
      final s = v?.toString();
      final parsed = (s == null || s.isEmpty) ? null : DateTime.tryParse(s);
      return (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
    }

    DateTime? parseUtc(Object? v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s)?.toUtc();
    }

    int parseInt(Object? v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? fallback;
    }

    bool parseBool(Object? v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      final s = v.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 't' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'f' || s == 'no') return false;
      return fallback;
    }

    return RadarEvent(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      churchId: (json['church_id'] ?? json['churchId'] ?? '').toString(),
      churchName: (json['church_name'] ?? json['churchName'] ?? '').toString(),
      eventTimeUtc: parseUtcRequired(json['event_time'] ?? json['eventTime']),
      creatorId: (json['creator_id'] ?? json['creatorId'] ?? '').toString(),
      visibility: (json['visibility'] ?? 'PUBLIC').toString(),
      status: (json['status'] ?? '').toString(),
      maxParticipants: parseInt(
        json['max_participants'] ?? json['maxParticipants'],
      ),
      allowMemberInvite: parseBool(
        json['allow_member_invite'] ?? json['allowMemberInvite'],
      ),
      requireHostApproval: parseBool(
        json['require_host_approval'] ?? json['requireHostApproval'],
      ),
      chatRoomId: (json['chat_room_id'] ?? json['chatRoomId'])?.toString(),
      createdAtUtc: parseUtc(json['created_at'] ?? json['createdAt']),
      updatedAtUtc: parseUtc(json['updated_at'] ?? json['updatedAt']),

      // Handle joins
      participantCount: parseInt(
        json['participant_count'] ?? json['participantCount'],
      ),
      creatorProfile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'church_id': churchId,
      'church_name': churchName,
      'event_time': eventTimeUtc.toUtc().toIso8601String(),
      'creator_id': creatorId,
      'visibility': visibility,
      'status': status,
      'max_participants': maxParticipants,
      'allow_member_invite': allowMemberInvite,
      'require_host_approval': requireHostApproval,
      'chat_room_id': chatRoomId,
      'created_at': createdAtUtc?.toUtc().toIso8601String(),
      'updated_at': updatedAtUtc?.toUtc().toIso8601String(),
    };
  }

  RadarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? churchId,
    String? churchName,
    DateTime? eventTimeUtc,
    String? creatorId,
    String? visibility,
    String? status,
    int? maxParticipants,
    bool? allowMemberInvite,
    bool? requireHostApproval,
    int? participantCount,
    Profile? creatorProfile,
    String? chatRoomId,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) {
    return RadarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      churchId: churchId ?? this.churchId,
      churchName: churchName ?? this.churchName,
      eventTimeUtc: eventTimeUtc ?? this.eventTimeUtc,
      creatorId: creatorId ?? this.creatorId,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,

      requireHostApproval: requireHostApproval ?? this.requireHostApproval,
      participantCount: participantCount ?? this.participantCount,
      creatorProfile: creatorProfile ?? this.creatorProfile,
      chatRoomId: chatRoomId ?? this.chatRoomId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
