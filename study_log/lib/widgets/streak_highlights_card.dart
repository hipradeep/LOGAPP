import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../controllers/progress_controller.dart';

/// Top Card: Total Active Days and Max Streak
class StreakHighlightsCard extends StatelessWidget {
  final ProgressController controller;

  const StreakHighlightsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF063321) : const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF10B981),
                    size: 15,
                  ),
                ),
                const HGapSm(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: 'Total active days: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${controller.totalActiveDays}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.borderColor(context),
          ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF332306) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                ),
                const HGapSm(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: 'Max streak: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '${controller.longestStreak}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Activity Heatmap Card
// =============================================================================
