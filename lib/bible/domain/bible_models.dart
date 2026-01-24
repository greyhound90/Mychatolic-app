enum BibleBookGroup {
  oldTestament,
  newTestament,
  deuterocanonical
}

enum BibleVerseType {
  text,
  heading,
  footnote
}

class BibleBook {
  final int id;
  final String name;
  final String abbreviation;
  final BibleBookGroup group;
  final int totalChapters;
  final int orderIndex;

  BibleBook({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.group,
    required this.totalChapters,
    required this.orderIndex,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    return BibleBook(
      id: json['id'],
      name: json['name'],
      abbreviation: json['abbreviation'],
      group: _parseGroup(json['grouping'] ?? json['group']), // Handle both cases
      totalChapters: json['total_chapters'],
      orderIndex: json['order_index'],
    );
  }

  static BibleBookGroup _parseGroup(String group) {
    switch (group) {
      case 'OldTestament':
        return BibleBookGroup.oldTestament;
      case 'NewTestament':
        return BibleBookGroup.newTestament;
      case 'Deuterocanonical':
        return BibleBookGroup.deuterocanonical;
      default:
        return BibleBookGroup.oldTestament;
    }
  }
}

class BibleVerse {
  final String id;
  final int bookId;
  final int chapter;
  final int verseNumber;
  final String content;
  final BibleVerseType type;

  BibleVerse({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verseNumber,
    required this.content,
    required this.type,
  });

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      id: json['id'].toString(),
      bookId: json['book_id'],
      chapter: json['chapter'],
      verseNumber: json['verse'] ?? json['verse_number'] ?? 0,
      content: json['content'],
      type: _parseType(json['type']),
    );
  }

  static BibleVerseType _parseType(String? type) {
    switch (type) {
      case 'heading':
        return BibleVerseType.heading;
      case 'footnote':
        return BibleVerseType.footnote;
      default:
        return BibleVerseType.text;
    }
  }
}
