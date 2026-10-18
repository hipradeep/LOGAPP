import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Compact, high-density collapsible section header for task groups.
///
/// Features:
/// - ~36px height maximizing vertical information density.
/// - Category title with letter-spacing.
/// - Count badge pill.
/// - Smooth animated chevron rotation indicating collapsed/expanded state.
/// - Full-width touch target for easy tapping.
class TodoGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isCollapsed;
  final VoidCallback onTap;
  final Color? countBadgeColor;
  final Color? countTextColor;

  const TodoGroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.isCollapsed,
    required this.onTap,
    this.countBadgeColor,
    this.countTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.textSecondaryColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
            const HGapSm(),
            // Compact Count Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: countBadgeColor ?? AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: countTextColor ?? textColor,
                  height: 1.1,
                ),
              ),
            ),
            const Spacer(),
            // Animated Chevron
            AnimatedRotation(
              turns: isCollapsed ? 0.0 : 0.25, // 0 deg -> 90 deg down
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
