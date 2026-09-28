import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';

/// "My Progress" screen matching the reference design:
/// - Header with back navigation, screen title, and dynamic time range filter
/// - Streak & Heatmap Strike activity card (Current streak, Longest streak, Most active day)
///   with 5-tier green strike heatmap grid and month labels
/// - Summary Stats card (Topics finished vs Topic revisions)
/// - Activity Breakdown stacked bar chart (Topics Finished green + Topic Revisions purple)
/// - Recent Activity card with day-by-day breakdown
class MyProgressScreen extends StatelessWidget {
  const MyProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final progressController = getIt<ProgressController>();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: progressController.refresh,
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.surface(context),
          child: ListenableBuilder(
            listenable: progressController,
            builder: (context, _) {
              if (progressController.isLoading && progressController.activitiesInRange.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomSafe + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MyProgressTopBar(),
                    const VGapLg(),
                    _StreakHighlightsCard(controller: progressController),
                    const VGapLg(),
                    _StrikeHeatmapCard(controller: progressController),
                    const VGapLg(),
                    _SummaryStatsCard(controller: progressController),
                    const VGapLg(),
                    _ActivityBreakdownCard(controller: progressController),
                    const VGapLg(),
                    _RecentActivityCard(controller: progressController),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Top Bar with Back Button and Scope Badge
// =============================================================================
class _MyProgressTopBar extends StatelessWidget {
  const _MyProgressTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  'My Progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const HGapSm(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.pastelPurple(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
            ),
          ),
          child: const Text(
            'Last 3 Months',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Card 1: Streak Highlights (Current Streak, Longest Streak, Most Active Day)
// =============================================================================
class _StreakHighlightsCard extends StatelessWidget {
  final ProgressController controller;

  const _StreakHighlightsCard({required this.controller});

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mostActiveDate = controller.mostActiveDay != null
        ? _dateFormat.format(controller.mostActiveDay!)
        : 'Today';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
          // 1. Current streak
          Expanded(
            child: _StreakStatItem(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFF10B981),
              iconBgColor: isDark
                  ? const Color(0xFF063321)
                  : const Color(0xFFE8F8F0),
              value: '${controller.currentStreak}',
              unit: 'days',
              label: 'Current streak',
            ),
          ),

          // Divider 1
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.borderColor(context),
          ),

          // 2. Longest streak
          Expanded(
            child: _StreakStatItem(
              icon: Icons.bolt_rounded,
              iconColor: const Color(0xFF7A6EFC),
              iconBgColor: isDark
                  ? const Color(0xFF231E52)
                  : const Color(0xFFF0EEFF),
              value: '${controller.longestStreak}',
              unit: 'days',
              label: 'Longest streak',
            ),
          ),

          // Divider 2
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppTheme.borderColor(context),
          ),

          // 3. Most active day
          Expanded(
            child: _StreakStatItem(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBgColor: isDark
                  ? const Color(0xFF332306)
                  : const Color(0xFFFEF3C7),
              value: mostActiveDate,
              unit: '',
              label: 'Most active day',
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakStatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String unit;
  final String label;

  const _StreakStatItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: iconColor,
                size: 16,
              ),
            ),
            const HGapXs(),
            Flexible(
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: unit.isNotEmpty ? 15 : 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  children: unit.isNotEmpty
                      ? [
                          TextSpan(
                            text: ' $unit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
        const VGapXs(),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Card 2: 3-Month Strike Activity Heatmap Grid
// =============================================================================
class _StrikeHeatmapCard extends StatelessWidget {
  final ProgressController controller;

  const _StrikeHeatmapCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final activeDaysCount = controller.activitiesInRange.where((a) => a.hasActivity).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  '3-Month Strike Activity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const HGapSm(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeDaysCount active days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),
          _HeatmapGrid(controller: controller),
        ],
      ),
    );
  }
}

// =============================================================================
// Heatmap Grid Widget (7-row calendar week alignment for 3-month view)
// =============================================================================
class _HeatmapGrid extends StatelessWidget {
  final ProgressController controller;

  const _HeatmapGrid({required this.controller});

  static final DateFormat _monthFormat = DateFormat('MMM');

