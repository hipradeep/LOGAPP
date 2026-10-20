import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../controllers/progress_controller.dart';

/// Summary Card: Topics finished, revisions, accuracy, etc.
class SummaryStatsCard extends StatelessWidget {
  final ProgressController controller;

  const SummaryStatsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final finished = controller.totalTopicsFinished;
    final revisions = controller.totalTopicRevisions;
    final totalActions = finished + revisions;
    final finishedPct = totalActions > 0 ? (finished / totalActions * 100).round() : 0;
    final revisionsPct = totalActions > 0 ? (100 - finishedPct) : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Study Volume',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const HGapSm(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$totalActions actions',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const VGapSm(),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'Topics finished',
                  subtitle: 'Completed',
                  count: finished,
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: isDark ? const Color(0xFF063321) : const Color(0xFFE8F8F0),
                  tileBgColor: isDark ? const Color(0xFF0F1F17) : const Color(0xFFF6FDF9),
                  borderColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.18),
                ),
              ),
              const HGapSm(),
              Expanded(
                child: _MetricTile(
                  title: 'Topic revisions',
                  subtitle: 'Reviewed',
                  count: revisions,
                  icon: Icons.sync_rounded,
                  iconColor: const Color(0xFF7A6EFC),
                  iconBgColor: isDark ? const Color(0xFF231E52) : const Color(0xFFF0EEFF),
                  tileBgColor: isDark ? const Color(0xFF161426) : const Color(0xFFF8F7FF),
                  borderColor: const Color(0xFF7A6EFC).withValues(alpha: isDark ? 0.25 : 0.18),
                ),
              ),
            ],
          ),
          if (totalActions > 0) ...[
            const VGapSm(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    if (finished > 0)
                      Expanded(
                        flex: finished,
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                    if (finished > 0 && revisions > 0)
                      Container(width: 2, color: AppTheme.surface(context)),
                    if (revisions > 0)
                      Expanded(
                        flex: revisions,
                        child: Container(color: const Color(0xFF7A6EFC)),
                      ),
                  ],
                ),
              ),
            ),
            const VGapXs(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), shape: BoxShape.circle,
                        ),
                      ),
                      const HGapXs(),
                      Flexible(
                        child: Text(
                          '$finishedPct% finished',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7A6EFC), shape: BoxShape.circle,
                        ),
                      ),
                      const HGapXs(),
                      Flexible(
                        child: Text(
                          '$revisionsPct% revisions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color tileBgColor;
  final Color borderColor;

  const _MetricTile({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.tileBgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tileBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const HGapXs(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const VGapXs(),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
// =============================================================================
// Card 3: Activity Breakdown Stacked Bar Chart (Weekly Wise)
// =============================================================================
