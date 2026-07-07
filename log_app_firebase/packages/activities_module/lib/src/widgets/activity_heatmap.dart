import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'package:intl/intl.dart';

class _HeatmapCellData {
  final DateTime date;
  final double completion;
  final bool isFuture;
  final bool isToday;
  final bool isScheduled;
  final bool isSkipped;

  _HeatmapCellData({
    required this.date,
    required this.completion,
    required this.isFuture,
    required this.isToday,
    required this.isScheduled,
    required this.isSkipped,
  });
}

class ActivityHeatmap extends StatelessWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;
  final int heatmapWeeks;
  final bool showTitle;

  const ActivityHeatmap({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
    this.heatmapWeeks = 12,
    this.showTitle = true,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isScheduledDay(DateTime date) {
    if (activity.startDate != null) {
      final start = DateTime(activity.startDate!.year, activity.startDate!.month, activity.startDate!.day);
      if (date.isBefore(start)) return false;
    }
    if (activity.endDate != null) {
      final end = DateTime(activity.endDate!.year, activity.endDate!.month, activity.endDate!.day);
      if (date.isAfter(end)) return false;
    }
    final repeatDays = activity.repeatDays;
    if (repeatDays.isEmpty) return true;
    return repeatDays.contains(date.weekday);
  }

  double _calculateDailyCompletion(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    if (activity.trackingType == 'single') {
      final dayCheckIns = checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
      return dayCheckIns.isNotEmpty ? 1.0 : 0.0;
    } else if (activity.trackingType == 'multiple') {
      final task = tasks.firstWhere(
        (t) => _isSameDay(t.timestamp, day),
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
      );
      if (task.id.isEmpty) {
        final dayCheckIns = checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
        if (dayCheckIns.isEmpty) return 0.0;
        final totalTemplates = activity.subTaskTemplates.length;
        if (totalTemplates == 0) return 0.0;
        return (dayCheckIns.length / totalTemplates).clamp(0.0, 1.0);
      }
      if (task.subTasks.isEmpty) {
        return task.checked ? 1.0 : 0.0;
      }
      final checkedCount = task.subTasks.where((st) => st.checked).length;
      return (checkedCount / task.subTasks.length).clamp(0.0, 1.0);
    } else if (activity.trackingType == 'milestone') {
      final milestoneTasks = tasks.where((t) {
        final taskDay = DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day);
        return !taskDay.isAfter(day);
      }).toList();

      if (milestoneTasks.isEmpty) return 0.0;

      double totalProgress = 0.0;
      for (var t in milestoneTasks) {
        if (t.subTasks.isEmpty) {
          totalProgress += t.checked ? 1.0 : 0.0;
        } else {
          final completed = t.subTasks.where((st) => st.checked).length;
          totalProgress += (completed / t.subTasks.length);
        }
      }
      return (totalProgress / milestoneTasks.length).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  bool _isDaySkipped(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final hasSkipCheckIn = checkIns.any((c) => _isSameDay(c.timestamp, day) && c.skipped);
    if (hasSkipCheckIn) return true;
    
    if (activity.skippable && _isScheduledDay(day)) {
      final hasAnyCheckIn = checkIns.any((c) => _isSameDay(c.timestamp, day) && c.checked);
      if (!hasAnyCheckIn) {
        if (activity.trackingType == 'multiple') {
          final task = tasks.any((t) => _isSameDay(t.timestamp, day) && (t.checked || t.subTasks.any((st) => st.checked)));
          return !task;
        }
        return true;
      }
    }
    return false;
  }

  List<List<_HeatmapCellData>> _getHeatmapGridData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday;
    
    final startOfWeek = today.subtract(Duration(days: weekday - 1));
    final gridStartDate = startOfWeek.subtract(Duration(days: (heatmapWeeks - 1) * 7));
    
    final List<List<_HeatmapCellData>> grid = [];
    
    for (int col = 0; col < heatmapWeeks; col++) {
      final List<_HeatmapCellData> column = [];
      final weekMonday = gridStartDate.add(Duration(days: col * 7));
      
      for (int row = 0; row < 7; row++) {
        final date = weekMonday.add(Duration(days: row));
        final isFuture = date.isAfter(today);
        final isToday = _isSameDay(date, today);
        final isScheduled = _isScheduledDay(date);
        
        double completion = 0.0;
        bool isSkipped = false;
        if (!isFuture) {
          completion = _calculateDailyCompletion(date);
          isSkipped = _isDaySkipped(date);
        }
        
        column.add(_HeatmapCellData(
          date: date,
          completion: completion,
          isFuture: isFuture,
          isToday: isToday,
          isScheduled: isScheduled,
          isSkipped: isSkipped,
        ));
      }
      grid.add(column);
    }
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final typeColor = activity.trackingType == 'multiple'
        ? AppTheme.secondaryColor
        : (activity.trackingType == 'milestone' ? AppTheme.warningColor : AppTheme.primaryColor);

    final grid = _getHeatmapGridData();
    const rowLabels = ['M', '', 'W', '', 'F', '', 'S'];
    
    final List<Widget> monthHeaders = [];
    int? lastMonthVal;
    
    for (int colIdx = 0; colIdx < heatmapWeeks; colIdx++) {
      final weekMonday = grid[colIdx].first.date;
      final String monthName = DateFormat('MMM').format(weekMonday);
      final bool showHeader = lastMonthVal == null || weekMonday.month != lastMonthVal;
      if (showHeader) {
        lastMonthVal = weekMonday.month;
      }
      monthHeaders.add(
        Expanded(
          child: Text(
            showHeader ? monthName : '',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final Widget gridContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month headers
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 6),
          child: Row(children: monthHeaders),
        ),
        
        // Grid with labels
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Labels
            Column(
              children: List.generate(7, (rowIdx) {
                return Container(
                  height: 12,
                  width: 16,
                  margin: const EdgeInsets.only(bottom: 3),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    rowLabels[rowIdx],
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            
            // Weeks Columns
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(heatmapWeeks, (colIdx) {
                  final column = grid[colIdx];
                  return Expanded(
                    child: Column(
                      children: List.generate(7, (rowIdx) {
                        final cell = column[rowIdx];
                        return _buildHeatmapCell(context, cell, typeColor);
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        // Legend Row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Less',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 6),
            _buildLegendCell(context, AppTheme.subtleFillColor(context), hasBorder: true),
            const SizedBox(width: 3),
            _buildLegendCell(context, typeColor.withValues(alpha: 0.25)),
            const SizedBox(width: 3),
            _buildLegendCell(context, typeColor.withValues(alpha: 0.55)),
            const SizedBox(width: 3),
            _buildLegendCell(context, typeColor),
            const SizedBox(width: 6),
            Text(
              'More',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );

    if (!showTitle) {
      return gridContent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.12),
            AppTheme.surface(context).withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_view_month_rounded,
                  color: typeColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Consistency Heatmap',
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          gridContent,
        ],
      ),
    );
  }

  Widget _buildHeatmapCell(BuildContext context, _HeatmapCellData cell, Color typeColor) {
    if (cell.isFuture) {
      return Container(
        height: 12,
        margin: const EdgeInsets.only(bottom: 3, left: 1, right: 1),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
      );
    }

    Color cellColor;
    BoxBorder? cellBorder;
    Widget? innerWidget;

    if (cell.isSkipped) {
      cellColor = typeColor.withValues(alpha: 0.15);
      cellBorder = Border.all(
        color: typeColor.withValues(alpha: 0.35),
        width: 1,
      );
      innerWidget = Center(
        child: Icon(
          Icons.double_arrow_rounded,
          size: 7,
          color: typeColor.withValues(alpha: 0.7),
        ),
      );
    } else if (cell.completion >= 0.01) {
      cellColor = typeColor.withValues(alpha: (cell.completion * 0.75 + 0.15).clamp(0.15, 0.9));
      cellBorder = null;
    } else if (cell.isScheduled) {
      cellColor = AppTheme.subtleFillColor(context);
      cellBorder = Border.all(
        color: AppTheme.borderColor(context),
        width: 1,
      );
    } else {
      cellColor = Colors.transparent;
      cellBorder = null;
    }

    if (cell.isToday) {
      cellBorder = Border.all(
        color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.8),
        width: 1.5,
      );
    }

    return Container(
      height: 12,
      margin: const EdgeInsets.only(bottom: 3, left: 1, right: 1),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(2.5),
        border: cellBorder,
        boxShadow: cell.isToday && cell.completion >= 0.99
            ? [
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                )
              ]
            : null,
      ),
      child: innerWidget,
    );
  }

  Widget _buildLegendCell(BuildContext context, Color color, {bool hasBorder = false}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: hasBorder
            ? Border.all(color: AppTheme.borderColor(context), width: 0.5)
            : null,
      ),
    );
  }
}
