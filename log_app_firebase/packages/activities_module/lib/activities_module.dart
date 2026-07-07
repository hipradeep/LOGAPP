import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
import 'src/controllers/track_activities_controller.dart';
import 'src/controllers/milestones_controller.dart';
import 'src/controllers/calendar_scheduler_controller.dart';
import 'src/screens/track_activities_screen.dart';
import 'src/screens/milestones_screen.dart';
import 'src/screens/calendar_scheduler_screen.dart';

export 'src/controllers/track_activities_controller.dart';
export 'src/controllers/milestones_controller.dart';
export 'src/controllers/calendar_scheduler_controller.dart';
export 'src/controllers/activity_details_controller.dart';
export 'src/screens/track_activities_screen.dart';
export 'src/screens/milestones_screen.dart';
export 'src/screens/calendar_scheduler_screen.dart';
export 'src/screens/activity_details_screen.dart';
export 'src/screens/add_activity_screen.dart';
export 'src/screens/add_milestone_task_screen.dart';
export 'src/widgets/activity_graph.dart';
export 'src/widgets/activity_chip.dart';
export 'src/widgets/check_in_sheet.dart';
export 'src/widgets/milestone_section.dart';
export 'src/widgets/task_card.dart';

class ActivitiesModule implements AppModule {
  @override
  String get id => 'activities';

  @override
  String get name => 'Activities & Habits';

  @override
  String get description => 'Daily habit tracking, milestones, and calendar scheduler';

  @override
  bool get isPremium => false;

  @override
  Future<void> initialize() async {
    GetIt.instance.registerFactory(() => TrackActivitiesController());
    GetIt.instance.registerFactory(() => MilestonesController());
    GetIt.instance.registerFactory(() => CalendarSchedulerController());
  }

  @override
  Future<void> shutdown() async {}

  @override
  Widget buildDashboardWidget(BuildContext context) => const SizedBox.shrink();

  @override
  List<NavigationItem> getNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.track_changes_rounded,
        label: 'Track',
        route: '/track',
        builder: (context) => const TrackActivitiesScreen(),
      ),
      NavigationItem(
        icon: Icons.flag_rounded,
        label: 'Milestones',
        route: '/milestones',
        builder: (context) => const MilestonesScreen(),
      ),
      NavigationItem(
        icon: Icons.calendar_month_rounded,
        label: 'Schedule',
        route: '/schedule',
        builder: (context) => const CalendarSchedulerScreen(),
      ),
    ];
  }
}
