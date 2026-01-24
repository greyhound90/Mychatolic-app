import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/bible/domain/bible_models.dart';
import 'package:mychatolic_app/bible/data/bible_repository.dart';

class BibleViewModel extends ChangeNotifier {
  final BibleRepository _repository;

  BibleViewModel({BibleRepository? repository}) 
      : _repository = repository ?? BibleRepositoryImpl(Supabase.instance.client);

  // Books State
  List<BibleBook> _books = [];
  List<BibleBook> get books => _books;
  bool _isLoadingBooks = false;
  bool get isLoadingBooks => _isLoadingBooks;

  // Reader State
  BibleBook? _currentBook;
  BibleBook? get currentBook => _currentBook;
  
  int _currentChapter = 1;
  int get currentChapter => _currentChapter;

  List<BibleVerse> _verses = [];
  List<BibleVerse> get verses => _verses;
  
  bool _isLoadingChapter = false;
  bool get isLoadingChapter => _isLoadingChapter;
  String? _readerError;
  String? get readerError => _readerError;

  // Settings
  double _fontSize = 16.0;
  double get fontSize => _fontSize;

  void setFontSize(double size) {
    _fontSize = size;
    notifyListeners();
  }

  Future<void> fetchBooks() async {
    if (_books.isNotEmpty) return; // Cache

    _isLoadingBooks = true;
    notifyListeners();

    try {
      _books = await _repository.getBooks();
    } catch (e) {
      debugPrint("Error fetching books: $e");
    } finally {
      _isLoadingBooks = false;
      notifyListeners();
    }
  }

  void openBook(BibleBook book) {
    _currentBook = book;
    // Notify not strictly needed if we navigate immediately, but good practice
  }

  Future<void> loadChapter(int chapter) async {
    if (_currentBook == null) return;

    _currentChapter = chapter;
    _isLoadingChapter = true;
    _readerError = null;
    _verses = []; // Clear previous text to avoid confusion
    notifyListeners();

    try {
      _verses = await _repository.getChapter(_currentBook!.id, chapter);
    } catch (e) {
      _readerError = "Gagal memuat teks. Periksa koneksi internet.";
      debugPrint("Error loading chapter: $e");
    } finally {
      _isLoadingChapter = false;
      notifyListeners();
    }
  }

  void nextChapter() {
    if (_currentBook == null) return;
    if (_currentChapter < _currentBook!.totalChapters) {
      loadChapter(_currentChapter + 1);
    }
  }

  void prevChapter() {
    if (_currentChapter > 1) {
      loadChapter(_currentChapter - 1);
    }
  }
}
