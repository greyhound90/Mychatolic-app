import 'package:timeago/timeago.dart' as timeago;

class UserPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String userFullName;
  final String caption;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;

  UserPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.userFullName,
    required this.caption,
    required this.imageUrls,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });

  /// CopyWith for optimistic updates
  UserPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userFullName,
    String? caption,
    List<String>? imageUrls,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isSaved,
  }) {
    return UserPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userFullName: userFullName ?? this.userFullName,
      caption: caption ?? this.caption,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  factory UserPost.fromJson(Map<String, dynamic> json) {
    // 1. Profile Logic
    final profile = json['profiles'] ?? {};
    final String uName = profile['username'] ?? 'user';
    final String uAvatar = profile['avatar_url'] ?? '';
    final String uFull = profile['full_name'] ?? 'Umat';

    // 2. Image Logic (Handle string or array)
    List<String> imgs = [];
    if (json['image_url'] != null) {
      if (json['image_url'] is List) {
        imgs = List<String>.from(json['image_url']);
      } else {
        final str = json['image_url'].toString();
        if (str.isNotEmpty) {
          imgs.add(str);
        }
      }
    }

    // 3. Likes/Comments Defaults
    final int lCount = (json['likes_count'] as num?)?.toInt() ?? 0;
    final int cCount = (json['comments_count'] as num?)?.toInt() ?? 0;

    // 4. Is Liked Logic
    bool liked = false;
    if (json['is_liked'] != null) {
      liked = json['is_liked'];
    } else if (json['isLiked'] != null) {
      liked = json['isLiked'];
    }

    // 5. Is Saved Logic
    bool saved = false;
    if (json['is_saved'] != null) {
      saved = json['is_saved'];
    } else if (json['isSaved'] != null) {
      saved = json['isSaved'];
    }

    return UserPost(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: uName,
      userAvatar: uAvatar,
      userFullName: uFull,
      caption: json['caption'] ?? '',
      imageUrls: imgs,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likesCount: lCount,
      commentsCount: cCount,
      isLiked: liked,
      isSaved: saved,
    );
  }

  // Backward Compatibility Getters
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;
  String? get content => caption;
  String get type => imageUrls.isNotEmpty ? 'photo' : 'text';
  bool get isLikedByMe => isLiked;

  // Also recreate author object getter for deep compatibility if needed
  // or simple field access is enough for most views.
  // For ProfilePage/PostCard legacy calls:
  dynamic get author => _AuthorComp(
    id: userId,
    fullName: userFullName,
    avatarUrl: userAvatar,
    role: 'Umat',
  );

  String get timeAgo => timeago.format(createdAt, locale: 'id');
  String get singleImageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';
}

// Helper for backward compatibility with 'post.author.fullName' calls
class _AuthorComp {
  final String id;
  final String fullName;
  final String avatarUrl;
  final String role;
  _AuthorComp({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    required this.role,
  });
}
