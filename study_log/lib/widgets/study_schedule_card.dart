import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Modern Course & Section Card matching the reference design:
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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const StudyScheduleCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.progressRatio,
    this.index = 0,
    this.progress = 0.45,
    this.onTap,
    this.onLongPress,
  });

  _PastelTheme _getTheme(int i) {
    switch (i % 4) {
      case 0:
        return const _PastelTheme(
          bg: AppTheme.pastelPurple,
          border: AppTheme.pastelPurpleBorder,
          accent: AppTheme.pastelPurpleText,
          icon: Icons.code_rounded,
        );
      case 1:
        return const _PastelTheme(
          bg: AppTheme.pastelGreen,
          border: AppTheme.pastelGreenBorder,
          accent: AppTheme.pastelGreenText,
          icon: Icons.settings_suggest_rounded,
        );
      case 2:
        return const _PastelTheme(
          bg: AppTheme.pastelOrange,
          border: AppTheme.pastelOrangeBorder,
          accent: AppTheme.pastelOrangeText,
          icon: Icons.smart_toy_rounded,
        );
      default:
        return const _PastelTheme(
          bg: AppTheme.pastelBlue,
          border: AppTheme.pastelBlueBorder,
          accent: AppTheme.pastelBlueText,
          icon: Icons.hub_outlined,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getTheme(index);

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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.05, 1.0),
                                minHeight: 5,
                                backgroundColor: const Color(0xFFECEEF6),
                                valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
                              ),
                            ),
                          ),
                          if (progressRatio != null) ...[
                            const HGapSm(),
                            Text(
                              progressRatio!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
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
