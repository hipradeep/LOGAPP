import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/topic.dart';

/// Circular status glyph for a topic row.
///
/// Completed is a filled tick, in-progress a partial ring, and not-started an
/// empty outline, so the three states stay distinguishable without relying on
/// colour alone.
class TopicStatusIndicator extends StatelessWidget {
  final TopicStatus status;

  const TopicStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TopicStatus.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 18,
          ),
        );
      case TopicStatus.inProgress:
        return const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            value: 0.72,
            strokeWidth: 2.8,
            color: AppTheme.primaryColor,
            backgroundColor: Color(0xFFE8E5FF),
          ),
        );
      case TopicStatus.notStarted:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 2.0,
            ),
          ),
        );
    }
  }
}
