import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';

class BibleVersionDto {
  final String id;
  final String name;
  final String? abbreviation;

  BibleVersionDto({required this.id, required this.name, this.abbreviation});

  factory BibleVersionDto.fromJson(Map<String, dynamic> json) {
    return BibleVersionDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      abbreviation: json['abbreviation']?.toString() ?? json['abbr']?.toString(),
    );
  }

  BibleVersion toEntity() => BibleVersion(id: id, name: name, abbreviation: abbreviation);
}

class BibleBookDto {
  final int id;
  final String name;
  final String? category;
  final int orderNumber;
  final bool isDeuterocanonical;
  final String? testament;
  final int? chapterCount;

  BibleBookDto({
    required this.id,
    required this.name,
    required this.orderNumber,
    this.category,
    this.isDeuterocanonical = false,
    this.testament,
    this.chapterCount,
  });

  factory BibleBookDto.fromJson(Map<String, dynamic> json) {
    final order = _toInt(json['order_number']) ?? _toInt(json['order']) ?? _toInt(json['no']) ?? _toInt(json['id']) ?? 0;
    return BibleBookDto(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
      orderNumber: order,
      isDeuterocanonical: json['is_deuterocanonical'] == true || json['deuterocanonical'] == true,
      testament: json['testament']?.toString(),
      chapterCount: _toInt(json['chapter_count']) ?? _toInt(json['chapters']) ?? _toInt(json['total_chapters']) ?? _toInt(json['total_pasal']),
    );
  }

  BibleBook toEntity() {
    return BibleBook(
      id: id,
      name: name,
      orderNumber: orderNumber,
      category: category,
      isDeuterocanonical: isDeuterocanonical,
      testament: testament,
      chapterCount: chapterCount,
    );
  }
}

class BibleVerseDto {
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

  BibleVerseDto({
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

  factory BibleVerseDto.fromJson(Map<String, dynamic> json) {
    return BibleVerseDto(
      bookId: _toInt(json['book_id']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']) ?? 0,
      content: json['content']?.toString() ?? '',
      highlightColor: json['highlight_color']?.toString(),
      note: json['note']?.toString(),
      isBookmarked: json['is_bookmarked'] == true || json['bookmarked'] == true,
      highlightId: json['highlight_id']?.toString(),
      bookmarkId: json['bookmark_id']?.toString(),
      noteId: json['note_id']?.toString(),
    );
  }

  BibleVerse toEntity({
    String? highlightColor,
    String? note,
    bool? isBookmarked,
    String? highlightId,
    String? bookmarkId,
    String? noteId,
  }) {
    return BibleVerse(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      content: content,
      highlightColor: highlightColor ?? this.highlightColor,
      note: note ?? this.note,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      highlightId: highlightId ?? this.highlightId,
      bookmarkId: bookmarkId ?? this.bookmarkId,
      noteId: noteId ?? this.noteId,
    );
  }
}

class HighlightDto {
  final String id;
  final int bookId;
  final int chapter;
  final int verse;
  final String color;
  final String? text;
  final String? reference;

  HighlightDto({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.color,
    this.text,
    this.reference,
  });

  factory HighlightDto.fromJson(Map<String, dynamic> json) {
    return HighlightDto(
      id: json['id']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']) ?? 0,
      color: json['color']?.toString() ?? json['highlight_color']?.toString() ?? '',
      text: json['text']?.toString(),
      reference: json['reference']?.toString(),
    );
  }

  Highlight toEntity() => Highlight(
        id: id,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        color: color,
        text: text,
        reference: reference,
      );
}

class BookmarkDto {
  final String id;
  final int bookId;
  final int chapter;
  final int verse;
  final String? text;
  final String? reference;

  BookmarkDto({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.text,
    this.reference,
  });

  factory BookmarkDto.fromJson(Map<String, dynamic> json) {
    return BookmarkDto(
      id: json['id']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']) ?? 0,
      text: json['text']?.toString(),
      reference: json['reference']?.toString(),
    );
  }

  Bookmark toEntity() => Bookmark(
        id: id,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        text: text,
        reference: reference,
      );
}

class NoteDto {
  final String id;
  final String? title;
  final String content;
  final int bookId;
  final int chapter;
  final int verse;
  final String? reference;
  final DateTime? createdAt;

  NoteDto({
    required this.id,
    required this.content,
    required this.bookId,
    required this.chapter,
    required this.verse,
    this.title,
    this.reference,
    this.createdAt,
  });

  factory NoteDto.fromJson(Map<String, dynamic> json) {
    return NoteDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      content: json['content']?.toString() ?? json['note']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']) ?? 0,
      reference: json['reference']?.toString(),
      createdAt: _toDate(json['created_at']),
    );
  }

  Note toEntity() => Note(
        id: id,
        title: title,
        content: content,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        reference: reference,
        createdAt: createdAt,
      );
}

class ReadingPlanDto {
  final String id;
  final String title;
  final int durationDays;
  final String? theme;
  final String? description;
  final bool isActive;
  final int? currentDay;
  final double? progress;

  ReadingPlanDto({
    required this.id,
    required this.title,
    required this.durationDays,
    this.theme,
    this.description,
    this.isActive = false,
    this.currentDay,
    this.progress,
  });

  factory ReadingPlanDto.fromJson(Map<String, dynamic> json) {
    return ReadingPlanDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      durationDays: _toInt(json['duration_days'] ?? json['days']) ?? 0,
      theme: json['theme']?.toString(),
      description: json['description']?.toString(),
      isActive: json['is_active'] == true,
      currentDay: _toInt(json['current_day'] ?? json['day']),
      progress: _toDouble(json['progress']),
    );
  }

  ReadingPlan toEntity() => ReadingPlan(
        id: id,
        title: title,
        durationDays: durationDays,
        theme: theme,
        description: description,
        isActive: isActive,
        currentDay: currentDay,
        progress: progress,
      );
}

class ReadingPlanDayDto {
  final int day;
  final List<ReadingRefDto> readings;
  final bool isCompleted;
  final String? reflectionPrompt;

