import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';

class BibleSearchViewModel extends ChangeNotifier {
  BibleSearchViewModel({required this.bibleRepository});

  final BibleRepository bibleRepository;

  bool isLoading = false;
  String? errorMessage;
  List<BibleVerseSearchResult> results = [];
  String? highlightQuery;

  Future<void> searchKeyword(String query) async {
    final trimmed = query.trim();
    highlightQuery = trimmed.isEmpty ? null : trimmed;
    if (trimmed.isEmpty) {
      results = [];
      errorMessage = null;
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      results = await bibleRepository.searchVerses(query: trimmed);
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> lookupReference(String ref) async {
    final trimmed = ref.trim();
    if (trimmed.isEmpty) return;
    highlightQuery = null;
    _setLoading(true);
    try {
      results = await bibleRepository.lookupReference(reference: trimmed);
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> searchTheme(String theme) async {
    highlightQuery = null;
    _setLoading(true);
    try {
      results = await bibleRepository.searchByTheme(theme: theme);
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
