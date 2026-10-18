import 'package:flutter/material.dart';
import '../models/module.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'study_confirmation_dialog.dart';
import '../controllers/modules_controller.dart';
import '../screens/add_module_screen.dart';
import 'sheet_action_widgets.dart';

enum ModuleOptionAction { edit, order, delete }

/// Bottom action sheet presented when tapping options or long-pressing a Module row.
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
    VoidCallback? onOrderModule,
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
      case ModuleOptionAction.order:
        onOrderModule?.call();
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
          icon: Icons.reorder_rounded,
          title: 'Order Module',
          onTap: () => Navigator.pop(context, ModuleOptionAction.order),
        ),
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
