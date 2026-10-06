import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/archived_course_options_sheet.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/custom_app_bar.dart';
import 'archived_course_detail_screen.dart';

/// Lists every archived course as a plain vertical list.
///
/// Tapping a course pushes [ArchivedCourseDetailScreen]; there is no tab bar
/// or inline selector here, so the list stays scannable regardless of how many
/// archived courses exist. Long-pressing a row opens [ArchivedCourseOptionsSheet]
/// for restore/delete, so the rows stay free of inline action buttons.
class ArchivedCoursesScreen extends StatelessWidget {
  const ArchivedCoursesScreen({super.key});

  void _openDetail(BuildContext context, Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchivedCourseDetailScreen(courseId: course.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final controller = getIt<CoursesController>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final archivedCourses = controller.archivedCourses;

            return Column(
              children: [
                CustomAppBar(
                  title: 'Archived Courses',
                  subtitle: archivedCourses.isNotEmpty
                      ? '${archivedCourses.length} ${archivedCourses.length == 1 ? "course" : "courses"}'
                      : null,
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: archivedCourses.isEmpty
                      ? _ArchivedEmptyState(bottomPadding: bottomSafe + 24)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            bottomSafe + 32,
                          ),
                          itemCount: archivedCourses.length,
                          separatorBuilder: (_, _) => const VGapSm(),
                          itemBuilder: (context, index) {
                            final course = archivedCourses[index];
                            return _ArchivedCourseRow(
                              course: course,
                              onTap: () => _openDetail(context, course),
                              onLongPress: () =>
                                  ArchivedCourseOptionsSheet.show(
                                    context,
                                    course: course,
                                  ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}



/// A single archived course. Tapping opens the detail page; long-pressing opens
/// the restore/delete sheet.
class _ArchivedCourseRow extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ArchivedCourseRow({
    required this.course,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface(context),
      borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            children: [
              CourseIconChip(courseId: course.id, size: 40, radius: 11),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (course.description.isNotEmpty) ...[
                      const VGapXs(),
                      Text(
                        course.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const HGapSm(),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondaryColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedEmptyState extends StatelessWidget {
  final double bottomPadding;

  const _ArchivedEmptyState({required this.bottomPadding});

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
              Icons.archive_outlined,
              color: AppTheme.pastelPurpleText(context),
              size: 30,
            ),
          ),
        ),
        const VGapMd(),
        Text(
          'No archived courses',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapXs(),
        Text(
          'Courses you archive will be moved here.\nOpen one to review its modules and topics, or restore it anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