  ReadingPlanDayDto({
    required this.day,
    required this.readings,
    this.isCompleted = false,
    this.reflectionPrompt,
  });

  factory ReadingPlanDayDto.fromJson(Map<String, dynamic> json) {
    final list = (json['readings'] as List<dynamic>? ?? [])
        .map((item) => ReadingRefDto.fromJson(item as Map<String, dynamic>))
        .toList();

    return ReadingPlanDayDto(
      day: _toInt(json['day']) ?? 1,
      readings: list,
      isCompleted: json['is_completed'] == true,
      reflectionPrompt: json['reflection_prompt']?.toString(),
    );
  }

  ReadingPlanDay toEntity() => ReadingPlanDay(
        day: day,
        readings: readings.map((e) => e.toEntity()).toList(),
        isCompleted: isCompleted,
        reflectionPrompt: reflectionPrompt,
      );
}

class ReadingRefDto {
  final String reference;
  final int? bookId;
  final int? chapter;
  final int? startVerse;
  final int? endVerse;

  ReadingRefDto({
    required this.reference,
    this.bookId,
    this.chapter,
    this.startVerse,
    this.endVerse,
  });

  factory ReadingRefDto.fromJson(Map<String, dynamic> json) {
    return ReadingRefDto(
      reference: json['reference']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']),
      chapter: _toInt(json['chapter']),
      startVerse: _toInt(json['start_verse'] ?? json['startVerse']),
      endVerse: _toInt(json['end_verse'] ?? json['endVerse']),
    );
  }

  ReadingRef toEntity() => ReadingRef(
        reference: reference,
        bookId: bookId,
        chapter: chapter,
        startVerse: startVerse,
        endVerse: endVerse,
      );
}

class VerseOfTheDayDto {
  final String reference;
  final String text;
  final int? bookId;
  final int? chapter;
  final int? verse;
  final String? versionId;

  VerseOfTheDayDto({
    required this.reference,
    required this.text,
    this.bookId,
    this.chapter,
    this.verse,
    this.versionId,
  });

  factory VerseOfTheDayDto.fromJson(Map<String, dynamic> json) {
    return VerseOfTheDayDto(
      reference: json['reference']?.toString() ?? '',
      text: json['text']?.toString() ?? json['content']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']),
      chapter: _toInt(json['chapter']),
      verse: _toInt(json['verse']),
      versionId: json['version_id']?.toString(),
    );
  }

  VerseOfTheDay toEntity() => VerseOfTheDay(
        reference: reference,
        text: text,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        versionId: versionId,
      );
}

class LastReadDto {
  final int bookId;
  final int chapter;
  final int? verse;
  final String? bookName;
  final DateTime? updatedAt;

  LastReadDto({
    required this.bookId,
    required this.chapter,
    this.verse,
    this.bookName,
    this.updatedAt,
  });

  factory LastReadDto.fromJson(Map<String, dynamic> json) {
    return LastReadDto(
      bookId: _toInt(json['book_id'] ?? json['bookId']) ?? 0,
      chapter: _toInt(json['chapter']) ?? 0,
      verse: _toInt(json['verse']),
      bookName: json['book_name']?.toString(),
      updatedAt: _toDate(json['updated_at']),
    );
  }

  LastRead toEntity() => LastRead(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        updatedAt: updatedAt,
      );
}

class BibleSearchResultDto {
  final String reference;
  final String snippet;
  final int? bookId;
  final int? chapter;
  final int? verse;

  BibleSearchResultDto({
    required this.reference,
    required this.snippet,
    this.bookId,
    this.chapter,
    this.verse,
  });

  factory BibleSearchResultDto.fromJson(Map<String, dynamic> json) {
    return BibleSearchResultDto(
      reference: json['reference']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? json['text']?.toString() ?? '',
      bookId: _toInt(json['book_id'] ?? json['bookId']),
      chapter: _toInt(json['chapter']),
      verse: _toInt(json['verse']),
    );
  }

  BibleVerseSearchResult toEntity() => BibleVerseSearchResult(
        reference: reference,
        snippet: snippet,
        bookId: bookId,
        chapter: chapter,
        verse: verse,
      );
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
