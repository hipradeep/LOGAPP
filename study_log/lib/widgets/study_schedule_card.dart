
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Modern Course & Module Card matching the reference design:
/// - Rounded square icon container with rotating pastel accents
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

  @override
  Widget build(BuildContext context) {
    final theme = _getTheme(context, index);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pastel rounded square icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.bg,
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                    border: Border.all(color: theme.border, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    theme.icon,
                    color: theme.accent,
                    size: 24,
                  ),
                ),
                const HGapMd(),
                // Title, Subtitle & Progress Bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
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
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                // Trailing Chevron
                 Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMutedColor(context),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
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

