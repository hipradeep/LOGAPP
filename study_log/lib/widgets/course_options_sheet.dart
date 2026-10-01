import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import 'app_spacers.dart';
import 'study_confirmation_dialog.dart';
import '../screens/add_course_screen.dart';
import 'course_icon_chip.dart';
import 'sheet_action_widgets.dart';

enum CourseOptionAction { edit, duplicate, archive, delete }

/// Bottom action sheet presented when tapping options or long-pressing a Course card.
/// Matches the reference design with squircle header, clean action rows, red delete button, and cancel button.
class CourseOptionsSheet extends StatelessWidget {
  final Course course;

  const CourseOptionsSheet({
    super.key,
    required this.course,
  });

  static Future<void> show(BuildContext context, {required Course course}) async {
    final action = await showModalBottomSheet<CourseOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseOptionsSheet(course: course),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case CourseOptionAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddCourseScreen(courseToEdit: course),
          ),
        );
        break;
      case CourseOptionAction.duplicate:
        await getIt<CoursesController>().addCourse(
          title: '${course.title} (Copy)',
          description: course.description,
          deadline: course.deadline,
          iconCodePoint: course.iconCodePoint,
          colorValue: course.colorValue,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Course "${course.title}" duplicated'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
          );
        }
        break;
      case CourseOptionAction.archive:
        final confirmed = await StudyConfirmationDialog.showArchiveCourse(
          context,
          courseTitle: course.title,
        );
        if (confirmed && context.mounted) {
          await getIt<CoursesController>().archiveCourse(course.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Course "${course.title}" archived'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                ),
              ),
            );
          }
        }
        break;
      case CourseOptionAction.delete:
        final confirmed = await StudyConfirmationDialog.showDeleteCourse(
          context,
          courseTitle: course.title,
        );
        if (confirmed && context.mounted) {
          await getIt<CoursesController>().deleteCourse(course.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Course "${course.title}" deleted'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                ),
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = course.description.isNotEmpty
        ? course.description
        : 'Course';

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
          subtitle: subtitle,
        ),
        const VGapSm(),
        SheetActionRow(
          icon: Icons.edit_outlined,
          title: 'Edit Course',
          onTap: () => Navigator.pop(context, CourseOptionAction.edit),
        ),
        SheetActionRow(
          icon: Icons.copy_rounded,
          title: 'Duplicate Course',
          onTap: () => Navigator.pop(context, CourseOptionAction.duplicate),
        ),
        SheetActionRow(
          icon: Icons.archive_outlined,
          title: 'Archive Course',
          onTap: () => Navigator.pop(context, CourseOptionAction.archive),
        ),
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Delete Course',
          onTap: () => Navigator.pop(context, CourseOptionAction.delete),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
