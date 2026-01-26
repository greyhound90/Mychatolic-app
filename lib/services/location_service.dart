
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Get Countries
  Future<List<Map<String, dynamic>>> getCountries() async {
    try {
      final response = await _supabase
          .from('countries')
          .select('id, name')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data negara: $e');
    }
  }

  // 2. Get Dioceses by Country
  Future<List<Map<String, dynamic>>> getDioceses(String countryId) async {
    try {
      final response = await _supabase
          .from('dioceses')
          .select('id, name')
          .eq('country_id', countryId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data keuskupan: $e');
    }
  }

  // 3. Get Churches by Diocese
  Future<List<Map<String, dynamic>>> getChurches(String dioceseId) async {
    try {
      final response = await _supabase
          .from('churches')
          .select('id, name')
          .eq('diocese_id', dioceseId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal mengambil data gereja: $e');
    }
  }
  
  // Helper: Get Name by ID (to sync string columns just in case)
  Future<String?> getNameById(String table, String id) async {
      try {
        final res = await _supabase.from(table).select('name').eq('id', id).single();
        return res['name'] as String?;
      } catch (e) {
        return null; 
      }
  }
}
