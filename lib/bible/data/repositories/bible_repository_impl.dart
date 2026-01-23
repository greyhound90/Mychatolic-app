import 'package:mychatolic_app/bible/data/datasources/bible_api_client.dart';
import 'package:mychatolic_app/bible/data/models/bible_dtos.dart';
import 'package:mychatolic_app/bible/core/lru_cache.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';

class BibleRepositoryImpl implements BibleRepository {
  BibleRepositoryImpl(this._client);

  final BibleApiClient _client;

  final Map<String, List<BibleVersion>> _versionsCache = {};
  final Map<String, List<BibleBook>> _booksCache = {};
  final LruCache<String, List<BibleVerse>> _versesCache = LruCache(maxEntries: 60);

  VerseOfTheDay? _verseOfTheDay;
  DateTime? _verseOfTheDayDate;
  LastRead? _lastRead;

  @override
  Future<List<BibleVersion>> getVersions({bool refresh = false}) async {
    if (!refresh && _versionsCache.containsKey('all')) {
      return _versionsCache['all']!;
    }
    try {
      final json = await _client.get('/bible/versions');
      final list = (json as List<dynamic>? ?? [])
          .map((e) => BibleVersionDto.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
      _versionsCache['all'] = list;
      return list;
    } catch (e) {
      final cached = _versionsCache['all'];
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<List<BibleBook>> getBooks({String? canonType, bool refresh = false}) async {
    final key = canonType ?? 'all';
    if (!refresh && _booksCache.containsKey(key)) {
      return _booksCache[key]!;
    }
    try {
      final json = await _client.get('/bible/books', query: {
        if (canonType != null) 'canon_type': canonType,
      });
      final list = (json as List<dynamic>? ?? [])
          .map((e) => BibleBookDto.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
      _booksCache[key] = list;
      return list;
    } catch (e) {
      final cached = _booksCache[key];
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<List<BibleVerse>> getVerses({
    required int bookId,
    required int chapter,
    String? versionId,
    bool refresh = false,
  }) async {
    final cacheKey = '${versionId ?? 'default'}-$bookId-$chapter';
    final cached = !refresh ? _versesCache.get(cacheKey) : null;
    if (cached != null) return cached;
    final fallback = _versesCache.peek(cacheKey);
    try {
      final json = await _client.get('/bible/verses', query: {
        'book_id': bookId,
        'chapter': chapter,
        if (versionId != null) 'version_id': versionId,
      });
      final list = (json as List<dynamic>? ?? [])
          .map((e) => BibleVerseDto.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
      _versesCache.set(cacheKey, list);
      return list;
    } catch (e) {
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  @override
  Future<List<BibleVerseSearchResult>> searchVerses({required String query, String? versionId}) async {
    final json = await _client.get('/bible/search', query: {
      'query': query,
      if (versionId != null) 'version_id': versionId,
    });
    return (json as List<dynamic>? ?? [])
        .map((e) => BibleSearchResultDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<List<BibleVerseSearchResult>> lookupReference({required String reference, String? versionId}) async {
    final json = await _client.get('/bible/lookup', query: {
      'ref': reference,
      if (versionId != null) 'version_id': versionId,
    });
    return (json as List<dynamic>? ?? [])
        .map((e) => BibleSearchResultDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<List<BibleVerseSearchResult>> searchByTheme({required String theme, String? versionId}) async {
    final json = await _client.get('/bible/theme', query: {
      'theme': theme,
      if (versionId != null) 'version_id': versionId,
    });
    return (json as List<dynamic>? ?? [])
        .map((e) => BibleSearchResultDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<VerseOfTheDay?> getVerseOfTheDay({bool refresh = false}) async {
    final now = DateTime.now();
    if (!refresh && _verseOfTheDay != null && _verseOfTheDayDate != null) {
      if (_verseOfTheDayDate!.year == now.year && _verseOfTheDayDate!.month == now.month && _verseOfTheDayDate!.day == now.day) {
        return _verseOfTheDay;
      }
    }
    try {
      final json = await _client.get('/bible/verse-of-the-day');
      if (json == null) return null;
      final verse = VerseOfTheDayDto.fromJson(json as Map<String, dynamic>).toEntity();
      _verseOfTheDay = verse;
      _verseOfTheDayDate = now;
      return verse;
    } catch (e) {
      if (_verseOfTheDay != null) return _verseOfTheDay;
      rethrow;
    }
  }

  @override
  Future<LastRead?> getLastRead({bool refresh = false}) async {
    if (!refresh && _lastRead != null) return _lastRead;
    try {
      final json = await _client.get('/bible/last-read');
      if (json == null) return null;
      _lastRead = LastReadDto.fromJson(json as Map<String, dynamic>).toEntity();
      return _lastRead;
    } catch (e) {
      if (_lastRead != null) return _lastRead;
      rethrow;
    }
  }

  @override
  Future<void> updateLastRead({required int bookId, required int chapter, int? verse, String? versionId}) async {
    await _client.post('/bible/last-read', {
      'book_id': bookId,
      'chapter': chapter,
      if (verse != null) 'verse': verse,
      if (versionId != null) 'version_id': versionId,
    });
    _lastRead = LastRead(
      bookId: bookId,
      chapter: chapter,
      verse: verse,
      updatedAt: DateTime.now(),
    );
  }
}
