import 'package:mychatolic_app/bible/data/datasources/bible_api_client.dart';
import 'package:mychatolic_app/bible/data/models/bible_dtos.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._client);

  final BibleApiClient _client;

  @override
  Future<List<Highlight>> getHighlights() async {
    final json = await _client.get('/bible/highlights');
    return (json as List<dynamic>? ?? [])
        .map((e) => HighlightDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<Highlight> createHighlight({
    required int bookId,
    required int chapter,
    required int verse,
    required String color,
    String? text,
    String? reference,
  }) async {
    final json = await _client.post('/bible/highlights', {
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      'color': color,
      if (text != null) 'text': text,
      if (reference != null) 'reference': reference,
    });
    return HighlightDto.fromJson(json as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> deleteHighlight(String id) => _client.delete('/bible/highlights/$id');

  @override
  Future<List<Bookmark>> getBookmarks() async {
    final json = await _client.get('/bible/bookmarks');
    return (json as List<dynamic>? ?? [])
        .map((e) => BookmarkDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<Bookmark> createBookmark({
    required int bookId,
    required int chapter,
    required int verse,
    String? text,
    String? reference,
  }) async {
    final json = await _client.post('/bible/bookmarks', {
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      if (text != null) 'text': text,
      if (reference != null) 'reference': reference,
    });
    return BookmarkDto.fromJson(json as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> deleteBookmark(String id) => _client.delete('/bible/bookmarks/$id');

  @override
  Future<List<Note>> getNotes() async {
    final json = await _client.get('/bible/notes');
    return (json as List<dynamic>? ?? [])
        .map((e) => NoteDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }

  @override
  Future<Note> createNote({
    required int bookId,
    required int chapter,
    required int verse,
    String? title,
    required String content,
    String? reference,
  }) async {
    final json = await _client.post('/bible/notes', {
      'book_id': bookId,
      'chapter': chapter,
      'verse': verse,
      if (title != null) 'title': title,
      'content': content,
      if (reference != null) 'reference': reference,
    });
    return NoteDto.fromJson(json as Map<String, dynamic>).toEntity();
  }

  @override
  Future<Note> updateNote(String id, {String? title, String? content}) async {
    final json = await _client.put('/bible/notes/$id', {
      if (title != null) 'title': title,
      if (content != null) 'content': content,
    });
    return NoteDto.fromJson(json as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> deleteNote(String id) => _client.delete('/bible/notes/$id');
}
