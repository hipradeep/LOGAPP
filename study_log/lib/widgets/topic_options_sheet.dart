import 'package:flutter/material.dart';
import '../controllers/topic_revision_controller.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/topic_icon_util.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

enum TopicOptionAction {
  edit,
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
  final VoidCallback? onEdit;
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
    this.onEdit,
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
    VoidCallback? onEdit,
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
        onEdit: onEdit,
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
        break;
      case TopicOptionAction.removeFromRevision:
        await _handleRemoveFromRevision(context, topic: topic);
        break;
      case TopicOptionAction.resetRevision:
        await _handleResetRevision(context, topic: topic);
        break;
      case TopicOptionAction.delete:
        onDelete?.call();
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
    if (!getIt.isRegistered<TopicRevisionController>()) return;
    try {
      await getIt<TopicRevisionController>().deleteByTopicId(topic.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${topic.title}" removed from revision schedule'),
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
        SheetActionRow(
          icon: Icons.edit_outlined,
          title: 'Edit Topic',
          onTap: () => Navigator.pop(context, TopicOptionAction.edit),
        ),
        SheetActionRow(
          icon: Icons.copy_rounded,
          title: 'Duplicate Topic',
          onTap: () => Navigator.pop(context, TopicOptionAction.duplicate),
        ),
        SheetActionRow(
          icon: Icons.swap_vert_rounded,
          title: 'Move Topic',
          onTap: () => Navigator.pop(context, TopicOptionAction.move),
        ),
        if (topicRev == null) ...[
          SheetActionRow(
            icon: Icons.replay_rounded,
            title: 'Add to Revision',
            subtitle: 'Start spaced repetition (R1 → R5) for this topic',
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
            subtitle: 'Restart spaced repetition back at R1',
            onTap: () => Navigator.pop(context, TopicOptionAction.resetRevision),
          ),
          SheetActionRow(
            icon: Icons.bookmark_remove_outlined,
            title: 'Remove from Revision',
            subtitle: 'Stop revision reminders for this topic',
            onTap: () => Navigator.pop(context, TopicOptionAction.removeFromRevision),
          ),
        ],
        const VGapXs(),
        SheetDestructiveButton(
          title: 'Delete Topic',
          onTap: () => Navigator.pop(context, TopicOptionAction.delete),
        ),
        const VGapSm(),
        const SheetCancelButton(),
      ],
    );
  }
}
