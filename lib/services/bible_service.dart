import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/bible_model.dart';
import 'package:flutter/foundation.dart';

class BibleService {
  final _supabase = Supabase.instance.client;

  // --- BOOKS ---
  Future<List<BibleBook>> getBooks({String? testament}) async {
    try {
      final response = await _supabase
          .from('bible_books')
          .select()
          .order('order_number', ascending: true);

      final data = response as List<dynamic>;
      final books = data.map((row) => BibleBook.fromJson(row)).toList();

      final normalized = _normalizeTestament(testament);
      if (normalized == null) return books;

      return books.where((book) {
        return book.testamentKey == normalized;
      }).toList();
    } catch (e) {
      try {
        final response = await _supabase
            .from('bible_books')
            .select()
            .order('id', ascending: true);
        final data = response as List<dynamic>;
        final books = data.map((row) => BibleBook.fromJson(row)).toList();
        final normalized = _normalizeTestament(testament);
        if (normalized == null) return books;
        return books.where((book) => book.testamentKey == normalized).toList();
      } catch (fallbackError) {
        debugPrint("BibleService getBooks error: $fallbackError");
        return [];
      }
    }
  }

  Future<List<int>> getAvailableChapters(int bookId) async {
    try {
      final response = await _supabase
          .from('bible_verses')
          .select('chapter')
          .eq('book_id', bookId)
          .order('chapter', ascending: true);

      final data = response as List<dynamic>;
      final chapters = <int>{};
      for (final row in data) {
        final value = row['chapter'];
        if (value == null) continue;
        final parsed = int.tryParse(value.toString());
        if (parsed != null) chapters.add(parsed);
      }
      final list = chapters.toList()..sort();
      return list;
    } catch (e) {
      debugPrint("BibleService getAvailableChapters error: $e");
      return [];
    }
  }

  // --- VERSES ---
  Future<List<BibleVerse>> getVerses(int bookId, int chapter) async {
    try {
      final verseResponse = await _supabase
          .from('bible_verses')
          .select('book_id, chapter, verse, content')
          .eq('book_id', bookId)
          .eq('chapter', chapter)
          .order('verse', ascending: true);

      final verseData = verseResponse as List<dynamic>;
      final user = _supabase.auth.currentUser;

      final interactionMap = <int, Map<String, dynamic>>{};
      if (user != null) {
        try {
          final interactionResponse = await _supabase
              .from('user_bible_interactions')
              .select()
              .eq('user_id', user.id)
              .eq('book_id', bookId)
              .eq('chapter', chapter);

          final interactions = interactionResponse as List<dynamic>;
          for (final row in interactions) {
            final verseNumber = int.tryParse(
              (row['verse'] ?? row['verse_number']).toString(),
            );
            if (verseNumber == null) continue;
            interactionMap[verseNumber] = row as Map<String, dynamic>;
          }
        } catch (interactionError) {
          debugPrint(
            "BibleService getVerses interaction error: $interactionError",
          );
        }
      }

      return verseData
          .map((row) {
            final verseNumber = int.tryParse(row['verse'].toString()) ?? 0;
            final interaction = interactionMap[verseNumber];
            return BibleVerse.fromJson(row, interaction: interaction);
          })
          .where((verse) => verse.verse > 0)
          .toList();
    } catch (e) {
      debugPrint("BibleService getVerses error: $e");
      return [];
    }
  }

