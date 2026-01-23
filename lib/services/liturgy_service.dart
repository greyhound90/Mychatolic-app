import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiturgyModel {
  final DateTime date;
  final String color; // e.g., 'green', 'white', 'red', 'purple'
  final String feastName;
  final Map<String, dynamic> readings;

  LiturgyModel({
    required this.date,
    required this.color,
    required this.feastName,
    required this.readings,
  });

  factory LiturgyModel.fromJson(Map<String, dynamic> json) {
    return LiturgyModel(
      date: DateTime.parse(json['date']),
      color: json['color'] ?? 'green',
      feastName: json['feast_name'] ?? '',
      readings: json['readings'] ?? {},
    );
  }
}

class LiturgyService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch liturgy for a specific date (YYYY-MM-DD)
  Future<LiturgyModel?> getLiturgyByDate(DateTime date) async {
    try {
      final dateString = date.toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('daily_liturgy')
          .select()
          .eq('date', dateString)
          .maybeSingle(); // Returns null if no record found

      if (response == null) {
        return null; 
      }

      return LiturgyModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching liturgy: $e');
      return null;
    }
  }

  /// Helper to convert DB color string to Flutter Color
  static Color getLiturgicalColor(String? colorCode) {
    switch (colorCode?.toLowerCase()) {
      case 'red':
        return Colors.red[800]!;
      case 'green':
        return Colors.green[800]!;
      case 'purple':
        return Colors.purple[800]!;
      case 'white':
      case 'gold':
        return Colors.amber[100]!; // Gold/Yellowish for visible 'White' theme
      case 'rose':
      case 'pink':
        return Colors.pink[300]!; 
      default:
        return Colors.blue; // Safe fallback
    }
  }
  
  /// Helper for text color on top of liturgical backgrounds
  static Color getLiturgicalTextColor(String? colorCode) {
     switch (colorCode?.toLowerCase()) {
      case 'white':
      case 'gold':
        return Colors.brown[900]!; // Dark text for light background
      default:
        return Colors.white; // Light text for dark backgrounds (Red, Green, Purple)
    }
  }
}
