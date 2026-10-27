import 'package:flutter/material.dart';
import '../controllers/topic_revision_controller.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/topic_icon_util.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';
import 'study_confirmation_dialog.dart';

enum TopicOptionAction {
  edit,
  order,
  duplicate,
  move,
  addToRevision,
  removeFromRevision,
  resetRevision,
  delete,
}

/// Bottom action sheet presented when tapping options or long-pressing a Topic row.
/// Matches the reference design with squircle header, clean action rows, revision actions, red delete button, and cancel button.
class TopicOptionsSheet extends StatelessWidget {
  final Topic topic;
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;
  final bool showRemoveFromRevision;
  final VoidCallback? onEdit;
  final VoidCallback? onOrderTopic;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const TopicOptionsSheet({
    super.key,
    required this.topic,
    required this.moduleTitle,
    this.courseTitle = '',
    this.courseId = '',
    this.moduleId = '',
    this.showRemoveFromRevision = false,
    this.onEdit,
    this.onOrderTopic,
    this.onDuplicate,
    this.onMove,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Topic topic,
    required String moduleTitle,
    String courseTitle = '',
    String courseId = '',
    String moduleId = '',
    bool showRemoveFromRevision = false,
    VoidCallback? onRevisionChanged,
    VoidCallback? onEdit,
    VoidCallback? onOrderTopic,
    VoidCallback? onDuplicate,
    VoidCallback? onMove,
    VoidCallback? onDelete,
  }) async {
    final action = await showModalBottomSheet<TopicOptionAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TopicOptionsSheet(
        topic: topic,
        moduleTitle: moduleTitle,
        courseTitle: courseTitle,
        courseId: courseId,
        moduleId: moduleId,
        showRemoveFromRevision: showRemoveFromRevision,
        onEdit: onEdit,
        onOrderTopic: onOrderTopic,
        onDuplicate: onDuplicate,
        onMove: onMove,
        onDelete: onDelete,
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case TopicOptionAction.edit:
        onEdit?.call();
        break;
      case TopicOptionAction.order:
        onOrderTopic?.call();
        break;
      case TopicOptionAction.duplicate:
        onDuplicate?.call();
        break;
      case TopicOptionAction.move:
        onMove?.call();
        break;
      case TopicOptionAction.addToRevision:
        await _handleAddToRevision(
          context,
          topic: topic,
          courseId: courseId.isNotEmpty ? courseId : topic.courseId,
          moduleId: moduleId.isNotEmpty ? moduleId : topic.moduleId,
        );
        onRevisionChanged?.call();
        break;
      case TopicOptionAction.removeFromRevision:
        await _handleRemoveFromRevision(context, topic: topic);
        onRevisionChanged?.call();
        break;
      case TopicOptionAction.resetRevision:
        await _handleResetRevision(context, topic: topic);
        onRevisionChanged?.call();
        break;
      case TopicOptionAction.delete:
        if (onDelete != null) {
          onDelete.call();
        } else {
          final confirmed = await StudyConfirmationDialog.showDeleteTopic(
            context,
            topicTitle: topic.title,
          );
          if (confirmed && context.mounted) {
            await DatabaseService.instance.deleteTopic(topic.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Topic "${topic.title}" deleted'),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                  ),
                ),
              );
            }
          }
        }
        break;
    }
  }

  static Future<void> _handleAddToRevision(
    BuildContext context, {
    required Topic topic,
    required String courseId,
    required String moduleId,
  }) async {
    if (!getIt.isRegistered<TopicRevisionController>()) return;
    try {
      await getIt<TopicRevisionController>().enrollTopicInRevision(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topic.id,
        title: topic.title,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${topic.title}" added to revision schedule'),
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
            content: Text('Failed to add topic to revision: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> _handleRemoveFromRevision(
    BuildContext context, {
    required Topic topic,
  }) async {
    final confirmed = await StudyConfirmationDialog.showRemoveRevisionTopic(
      context,
      topicTitle: topic.title,
    );
    if (!confirmed || !context.mounted) return;

    if (!getIt.isRegistered<TopicRevisionController>()) return;
    try {
      await getIt<TopicRevisionController>().removeTopicFromRevision(
        topic.id,
        moduleId: topic.moduleId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${topic.title}" removed from revision (marked completed)'),
            backgroundColor: AppTheme.primaryColor,
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
            content: Text('Failed to remove from revision: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static Future<void> _handleResetRevision(
    BuildContext context, {
    required Topic topic,
  }) async {
    if (!getIt.isRegistered<TopicRevisionController>()) return;
    try {
      final rev = getIt<TopicRevisionController>().topicRevisionFor(topic.id);
      if (rev != null) {
        final confirmed = await StudyConfirmationDialog.showResetRevision(
          context,
          title: topic.title,
          currentLevelLabel: rev.levelLabel,
        );
        if (!confirmed || !context.mounted) return;

        await getIt<TopicRevisionController>().resetTopicRevision(rev.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Revision ladder reset to R1 for "${topic.title}"'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset revision: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = topicIconFrom(topic.iconCodePoint);
    final subtitle = courseTitle.isNotEmpty ? '$courseTitle › $moduleTitle' : moduleTitle;

    final TopicRevision? topicRev = getIt.isRegistered<TopicRevisionController>()
        ? getIt<TopicRevisionController>().topicRevisionFor(topic.id)
        : null;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapSm(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: AppTheme.pastelBlue(context),
            child: Icon(
              iconData,
              color: AppTheme.pastelBlueText(context),
              size: 22,
            ),
          ),
          title: topic.title,
          subtitle: subtitle,
        ),
        const VGapSm(),
        if (onEdit != null)
          SheetActionRow(
            icon: Icons.edit_outlined,
            title: 'Edit Topic',
            onTap: () => Navigator.pop(context, TopicOptionAction.edit),
          ),
        if (onOrderTopic != null)
          SheetActionRow(
            icon: Icons.reorder_rounded,
            title: 'Order Topic',
            onTap: () => Navigator.pop(context, TopicOptionAction.order),
          ),
        if (topicRev == null) ...[
          SheetActionRow(
            icon: Icons.replay_rounded,
            title: 'Add to Revision',
            onTap: () => Navigator.pop(context, TopicOptionAction.addToRevision),
          ),
        ] else ...[
          SheetActionRow(
            icon: Icons.check_circle_outline_rounded,
            title: 'In Revision (${topicRev.levelLabel}${topicRev.isFinished ? ' - Mastered' : ''})',
            subtitle: 'Next: ${topicRev.dueStatusLabel(DateTime.now())}',
            onTap: null,
          ),
          SheetActionRow(
            icon: Icons.restart_alt_rounded,
            title: 'Reset Revision Ladder',
            onTap: () => Navigator.pop(context, TopicOptionAction.resetRevision),
          ),
          if (showRemoveFromRevision)
            SheetActionRow(
              icon: Icons.bookmark_remove_outlined,
              title: 'Remove from Revision',
              onTap: () => Navigator.pop(context, TopicOptionAction.removeFromRevision),
            ),
        ],
        if (onDelete != null) ...[
          const VGapXs(),
          SheetDestructiveButton(
            title: 'Delete Topic',
            onTap: () => Navigator.pop(context, TopicOptionAction.delete),
          ),
        ],
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
