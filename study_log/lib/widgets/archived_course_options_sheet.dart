import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'course_icon_chip.dart';
import 'sheet_action_widgets.dart';
import 'study_confirmation_dialog.dart';

enum ArchivedCourseOptionAction { restore, delete }

/// Bottom action sheet for an archived course, opened by long-pressing its row.
///
/// Archived courses are read-only, so the only actions are restoring the course
/// back to the active list and deleting it permanently.
class ArchivedCourseOptionsSheet extends StatelessWidget {
  final Course course;

  const ArchivedCourseOptionsSheet({super.key, required this.course});

  static Future<void> show(
    BuildContext context, {
    required Course course,
  }) async {
    final action = await showModalBottomSheet<ArchivedCourseOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArchivedCourseOptionsSheet(course: course),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case ArchivedCourseOptionAction.restore:
        final confirmed = await StudyConfirmationDialog.showRestoreCourse(
          context,
          courseTitle: course.title,
        );
        if (!confirmed || !context.mounted) return;
        await getIt<CoursesController>().unarchiveCourse(course.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Course "${course.title}" restored to active courses',
              ),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.defaultBorderRadius,
                ),
              ),
            ),
          );
        break;
      case ArchivedCourseOptionAction.delete:
        final confirmed = await StudyConfirmationDialog.showDeleteCourse(
          context,
          courseTitle: course.title,
        );
        if (!confirmed || !context.mounted) return;
        await getIt<CoursesController>().deleteCourse(course.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Course "${course.title}" deleted'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppTheme.defaultBorderRadius,
                ),
              ),
            ),
          );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: SheetHeaderBadge(
            child: CourseIconChip(
              courseId: course.id,
              iconCodePoint: course.iconCodePoint,
              colorValue: course.colorValue,
              size: 38,
              radius: 10,
            ),
          ),
          title: course.title,
          subtitle: course.description.isNotEmpty
              ? course.description
              : 'Archived course',
        ),
        const VGapSm(),
        SheetActionRow(
          icon: Icons.unarchive_outlined,
          title: 'Restore Course',
          onTap: () =>
              Navigator.pop(context, ArchivedCourseOptionAction.restore),
        ),
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Delete Course',
          onTap: () =>
              Navigator.pop(context, ArchivedCourseOptionAction.delete),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
