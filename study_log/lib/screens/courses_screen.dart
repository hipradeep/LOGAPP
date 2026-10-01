import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/course_options_sheet.dart';
import '../widgets/compact_list_item.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';
import 'add_course_screen.dart';
import 'archived_courses_screen.dart';
import 'course_detail_screen.dart';

/// Courses screen listing only the user's own courses:
/// - Top bar with Back navigation, "Courses" title, and Add Course pill button
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

  void _openArchivedCourses() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArchivedCoursesScreen()),
    );
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
                onOpenArchived: _openArchivedCourses,
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

  const _CoursesTopBar({
    required this.onBack,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 16.0, 10.0),
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
          AddPillButton(
            label: 'Add Course',
            onPressed: onAddCourse,
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
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
           Icon(
            Icons.search_rounded,
            color: AppTheme.textMutedColor(context),
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
              decoration:  InputDecoration(
                hintText: 'Search courses...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMutedColor(context),
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
  final VoidCallback onOpenArchived;
  final double bottomPadding;

  const _CoursesFilteredList({
    required this.coursesController,
    required this.searchQueryNotifier,
    required this.onCourseTap,
    required this.onCourseLongPress,
    required this.onAddCourse,
    required this.onOpenArchived,
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
        final archivedCount = coursesController.archivedCourses.length;

        final filtered = userCourses.where((c) {
          if (query.isEmpty) return true;
          return c.title.toLowerCase().contains(query) ||
              c.description.toLowerCase().contains(query);
        }).toList();

        if (userCourses.isEmpty) {
          return _CoursesEmptyState(
            bottomPadding: bottomPadding,
            onAddCourse: onAddCourse,
            archivedCount: archivedCount,
            onOpenArchived: onOpenArchived,
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
              const VGapLg(),
              _ArchivedCoursesButton(
                count: archivedCount,
                onTap: onOpenArchived,
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: bottomPadding),
          itemCount: filtered.length + 1,
          itemBuilder: (context, index) {
            if (index == filtered.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                child: _ArchivedCoursesButton(
                  count: archivedCount,
                  onTap: onOpenArchived,
                ),
              );
            }

            final Course course = filtered[index];
            final rollup = ongoing?.progressForCourse(course.id);
            final isComplete = rollup?.isComplete ??
                (course.status.toLowerCase() == 'completed');

            final String subtitle;
            if (rollup != null && rollup.hasModules) {
              subtitle =
                  '${rollup.completedModules} / ${rollup.totalModules} modules';
            } else {
              subtitle = 'No modules yet';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _CourseItemCard(
                courseId: course.id,
                title: course.title,
                subtitle: subtitle,
                isComplete: isComplete,
                onTap: () => onCourseTap(course),
                onLongPress: () => onCourseLongPress(course),
                onOptionsTap: () => onCourseLongPress(course),
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
  final VoidCallback onOpenArchived;
  final int archivedCount;
  final double bottomPadding;

  const _CoursesEmptyState({
    required this.onAddCourse,
    required this.onOpenArchived,
    required this.archivedCount,
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
        if (archivedCount > 0) ...[
          const VGapLg(),
          _ArchivedCoursesButton(
            count: archivedCount,
            onTap: onOpenArchived,
          ),
        ],
      ],
    );
  }
}

class _ArchivedCoursesButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ArchivedCoursesButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.pastelPurple(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.pastelPurpleBorder(context),
                    ),
                  ),
                  child: Icon(
                    Icons.archive_outlined,
                    color: AppTheme.pastelPurpleText(context),
                    size: 20,
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Archived Courses',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const VGapXs(),
                      Text(
                        count > 0
                            ? '$count ${count == 1 ? "course" : "courses"} archived'
                            : 'View archived courses',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMutedColor(context),
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

class _CourseItemCard extends StatelessWidget {
  final String courseId;
  final String title;
  final String subtitle;
  final bool isComplete;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;

  const _CourseItemCard({
    required this.courseId,
    required this.title,
    required this.subtitle,
    this.isComplete = false,
    this.onTap,
    this.onLongPress,
    this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return CompactListItem(
      margin: EdgeInsets.zero,
      isCompleted: isComplete,
      leading: CourseIconChip(
        courseId: courseId,
        size: 38,
        radius: 10,
      ),
      title: title,
      titleBadge: isComplete
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'COMPLETED',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.successColor,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : null,
      subtitle: subtitle,
      onTap: onTap,
      onLongPress: onLongPress,
      onOptionsTap: onOptionsTap,
    );
  }
}

