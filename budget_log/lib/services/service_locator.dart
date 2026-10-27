import 'package:get_it/get_it.dart';

import '../controllers/cloud_sync_controller.dart';
import '../controllers/contacts_controller.dart';
import '../controllers/debt_controller.dart';
import '../controllers/finance_controller.dart';
import '../controllers/sms_inbox_controller.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/theme_controller.dart';
import 'database_backup_service.dart';
import 'database_service.dart';
import 'google_auth_service.dart';
import 'google_drive_service.dart';
import 'notification_service.dart';
import 'sms_inbox_service.dart';
import 'sms_native_bridge.dart';
import 'sms_parser_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  if (!getIt.isRegistered<ThemeController>()) {
    getIt.registerLazySingleton<ThemeController>(() => ThemeController());
  }
  if (!getIt.isRegistered<DatabaseService>()) {
    getIt.registerLazySingleton<DatabaseService>(
      () => DatabaseService.instance,
    );
  }
  if (!getIt.isRegistered<DatabaseBackupService>()) {
    getIt.registerLazySingleton<DatabaseBackupService>(
      () => DatabaseBackupService(),
    );
  }
  if (!getIt.isRegistered<FinanceController>()) {
    getIt.registerLazySingleton<FinanceController>(
      () => FinanceController(dbService: getIt<DatabaseService>()),
    );
  }
  if (!getIt.isRegistered<ContactsController>()) {
    getIt.registerLazySingleton<ContactsController>(
      () => ContactsController(dbService: getIt<DatabaseService>()),
    );
  }
  if (!getIt.isRegistered<DebtController>()) {
    getIt.registerLazySingleton<DebtController>(
      () => DebtController(dbService: getIt<DatabaseService>()),
    );
  }
  if (!getIt.isRegistered<NotificationService>()) {
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(),
    );
  }
  if (!getIt.isRegistered<SubscriptionController>()) {
    getIt.registerLazySingleton<SubscriptionController>(
      () => SubscriptionController(
        dbService: getIt<DatabaseService>(),
        onSubscriptionsChanged: (subscriptions) =>
            getIt<NotificationService>().syncSchedules(subscriptions),
      ),
    );
  }
  if (!getIt.isRegistered<SmsNativeBridge>()) {
    getIt.registerLazySingleton<SmsNativeBridge>(() => SmsNativeBridge());
  }
  if (!getIt.isRegistered<SmsParserService>()) {
    getIt.registerLazySingleton<SmsParserService>(
      () => const SmsParserService(),
    );
  }
  if (!getIt.isRegistered<SmsInboxService>()) {
    getIt.registerLazySingleton<SmsInboxService>(
      () => SmsInboxService(
        bridge: getIt<SmsNativeBridge>(),
        parser: getIt<SmsParserService>(),
        dbService: getIt<DatabaseService>(),
      ),
    );
  }
  if (!getIt.isRegistered<SmsInboxController>()) {
    getIt.registerLazySingleton<SmsInboxController>(
      () => SmsInboxController(
        service: getIt<SmsInboxService>(),
        dbService: getIt<DatabaseService>(),
      ),
    );
  }
  if (!getIt.isRegistered<GoogleAuthService>()) {
    getIt.registerLazySingleton<GoogleAuthService>(() => GoogleAuthService());
  }
  if (!getIt.isRegistered<GoogleDriveService>()) {
    getIt.registerLazySingleton<GoogleDriveService>(
      () => GoogleDriveService(getIt<GoogleAuthService>()),
    );
  }
  if (!getIt.isRegistered<CloudSyncController>()) {
    getIt.registerLazySingleton<CloudSyncController>(
      () => CloudSyncController(
        authService: getIt<GoogleAuthService>(),
        driveService: getIt<GoogleDriveService>(),
        backupService: getIt<DatabaseBackupService>(),
        dbService: getIt<DatabaseService>(),
      ),
    );
  }
}

Future<void> initializeServices() async {
  await getIt<ThemeController>().load();
  await getIt<DatabaseService>().init();
  await getIt<FinanceController>().load();
  await getIt<ContactsController>().load();
  await getIt<DebtController>().load();
  await getIt<SubscriptionController>().load();
  await getIt<SmsInboxController>().initialize();
}
