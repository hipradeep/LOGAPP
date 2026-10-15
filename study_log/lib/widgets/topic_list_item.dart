import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;
    if (showCheckbox) {
      final indicator = TopicStatusIndicator(status: topic.status);
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

    return CompactListItem(
      isCard: isCard,
      isCompleted: topic.isCompleted,
      leading: leadingWidget,
      title: topic.title,
      titleBadge: badge,
      showTrailingChevron: showTrailing,
      onTap: onTap,
      onLongPress: onLongPress,
      onOptionsTap: onOptionsTap,
      titleMaxLines: titleMaxLines,
    );
  }
}
