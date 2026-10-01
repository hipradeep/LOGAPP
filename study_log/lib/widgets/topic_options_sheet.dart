import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../theme/app_theme.dart';
import '../utils/topic_icon_util.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

enum TopicOptionAction { edit, duplicate, move, delete }

/// Bottom action sheet presented when tapping options or long-pressing a Topic row.
/// Matches the reference design with squircle header, clean action rows, red delete button, and cancel button.
class TopicOptionsSheet extends StatelessWidget {
  final Topic topic;
  final String moduleTitle;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onMove;
  final VoidCallback? onDelete;

  const TopicOptionsSheet({
    super.key,
    required this.topic,
    required this.moduleTitle,
    this.onEdit,
    this.onDuplicate,
    this.onMove,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required Topic topic,
    required String moduleTitle,
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
      case TopicOptionAction.delete:
        onDelete?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = topicIconFrom(topic.iconCodePoint);

    final subtitle = moduleTitle;

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
