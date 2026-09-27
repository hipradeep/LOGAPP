import 'package:get_it/get_it.dart';
import '../controllers/theme_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_sections_controller.dart';
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
  if (!getIt.isRegistered<OngoingSectionsController>()) {
    getIt.registerLazySingleton<OngoingSectionsController>(() => OngoingSectionsController());
  }
}