  Future<void> saveInteraction({
    required int bookId,
    required int chapter,
    required int verse,
    String? highlightColor,
    bool clearHighlight = false,
    String? note,
    bool clearNote = false,
    bool? isBookmarked,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception("User not authenticated");
    }

    final payload = <String, dynamic>{
      'user_id': user.id,
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (clearHighlight) {
      payload['highlight_color'] = null;
    } else if (highlightColor != null) {
      payload['highlight_color'] = highlightColor;
    }

    if (clearNote) {
      payload['note'] = null;
    } else if (note != null) {
      payload['note'] = note;
    }

    if (isBookmarked != null) {
      payload['is_bookmarked'] = isBookmarked;
    }

    await _supabase
        .from('user_bible_interactions')
        .upsert(payload, onConflict: 'user_id, book_id, chapter, verse');
  }

  // --- LEGACY (USED BY LITURGY SCHEDULE) ---
  /// Fetches Bible verses text based on a reference string (e.g., "Mrk 1:29-39" or "1 Kor 13:4-8")
  Future<String?> getVersesText(String reference) async {
    const String fallbackMessage =
        "Teks belum tersedia di database. Silakan gunakan Alkitab fisik.";

    try {
      final parts = reference.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) {
        debugPrint(
          "BibleService Parsing Error: Reference '$reference' has too few parts.",
        );
        return fallbackMessage;
      }

      final bookAbbr = parts.sublist(0, parts.length - 1).join(' ');
      final numberPart = parts.last;

      final numberSplits = numberPart.split(':');
      if (numberSplits.length < 2) {
        debugPrint("BibleService Parsing Error: Missing ':' in '$numberPart'");
        return fallbackMessage;
      }

      final chapterNumber = int.tryParse(numberSplits[0]);
      if (chapterNumber == null) {
        debugPrint(
          "BibleService Parsing Error: Invalid chapter number in '$numberPart'",
        );
        return fallbackMessage;
      }

      final verseRange = numberSplits[1];
      int startVerse;
      int endVerse;

      if (verseRange.contains('-')) {
        final verseParts = verseRange.split('-');
        startVerse = int.tryParse(verseParts[0]) ?? 0;
        final endStr = verseParts.length > 1 ? verseParts[1] : '';
        final cleanEnd = endStr.replaceAll(RegExp(r'[^0-9]'), '');
        endVerse = int.tryParse(cleanEnd) ?? startVerse;
      } else {
        final cleanRef = verseRange.replaceAll(RegExp(r'[^0-9]'), '');
        startVerse = int.tryParse(cleanRef) ?? 0;
        endVerse = startVerse;
      }

      if (startVerse == 0) {
        debugPrint("BibleService Parsing Error: Invalid start verse 0");
        return fallbackMessage;
      }

      final bookId = await _resolveBookId(bookAbbr);
      if (bookId == null) {
        return fallbackMessage;
      }

      final response = await _supabase
          .from('bible_verses')
          .select('verse, content')
          .eq('book_id', bookId)
          .eq('chapter', chapterNumber)
          .gte('verse', startVerse)
          .lte('verse', endVerse)
          .order('verse', ascending: true);

      final data = response as List<dynamic>;
      if (data.isEmpty) return fallbackMessage;

      final buffer = StringBuffer();
      for (final row in data) {
        final vNum = row['verse'];
        final text = row['content'];
        buffer.write('[$vNum] $text ');
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('BibleService Exception for reference "$reference": $e');
      return fallbackMessage;
    }
  }

  Future<int?> _resolveBookId(String abbreviationOrName) async {
    try {
      final response = await _supabase
          .from('bible_books')
          .select('id, name, abbreviation')
          .ilike('abbreviation', abbreviationOrName)
          .maybeSingle();

      if (response != null && response['id'] != null) {
        return int.tryParse(response['id'].toString());
      }
    } catch (_) {}

    try {
      final response = await _supabase
          .from('bible_books')
          .select('id, name')
          .ilike('name', abbreviationOrName)
          .maybeSingle();

      if (response != null && response['id'] != null) {
        return int.tryParse(response['id'].toString());
      }
    } catch (_) {}

    return null;
  }

  String? _normalizeTestament(String? testament) {
    if (testament == null) return null;
    final value = testament.trim().toLowerCase();
    if (value.contains('lama') || value.contains('old') || value == 'ot') {
      return 'ot';
    }
    if (value.contains('baru') || value.contains('new') || value == 'nt') {
      return 'nt';
    }
    return value;
  }
}
