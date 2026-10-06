import 'package:flutter/material.dart';
import '../models/module.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'study_confirmation_dialog.dart';
import '../controllers/modules_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../services/service_locator.dart';
import '../screens/add_module_screen.dart';
import 'sheet_action_widgets.dart';

enum ModuleOptionAction { edit, duplicate, addToRevision, delete }

/// Bottom action sheet presented when tapping options or long-pressing a Module row.
/// Shows "Add to Revision" action only for completed modules.
class ModuleOptionsSheet extends StatelessWidget {
  final Module module;
  final String courseTitle;
  final String courseId;
  final ModulesController? modulesController;
  final bool? isCompleted;

  const ModuleOptionsSheet({
    super.key,
    required this.module,
    required this.courseTitle,
    this.courseId = '',
    this.modulesController,
    this.isCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    required Module module,
    required String courseTitle,
    String courseId = '',
    ModulesController? modulesController,
    bool? isCompleted,
  }) async {
    final action = await showModalBottomSheet<ModuleOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModuleOptionsSheet(
        module: module,
        courseTitle: courseTitle,
        courseId: courseId,
        modulesController: modulesController,
        isCompleted: isCompleted,
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case ModuleOptionAction.edit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddModuleScreen(
              courseId: module.courseId.isNotEmpty ? module.courseId : courseId,
              courseTitle: courseTitle,
              modulesController: modulesController,
              moduleToEdit: module,
            ),
          ),
        );
        break;
      case ModuleOptionAction.duplicate:
        await modulesController?.addModule(
          title: '${module.title} (Copy)',
          description: module.description,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Module "${module.title}" duplicated'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
          );
        }
        break;
      case ModuleOptionAction.addToRevision:
        await _handleAddToRevision(context, module: module, courseTitle: courseTitle, courseId: courseId);
        break;
      case ModuleOptionAction.delete:
        final confirmed = await StudyConfirmationDialog.showDeleteModule(
          context,
          moduleTitle: module.title,
        );
        if (confirmed && context.mounted) {
          await modulesController?.deleteModule(module.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Module "${module.title}" deleted'),
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

  static Future<void> _handleAddToRevision(
    BuildContext context, {
    required Module module,
    required String courseTitle,
    required String courseId,
  }) async {
    if (!getIt.isRegistered<RevisionController>()) return;
    try {
      await getIt<RevisionController>().createOrEnsureRevision(
        courseId: courseId.isNotEmpty ? courseId : module.courseId,
        moduleId: module.id,
        courseTitle: courseTitle,
        moduleTitle: module.title,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${module.title}" added to revision schedule'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to revision: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool get _isCompleted {
    if (isCompleted != null) return isCompleted!;
    if (module.id.isNotEmpty && getIt.isRegistered<OngoingModulesController>()) {
      final ongoing = getIt<OngoingModulesController>();
      if (ongoing.isModuleComplete(module.id)) return true;
      final total = ongoing.topicCountForModule(module.id);
      final done = ongoing.completedTopicCountForModule(module.id);
      if (total > 0 && done >= total) return true;
    }
    return module.status.toLowerCase() == 'completed';
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = courseTitle;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: AppTheme.pastelPurple(context),
            child: Text(
              '${module.orderIndex + 1}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.pastelPurpleText(context),
              ),
            ),
          ),
          title: module.title,
          subtitle: subtitle,
        ),
        const VGapSm(),
        SheetActionRow(
          icon: Icons.edit_outlined,
          title: 'Edit Module',
          onTap: () => Navigator.pop(context, ModuleOptionAction.edit),
        ),
        SheetActionRow(
          icon: Icons.copy_rounded,
          title: 'Duplicate Module',
          onTap: () => Navigator.pop(context, ModuleOptionAction.duplicate),
        ),
        if (_isCompleted) ...[
          Builder(
            builder: (ctx) {
              final isInRevision = getIt.isRegistered<RevisionController>() &&
                  getIt<RevisionController>().revisionForModule(
                    module.id,
                    moduleTitle: module.title,
                  ) != null;
              return SheetActionRow(
                icon: isInRevision ? Icons.check_circle_outline_rounded : Icons.replay_rounded,
                title: isInRevision ? 'In Revision Schedule' : 'Add to Revision',
                onTap: () => Navigator.pop(context, ModuleOptionAction.addToRevision),
              );
            },
          ),
        ],
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Delete Module',
          onTap: () => Navigator.pop(context, ModuleOptionAction.delete),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
