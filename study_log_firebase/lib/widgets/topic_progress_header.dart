import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

/// \"N / M topics\" plus a two-color progress bar, shown above a topic list.
/// - Green segment = completed topics
/// - Primary color segment = in-progress topics
class TopicProgressHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final double progress;
  final double inProgressRatio;

  const TopicProgressHeader({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.progress,
    this.inProgressRatio = 0.0,
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
        _TwoColorTopicProgressBar(
          completedRatio: progress.clamp(0.0, 1.0),
          inProgressRatio: inProgressRatio.clamp(0.0, 1.0),
        ),
      ],
    );
  }
}

class _TwoColorTopicProgressBar extends StatelessWidget {
  final double completedRatio;
  final double inProgressRatio;

  const _TwoColorTopicProgressBar({
    required this.completedRatio,
    required this.inProgressRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final completedW = width * completedRatio;
            final inProgressW = (width * inProgressRatio).clamp(0.0, width - completedW);
            return Stack(
              children: [
                // Background track
                Container(width: width, color: const Color(0xFFECEEF6)),
                // In-progress segment (primary color)
                if (inProgressW > 0)
                  Container(
                    width: completedW + inProgressW,
                    color: AppTheme.primaryColor,
                  ),
                // Completed segment (green, on top)
                if (completedW > 0)
                  Container(
                    width: completedW,
                    color: AppTheme.successColor,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
