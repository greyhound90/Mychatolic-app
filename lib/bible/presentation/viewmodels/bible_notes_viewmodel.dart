import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/notes_repository.dart';

class BibleNotesViewModel extends ChangeNotifier {
  BibleNotesViewModel({required this.notesRepository});

  final NotesRepository notesRepository;

  bool isLoading = false;
  String? errorMessage;
  List<Highlight> highlights = [];
  List<Bookmark> bookmarks = [];
  List<Note> notes = [];

  Future<void> loadAll() async {
    _setLoading(true);
    try {
      highlights = await notesRepository.getHighlights();
      bookmarks = await notesRepository.getBookmarks();
      notes = await notesRepository.getNotes();
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