  Color _cellColor(BuildContext context, StrikeActivityLevel level) {
    final isDark = AppTheme.isDark;
    switch (level) {
      case StrikeActivityLevel.none:
        return isDark ? const Color(0xFF232936) : const Color(0xFFEFF2F6);
      case StrikeActivityLevel.low:
        return const Color(0xFFB7E4C7);
      case StrikeActivityLevel.medium:
        return const Color(0xFF52B788);
      case StrikeActivityLevel.high:
        return const Color(0xFF1B8A5A);
      case StrikeActivityLevel.mostActive:
        return const Color(0xFF0B4228); // Darkest green for most active day
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = controller.activitiesInRange;
    if (items.isEmpty) return const SizedBox.shrink();

    const int rows = 7; // Mon - Sun
    final firstDate = items.first.date;
    // Weekday: Monday is 1, Sunday is 7 in DateTime
    final int startPadding = firstDate.weekday - 1;

    // Total cells in grid
    final int totalCells = startPadding + items.length;
    final int cols = (totalCells / rows).ceil();
    final maxActivity = controller.mostActiveDayCount;

    // Collect month label for each column
    final Map<int, String> monthLabels = {};
    String lastMonth = '';

    for (int col = 0; col < cols; col++) {
      for (int row = 0; row < rows; row++) {
        final cellIdx = col * rows + row;
        final itemIdx = cellIdx - startPadding;
        if (itemIdx >= 0 && itemIdx < items.length) {
          final m = _monthFormat.format(items[itemIdx].date);
          if (m != lastMonth) {
            monthLabels[col] = m;
            lastMonth = m;
          }
          break;
        }
      }
    }

    const double cellSize = 13.5;
    const double cellGap = 3.5;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels row above columns
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cols, (colIndex) {
                final label = monthLabels[colIndex];
                return SizedBox(
                  width: cellSize + cellGap,
                  child: label != null
                      ? Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        )
                      : null,
                );
              }),
            ),
          ),

          // Main Heatmap Grid with Weekday indicators
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Weekday labels: Mon, Wed, Fri
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _weekdayLabel(context, 'M', cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayPlaceholder(cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayLabel(context, 'W', cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayPlaceholder(cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayLabel(context, 'F', cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayPlaceholder(cellSize),
                    const SizedBox(height: cellGap),
                    _weekdayPlaceholder(cellSize),
                  ],
                ),
              ),

              // Columns of 7 days each
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(cols, (colIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: cellGap),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(rows, (rowIndex) {
                        final cellIdx = colIndex * rows + rowIndex;
                        final itemIdx = cellIdx - startPadding;

                        if (itemIdx < 0 || itemIdx >= items.length) {
                          return const SizedBox(
                            width: cellSize,
                            height: cellSize + cellGap,
                          );
                        }

                        final activity = items[itemIdx];
                        final level = activity.activityLevel(maxActivity);
                        final color = _cellColor(context, level);

                        return Tooltip(
                          message:
                              '${DateFormat('EEE, d MMM yyyy').format(activity.date)}\n'
                              '${activity.topicsFinished} topics finished • ${activity.revisionsDone} revisions',
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            margin: const EdgeInsets.only(bottom: cellGap),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3.0),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdayLabel(BuildContext context, String text, double size) {
    return SizedBox(
      width: 14,
      height: size,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }

  Widget _weekdayPlaceholder(double size) {
    return SizedBox(width: 14, height: size);
  }
}

// =============================================================================
// Card 2: Summary Stats (Topics Finished vs Topic Revisions)
// =============================================================================
class _SummaryStatsCard extends StatelessWidget {
  final ProgressController controller;

  const _SummaryStatsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final finished = controller.totalTopicsFinished;
    final revisions = controller.totalTopicRevisions;
    final totalActions = finished + revisions;
    final finishedPct = totalActions > 0 ? (finished / totalActions * 100).round() : 0;
    final revisionsPct = totalActions > 0 ? (100 - finishedPct) : 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Section title + Total badge
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const HGapSm(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  '$totalActions actions',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),

          // Two side-by-side metric tiles
          Row(
            children: [
              // Left Tile: Topics Finished
              Expanded(
                child: _MetricTile(
                  title: 'Topics finished',
                  subtitle: 'Completed',
                  count: finished,
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: isDark
                      ? const Color(0xFF063321)
                      : const Color(0xFFE8F8F0),
                  tileBgColor: isDark
                      ? const Color(0xFF0F1F17)
                      : const Color(0xFFF6FDF9),
                  borderColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.18),
                ),
              ),
              const HGapMd(),

              // Right Tile: Topic Revisions
              Expanded(
                child: _MetricTile(
                  title: 'Topic revisions',
                  subtitle: 'Reviewed',
                  count: revisions,
                  icon: Icons.sync_rounded,
                  iconColor: const Color(0xFF7A6EFC),
                  iconBgColor: isDark
                      ? const Color(0xFF231E52)
                      : const Color(0xFFF0EEFF),
                  tileBgColor: isDark
                      ? const Color(0xFF161426)
                      : const Color(0xFFF8F7FF),
                  borderColor: const Color(0xFF7A6EFC).withValues(alpha: isDark ? 0.25 : 0.18),
                ),
              ),
            ],
          ),

          if (totalActions > 0) ...[
            const VGapLg(),
            // Activity Distribution Split Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
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
            const VGapSm(),

            // Split Bar Footnote
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const HGapXs(),
                      Flexible(
                        child: Text(
                          '$finishedPct% finished',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
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
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7A6EFC),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const HGapXs(),
                      Flexible(
                        child: Text(
                          '$revisionsPct% revisions',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const HGapXs(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
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
          const VGapSm(),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.5,
            ),
          ),
          const VGapXs(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
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
// Card 3: Activity Breakdown Stacked Bar Chart
// =============================================================================
class _ActivityBreakdownCard extends StatelessWidget {
  final ProgressController controller;

  const _ActivityBreakdownCard({required this.controller});

  List<DailyProgressActivity> _aggregateActivities(List<DailyProgressActivity> raw) {
    if (raw.length <= 31) return raw;

    // Aggregate into weekly buckets (7 days each)
    final List<DailyProgressActivity> weekly = [];
    for (int i = 0; i < raw.length; i += 7) {
      final end = (i + 7 < raw.length) ? i + 7 : raw.length;
      final chunk = raw.sublist(i, end);
      int finished = 0;
      int revisions = 0;
      for (final a in chunk) {
        finished += a.topicsFinished;
        revisions += a.revisionsDone;
      }
      weekly.add(DailyProgressActivity(
        date: chunk.first.date,
        topicsFinished: finished,
        revisionsDone: revisions,
      ));
    }
    return weekly;
  }

  @override
  Widget build(BuildContext context) {
    final chartActivities = _aggregateActivities(controller.activitiesInRange);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapLg(),

          // Custom Painted Stacked Bar Chart
          RepaintBoundary(
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _ActivityBreakdownPainter(
                  activities: chartActivities,
                  gridColor: AppTheme.borderColor(context),
                  textColor: AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBreakdownPainter extends CustomPainter {
  final List<DailyProgressActivity> activities;
  final Color gridColor;
  final Color textColor;

  _ActivityBreakdownPainter({
    required this.activities,
    required this.gridColor,
    required this.textColor,
  });

  static final DateFormat _dayFormat = DateFormat('d MMM');

  @override
  void paint(Canvas canvas, Size size) {
    if (activities.isEmpty) return;

    const double leftPadding = 24.0;
    const double bottomPadding = 24.0;
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;

    // Determine max value for Y-axis scale (at least 10, or up to 30)
    int maxVal = 10;
    for (final a in activities) {
      if (a.totalActivity > maxVal) maxVal = a.totalActivity;
    }
    // Round up to nearest multiple of 10
    final int topY = ((maxVal + 9) ~/ 10) * 10;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw Y-axis reference lines & labels (e.g. 0, 10, 20, 30)
    const int stepCount = 3;
    for (int i = 0; i <= stepCount; i++) {
      final val = (topY / stepCount * i).round();
      final y = chartHeight - (chartHeight / stepCount * i);

      // Dashed horizontal line
      _drawDashedLine(canvas, Offset(leftPadding, y), Offset(size.width, y), gridPaint);

      // Y-axis label
      textPainter.text = TextSpan(
        text: '$val',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Draw Stacked Bars
    final int count = activities.length;
    final double slotWidth = chartWidth / count;
    final double barWidth = (slotWidth * 0.55).clamp(4.0, 10.0);

    final Paint finishedPaint = Paint()..color = const Color(0xFF10B981);
    final Paint revisionPaint = Paint()..color = const Color(0xFF7A6EFC);

    final int labelStep = count > 30 ? 7 : (count > 15 ? 4 : 2);

    for (int i = 0; i < count; i++) {
      final act = activities[i];
      final double x = leftPadding + (i * slotWidth) + (slotWidth - barWidth) / 2;

      final double finishedHeight = (act.topicsFinished / topY) * chartHeight;
      final double revisionHeight = (act.revisionsDone / topY) * chartHeight;
      final double totalHeight = finishedHeight + revisionHeight;

      if (totalHeight > 0) {
        final double baseY = chartHeight;

        // Bottom green segment
        if (finishedHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - finishedHeight,
            barWidth,
            finishedHeight,
          );
          // If no revision on top, round top corners
          if (revisionHeight <= 0) {
            final rrect = RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3),
            );
            canvas.drawRRect(rrect, finishedPaint);
          } else {
            canvas.drawRect(rect, finishedPaint);
          }
        }

        // Top purple segment
        if (revisionHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - totalHeight,
            barWidth,
            revisionHeight,
          );
          final rrect = RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          );
          canvas.drawRRect(rrect, revisionPaint);
        }
      }

      // X-axis label
      if (i % labelStep == 0 || i == count - 1) {
        textPainter.text = TextSpan(
          text: _dayFormat.format(act.date),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x + barWidth / 2 - textPainter.width / 2, chartHeight + 6),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 4.0;
    const double dashSpace = 4.0;
    double currentX = start.dx;
    while (currentX < end.dx) {
      canvas.drawLine(
        Offset(currentX, start.dy),
        Offset((currentX + dashWidth).clamp(start.dx, end.dx), start.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityBreakdownPainter oldDelegate) {
    return oldDelegate.activities != activities ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

// =============================================================================
// Card 4: Recent Activity List
// =============================================================================
class _RecentActivityCard extends StatefulWidget {
  final ProgressController controller;

  const _RecentActivityCard({required this.controller});

  @override
  State<_RecentActivityCard> createState() => _RecentActivityCardState();
}

class _RecentActivityCardState extends State<_RecentActivityCard> {
  bool _showAll = false;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');
  static final DateFormat _weekdayFormat = DateFormat('EEE');

  @override
  Widget build(BuildContext context) {
    final allRecent = widget.controller.recentActivities;
    final displayItems = _showAll ? allRecent : allRecent.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              if (allRecent.length > 4)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAll ? 'Show Less' : 'View All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const HGapXs(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const VGapMd(),

          if (displayItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No activity recorded yet in the last 3 months.\nComplete topics and revisions to build your streak!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor(context),
                    height: 1.4,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: displayItems.length,
              separatorBuilder: (context, _) => Divider(
                color: AppTheme.borderColor(context),
                height: 24,
              ),
              itemBuilder: (context, index) {
                final item = displayItems[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date & Weekday Column
                    SizedBox(
                      width: 82,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dateFormat.format(item.date),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const VGapXs(),
                          Text(
                            _weekdayFormat.format(item.date),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textSecondaryColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HGapSm(),

                    // Topics Finished Pill
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Color(0xFF10B981),
                              size: 16,
                            ),
                          ),
                          const HGapXs(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.topicsFinished}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor(context),
                                  ),
                                ),
                                Text(
                                  'Topics finished',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HGapXs(),

                    // Topic Revisions Pill
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEFF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sync_rounded,
                              color: Color(0xFF7A6EFC),
                              size: 16,
                            ),
                          ),
                          const HGapXs(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${item.revisionsDone}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryColor(context),
                                  ),
                                ),
                                Text(
                                  'Topic revisions',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Trailing Chevron
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
