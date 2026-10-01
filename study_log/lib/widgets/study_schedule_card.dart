
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'compact_list_item.dart';
import 'course_icon_chip.dart';

/// Modern Course & Module Card matching the reference design:
/// - Rounded square icon container with course glyph & color accent
/// - Bold course/topic title
/// - Breadcrumb subtitle (e.g. "DSA › Basic Problems")
/// - Category-matched progress bar indicator + progress ratio (e.g. "3 / 8")
/// - Trailing chevron
class StudyScheduleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? progressRatio;
  final int index;
  final double progress;
  final double inProgressRatio;
  final Course? course;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const StudyScheduleCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.progressRatio,
    this.index = 0,
    this.progress = 0.0,
    this.inProgressRatio = 0.0,
    this.course,
    this.onTap,
    this.onLongPress,
  });

  _PastelTheme _getTheme(BuildContext context, int i) {
    switch (i % 4) {
      case 0:
        return _PastelTheme(
          bg: AppTheme.pastelOrange(context),
          border: AppTheme.pastelOrangeBorder(context),
          accent: AppTheme.pastelOrangeText(context),
          icon: Icons.code_rounded,
        );
      case 1:
        return _PastelTheme(
          bg: AppTheme.pastelGreen(context),
          border: AppTheme.pastelGreenBorder(context),
          accent: AppTheme.pastelGreenText(context),
          icon: Icons.hub_outlined,
        );
      case 2:
        return _PastelTheme(
          bg: AppTheme.pastelBlue(context),
          border: AppTheme.pastelBlueBorder(context),
          accent: AppTheme.pastelBlueText(context),
          icon: Icons.psychology_rounded,
        );
      default:
        return _PastelTheme(
          bg: AppTheme.pastelPurple(context),
          border: AppTheme.pastelPurpleBorder(context),
          accent: AppTheme.pastelPurpleText(context),
          icon: Icons.data_object_rounded,
        );
    }
  }

  Widget _buildLeading(BuildContext context) {
    if (course != null) {
      return CourseIconChip(
        courseId: course!.id,
        iconCodePoint: course!.iconCodePoint,
        colorValue: course!.colorValue,
        size: 38,
        radius: 10,
      );
    }
    final theme = _getTheme(context, index);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(
        theme.icon,
        color: theme.accent,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompactListItem(
      leading: _buildLeading(context),
      title: title,
      subtitle: subtitle,
      margin: EdgeInsets.zero,
      bottom: Row(
        children: [
          Expanded(
            child: _TwoColorProgressBar(
              completedRatio: progress.clamp(0.0, 1.0),
              inProgressRatio: inProgressRatio.clamp(0.0, 1.0),
            ),
          ),
          if (progressRatio != null) ...[
            const HGapSm(),
            Text(
              progressRatio!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _PastelTheme {
  final Color bg;
  final Color border;
  final Color accent;
  final IconData icon;

  const _PastelTheme({
    required this.bg,
    required this.border,
    required this.accent,
    required this.icon,
  });
}

/// A stacked progress bar with two distinct color segments:
/// - Green = completed ratio
/// - Primary purple = in-progress ratio
/// - Grey background = remaining
class _TwoColorProgressBar extends StatelessWidget {
  final double completedRatio;
  final double inProgressRatio;

  const _TwoColorProgressBar({
    required this.completedRatio,
    required this.inProgressRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final completedW = width * completedRatio;
            final inProgressW = (width * inProgressRatio).clamp(0.0, width - completedW);
            return Stack(
              children: [
                // Background track
                Container(
                  width: width,
                  color: const Color(0xFFECEEF6),
                ),
                // In-progress segment
                if (inProgressW > 0)
                  Container(
                    width: completedW + inProgressW,
                    color: AppTheme.primaryColor,
                  ),
                // Completed segment (on top, green)
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

