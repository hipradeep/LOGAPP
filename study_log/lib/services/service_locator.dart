import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../controllers/theme_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/notification_controller.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

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
  if (!getIt.isRegistered<ProgressController>()) {
    getIt.registerLazySingleton<ProgressController>(() => ProgressController());
  }
  if (!getIt.isRegistered<NotificationService>()) {
    getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  }
  if (!getIt.isRegistered<NotificationController>()) {
    getIt.registerLazySingleton<NotificationController>(() => NotificationController());
  }
}

/// Warms up all singleton controllers on app start so local storage is hydrated
/// and Firestore streams are active before the user arrives on the home screen.
Future<void> warmupControllers() async {
  try {
    final courses = getIt<CoursesController>();
    final ongoing = getIt<OngoingModulesController>();
    final revision = getIt<RevisionController>();
    final progress = getIt<ProgressController>();

    await Future.wait([
      courses.loadCourses(),
      ongoing.refresh(),
      revision.reconcile(),
    ]);
    await progress.load();
  } catch (e) {
    debugPrint('warmupControllers error: $e');
    try {
      if (getIt.isRegistered<ProgressController>()) {
        await getIt<ProgressController>().load();
      }
    } catch (_) {}
  }
}
