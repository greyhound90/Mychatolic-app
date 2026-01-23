import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

abstract class BibleRepository {
  Future<List<BibleVersion>> getVersions({bool refresh = false});
  Future<List<BibleBook>> getBooks({String? canonType, bool refresh = false});
  Future<List<BibleVerse>> getVerses({
    required int bookId,
    required int chapter,
    String? versionId,
    bool refresh = false,
  });

  Future<List<BibleVerseSearchResult>> searchVerses({
    required String query,
    String? versionId,
  });

  Future<List<BibleVerseSearchResult>> lookupReference({
    required String reference,
    String? versionId,
  });

  Future<List<BibleVerseSearchResult>> searchByTheme({
    required String theme,
    String? versionId,
  });

  Future<VerseOfTheDay?> getVerseOfTheDay({bool refresh = false});
  Future<LastRead?> getLastRead({bool refresh = false});
  Future<void> updateLastRead({
    required int bookId,
    required int chapter,
    int? verse,
    String? versionId,
  });
}

class BibleVerseSearchResult {
  final String reference;
  final String snippet;
  final int? bookId;
  final int? chapter;
  final int? verse;

  BibleVerseSearchResult({
    required this.reference,
    required this.snippet,
    this.bookId,
    this.chapter,
    this.verse,
  });
}
