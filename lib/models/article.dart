class Article {
  final int id;
  final String title;
  final String? content;
  final String? imageUrl;
  final String? category;
  final bool isPublished;
  final DateTime createdAt;

  Article({
    required this.id,
    required this.title,
    this.content,
    this.imageUrl,
    this.category,
    required this.isPublished,
    required this.createdAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'category': category,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
