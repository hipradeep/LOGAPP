import 'package:get_it/get_it.dart';
import '../controllers/theme_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/calendar_controller.dart';
import 'firestore_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  if (!getIt.isRegistered<ThemeController>()) {
    getIt.registerLazySingleton<ThemeController>(() => ThemeController());
  }
  if (!getIt.isRegistered<FirestoreService>()) {
    getIt.registerLazySingleton<FirestoreService>(() => FirestoreService());
  }
  if (!getIt.isRegistered<CoursesController>()) {
    getIt.registerLazySingleton<CoursesController>(() => CoursesController());
  }
  if (!getIt.isRegistered<OngoingModulesController>()) {
    getIt.registerLazySingleton<OngoingModulesController>(() => OngoingModulesController());
  }
  if (!getIt.isRegistered<RevisionController>()) {
    getIt.registerLazySingleton<RevisionController>(() => RevisionController());
  }
  if (!getIt.isRegistered<CalendarController>()) {
    getIt.registerLazySingleton<CalendarController>(() => CalendarController());
  }
}
