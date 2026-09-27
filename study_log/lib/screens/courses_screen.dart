import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/course_options_sheet.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';
import 'add_course_screen.dart';
import 'course_detail_screen.dart';

/// Courses screen listing only the user's own courses:
/// - Top bar with Back navigation, "Courses" title, circular "+", and 3-dots menu (Delete, Archive)
/// - "Search courses..." rounded search bar
/// - One card per course showing real module completion, progress bar and percentage
/// - Icon and pastel colours come from the course id, so a course keeps the same
///   glyph regardless of its position in the list
/// - Empty and no-match states replace the old hardcoded sample courses
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  late final TextEditingController _searchController;
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery.value = _searchController.text.trim().toLowerCase();
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openAddCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCourseScreen()),
    );
  }

  void _openCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
    );
  }

  void _openCourseOptions(Course course) {
    CourseOptionsSheet.show(context, course: course);
  }

  Future<void> _handleTopMenuAction(String action) async {
    final coursesController = getIt<CoursesController>();
    if (coursesController.courses.isEmpty) return;
    final firstCourse = coursesController.courses.first;

    if (action == 'delete') {
      final confirmed = await StudyConfirmationDialog.showDeleteCourse(
        context,
        courseTitle: firstCourse.title,
      );
      if (confirmed && mounted) {
        await coursesController.deleteCourse(firstCourse.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${firstCourse.title}" deleted'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (action == 'archive') {
      final confirmed = await StudyConfirmationDialog.showArchiveCourse(
        context,
        courseTitle: firstCourse.title,
      );
      if (confirmed && mounted) {
        await coursesController.updateCourse(firstCourse.copyWith(status: 'archived'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${firstCourse.title}" archived'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final coursesController = getIt<CoursesController>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _CoursesTopBar(
              onBack: _handleBack,
              onAddCourse: _openAddCourse,
              onMenuAction: _handleTopMenuAction,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _CoursesSearchBar(controller: _searchController),
            ),
            Expanded(
              child: _CoursesFilteredList(
                coursesController: coursesController,
                searchQueryNotifier: _searchQuery,
                onCourseTap: _openCourseDetail,
                onCourseLongPress: _openCourseOptions,
                onAddCourse: _openAddCourse,
                bottomPadding: bottomSafe + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoursesTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAddCourse;
  final ValueChanged<String> onMenuAction;

  const _CoursesTopBar({
    required this.onBack,
    required this.onAddCourse,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          Text(
            'Courses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Circular "+" button matching reference screenshot
          InkWell(
            onTap: onAddCourse,
            customBorder: const CircleBorder(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
          ),
          const HGapXs(),
          // 3-dots popup menu with Delete & Archive matching reference screenshot
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
            onSelected: onMenuAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    HGapMd(),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF1E293B),
                      size: 19,
                    ),
                    HGapMd(),
                    Text(
                      'Archive',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoursesSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _CoursesSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          const HGapSm(),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor(context),
              ),
              decoration: const InputDecoration(
                hintText: 'Search courses...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursesFilteredList extends StatelessWidget {
  final CoursesController coursesController;
  final ValueNotifier<String> searchQueryNotifier;
  final ValueChanged<Course> onCourseTap;
  final ValueChanged<Course> onCourseLongPress;
  final VoidCallback onAddCourse;
  final double bottomPadding;

  const _CoursesFilteredList({
    required this.coursesController,
    required this.searchQueryNotifier,
    required this.onCourseTap,
    required this.onCourseLongPress,
    required this.onAddCourse,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;

    return ListenableBuilder(
      listenable: Listenable.merge(
          [coursesController, searchQueryNotifier, ?ongoing]),
      builder: (context, _) {
        final query = searchQueryNotifier.value;
        final userCourses = coursesController.courses;

        final filtered = userCourses.where((c) {
          if (query.isEmpty) return true;
          return c.title.toLowerCase().contains(query) ||
              c.description.toLowerCase().contains(query);
        }).toList();

        if (userCourses.isEmpty) {
          return _CoursesEmptyState(
            bottomPadding: bottomPadding,
            onAddCourse: onAddCourse,
          );
        }

        if (filtered.isEmpty) {
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 48, bottom: bottomPadding),
            children: [
              Center(
                child: Text(
                  'No courses match "$query"',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final Course course = filtered[index];
            final rollup = ongoing?.progressForCourse(course.id);
            final progress = rollup?.ratio ?? 0.0;
            final percent = (progress * 100).round();

            final String subtitle;
            if (course.description.isNotEmpty) {
              subtitle = course.description;
            } else if (rollup != null && rollup.hasModules) {
              subtitle = '${rollup.completedModules} / ${rollup.totalModules} modules';
            } else {
              subtitle = 'No modules yet';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _CourseItemCard(
                courseId: course.id,
                title: course.title,
                subtitle: subtitle,
                progress: progress,
                percentage: '$percent%',
                onTap: () => onCourseTap(course),
                onLongPress: () => onCourseLongPress(course),
              ),
            );
          },
        );
      },
    );
  }
}

class _CoursesEmptyState extends StatelessWidget {
  final VoidCallback onAddCourse;
  final double bottomPadding;

  const _CoursesEmptyState({
    required this.onAddCourse,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPadding),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.pastelPurple(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
            ),
            child: Icon(
              Icons.school_outlined,
              color: AppTheme.pastelPurpleText(context),
              size: 30,
            ),
          ),
        ),
        const VGapMd(),
        Text(
          'No courses yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapXs(),
        Text(
          'Add a course to start tracking its modules and topics.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapMd(),
        Center(
          child: TextButton.icon(
            onPressed: onAddCourse,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add course'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseItemCard extends StatelessWidget {
  final String courseId;
  final String title;
  final String subtitle;
  final double progress;
  final String percentage;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CourseItemCard({
    required this.courseId,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.percentage,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accentIndex =
        CourseIconChip.stableIndex(courseId, AppTheme.tintCount);
    final accentColor = AppTheme.tintFor(context, accentIndex).$2;

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CourseIconChip(
                  courseId: courseId,
                  size: 48,
                  radius: AppTheme.smallBorderRadius,
                ),
                const HGapMd(),
                // Title, Subtitle, Progress Bar & Percentage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: const Color(0xFFECEEF6),
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                          const HGapSm(),
                          Text(
                            percentage,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                // Trailing Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

