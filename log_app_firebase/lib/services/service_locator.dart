import 'package:get_it/get_it.dart';
import 'activity_service.dart';
import 'check_in_service.dart';
import 'milestone_service.dart';
import 'budget_service.dart';
import 'notification_service.dart';
import 'notification_transaction_service.dart';
import 'water_service.dart';

final GetIt getIt = GetIt.instance;

void setupLocator() {
  getIt.registerLazySingleton<ActivityService>(() => ActivityService());
  getIt.registerLazySingleton<CheckInService>(() => CheckInService());
  getIt.registerLazySingleton<MilestoneService>(() => MilestoneService());
  getIt.registerLazySingleton<BudgetService>(() => BudgetService());
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<NotificationTransactionService>(() => NotificationTransactionService());
  getIt.registerLazySingleton<WaterService>(() => WaterService());
}
