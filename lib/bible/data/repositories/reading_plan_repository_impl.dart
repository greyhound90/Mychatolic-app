import 'package:mychatolic_app/bible/data/datasources/bible_api_client.dart';
import 'package:mychatolic_app/bible/data/models/bible_dtos.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/reading_plan_repository.dart';

class ReadingPlanRepositoryImpl implements ReadingPlanRepository {
  ReadingPlanRepositoryImpl(this._client);

  final BibleApiClient _client;

  List<ReadingPlan>? _plansCache;
  ReadingPlan? _activePlan;

  @override
  Future<List<ReadingPlan>> getPlans({bool refresh = false}) async {
    if (!refresh && _plansCache != null) {
      return _plansCache!;
    }
    final json = await _client.get('/bible/plans');
    final list = (json as List<dynamic>? ?? [])
        .map((e) => ReadingPlanDto.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
    _plansCache = list;
    return list;
  }

  @override
  Future<ReadingPlan?> getActivePlan({bool refresh = false}) async {
    if (!refresh && _activePlan != null) return _activePlan;
    final json = await _client.get('/bible/plans/active');
    if (json == null) return null;
    _activePlan = ReadingPlanDto.fromJson(json as Map<String, dynamic>).toEntity();
    return _activePlan;
  }

  @override
  Future<void> startPlan(String planId) async {
    await _client.post('/bible/plans/$planId/start', {});
    _activePlan = null;
  }

  @override
  Future<ReadingPlanDay> getPlanDay(String planId, int day) async {
    final json = await _client.get('/bible/plans/$planId/day/$day');
    return ReadingPlanDayDto.fromJson(json as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> markPlanDayComplete(String planId, int day, {String? reflection}) async {
    await _client.post('/bible/plans/$planId/day/$day/complete', {
      if (reflection != null) 'reflection': reflection,
    });
  }
}
