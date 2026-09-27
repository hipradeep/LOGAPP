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
import '../models/course.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';
import 'courses_screen.dart';
import 'module_detail_screen.dart';
import '../widgets/study_confirmation_dialog.dart';

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
    getIt<CoursesController>();
    getIt<OngoingModulesController>();
    getIt<RevisionController>();
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
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        bottom: false,
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
              padding: EdgeInsets.only(left: 20, right: 20, bottom: bottomSafe + 32),
              sliver: _CurrentModulesSliverList(
                ongoingController: ongoingController,
                onModuleTap: _openModuleDetail,
                onAddCourse: _openAddCourse,
                onViewAll: _handleViewAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hi, Pradeep 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              VGapXs(),
              Text(
                'Keep learning, keep growing!',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Notification bell with red alert dot
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: AppTheme.textPrimary,
                size: 22,
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
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
        const Text(
          'Current Modules',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
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
        final items = ongoingController.ongoingItems;

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

        final displayItems = items.length > 5 ? items.sublist(0, 5) : items;
        final hasMore = items.length > 5;

        return SliverList.builder(
          itemCount: displayItems.length + (hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (hasMore && index == displayItems.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: GestureDetector(
                  onTap: onViewAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                      border: Border.all(color: AppTheme.borderColor),
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: StudyScheduleCard(
                key: ValueKey(item.module.id),
                title: item.title,
                subtitle: item.breadcrumb,
                progressRatio: item.progressRatio,
                index: index,
                progress: item.progress,
                onTap: () {
                  onModuleTap(
                    item.module.title,
                    item.course.title,
                    item.course.id,
                    item.module.id,
                    item.module.orderIndex,
                  );
                },
                onLongPress: () async {
                  final confirmed = await StudyConfirmationDialog.showDeleteModule(
                    context,
                    moduleTitle: item.title,
                  );
                  if (confirmed && context.mounted) {
                    await ongoingController.deleteModule(item);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Module "${item.title}" deleted'),
                          backgroundColor: AppTheme.primaryColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                          ),
                        ),
                      );
                    }
                  }
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
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 36,
            color: AppTheme.textSecondary,
          ),
          const VGapMd(),
          const Text(
            'No running or upcoming modules',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const VGapXs(),
          const Text(
            'Add modules to your courses to see your study schedule here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
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
