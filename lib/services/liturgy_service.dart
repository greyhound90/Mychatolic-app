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
        return const Color(0xFFC62828);
      case 'green':
        return const Color(0xFF2E7D32);
      case 'purple':
        return const Color(0xFF6A1B9A);
      case 'white':
      case 'gold':
        return const Color(0xFFF5F5F5);
      case 'rose':
      case 'pink':
        return const Color(0xFFEC407A);
      case 'black':
        return const Color(0xFF111111);
      default:
        return Colors.blue; // Safe fallback
    }
  }

  /// Helper for text color on top of liturgical backgrounds
  static Color getLiturgicalTextColor(String? colorCode) {
    switch (colorCode?.toLowerCase()) {
      case 'white':
      case 'gold':
        return const Color(0xFF1A1A1A);
      case 'rose':
      case 'pink':
        return const Color(0xFF1A1A1A);
      case 'black':
        return Colors.white;
      case 'red':
      case 'green':
      case 'purple':
        return Colors.white;
      default:
        return Colors.white;
    }
  }
}
