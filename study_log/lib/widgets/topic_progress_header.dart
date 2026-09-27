import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

/// "N / M topics" plus a progress bar, shown above a topic list.
class TopicProgressHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final double progress;

  const TopicProgressHeader({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedCount / $totalCount topics',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ],
        ),
        const VGapSm(),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFECEEF6),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}
