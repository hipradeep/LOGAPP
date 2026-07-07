import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'package:intl/intl.dart';

class ActivityBarGraph extends StatefulWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;
  final int daysWindow;
  final bool showTitle;
  final bool showWindowButtons;

  const ActivityBarGraph({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
    this.daysWindow = 7,
    this.showTitle = true,
    this.showWindowButtons = true,
  });

  @override
  State<ActivityBarGraph> createState() => _ActivityBarGraphState();
}

class _ActivityBarGraphState extends State<ActivityBarGraph> {
  late int _daysWindow;

  @override
  void initState() {
    super.initState();
    _daysWindow = widget.daysWindow;
  }

  @override
  void didUpdateWidget(covariant ActivityBarGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.daysWindow != widget.daysWindow) {
      _daysWindow = widget.daysWindow;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isScheduledDay(DateTime date) {
    if (widget.activity.startDate != null) {
      final start = DateTime(widget.activity.startDate!.year, widget.activity.startDate!.month, widget.activity.startDate!.day);
      if (date.isBefore(start)) return false;
    }
    if (widget.activity.endDate != null) {
      final end = DateTime(widget.activity.endDate!.year, widget.activity.endDate!.month, widget.activity.endDate!.day);
      if (date.isAfter(end)) return false;
    }
    final repeatDays = widget.activity.repeatDays;
    if (repeatDays.isEmpty) return true;
    return repeatDays.contains(date.weekday);
  }

  double _calculateDailyCompletion(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    if (widget.activity.trackingType == 'single') {
      final dayCheckIns = widget.checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
      return widget.activity.targetCount > 0
          ? (dayCheckIns.length / widget.activity.targetCount).clamp(0.0, 1.0)
          : 0.0;
    } else if (widget.activity.trackingType == 'multiple') {
      final task = widget.tasks.firstWhere(
        (t) => _isSameDay(t.timestamp, day),
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
      );
      if (task.id.isEmpty) {
        final dayCheckIns = widget.checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
        if (dayCheckIns.isEmpty) return 0.0;
        final totalTemplates = widget.activity.subTaskTemplates.length;
        if (totalTemplates == 0) return 0.0;
        return (dayCheckIns.length / totalTemplates).clamp(0.0, 1.0);
      }
      if (task.subTasks.isEmpty) {
        return task.checked ? 1.0 : 0.0;
      }
      final checkedCount = task.subTasks.where((st) => st.checked).length;
      return (checkedCount / task.subTasks.length).clamp(0.0, 1.0);
    } else if (widget.activity.trackingType == 'milestone') {
      final milestoneTasks = widget.tasks.where((t) {
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

  Widget _buildWindowButton(int days, String title) {
    final isActive = _daysWindow == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          _daysWindow = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.subtleFillColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppTheme.borderColor(context) : AppTheme.borderColor(context).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTrendsBarGraph(
    BuildContext context,
    List<double> completionRates,
    List<DateTime> dates,
    Color typeColor,
  ) {
    final now = DateTime.now();
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Stack(
            children: [
              // Grid lines
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (index) => Container(
                  height: 1,
                  color: AppTheme.borderColor(context).withValues(alpha: 0.3),
                )),
              ),
              
              // Bars Row
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(completionRates.length, (index) {
                      final rate = completionRates[index];
                      final date = dates[index];
                      final isToday = _isSameDay(date, now);
                      
                      return Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double barWidth = (constraints.maxWidth * 0.6).clamp(3.0, 16.0);
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message: '${DateFormat('MMM d').format(date)}: ${(rate * 100).toStringAsFixed(0)}%',
                                  child: Container(
                                    width: barWidth,
                                    height: (120 * rate).clamp(4.0, 120.0),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          typeColor,
                                          typeColor.withValues(alpha: 0.4),
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      boxShadow: isToday
                                          ? [
                                              BoxShadow(
                                                color: typeColor.withValues(alpha: 0.4),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Timeline Day Labels Row
        if (_daysWindow == 7)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = dates[index];
              final isToday = _isSameDay(date, now);
              final isScheduled = _isScheduledDay(date);
              final label = DateFormat('E').format(date).substring(0, 1);

              return Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: isToday
                        ? BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          )
                        : null,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isToday
                            ? AppTheme.textPrimaryColor(context)
                            : (isScheduled ? AppTheme.textSecondaryColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)),
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(dates.first),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(dates[15]),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final typeColor = widget.activity.trackingType == 'multiple'
        ? AppTheme.secondaryColor
        : (widget.activity.trackingType == 'milestone' ? AppTheme.warningColor : AppTheme.primaryColor);

    final now = DateTime.now();
    final List<DateTime> trendsDates = List.generate(_daysWindow, (index) {
      final date = now.subtract(Duration(days: _daysWindow - 1 - index));
      return DateTime(date.year, date.month, date.day);
    });
    final List<double> trendsCompletionRates = trendsDates.map((d) => _calculateDailyCompletion(d)).toList();

    final Widget chartContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showWindowButtons) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildWindowButton(7, '7 Days'),
              const SizedBox(width: 8),
              _buildWindowButton(30, '30 Days'),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _buildTrendsBarGraph(context, trendsCompletionRates, trendsDates, typeColor),
      ],
    );

    if (!widget.showTitle) {
      return chartContent;
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
                'Completion Trends',
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          chartContent,
        ],
      ),
    );
  }
}
