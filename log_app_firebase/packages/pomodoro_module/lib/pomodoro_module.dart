import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
import 'src/services/pomodoro_manager.dart';
import 'src/controllers/pomodoro_activities_controller.dart';
import 'src/screens/pomodoro_activities_screen.dart';

export 'src/services/pomodoro_manager.dart';
export 'src/controllers/pomodoro_activities_controller.dart';
export 'src/screens/pomodoro_activities_screen.dart';
export 'src/screens/pomodoro_ready_screen.dart';
export 'src/screens/pomodoro_timer_screen.dart';

class PomodoroModule implements AppModule {
  @override
  String get id => 'pomodoro';

  @override
  String get name => 'Pomodoro Focus Timer';

  @override
  String get description => 'Focus session timer with task tracking';

  @override
  bool get isPremium => false;

  @override
  Future<void> initialize() async {
    GetIt.instance.registerLazySingleton(() => PomodoroManager.instance);
    GetIt.instance.registerFactory(() => PomodoroActivitiesController());
  }

  @override
  Future<void> shutdown() async {
    if (GetIt.instance.isRegistered<PomodoroManager>()) {
      GetIt.instance.unregister<PomodoroManager>();
    }
    if (GetIt.instance.isRegistered<PomodoroActivitiesController>()) {
      GetIt.instance.unregister<PomodoroActivitiesController>();
    }
  }

  @override
  Widget buildDashboardWidget(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  List<NavigationItem> getNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.timer,
        label: 'Focus',
        route: '/pomodoro',
        builder: (context) => const PomodoroActivitiesScreen(),
      ),
    ];
  }
}
