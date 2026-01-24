import 'package:mychatolic_app/bible/data/datasources/bible_api_client.dart';
import 'package:mychatolic_app/bible/data/repositories/bible_repository_impl.dart';
import 'package:mychatolic_app/bible/data/repositories/notes_repository_impl.dart';
import 'package:mychatolic_app/bible/data/repositories/reading_plan_repository_impl.dart';
import 'package:mychatolic_app/bible/domain/repositories/bible_repository.dart';
import 'package:mychatolic_app/bible/domain/repositories/notes_repository.dart';
import 'package:mychatolic_app/bible/domain/repositories/reading_plan_repository.dart';
import 'package:mychatolic_app/bible/presentation/viewmodels/reader_settings_controller.dart';

class BibleModule {
  static final BibleApiClient _client = BibleApiClient();

  static final BibleRepository bibleRepository = BibleRepositoryImpl(_client);
  static final NotesRepository notesRepository = NotesRepositoryImpl(_client);
  static final ReadingPlanRepository readingPlanRepository =
      ReadingPlanRepositoryImpl(_client);
  static final ReaderSettingsController readerSettingsController =
      ReaderSettingsController();
}
