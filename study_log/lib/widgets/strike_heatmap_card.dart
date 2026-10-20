import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../controllers/progress_controller.dart';

/// Activity Card: Calendar heatmap grid of study & revision activity
class StrikeHeatmapCard extends StatelessWidget {
  final ProgressController controller;

  const StrikeHeatmapCard({super.key, required this.controller});

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

        const VGapSm(),

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
