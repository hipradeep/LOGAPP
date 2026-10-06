import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/topic.dart';

/// Caption that spells out the [TopicStatusIndicator] state in words.
class TopicStatusLabel extends StatelessWidget {
  final TopicStatus status;

  const TopicStatusLabel({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TopicStatus.completed:
        return const Text(
          'Completed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.successColor,
          ),
        );
      case TopicStatus.inProgress:
        return const Text(
          'In Progress',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.primaryColor,
          ),
        );
      case TopicStatus.notStarted:
        return  Text(
          'Not started',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textMutedColor(context),
          ),
        );
    }
  }
}
