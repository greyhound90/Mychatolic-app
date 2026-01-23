import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

abstract class NotesRepository {
  Future<List<Highlight>> getHighlights();
  Future<Highlight> createHighlight({
    required int bookId,
    required int chapter,
    required int verse,
    required String color,
    String? text,
    String? reference,
  });
  Future<void> deleteHighlight(String id);

  Future<List<Bookmark>> getBookmarks();
  Future<Bookmark> createBookmark({
    required int bookId,
    required int chapter,
    required int verse,
    String? text,
    String? reference,
  });
  Future<void> deleteBookmark(String id);

  Future<List<Note>> getNotes();
  Future<Note> createNote({
    required int bookId,
    required int chapter,
    required int verse,
    String? title,
    required String content,
    String? reference,
  });
  Future<Note> updateNote(String id, {String? title, String? content});
  Future<void> deleteNote(String id);
}
