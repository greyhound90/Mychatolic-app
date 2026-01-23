import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/country.dart';
import 'package:mychatolic_app/models/diocese.dart';
import 'package:mychatolic_app/models/church.dart';
import 'package:mychatolic_app/models/schedule.dart';
import 'package:mychatolic_app/models/article.dart';
import 'package:flutter/foundation.dart';

class MasterDataService {
  final _supabase = Supabase.instance.client;

  // 1. Fetch Countries
  Future<List<Country>> fetchCountries() async {
    try {
      final response = await _supabase.from('countries').select().order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Country.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch countries: $e');
    }
  }

  // 2. Fetch Dioceses
  Future<List<Diocese>> fetchDioceses(String countryId) async {
    try {
      final response = await _supabase
          .from('dioceses')
          .select()
          .eq('country_id', countryId)
          .order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Diocese.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch dioceses: $e');
    }
  }

  // 3. Fetch Churches
  Future<List<Church>> fetchChurches(String dioceseId) async {
    try {
      final response = await _supabase
          .from('churches')
          .select()
          .eq('diocese_id', dioceseId)
          .order('name', ascending: true);
      final data = response as List<dynamic>;
      return data.map((json) => Church.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch churches: $e');
    }
  }

  // 4. Fetch Schedules
  Future<List<Schedule>> fetchSchedules(String churchId) async {
    try {
      final response = await _supabase
          .from('mass_schedules')
          .select()
          .eq('church_id', churchId);

      final List<dynamic> data = response as List<dynamic>;
      final List<Schedule> validSchedules = [];

      for (var json in data) {
        try {
          final schedule = Schedule.fromJson(json);
          validSchedules.add(schedule);
        } catch (e) {
          debugPrint('Error parsing schedule item: $e');
          continue; 
        }
      }

      // Manual Sort: 
      // 1. Day of Week (Ascending 0-6)
      // 2. Time Start (Ascending HH:MM)
      validSchedules.sort((a, b) {
        int dayComp = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayComp != 0) return dayComp;
        return a.timeStart.compareTo(b.timeStart);
      });

      return validSchedules;
    } catch (e) {
      throw Exception('Failed to fetch schedules: $e');
    }
  }

  // 5. Fetch Latest Articles
  Future<List<Article>> fetchLatestArticles() async {
    try {
      final response = await _supabase
          .from('articles')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(20); 
      final data = response as List<dynamic>;
      return data.map((json) => Article.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch articles: $e');
    }
  }

  // 6. Search Locations
  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.isEmpty) return [];
    
    try {
      List<Future<dynamic>> searchTasks = [
        _supabase.from('countries').select('id, name').ilike('name', '%$query%').limit(5),
        _supabase.from('dioceses').select('id, name').ilike('name', '%$query%').limit(5),
        _supabase.from('churches').select('id, name').ilike('name', '%$query%').limit(5),
      ];

      final results = await Future.wait(searchTasks);
      
      final countries = (results[0] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'country', 
      }).toList();
      
      final dioceses = (results[1] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'diocese', 
      }).toList();
      
      final churches = (results[2] as List<dynamic>).map((e) => {
        'id': e['id'].toString(), 
        'name': e['name'] as String, 
        'type': 'church', 
      }).toList();

      return [...countries, ...dioceses, ...churches];
    } catch (e) {
      debugPrint("Search Error: $e");
      return [];
    }
  }

  // --- HELPER DROPDOWNS (Return Map) ---

  Future<List<Map<String, dynamic>>> getCountries() async {
    final response = await _supabase.from('countries').select().order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getDioceses({required String countryId}) async {
    final response = await _supabase
        .from('dioceses')
        .select()
        .eq('country_id', countryId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getChurches({required String dioceseId}) async {
    final response = await _supabase
        .from('churches')
        .select()
        .eq('diocese_id', dioceseId)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // 7. Fetch Church Schedules (Dynamic Map)
  Future<List<Map<String, dynamic>>> fetchChurchSchedules(String churchId) async {
    try {
      final response = await _supabase
          .from('mass_schedules')
          .select()
          .eq('church_id', churchId)
          .order('day_of_week')
          .order('time_start');
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching church schedules: $e");
      return [];
    }
  }
}