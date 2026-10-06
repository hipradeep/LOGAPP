import 'package:flutter/material.dart';
import '../models/revision.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'course_icon_chip.dart';
import 'sheet_action_widgets.dart';
import 'study_confirmation_dialog.dart';
import '../controllers/revision_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';

enum RevisionOptionAction {
  openDetails,
  resetToR1,
  remove,
}

/// Bottom action sheet presented when long-pressing a Revision Module item in the list.
/// Provides quick access to viewing details, resetting to R1, or removing from revision schedule.
class RevisionOptionsSheet extends StatelessWidget {
  final Revision revision;

  const RevisionOptionsSheet({
    super.key,
    required this.revision,
  });

  static Future<void> show(
    BuildContext context, {
    required Revision revision,
    required RevisionController revisionController,
    required void Function(Revision revision) onOpenRevision,
  }) async {
    final action = await showModalBottomSheet<RevisionOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RevisionOptionsSheet(revision: revision),
    );

    if (!context.mounted || action == null) return;

    final moduleTitle = _moduleTitleFor(revision);

    switch (action) {
      case RevisionOptionAction.openDetails:
        onOpenRevision(revision);
        break;

      case RevisionOptionAction.resetToR1:
        await revisionController.resetRevision(revision.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset "$moduleTitle" to R1'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
          );
        }
        break;

      case RevisionOptionAction.remove:
        final confirmed = await StudyConfirmationDialog.showRemoveRevisionModule(
          context,
          moduleTitle: moduleTitle,
        );
        if (confirmed && context.mounted) {
          await revisionController.deleteRevision(revision.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$moduleTitle" removed from revision'),
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

  static String _moduleTitleFor(Revision revision) {
    if (getIt.isRegistered<OngoingModulesController>()) {
      final title = getIt<OngoingModulesController>().moduleTitleFor(revision.moduleId);
      if (title.isNotEmpty) return title;
    }
    return 'Revision Module';
  }

  static String _courseFor(Revision revision) {
    if (getIt.isRegistered<CoursesController>()) {
      final course = getIt<CoursesController>().getCourseById(revision.courseId);
      if (course != null && course.title.isNotEmpty) return course.title;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final title = _moduleTitleFor(revision);
    final course = _courseFor(revision);
    final level = revision.isFinished ? 'Completed' : 'Level R${revision.currentLevel}';
    final subtitle = course.isNotEmpty ? '$course • $level' : level;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: CourseIconChip(
            courseId: revision.courseId,
            size: 42,
            radius: 10,
          ),
          title: title,
          subtitle: subtitle,
        ),
        const VGapSm(),
        SheetActionRow(
          icon: Icons.visibility_outlined,
          title: 'Open Revision Details',
          onTap: () => Navigator.pop(context, RevisionOptionAction.openDetails),
        ),
        SheetActionRow(
          icon: Icons.restart_alt_rounded,
          title: 'Reset to R1',
          onTap: () => Navigator.pop(context, RevisionOptionAction.resetToR1),
        ),
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Remove from Revision',
          onTap: () => Navigator.pop(context, RevisionOptionAction.remove),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
