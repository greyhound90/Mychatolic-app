import 'package:flutter/foundation.dart';
import 'package:mychatolic_app/bible/core/api_error.dart';
import 'package:mychatolic_app/bible/domain/entities/bible_entities.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';
import 'package:mychatolic_app/bible/domain/repositories/reading_plan_repository.dart';

class BibleMeViewModel extends ChangeNotifier {
  BibleMeViewModel({
    required this.bibleRepository,
    required this.planRepository,
  });

  final BibleRepository bibleRepository;
  final ReadingPlanRepository planRepository;

  bool isLoading = false;
  String? errorMessage;
  VerseOfTheDay? verseOfTheDay;
  LastRead? lastRead;
  ReadingPlan? activePlan;

  Future<void> load() async {
    _setLoading(true);
    try {
      verseOfTheDay = await bibleRepository.getVerseOfTheDay();
      lastRead = await bibleRepository.getLastRead();
      activePlan = await planRepository.getActivePlan();
      errorMessage = null;
    } catch (e) {
      errorMessage = ApiErrorMapper.toUserMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
