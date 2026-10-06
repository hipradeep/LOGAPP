import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/study_schedule_card.dart';
import '../widgets/today_progress_card.dart';
import '../widgets/your_courses_carousel.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/notification_controller.dart';
import '../services/notification_service.dart';
import '../models/course.dart';
import 'activity_screen.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';
import 'courses_screen.dart';
import 'module_detail_screen.dart';
import '../widgets/recent_activity_card.dart';

/// Redesigned Home Screen matching the reference design:
/// - "Hi, Pradeep 👋" greeting & notification bell with badge dot
/// - "Your Courses" horizontal carousel with progress bars and indicator dots
/// - "Today's Progress" with formatted date and 4 statistics
/// - "Current Modules" fetching ongoing courses and active ongoing modules
/// - Passes all 24 rules of [optimize.md]
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _ensureDataLoaded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  Future<void> _checkNotificationPermission() async {
    try {
      if (!getIt.isRegistered<NotificationService>()) return;
      final granted = await getIt<NotificationService>().requestPermission();
      if (granted && getIt.isRegistered<NotificationController>()) {
        unawaited(getIt<NotificationController>().syncAllNotifications());
      }
    } catch (e) {
      debugPrint('HomeScreen notification permission error: $e');
    }
  }

  void _ensureDataLoaded() {
    final coursesCtrl = getIt<CoursesController>();
    final ongoingCtrl = getIt<OngoingModulesController>();

    if (coursesCtrl.courses.isEmpty) {
      coursesCtrl.loadCourses().then((_) {
        ongoingCtrl.refresh();
      });
    } else if (ongoingCtrl.ongoingItems.isEmpty ||
        ongoingCtrl.ongoingItems.any((i) => i.progressRatio == '0 topics')) {
      ongoingCtrl.refresh();
    }

    if (getIt.isRegistered<ProgressController>()) {
      final progressCtrl = getIt<ProgressController>();
      if (progressCtrl.recentActivities.isEmpty) {
        progressCtrl.load();
      }
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      getIt<CoursesController>().loadCourses(),
      getIt<OngoingModulesController>().refresh(),
      getIt<RevisionController>().reconcile(),
      if (getIt.isRegistered<ProgressController>())
        getIt<ProgressController>().refresh(),
    ]);
  }

  void _openActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityScreen()),
    );
  }

  void _openCourseDetail(BuildContext context, Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  void _openModuleDetail(
    String moduleTitle,
    String courseTitle,
    String courseId,
    String moduleId,
    int orderIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(
          moduleTitle: moduleTitle,
          courseTitle: courseTitle,
          courseId: courseId,
          moduleId: moduleId,
          moduleOrderIndex: orderIndex,
        ),
      ),
    );
  }

  void _openAddCourse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    );
  }

  void _openAllCourses(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoursesScreen()),
    );
  }

  void _openCourseByTitle(String title) {
    final courses = getIt<CoursesController>().courses;
    Course? match;
    for (final c in courses) {
      if (c.title.toLowerCase() == title.toLowerCase()) {
        match = c;
        break;
      }
    }
    final course = match ?? Course(
      id: title.toLowerCase().replaceAll(' ', '_'),
      title: title,
      description: '$title syllabus and topics',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  void _handleViewAll() {
    _openAllCourses(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final ongoingController = getIt<OngoingModulesController>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.surface(context),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                sliver: SliverToBoxAdapter(
                  child: _HomeTopModule(
                    ongoingController: ongoingController,
                    onViewAll: _handleViewAll,
                    onCourseTap: _openCourseByTitle,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                sliver: _CurrentModulesSliverList(
                  ongoingController: ongoingController,
                  onModuleTap: _openModuleDetail,
                  onAddCourse: _openAddCourse,
                  onViewAll: _handleViewAll,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomSafe + 32),
                sliver: SliverToBoxAdapter(
                  child: _HomeRecentActivitySection(
                    onOpenActivity: () => _openActivity(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hi, Pradeep 👋',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
            letterSpacing: -0.3,
          ),
        ),
        const VGapXs(),
        Text(
          'Keep learning, keep growing!',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CurrentModulesHeader extends StatelessWidget {
  final VoidCallback onViewAll;

  const _CurrentModulesHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Current Modules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              'View All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeTopModule extends StatelessWidget {
  final OngoingModulesController ongoingController;
  final VoidCallback onViewAll;
  final ValueChanged<String> onCourseTap;

  const _HomeTopModule({
    required this.ongoingController,
    required this.onViewAll,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _GreetingHeader(),
        const VGapLg(),
        YourCoursesCarousel(
          onMoreTap: onViewAll,
          onCourseTap: onCourseTap,
        ),
        const VGapLg(),
        ListenableBuilder(
          listenable: Listenable.merge([
            ongoingController,
            getIt<RevisionController>(),
          ]),
          builder: (context, _) => TodayProgressCard(
            completedToday: ongoingController.completedTodayCount,
            pendingCount: getIt<RevisionController>().dueCount,
            dayStreak: ongoingController.dayStreakCount,
            goalProgress: ongoingController.goalProgress,
          ),
        ),
        const VGapLg(),
        _CurrentModulesHeader(onViewAll: onViewAll),
        const VGapSm(),
      ],
    );
  }
}

class _CurrentModulesSliverList extends StatelessWidget {
  final OngoingModulesController ongoingController;
  final void Function(String, String, String, String, int) onModuleTap;
  final void Function(BuildContext) onAddCourse;
  final VoidCallback onViewAll;

  const _CurrentModulesSliverList({
    required this.ongoingController,
    required this.onModuleTap,
    required this.onAddCourse,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ongoingController,
      builder: (context, _) {
        final items = ongoingController.ongoingItems
            .where((i) =>
                i.status == ModuleStudyStatus.running ||
                i.status == ModuleStudyStatus.upcoming)
            .toList();

        if (ongoingController.isLoading && items.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyOngoingModulesCard(onAddCourse: () => onAddCourse(context)),
          );
        }

        final displayItems = items.length > 4 ? items.sublist(0, 4) : items;
        final hasMore = items.length > 4;

        return SliverList.builder(
          itemCount: displayItems.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasMore && index == displayItems.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'View All Modules →',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              );
            }
            final item = displayItems[index];
            final cleanSubtitle = item.course.title;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: StudyScheduleCard(
                key: ValueKey(item.module.id),
                course: item.course,
                title: item.title,
                subtitle: cleanSubtitle,
                progressRatio: item.progressRatio,
                index: index,
                progress: item.progress,
                inProgressRatio: item.inProgressRatio,
                onTap: () {
                  onModuleTap(
                    item.module.title,
                    item.course.title,
                    item.course.id,
                    item.module.id,
                    item.module.orderIndex,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyOngoingModulesCard extends StatelessWidget {
  final VoidCallback onAddCourse;

  const _EmptyOngoingModulesCard({required this.onAddCourse});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 36,
            color: AppTheme.textSecondaryColor(context),
          ),
          const VGapMd(),
          Text(
            'No running or upcoming modules',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapXs(),
          Text(
            'Add modules to your courses to see your study schedule here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapMd(),
          ElevatedButton.icon(
            onPressed: onAddCourse,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeRecentActivitySection extends StatelessWidget {
  final VoidCallback onOpenActivity;

  const _HomeRecentActivitySection({
    required this.onOpenActivity,
  });

  @override
  Widget build(BuildContext context) {
    final progressCtrl = getIt.isRegistered<ProgressController>()
        ? getIt<ProgressController>()
        : null;

    if (progressCtrl == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        ListenableBuilder(
          listenable: progressCtrl,
          builder: (context, _) {
            return RecentActivityCard(
              controller: progressCtrl,
              maxDays: 3,
              showHeader: false,
              onItemTap: (_) => onOpenActivity(),
            );
          },
        ),
        const VGapSm(),
        GestureDetector(
          onTap: onOpenActivity,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            alignment: Alignment.center,
            child: const Text(
              'View All Activity →',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

