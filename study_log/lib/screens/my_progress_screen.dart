import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';
import 'activity_screen.dart';
import 'recent_activity_screen.dart';
import '../widgets/recent_activity_card.dart';

export '../widgets/recent_activity_card.dart';

/// "My Progress" screen showing:
/// - Top Card: Total active days and Max streak
/// - Activity Card: Calendar heatmap grid of study & revision activity
class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  late final ProgressController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = getIt<ProgressController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressController.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'My Progress',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: ListenableBuilder(
                  listenable: _progressController,
                  builder: (context, _) {
                    if (_progressController.isLoading &&
                        _progressController.totalTopicsFinished == 0 &&
                        _progressController.totalTopicRevisions == 0) {
                      return const SizedBox(
                        height: 300,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StreakHighlightsCard(controller: _progressController),
                        const VGapMd(),
                        StrikeHeatmapCard(controller: _progressController),
                        const VGapMd(),
                        SummaryStatsCard(controller: _progressController),
                        const VGapMd(),
                        ActivityBreakdownCard(controller: _progressController),
                        const VGapMd(),
                        RecentActivityCard(controller: _progressController),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Top Card: Total Active Days and Max Streak
// =============================================================================
class StreakHighlightsCard extends StatelessWidget {
  final ProgressController controller;

  const StreakHighlightsCard({required this.controller});

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
class StrikeHeatmapCard extends StatelessWidget {
  final ProgressController controller;

  const StrikeHeatmapCard({required this.controller});

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Activity',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapSm(),
          _HeatmapGrid(controller: controller),
        ],
      ),
    );
  }
}

// =============================================================================
// Heatmap Grid Widget (Month Blocks matching reference design)
// =============================================================================
class _MonthData {
  final DateTime monthDate;
  final bool isCurrentMonth;
  final List<List<DailyProgressActivity?>> columns;

  const _MonthData({
    required this.monthDate,
    required this.isCurrentMonth,
    required this.columns,
  });
}

class _HeatmapGrid extends StatelessWidget {
  final ProgressController controller;

  const _HeatmapGrid({required this.controller});

  Color _cellColor(BuildContext context, StrikeActivityLevel level) {
    final isDark = AppTheme.isDark;
    switch (level) {
      case StrikeActivityLevel.none:
        return isDark ? const Color(0xFF232936) : const Color(0xFFF1F5F9);
      case StrikeActivityLevel.low:
        return const Color(0xFF9AE6B4); // Mint green
      case StrikeActivityLevel.medium:
        return const Color(0xFF48BB78); // Fresh green
      case StrikeActivityLevel.high:
        return const Color(0xFF1E824C); // Rich green
      case StrikeActivityLevel.mostActive:
        return const Color(0xFF065F38); // Deep forest green
    }
  }

  static List<_MonthData> _buildMonthData(
    List<DailyProgressActivity> items,
    DateTime now,
  ) {
    final Map<DateTime, DailyProgressActivity> activityMap = {};
    for (final a in items) {
      activityMap[ProgressController.normalizeDate(a.date)] = a;
    }

    final List<_MonthData> result = [];

    // 3 consecutive months: 2 months ago, 1 month ago, current month
    for (int offset = 2; offset >= 0; offset--) {
      final monthDate = DateTime(now.year, now.month - offset, 1);
      final isCurrent = offset == 0;
      final totalDays = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      final List<List<DailyProgressActivity?>> columns = [];
      List<DailyProgressActivity?> currentCol = List.filled(7, null);

      for (int day = 1; day <= totalDays; day++) {
        final d = DateTime(monthDate.year, monthDate.month, day);
        final weekdayIdx = d.weekday - 1; // 0=Mon ... 6=Sun

        // Start a new column on Monday (except day 1 if day 1 is Monday)
        if (weekdayIdx == 0 && day > 1) {
          columns.add(currentCol);
          currentCol = List.filled(7, null);
        }

        final normDate = ProgressController.normalizeDate(d);
        currentCol[weekdayIdx] = activityMap[normDate] ??
            DailyProgressActivity(
              date: d,
              topicsFinished: 0,
              revisionsDone: 0,
            );
      }

      if (currentCol.any((element) => element != null)) {
        columns.add(currentCol);
      }

      result.add(_MonthData(
        monthDate: monthDate,
        isCurrentMonth: isCurrent,
        columns: columns,
      ));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = controller.activitiesInRange;
    final now = DateTime.now();
    final months = _buildMonthData(items, now);
    final maxActivity = controller.mostActiveDayCount;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(months.length, (idx) {
            final monthData = months[idx];
            return Padding(
              padding: EdgeInsets.only(
                right: idx < months.length - 1 ? 20.0 : 0.0,
              ),
              child: _MonthBlock(
                data: monthData,
                maxActivity: maxActivity,
                cellColor: _cellColor,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MonthBlock extends StatelessWidget {
  final _MonthData data;
  final int maxActivity;
  final Color Function(BuildContext, StrikeActivityLevel) cellColor;

  const _MonthBlock({
    required this.data,
    required this.maxActivity,
    required this.cellColor,
  });

  static final DateFormat _monthFormat = DateFormat('MMM');
  static final DateFormat _tooltipDateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    const double cellSize = 12.5;
    const double cellGap = 2.5;

    final monthName = _monthFormat.format(data.monthDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 7-day columns
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(data.columns.length, (colIdx) {
            final col = data.columns[colIdx];
            return Padding(
              padding: EdgeInsets.only(
                right: colIdx < data.columns.length - 1 ? cellGap : 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(7, (rowIdx) {
                  final activity = col[rowIdx];
                  if (activity == null) {
                    return const SizedBox(
                      width: cellSize,
                      height: cellSize + cellGap,
                    );
                  }

                  final level = activity.activityLevel(maxActivity);
                  final color = cellColor(context, level);

                  return Tooltip(
                    message:
                        '${_tooltipDateFormat.format(activity.date)}\n'
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

        const SizedBox(height: 8),

        // Centered month name
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              monthName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF5B7A9C),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Card 2: Summary Stats (Topics Finished vs Topic Revisions)
// =============================================================================
class SummaryStatsCard extends StatelessWidget {
  final ProgressController controller;

  const SummaryStatsCard({required this.controller});

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
class WeeklyProgressActivity {
  final DateTime startDate;
  final DateTime endDate;
  final int topicsFinished;
  final int revisionsDone;
  final bool isCurrentWeek;

  const WeeklyProgressActivity({
    required this.startDate,
    required this.endDate,
    required this.topicsFinished,
    required this.revisionsDone,
    required this.isCurrentWeek,
  });

  int get totalActivity => topicsFinished + revisionsDone;
}

class ActivityBreakdownCard extends StatelessWidget {
  final ProgressController controller;

  const ActivityBreakdownCard({super.key, required this.controller});

  static final DateFormat _rangeFormat = DateFormat('d MMM');

  List<WeeklyProgressActivity> _getWeeklyActivities(List<DailyProgressActivity> allActivities) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    final Map<DateTime, DailyProgressActivity> map = {};
    for (final a in allActivities) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      map[d] = a;
    }

    const int weekCount = 7;
    final List<WeeklyProgressActivity> weeks = [];

    for (int i = weekCount - 1; i >= 0; i--) {
      final weekStart = currentMonday.subtract(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final isCurrent = i == 0;

      int finished = 0;
      int revisions = 0;

      for (int d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        // Only count days up to today if current week
        if (isCurrent && day.isAfter(today)) break;

        final act = map[day];
        if (act != null) {
          finished += act.topicsFinished;
          revisions += act.revisionsDone;
        }
      }

      weeks.add(WeeklyProgressActivity(
        startDate: weekStart,
        endDate: weekEnd,
        topicsFinished: finished,
        revisionsDone: revisions,
        isCurrentWeek: isCurrent,
      ));
    }

    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyActivities = _getWeeklyActivities(controller.activitiesInRange);

    int finishedTotal = 0;
    int revisionsTotal = 0;
    for (final w in weeklyActivities) {
      finishedTotal += w.topicsFinished;
      revisionsTotal += w.revisionsDone;
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Weekly • Last 7 Weeks',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BreakdownLegendIndicator(
                    color: const Color(0xFF10B981),
                    label: 'Finished ($finishedTotal)',
                  ),
                  const HGapSm(),
                  _BreakdownLegendIndicator(
                    color: const Color(0xFF7A6EFC),
                    label: 'Revised ($revisionsTotal)',
                  ),
                ],
              ),
            ],
          ),
          const VGapMd(),
          RepaintBoundary(
            child: SizedBox(
              height: 145,
              width: double.infinity,
              child: CustomPaint(
                painter: _ActivityBreakdownPainter(
                  activities: weeklyActivities,
                  gridColor: AppTheme.borderColor(context),
                  textColor: AppTheme.textSecondaryColor(context),
                  primaryColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _BreakdownLegendIndicator({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const HGapXs(),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}

class _ActivityBreakdownPainter extends CustomPainter {
  final List<WeeklyProgressActivity> activities;
  final Color gridColor;
  final Color textColor;
  final Color primaryColor;

  _ActivityBreakdownPainter({
    required this.activities,
    required this.gridColor,
    required this.textColor,
    required this.primaryColor,
  });

  static final DateFormat _dayFormat = DateFormat('d MMM');

  @override
  void paint(Canvas canvas, Size size) {
    if (activities.isEmpty) return;

    const double leftPadding = 20.0;
    const double bottomPadding = 28.0;
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;

    // Determine max value for Y-axis scale based on weekly activity
    int maxVal = 0;
    for (final a in activities) {
      if (a.totalActivity > maxVal) maxVal = a.totalActivity;
    }

    final int topY;
    final int stepCount;
    if (maxVal <= 0) {
      topY = 10;
      stepCount = 2;
    } else if (maxVal <= 10) {
      topY = 10;
      stepCount = 2;
    } else if (maxVal <= 20) {
      topY = 20;
      stepCount = 2;
    } else {
      topY = ((maxVal + 9) ~/ 10) * 10;
      stepCount = 3;
    }

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    // Draw Y-axis reference lines & labels
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

    // Draw 7 Weekly Bars
    final int count = activities.length;
    final double slotWidth = chartWidth / count;
    final double barWidth = (slotWidth * 0.45).clamp(12.0, 20.0);

    final Paint emptyTrackPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final Paint finishedPaint = Paint()..color = const Color(0xFF10B981);
    final Paint revisionPaint = Paint()..color = const Color(0xFF7A6EFC);
    final Paint todayDotPaint = Paint()..color = primaryColor;

    for (int i = 0; i < count; i++) {
      final act = activities[i];
      final double x = leftPadding + (i * slotWidth) + (slotWidth - barWidth) / 2;

      // Background subtle slot track
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, chartHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(trackRect, emptyTrackPaint);

      final double finishedHeight = (act.topicsFinished / topY) * chartHeight;
      final double revisionHeight = (act.revisionsDone / topY) * chartHeight;
      final double totalHeight = (finishedHeight + revisionHeight).clamp(0.0, chartHeight);

      if (totalHeight > 0) {
        final double baseY = chartHeight;

        // Bottom green segment (Topics Finished)
        if (finishedHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - finishedHeight,
            barWidth,
            finishedHeight,
          );
          if (revisionHeight <= 0) {
            final rrect = RRect.fromRectAndRadius(
              rect,
              const Radius.circular(4),
            );
            canvas.drawRRect(rrect, finishedPaint);
          } else {
            final rrect = RRect.fromRectAndCorners(
              rect,
              bottomLeft: const Radius.circular(4),
              bottomRight: const Radius.circular(4),
            );
            canvas.drawRRect(rrect, finishedPaint);
          }
        }

        // Top purple segment (Topic Revisions)
        if (revisionHeight > 0) {
          final rect = Rect.fromLTWH(
            x,
            baseY - totalHeight,
            barWidth,
            revisionHeight,
          );
          if (finishedHeight <= 0) {
            final rrect = RRect.fromRectAndRadius(
              rect,
              const Radius.circular(4),
            );
            canvas.drawRRect(rrect, revisionPaint);
          } else {
            final rrect = RRect.fromRectAndCorners(
              rect,
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            );
            canvas.drawRRect(rrect, revisionPaint);
          }
        }
      }

      // X-axis label
      final String label = act.isCurrentWeek ? 'This Wk' : _dayFormat.format(act.startDate);
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          letterSpacing: -0.2,
          fontWeight: act.isCurrentWeek ? FontWeight.bold : FontWeight.w500,
          color: act.isCurrentWeek ? primaryColor : textColor,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, chartHeight + 6),
      );

      // Indicator dot for current week
      if (act.isCurrentWeek) {
        canvas.drawCircle(
          Offset(x + barWidth / 2, chartHeight + 21),
          2.0,
          todayDotPaint,
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
        oldDelegate.textColor != textColor ||
        oldDelegate.primaryColor != primaryColor;
  }
}
