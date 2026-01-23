import 'package:mychatolic_app/models/profile.dart';

class Comment {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Profile? author;

  final String? parentId;
  final List<Comment> replies;
  final int likesCount;
  final bool isLikedByMe;

  Comment({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.author,
    this.parentId,
    this.replies = const [],
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    Profile? authorProfile;
    if (json['profiles'] != null) {
      if (json['profiles'] is List) {
        final List list = json['profiles'];
        if (list.isNotEmpty) {
           authorProfile = Profile.fromJson(list.first);
        }
      } else if (json['profiles'] is Map<String, dynamic>) { // Strict Map check
        authorProfile = Profile.fromJson(json['profiles']);
      } else if (json['profiles'] is Map) { // Dynamic Map Check
        // Try strict cast
        try {
          authorProfile = Profile.fromJson(Map<String, dynamic>.from(json['profiles']));
        } catch (_) {}
      }
    }

    // Defensive Date Parsing
    DateTime date;
    if (json['created_at'] != null) {
      date = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    return Comment(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '', // CRITICAL: Prevent null content crash
      createdAt: date,
      author: authorProfile,
      parentId: json['parent_id']?.toString(), // Handle null
      // replies will be populated manually later or if json has it
      likesCount: json['likes_count'] != null 
          ? (json['likes_count'] as num).toInt() 
          : (json['comment_likes'] as List?)?.length ?? 0, 
      isLikedByMe: json['is_liked_by_me'] ?? false, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
