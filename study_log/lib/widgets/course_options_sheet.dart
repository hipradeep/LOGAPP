import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import 'app_spacers.dart';
import 'study_confirmation_dialog.dart';
import '../screens/add_course_screen.dart';

enum CourseOptionAction { edit, archive, delete }

/// Bottom action sheet presented when long-pressing a Course card.
/// Presents options (Edit, Archive, Delete) matching the reference design.
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
      case CourseOptionAction.archive:
        final confirmed = await StudyConfirmationDialog.showArchiveCourse(
          context,
          courseTitle: course.title,
        );
        if (confirmed && context.mounted) {
          await getIt<CoursesController>().updateCourse(course.copyWith(status: 'archived'));
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

  void _selectEdit(BuildContext context) {
    Navigator.pop(context, CourseOptionAction.edit);
  }

  void _selectArchive(BuildContext context) {
    Navigator.pop(context, CourseOptionAction.archive);
  }

  void _selectDelete(BuildContext context) {
    Navigator.pop(context, CourseOptionAction.delete);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HandleBar(),
          const VGapLg(),
          _CourseHeader(course: course),
          const VGapMd(),
          Divider(
            color: AppTheme.borderColor(context).withValues(alpha: 0.6),
            height: 1,
          ),
          const VGapMd(),
          _CourseOptionTile(
            icon: Icons.edit_outlined,
            title: 'Edit Course',
            subtitle: 'Change title, description, or deadline',
            onTap: () => _selectEdit(context),
          ),
          const VGapSm(),
          _CourseOptionTile(
            icon: Icons.calendar_today_outlined,
            title: 'Archive Course',
            subtitle: 'Move course to archive',
            onTap: () => _selectArchive(context),
          ),
          const VGapSm(),
          _CourseOptionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Course',
            subtitle: 'Permanently remove this course',
            isDestructive: true,
            onTap: () => _selectDelete(context),
          ),
          const VGapSm(),
        ],
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.borderColor(context),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final Course course;

  const _CourseHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.auto_stories_outlined,
            color: AppTheme.primaryColor,
            size: 22,
          ),
        ),
        const HGapMd(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                course.title,
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const VGapXs(),
              Text(
                course.description.isEmpty ? 'Course Options' : course.description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _CourseOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? AppTheme.errorColor : AppTheme.primaryColor;
    final titleColor = isDestructive ? AppTheme.errorColor : AppTheme.textPrimaryColor(context);
    final tileBg = isDestructive
        ? AppTheme.errorColor.withValues(alpha: 0.06)
        : AppTheme.surfaceVariant(context);
    final borderColor = isDestructive
        ? AppTheme.errorColor.withValues(alpha: 0.2)
        : AppTheme.borderColor(context).withValues(alpha: 0.6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppTheme.errorColor.withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDestructive
                            ? AppTheme.errorColor.withValues(alpha: 0.8)
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? AppTheme.errorColor.withValues(alpha: 0.5)
                    : AppTheme.textSecondaryColor(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
