class BibleBook {
  final int id;
  final String name;
  final String? category;
  final int orderNumber;
  final bool isDeuterocanonical;
  final String? testament;
  final int? chapterCount;

  BibleBook({
    required this.id,
    required this.name,
    required this.orderNumber,
    this.category,
    this.isDeuterocanonical = false,
    this.testament,
    this.chapterCount,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final order =
        _toInt(json['order_number']) ??
        _toInt(json['order']) ??
        _toInt(json['no']) ??
        _toInt(json['id']) ??
        0;

    return BibleBook(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
      orderNumber: order,
      isDeuterocanonical:
          json['is_deuterocanonical'] == true ||
          json['deuterocanonical'] == true,
      testament: json['testament']?.toString(),
      chapterCount:
          _toInt(json['chapter_count']) ??
          _toInt(json['chapters']) ??
          _toInt(json['total_chapters']) ??
          _toInt(json['total_pasal']),
    );
  }

  bool get isOldTestament {
    final key = testament?.toLowerCase();
    if (key != null) {
      if (key.contains('lama') || key.contains('old') || key == 'ot') {
        return true;
      }
      if (key.contains('baru') || key.contains('new') || key == 'nt') {
        return false;
      }
    }
    return orderNumber <= 46;
  }

  String get testamentKey => isOldTestament ? 'ot' : 'nt';

  String get displayCategory =>
      (category == null || category!.trim().isEmpty) ? 'Lainnya' : category!;
}

class BibleVerse {
  final int bookId;
  final int chapter;
  final int verse;
  final String content;
  final String? highlightColor;
  final String? note;
  final bool isBookmarked;
  final String? interactionId;

  BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.content,
    this.highlightColor,
    this.note,
    this.isBookmarked = false,
    this.interactionId,
  });

  factory BibleVerse.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? interaction,
  }) {
    return BibleVerse(
      bookId: _toInt(json['book_id']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']) ?? 0,
      content: json['content']?.toString() ?? '',
      highlightColor: interaction?['highlight_color']?.toString(),
      note: interaction?['note']?.toString(),
      isBookmarked:
          interaction?['is_bookmarked'] == true ||
          interaction?['bookmarked'] == true,
      interactionId: interaction?['id']?.toString(),
    );
  }

  BibleVerse copyWith({
    String? highlightColor,
    String? note,
    bool? isBookmarked,
    bool clearHighlight = false,
    bool clearNote = false,
  }) {
    return BibleVerse(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      content: content,
      highlightColor: clearHighlight
          ? null
          : (highlightColor ?? this.highlightColor),
      note: clearNote ? null : (note ?? this.note),
      isBookmarked: isBookmarked ?? this.isBookmarked,
      interactionId: interactionId,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
