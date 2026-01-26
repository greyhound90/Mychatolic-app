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
    // 1. Ambil data profil (Support Flat JSON dari RPC/View & Nested JSON dari Table)
    Profile? authorData;
    
    // Cek jika data flat (dari View/RPC) tersedia
    // Biasanya view mengembalikan 'full_name' atau 'username' di root
    if (json['full_name'] != null || json['username'] != null) {
       authorData = Profile(
         id: json['user_id']?.toString() ?? '',
         fullName: json['full_name']?.toString() ?? json['username']?.toString() ?? 'User', 
         avatarUrl: json['avatar_url']?.toString(), 
       );
    } 
    // Cek jika data nested (dari Table standard) tersedia
    else if (json['profiles'] != null) {
       // Handle jika profiles adalah List (kadang terjadi di join one-to-many meski limit 1)
       if (json['profiles'] is List && (json['profiles'] as List).isNotEmpty) {
          authorData = Profile.fromJson((json['profiles'] as List).first);
       } 
       // Handle jika profiles adalah Map (join one-to-one standard)
       else if (json['profiles'] is Map<String, dynamic>) {
          authorData = Profile.fromJson(json['profiles']);
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
      content: json['content']?.toString() ?? '',
      createdAt: date,
      author: authorData,
      parentId: json['parent_id']?.toString(),
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
