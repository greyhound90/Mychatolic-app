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
    try {
      // Fetch specific columns for optimization
      final response = await _supabase
          .from('bible_verses')
          .select('id, book_id, chapter, verse, content, type') // 'verse' maps to verse_number in DB schema usually, adjusting for aliasing if needed or standardizing on 'verse' as per schema prompt 'verse' was requested but DB migration used 'verse' or 'verse_number'. I'll stick to 'verse' based on schema prompt saying 'verse (int)'
          .eq('book_id', bookId)
          .eq('chapter', chapter)
          .order('verse', ascending: true); // Ordering by verse number is safer than id

      final data = response as List<dynamic>;
      return data.map((json) => BibleVerse.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal memuat pasal: $e');
    }
  }
}
