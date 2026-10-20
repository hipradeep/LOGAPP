import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import '../models/topic.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'topic_status_indicator.dart';

/// Ultra-minimal, flat Todo checklist row component.
///
/// Designed in the style of Apple Reminders & Things 3:
/// - Flat & borderless (no card boxes, no shadows).
/// - Clean single-line layout focusing strictly on task completion.
/// - Left circular progress/status checkbox.
/// - Title with completion strikethrough styling.
/// - Single-tap checkbox completion toggle.
/// - Tap row to open detail/edit screen.
/// - Long-press to open [TodoOptionsSheet].
class TodoChecklistItem extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCheckboxTap;
  final EdgeInsetsGeometry padding;

  const TodoChecklistItem({
    super.key,
    required this.todo,
    this.onTap,
    this.onLongPress,
    this.onCheckboxTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.textSecondaryColor(context);
    final textPrimary = AppTheme.textPrimaryColor(context);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          child: Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Status / Progress Checkbox
                _buildCheckbox(context),
                const HGapMd(),

                // 2. Task Title
                Expanded(
                  child: Text(
                    todo.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: todo.isCompleted ? textSecondary : textPrimary,
                      decoration:
                          todo.isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    Widget indicator;

    if (todo.isCompleted) {
      indicator = const TopicStatusIndicator(status: TopicStatus.completed);
    } else if (todo.hasSubtasks && todo.completedSubtaskCount > 0) {
      // Partial progress ring matching subtasks completion ratio
      indicator = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          value: todo.progressRatio,
          strokeWidth: 2.6,
          color: AppTheme.primaryColor,
          backgroundColor: const Color(0xFFE8E5FF),
        ),
      );
    } else if (todo.status == TodoStatus.inProgress) {
      indicator = const TopicStatusIndicator(status: TopicStatus.inProgress);
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      indicator = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            width: 2.0,
          ),
        ),
      );
    }

    if (onCheckboxTap == null) return indicator;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCheckboxTap,
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: indicator,
      ),
    );
  }
}
