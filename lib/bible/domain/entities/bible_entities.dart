class BibleVersion {
  final String id;
  final String name;
  final String? abbreviation;

  BibleVersion({
    required this.id,
    required this.name,
    this.abbreviation,
  });
}

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

  bool get isOldTestament {
    final key = testament?.toLowerCase();
    if (key != null) {
      if (key.contains('lama') || key.contains('old') || key == 'ot') return true;
      if (key.contains('baru') || key.contains('new') || key == 'nt') return false;
    }
    return orderNumber <= 46;
  }

  String get displayCategory => (category == null || category!.trim().isEmpty) ? 'Lainnya' : category!;
}

class BibleVerse {
  final int bookId;
  final int chapter;
  final int verse;
  final String content;
  final String? highlightColor;
  final String? note;
  final bool isBookmarked;
  final String? highlightId;
  final String? bookmarkId;
  final String? noteId;

  BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.content,
    this.highlightColor,
    this.note,
    this.isBookmarked = false,
    this.highlightId,
    this.bookmarkId,
    this.noteId,
  });

  BibleVerse copyWith({
    String? highlightColor,
    String? note,
    bool? isBookmarked,
    bool clearHighlight = false,
    bool clearNote = false,
    String? highlightId,
    String? bookmarkId,
    String? noteId,
  }) {
    return BibleVerse(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      content: content,
      highlightColor: clearHighlight ? null : (highlightColor ?? this.highlightColor),
      note: clearNote ? null : (note ?? this.note),
      isBookmarked: isBookmarked ?? this.isBookmarked,
      highlightId: highlightId ?? this.highlightId,
      bookmarkId: bookmarkId ?? this.bookmarkId,
      noteId: noteId ?? this.noteId,
    );
  }
}

class Highlight {
  final String id;
  final int bookId;
  final int chapter;
  final int verse;
  final String color;
  final String? text;
  final String? reference;

  Highlight({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.color,
    this.text,
    this.reference,
  });
}

class Bookmark {
  final String id;
  final int bookId;
  final int chapter;
  final int verse;
  final String? text;
  final String? reference;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.text,
    this.reference,
  });
}

class Note {
  final String id;
  final String? title;
  final String content;
  final int bookId;
  final int chapter;
  final int verse;
  final String? reference;
  final DateTime? createdAt;

  Note({
    required this.id,
    required this.content,
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.title,
    this.reference,
    this.createdAt,
  });
}

class ReadingPlan {
  final String id;
  final String title;
  final int durationDays;
  final String? theme;
  final String? description;
  final bool isActive;
  final int? currentDay;
  final double? progress;

  ReadingPlan({
    required this.id,
    required this.title,
    required this.durationDays,
    this.theme,
    this.description,
    this.isActive = false,
    this.currentDay,
    this.progress,
  });
}

class ReadingPlanDay {
  final int day;
  final List<ReadingRef> readings;
  final bool isCompleted;
  final String? reflectionPrompt;

  ReadingPlanDay({
    required this.day,
    required this.readings,
    this.isCompleted = false,
    this.reflectionPrompt,
  });
}

class ReadingRef {
  final String reference;
  final int? bookId;
  final int? chapter;
  final int? startVerse;
  final int? endVerse;

  ReadingRef({
    required this.reference,
    this.bookId,
    this.chapter,
    this.startVerse,
    this.endVerse,
  });
}

class VerseOfTheDay {
  final String reference;
  final String text;
  final int? bookId;
  final int? chapter;
  final int? verse;
  final String? versionId;

  VerseOfTheDay({
    required this.reference,
    required this.text,
    this.bookId,
    this.chapter,
    this.verse,
    this.versionId,
  });
}

class LastRead {
  final int bookId;
  final int chapter;
  final int? verse;
  final String? bookName;
  final DateTime? updatedAt;

  LastRead({
    required this.bookId,
    required this.chapter,
    this.verse,
    this.bookName,
    this.updatedAt,
  });
}
