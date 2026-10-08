import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../controllers/theme_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/notification_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import 'database_service.dart';
import 'database_backup_service.dart';
import 'notification_service.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  if (!getIt.isRegistered<ThemeController>()) {
    getIt.registerLazySingleton<ThemeController>(() => ThemeController());
  }
  if (!getIt.isRegistered<DatabaseService>()) {
    getIt.registerLazySingleton<DatabaseService>(() => DatabaseService.instance);
  }
  if (!getIt.isRegistered<DatabaseBackupService>()) {
    getIt.registerLazySingleton<DatabaseBackupService>(() => DatabaseBackupService());
  }
  if (!getIt.isRegistered<GoogleAuthService>()) {
    getIt.registerLazySingleton<GoogleAuthService>(() => GoogleAuthService());
  }
  if (!getIt.isRegistered<GoogleDriveService>()) {
    getIt.registerLazySingleton<GoogleDriveService>(
        () => GoogleDriveService(getIt<GoogleAuthService>()));
  }
  if (!getIt.isRegistered<CloudSyncController>()) {
    getIt.registerLazySingleton<CloudSyncController>(() => CloudSyncController());
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

/// Warms up all singleton controllers on app start so local SQLite storage is hydrated
/// and streams are active before the user arrives on the home screen.
Future<void> warmupControllers() async {
  try {
    await DatabaseService.instance.init();
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
    if (getIt.isRegistered<NotificationController>()) {
      await getIt<NotificationController>().syncAllNotifications();
    }
    // Warm up CloudSyncController so silent sign-in and cloud metadata handshake
    // run in the background during app startup rather than delaying until Settings is opened.
    if (getIt.isRegistered<CloudSyncController>()) {
      getIt<CloudSyncController>();
    }
  } catch (e) {
    debugPrint('warmupControllers error: $e');
    try {
      if (getIt.isRegistered<ProgressController>()) {
        await getIt<ProgressController>().load();
      }
    } catch (_) {}
  }
}
