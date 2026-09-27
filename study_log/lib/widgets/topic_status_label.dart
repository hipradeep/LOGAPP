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
            color: Color(0xFF10B981),
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
        return const Text(
          'Not started',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9CA3AF),
          ),
        );
    }
  }
}
