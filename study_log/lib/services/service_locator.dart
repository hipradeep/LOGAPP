import 'package:get_it/get_it.dart';
import '../controllers/theme_controller.dart';
import '../controllers/courses_controller.dart';

final getIt = GetIt.instance;

void setupLocator() {
  if (!getIt.isRegistered<ThemeController>()) {
    getIt.registerLazySingleton<ThemeController>(() => ThemeController());
  }
  if (!getIt.isRegistered<CoursesController>()) {
    getIt.registerLazySingleton<CoursesController>(() => CoursesController());
  }
}
