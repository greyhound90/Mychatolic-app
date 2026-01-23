import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> submitReport({
    required String targetEntity,
    required String targetId,
    required String reason,
    required String description,
  }) async {
    final reporterId = _supabase.auth.currentUser?.id;
    if (reporterId == null) throw Exception("User belum login");
    if (targetEntity.trim().isEmpty) throw Exception("Target tidak valid");
    if (targetId.trim().isEmpty) throw Exception("Target tidak valid");
    if (reason.trim().isEmpty) throw Exception("Alasan wajib diisi");

    final payload = <String, dynamic>{
      'reporter_id': reporterId,
      'target_entity': targetEntity.trim().toUpperCase(),
      'target_id': targetId.trim(),
      'reason': reason.trim(),
      'description': description.trim(),
      'status': 'OPEN',
    };

    try {
      await _supabase.from('reports').insert(payload);
      if (targetEntity.trim().toUpperCase() == 'RADAR') {
        try {
          await _supabase.from('radar_change_logs').insert({
            'radar_id': targetId.trim(),
            'changed_by': reporterId,
            'change_type': 'REPORT',
            'description': 'Melaporkan radar',
          });
        } catch (e, st) {
          if (kDebugMode) {
            debugPrint("[REPORT LOG ERROR] $e\n$st");
          }
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint("[REPORT SUBMIT ERROR] type=${e.runtimeType}");
        debugPrint("[REPORT SUBMIT ERROR] $e");
        if (e is PostgrestException) {
          debugPrint("[REPORT SUBMIT ERROR] message=${e.message}");
          debugPrint("[REPORT SUBMIT ERROR] code=${e.code}");
          debugPrint("[REPORT SUBMIT ERROR] details=${e.details}");
          debugPrint("[REPORT SUBMIT ERROR] hint=${e.hint}");
        }
        debugPrint("[REPORT SUBMIT ERROR] stacktrace=$st");
        debugPrint("[REPORT SUBMIT ERROR] payload=$payload");
      }
      throw Exception("Gagal mengirim laporan");
    }
  }
}
