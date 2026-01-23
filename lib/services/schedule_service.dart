import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mychatolic_app/models/mass_schedule.dart';
import 'package:flutter/foundation.dart';

class ScheduleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches schedules with optional filters. 
  /// Returns a strongly typed `List<MassSchedule>`.
  Future<List<MassSchedule>> fetchSchedules({
    int? dayOfWeek, 
    String? churchId,
    String? dioceseId,
    String? countryId, 
  }) async {
    try {
      // 1. Build Query (Simple: No Joins)
      var query = _supabase
          .from('mass_schedules')
          .select('id, church_id, day_number, start_time, language'); 

      // 2. Apply Filters
      if (dayOfWeek != null) query = query.eq('day_number', dayOfWeek);
      if (churchId != null) query = query.eq('church_id', churchId);
      
      // Note: dioceseId and countryId filters are ignored to prevent join errors

      // 3. Order Results
      final response = await query
          .order('day_number', ascending: true)
          .order('start_time', ascending: true);

      // 4. Convert to List<MassSchedule>
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();

    } catch (e) {
      debugPrint("Schedule Fetch Error: $e");
      return [];
    }
  }

  /// Helper: Get upcoming schedules (Next Mass feature)
  Future<List<MassSchedule>> getUpcomingSchedules() async {
    try {
      final now = DateTime.now();
      final currentDay = now.weekday; 
      final currentTime = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:00";

      final response = await _supabase
          .from('mass_schedules')
          .select('id, church_id, day_number, start_time, language')
          .eq('day_number', currentDay)
          .gte('start_time', currentTime)
          .order('start_time', ascending: true)
          .limit(3);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => MassSchedule.fromJson(json)).toList();
    } catch (e) {
      debugPrint("Error fetching upcoming schedules: $e");
      return [];
    }
  }
}
