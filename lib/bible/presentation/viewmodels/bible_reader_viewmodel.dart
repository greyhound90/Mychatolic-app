import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';
import 'package:mychatolic_app/bible/domain/repositories/notes_repository.dart';

class BibleReaderViewModel extends ChangeNotifier {
  BibleReaderViewModel({
    required this.bibleRepository,
    required this.notesRepository,
  });

  final BibleRepository bibleRepository;
  final NotesRepository notesRepository;

  bool isLoading = false;
  String? errorMessage;

  List<BibleBook> books = [];
  List<BibleVersion> versions = [];
  BibleVersion? selectedVersion;
  BibleBook? selectedBook;
  VerseOfTheDay? verseOfTheDay;
  LastRead? lastRead;

  String testament = 'ot';
  bool showDeuterocanonical = true;
  int currentChapter = 1;
  List<BibleVerse> verses = [];

  Future<void> init({
    int? bookId,
    int? chapter,
    bool loadVerseOfDay = true,
  }) async {
    _setLoading(true);
    try {
      versions = await bibleRepository.getVersions();
      books = await bibleRepository.getBooks();
      selectedVersion = versions.isNotEmpty ? versions.first : null;
      if (loadVerseOfDay) {
        verseOfTheDay = await bibleRepository.getVerseOfTheDay();
      }
      lastRead = await bibleRepository.getLastRead();
      _resolveInitialSelection(bookId: bookId, chapter: chapter);
      await loadVerses();
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _resolveInitialSelection({int? bookId, int? chapter}) {
    if (books.isEmpty) return;
    BibleBook initial;
    if (bookId != null) {
      initial = books.firstWhere(
        (b) => b.id == bookId,
        orElse: () => books.first,
      );
    } else if (lastRead != null) {
      initial = books.firstWhere(
        (b) => b.id == lastRead!.bookId,
        orElse: () => books.first,
      );
    } else {
      initial = books.first;
    }
    selectedBook = initial;
    testament = initial.isOldTestament ? 'ot' : 'nt';
    currentChapter = chapter ?? lastRead?.chapter ?? 1;
  }

  Future<void> loadVerses({bool refresh = false}) async {
    final book = selectedBook;
    if (book == null) return;

    _setLoading(true);
    try {
      verses = await bibleRepository.getVerses(
        bookId: book.id,
        chapter: currentChapter,
        versionId: selectedVersion?.id,
        refresh: refresh,
      );
      await bibleRepository.updateLastRead(
        bookId: book.id,
        chapter: currentChapter,
        verse: null,
        versionId: selectedVersion?.id,
      );
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void changeTestament(String value) {
    testament = value;
    final available = books.where((book) {
      final matchesTestament = value == 'ot'
          ? book.isOldTestament
          : !book.isOldTestament;
      if (!matchesTestament) return false;
      if (!showDeuterocanonical && book.isDeuterocanonical) return false;
      return true;
    }).toList()..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    if (available.isNotEmpty) {
      selectedBook = available.first;
      currentChapter = 1;
      loadVerses();
    }
    notifyListeners();
  }

  void toggleDeuterocanonical(bool value) {
    showDeuterocanonical = value;
    if (!value && selectedBook?.isDeuterocanonical == true) {
      final available = books.where((book) {
        final matchesTestament = testament == 'ot'
            ? book.isOldTestament
            : !book.isOldTestament;
        if (!matchesTestament) return false;
        if (book.isDeuterocanonical) return false;
        return true;
      }).toList()..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
      if (available.isNotEmpty) {
        selectedBook = available.first;
        currentChapter = 1;
        loadVerses();
      }
    }
    notifyListeners();
  }

  void setBook(BibleBook book) {
    setLocation(book: book, chapter: 1);
  }

  void setChapter(int chapter) {
    currentChapter = chapter;
    loadVerses();
    notifyListeners();
  }

  void setLocation({required BibleBook book, required int chapter}) {
    selectedBook = book;
    testament = book.isOldTestament ? 'ot' : 'nt';
    currentChapter = chapter;
    loadVerses();
    notifyListeners();
  }

  void setVersion(BibleVersion version) {
    selectedVersion = version;
    loadVerses();
    notifyListeners();
  }

  Future<void> applyHighlight(BibleVerse verse, String color) async {
    try {
      final highlight = await notesRepository.createHighlight(
        bookId: verse.bookId,
        chapter: verse.chapter,
        verse: verse.verse,
        color: color,
        text: verse.content,
        reference: _referenceFor(verse),
      );
      _updateVerse(
        verse,
        highlightColor: highlight.color,
        highlightId: highlight.id,
      );
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  Future<void> toggleBookmark(BibleVerse verse) async {
    try {
      if (verse.isBookmarked && verse.bookmarkId != null) {
        await notesRepository.deleteBookmark(verse.bookmarkId!);
        _updateVerse(verse, isBookmarked: false, bookmarkId: null);
        return;
      }

      final bookmark = await notesRepository.createBookmark(
        bookId: verse.bookId,
        chapter: verse.chapter,
        verse: verse.verse,
        text: verse.content,
        reference: _referenceFor(verse),
      );
      _updateVerse(verse, isBookmarked: true, bookmarkId: bookmark.id);
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  Future<void> saveNote(BibleVerse verse, String content) async {
    try {
      if (verse.noteId != null) {
        final note = await notesRepository.updateNote(
          verse.noteId!,
          content: content,
        );
        _updateVerse(verse, note: note.content, noteId: note.id);
        return;
      }
      final note = await notesRepository.createNote(
        bookId: verse.bookId,
        chapter: verse.chapter,
        verse: verse.verse,
        content: content,
        reference: _referenceFor(verse),
      );
      _updateVerse(verse, note: note.content, noteId: note.id);
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  void _updateVerse(
    BibleVerse verse, {
    String? highlightColor,
    bool? isBookmarked,
    String? note,
    String? highlightId,
    String? bookmarkId,
    String? noteId,
  }) {
    verses = verses.map((v) {
      if (v.verse == verse.verse) {
        return v.copyWith(
          highlightColor: highlightColor,
          isBookmarked: isBookmarked,
          note: note,
          highlightId: highlightId,
          bookmarkId: bookmarkId,
          noteId: noteId,
        );
      }
      return v;
    }).toList();
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  String _referenceFor(BibleVerse verse) {
    final bookName = selectedBook?.name ?? '';
    return '$bookName ${verse.chapter}:${verse.verse}';
  }
}
