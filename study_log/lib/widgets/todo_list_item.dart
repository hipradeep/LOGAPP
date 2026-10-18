import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../models/topic.dart';
import '../theme/app_theme.dart';
import 'compact_list_item.dart';
import 'topic_status_indicator.dart';

/// Minimal, high-density Todo row built strictly on [CompactListItem].
///
/// Features:
/// - Circular progress checkbox on the left matching topic items.
/// - Title with completion strikethrough styling.
/// - Clean subtitle showing strictly: subtask count and due date.
/// - Single-tap checkbox completion toggle.
/// - Tap row to open detail/edit screen.
/// - Long-press to open [TodoOptionsSheet].
class TodoListItem extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxTap;

  static final DateFormat _dueDateFormat = DateFormat('d MMM');

  const TodoListItem({
    super.key,
    required this.todo,
    this.onTap,
    this.onLongPress,
    this.onCheckboxTap,
  });

  @override
  Widget build(BuildContext context) {
    return CompactListItem(
      key: ValueKey(todo.id),
      isCard: true,
      isCompleted: todo.isCompleted,
      leading: _buildLeadingIndicator(context),
      title: todo.title,
      subtitle: _buildSubtitleText(),
      showTrailingChevron: true,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildLeadingIndicator(BuildContext context) {
    Widget indicator;

    if (todo.isCompleted) {
      indicator = const TopicStatusIndicator(status: TopicStatus.completed);
    } else if (todo.hasSubtasks && todo.completedSubtaskCount > 0) {
      // Partial progress ring matching subtasks completion ratio
      indicator = SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          value: todo.progressRatio,
          strokeWidth: 2.8,
          color: AppTheme.primaryColor,
          backgroundColor: const Color(0xFFE8E5FF),
        ),
      );
    } else if (todo.status == TodoStatus.inProgress) {
      indicator = const TopicStatusIndicator(status: TopicStatus.inProgress);
    } else {
      indicator = const TopicStatusIndicator(status: TopicStatus.notStarted);
    }

    if (onCheckboxTap == null) return indicator;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCheckboxTap,
      child: indicator,
    );
  }

  String? _buildSubtitleText() {
    final parts = <String>[];

    // 1. Subtask count
    if (todo.hasSubtasks) {
      parts.add('${todo.completedSubtaskCount}/${todo.subtasks.length} subtasks');
    }

    // 2. Due date indicator
    if (todo.deadline != null) {
      if (todo.isOverdue) {
        parts.add('Overdue (${_dueDateFormat.format(todo.deadline!)})');
      } else if (DateUtils.isSameDay(todo.deadline!, DateTime.now())) {
        parts.add('Due Today');
      } else {
        parts.add('Due ${_dueDateFormat.format(todo.deadline!)}');
      }
    }

    if (parts.isEmpty) return null;
    return parts.join('  •  ');
  }
}
