import 'package:flutter/material.dart';
import '../models/topic.dart';
import 'compact_list_item.dart';
import 'topic_status_indicator.dart';

/// Reusable topic list item component.
///
/// Features:
/// - Interactive status checkbox/glyph leading widget using [TopicStatusIndicator].
/// - Clean title display without redundant descriptions or status text.
/// - Configurable tap, long-press, and checkbox toggle handlers.
/// - Supports both flat list row (ideal with Dividers) and card style.
class TopicListItem extends StatelessWidget {
  final Topic topic;
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

    return CompactListItem(
      isCard: isCard,
      isCompleted: topic.isCompleted,
      leading: leadingWidget,
      title: topic.title,
      showTrailingChevron: showTrailing,
      onTap: onTap,
      onLongPress: onLongPress,
      onOptionsTap: onOptionsTap,
      titleMaxLines: titleMaxLines,
    );
  }
}
