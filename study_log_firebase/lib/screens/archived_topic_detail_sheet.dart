import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/sheet_action_widgets.dart';

/// Read-only bottom sheet for an archived topic.
///
/// Archived courses show only the topic name in the list, so tapping a row opens
/// this sheet to reveal the description (and completion state) on demand.
class ArchivedTopicDetailSheet extends StatelessWidget {
  final Topic topic;
  final String moduleTitle;

  const ArchivedTopicDetailSheet({
    super.key,
    required this.topic,
    required this.moduleTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required Topic topic,
    required String moduleTitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ArchivedTopicDetailSheet(topic: topic, moduleTitle: moduleTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final hasDescription = topic.description.trim().isNotEmpty;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: topic.isCompleted
                ? AppTheme.successColor.withValues(alpha: 0.12)
                : AppTheme.pastelBlue(context),
            child: Icon(
              topic.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.menu_book_rounded,
              size: 20,
              color: topic.isCompleted
                  ? AppTheme.successColor
                  : AppTheme.primaryColor,
            ),
          ),
          title: topic.title,
          subtitle: moduleTitle,
        ),
        const VGapMd(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: topic.isCompleted
                ? AppTheme.successColor.withValues(alpha: 0.10)
                : AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                topic.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: topic.isCompleted
                    ? AppTheme.successColor
                    : AppTheme.textMutedColor(context),
              ),
              const HGapXs(),
              Text(
                topic.isCompleted ? 'Completed' : 'Not completed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: topic.isCompleted
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
        const VGapMd(),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.45),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: hasDescription
                ? Text(
                    topic.description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppTheme.textMutedColor(context),
                      ),
                      const HGapSm(),
                      Expanded(
                        child: Text(
                          'No description added for this topic.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const VGapLg(),
        SheetCancelButton(),
      ],
    );
  }
}
