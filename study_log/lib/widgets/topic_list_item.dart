import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../theme/app_theme.dart';
import 'compact_list_item.dart';
import 'topic_revision_badge.dart';
import 'topic_status_indicator.dart';

/// Reusable topic list item component.
///
/// Features:
/// - Interactive status checkbox/glyph leading widget using [TopicStatusIndicator].
/// - Clean title display without redundant descriptions or status text.
/// - Spaced repetition badge support via [TopicRevisionBadge].
/// - Configurable tap, long-press, and checkbox toggle handlers.
/// - Supports both flat list row (ideal with Dividers) and card style.
class TopicListItem extends StatelessWidget {
  final Topic topic;
  final TopicRevision? topicRevision;
  final Widget? titleBadge;
  final VoidCallback? onCheckboxTap;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;
  final bool isCard;
  final bool showCheckbox;
  final bool showTrailing;
  final int? titleMaxLines;
  final Widget? trailing;
  final String? subtitle;

  const TopicListItem({
    super.key,
    required this.topic,
    this.topicRevision,
    this.titleBadge,
    this.onCheckboxTap,
    this.onTap,
    this.onLongPress,
    this.onOptionsTap,
    this.isCard = false,
    this.showCheckbox = true,
    this.showTrailing = true,
    this.titleMaxLines,
    this.trailing,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isEarlyCompleted = topicRevision != null &&
        !topicRevision!.isFinished &&
        topicRevision!.levelStatus == TopicStatus.completed &&
        !topicRevision!.isDueAt(now);

    Widget? leadingWidget;
    if (showCheckbox) {
      final effectiveStatus = topicRevision?.levelStatus ?? topic.status;
      final indicator = TopicStatusIndicator(
        status: effectiveStatus,
        completedColor: isEarlyCompleted ? AppTheme.pastelBlueText(context) : null,
      );
      leadingWidget = onCheckboxTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCheckboxTap,
              child: indicator,
            )
          : indicator;
    }

    final badge = titleBadge ??
        (topicRevision != null
            ? TopicRevisionBadge(revision: topicRevision!)
            : null);

    // Before due date, early completed revision is NOT cleared (should not be struck-through/dimmed).
    final effectiveIsCompleted = topicRevision != null
        ? (topicRevision!.isFinished ||
            (topicRevision!.levelStatus == TopicStatus.completed && topicRevision!.isDueAt(now)))
        : topic.isCompleted;

    return CompactListItem(
      isCard: isCard,
      isCompleted: effectiveIsCompleted,
      leading: leadingWidget,
      title: topic.title,
      subtitle: subtitle,
      titleBadge: badge,
      trailing: trailing,
      showTrailingChevron: showTrailing,
      onTap: onTap,
      onLongPress: onLongPress,
      onOptionsTap: onOptionsTap,
      titleMaxLines: titleMaxLines,
    );
  }
}
