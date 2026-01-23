enum MediaType { image, video }

class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final MediaType mediaType;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  // Author info (optional, usually joined from profiles)
  final String? authorName;
  final String? authorAvatar;

  Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.authorName,
    this.authorAvatar,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    // Handle parsing the joined profile data if it exists
    String? name;
    String? avatar;
    
    // Supabase often returns joined data in 'profiles' or similar key if configured
    if (json['profiles'] != null) {
      final profile = json['profiles'];
      name = profile['full_name'];
      avatar = profile['avatar_url'];
    }

    return Story(
      id: json['id'],
      userId: json['user_id'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'] == 'video' ? MediaType.video : MediaType.image,
      caption: json['caption'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      expiresAt: DateTime.parse(json['expires_at']).toLocal(),
      authorName: name,
      authorAvatar: avatar,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': mediaUrl,
      'media_type': mediaType == MediaType.video ? 'video' : 'image',
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }

  bool get isActive => expiresAt.isAfter(DateTime.now());
}

/// Helper class to group active stories by User
class UserStoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final List<Story> stories;

  UserStoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.stories,
  });
}
