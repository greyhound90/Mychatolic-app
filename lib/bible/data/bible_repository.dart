import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/bible/domain/bible_models.dart';

abstract class BibleRepository {
  Future<List<BibleBook>> getBooks();
  Future<List<BibleVerse>> getChapter(int bookId, int chapter);
}

class BibleRepositoryImpl implements BibleRepository {
  final SupabaseClient _supabase;

  BibleRepositoryImpl(this._supabase);

  @override
  Future<List<BibleBook>> getBooks() async {
    try {
      final response = await _supabase
          .from('bible_books')
          .select()
          .order('order_index', ascending: true);
      
      final data = response as List<dynamic>;
      return data.map((json) => BibleBook.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal memuat daftar kitab: $e');
    }
  }

  @override
  Future<List<BibleVerse>> getChapter(int bookId, int chapter) async {
    print(">>> FETCHING Bible Chapter: BookId=$bookId, Chapter=$chapter");
    try {
      // Fetch ALL columns to avoid "Column does not exist" errors
      // and ensure we don't accidentally miss 'verse' or 'verse_number'
      final response = await _supabase
          .from('bible_verses')
          .select()
          .eq('book_id', bookId)
          .eq('chapter', chapter)
          .order('verse_number', ascending: true);

      final data = response as List<dynamic>;
      print(">>> FETCH SUCCESS: Retrieved ${data.length} verses");
      
      return data.map((json) => BibleVerse.fromJson(json)).toList();
    } catch (e) {
      print(">>> FETCH ERROR: $e");
      throw Exception('Gagal memuat pasal: $e');
    }
  }
}
