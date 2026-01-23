import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';

abstract class ReadingPlanRepository {
  Future<List<ReadingPlan>> getPlans({bool refresh = false});
  Future<ReadingPlan?> getActivePlan({bool refresh = false});
  Future<void> startPlan(String planId);
  Future<ReadingPlanDay> getPlanDay(String planId, int day);
  Future<void> markPlanDayComplete(String planId, int day, {String? reflection});
}
