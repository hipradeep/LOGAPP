import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';
import 'study_confirmation_dialog.dart';

enum TodoOptionAction {
  edit,
  pomodoro,
  toggleArchive,
  delete,
}

/// Action bottom sheet presented when long-pressing a Todo task row.
class TodoOptionsSheet extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback? onEdit;
  final VoidCallback? onPomodoro;
  final VoidCallback? onToggleArchive;
  final VoidCallback? onDelete;

  const TodoOptionsSheet({
    super.key,
    required this.todo,
    this.onEdit,
    this.onPomodoro,
    this.onToggleArchive,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required TodoItem todo,
    VoidCallback? onEdit,
    VoidCallback? onPomodoro,
    VoidCallback? onToggleArchive,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => TodoOptionsSheet(
        todo: todo,
        onEdit: onEdit,
        onPomodoro: onPomodoro,
        onToggleArchive: onToggleArchive,
        onDelete: onDelete,
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    Navigator.pop(context);
    final confirmed = await StudyConfirmationDialog.showDeleteTask(context, taskTitle: todo.title);
    if (confirmed == true) {
      onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArchived = todo.isArchived;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          title: todo.title,
          subtitle: _formatSubtitle(),
        ),
        const VGapSm(),
        SheetActionRow(
          icon: Icons.edit_outlined,
          title: 'Edit Task',
          onTap: () {
            Navigator.pop(context);
            onEdit?.call();
          },
        ),
        SheetActionRow(
          icon: Icons.timer_outlined,
          title: 'Start Pomodoro Session (25m)',
          onTap: () {
            Navigator.pop(context);
            onPomodoro?.call();
          },
        ),
        SheetActionRow(
          icon: isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
          title: isArchived ? 'Unarchive Task' : 'Archive Task',
          onTap: () {
            Navigator.pop(context);
            onToggleArchive?.call();
          },
        ),
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Delete Task',
          onTap: () => _handleDelete(context),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }

  String _formatSubtitle() {
    final parts = <String>[];
    if (todo.hasSubtasks) {
      parts.add('${todo.completedSubtaskCount}/${todo.subtasks.length} subtasks');
    }
    parts.add('${todo.priority.value} Priority');
    if (todo.deadline != null) {
      parts.add(todo.isOverdue ? 'Overdue' : (todo.isDueTodayOrOverdue ? 'Due Today' : 'Upcoming'));
    }
    return parts.join('  •  ');
  }
}
