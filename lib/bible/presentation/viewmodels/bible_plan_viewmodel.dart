import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/reading_plan_repository.dart';

class BiblePlanViewModel extends ChangeNotifier {
  BiblePlanViewModel({required this.planRepository});

  final ReadingPlanRepository planRepository;

  bool isLoading = false;
  String? errorMessage;
  ReadingPlan? activePlan;
  List<ReadingPlan> plans = [];

  Future<void> loadPlans() async {
    _setLoading(true);
    try {
      activePlan = await planRepository.getActivePlan();
      plans = await planRepository.getPlans();
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startPlan(ReadingPlan plan) async {
    try {
      await planRepository.startPlan(plan.id);
      await loadPlans();
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
