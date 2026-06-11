import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';

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

class ActivityGraphCard extends StatefulWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;

  const ActivityGraphCard({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
  });

  @override
  State<ActivityGraphCard> createState() => _ActivityGraphCardState();
}

class _ActivityGraphCardState extends State<ActivityGraphCard> {
  int _activeTab = 0; // 0 = Completion Trends (Line Graph), 1 = Consistency Heatmap
  int _daysWindow = 7; // 7 or 30 days for Line Graph

  // Helper to check if a date is same day as target
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Check if a day is scheduled
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

  // Calculate daily completion rate (0.0 to 1.0)
  double _calculateDailyCompletion(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);

    if (widget.activity.trackingType == 'single') {
      final dayCheckIns = widget.checkIns.where((c) => _isSameDay(c.timestamp, day) && c.checked && !c.skipped).toList();
      return dayCheckIns.isNotEmpty ? 1.0 : 0.0;
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

  // Calculate absolute milestone completion rate

  // Check if a day was skipped
  bool _isDaySkipped(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final hasSkipCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, day) && c.skipped);
    if (hasSkipCheckIn) return true;
    
    if (widget.activity.skippable && _isScheduledDay(day)) {
      final hasAnyCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, day) && c.checked);
      if (!hasAnyCheckIn) {
        if (widget.activity.trackingType == 'multiple') {
          final task = widget.tasks.any((t) => _isSameDay(t.timestamp, day) && (t.checked || t.subTasks.any((st) => st.checked)));
          return !task;
        }
        return true;
      }
    }
    return false;
  }

  // Calculate current active streak
  int _calculateStreak() {
    int streak = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool todayCompletedOrSkipped = false;
    if (!_isScheduledDay(today)) {
      todayCompletedOrSkipped = true;
    } else {
      final completion = _calculateDailyCompletion(today);
      final isCompleted = completion >= 0.99;
      final isSkipped = _isDaySkipped(today);
      if (isCompleted || isSkipped) {
        todayCompletedOrSkipped = true;
        if (isCompleted && !isSkipped) {
          streak = 1;
        }
      }
    }

    DateTime checkDate = today.subtract(const Duration(days: 1));
    for (int i = 1; i < 365; i++) {
      final day = DateTime(checkDate.year, checkDate.month, checkDate.day);
      if (!_isScheduledDay(day)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }

      final completion = _calculateDailyCompletion(day);
      final isCompleted = completion >= 0.99;
      final isSkipped = _isDaySkipped(day);

      if (isCompleted) {
        streak++;
      } else if (isSkipped) {
        // preserve
      } else {
        if (i == 1 && !todayCompletedOrSkipped) {
          return 0;
        }
        break;
      }
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // Heatmap: Get 12 weeks of data ending with current week
  List<List<_HeatmapCellData>> _getHeatmapGridData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday;
    
    final startOfWeek = today.subtract(Duration(days: weekday - 1));
    final gridStartDate = startOfWeek.subtract(const Duration(days: 11 * 7)); // 11 weeks ago Monday
    
    final List<List<_HeatmapCellData>> grid = [];
    
    for (int col = 0; col < 12; col++) {
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

  Widget _buildHeatmapGrid(BuildContext context, Color typeColor) {
    final grid = _getHeatmapGridData();
    const rowLabels = ['M', '', 'W', '', 'F', '', 'S'];
    
    final List<Widget> monthHeaders = [];
    int? lastMonthVal;
    
    for (int colIdx = 0; colIdx < 12; colIdx++) {
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
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Column(
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
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 8),
            
            // 12 Weeks Columns
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(12, (colIdx) {
                  final column = grid[colIdx];
                  return Expanded(
                    child: Column(
                      children: List.generate(7, (rowIdx) {
                        final cell = column[rowIdx];
                        return _buildHeatmapCell(cell, typeColor);
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
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
            const SizedBox(width: 6),
            _buildLegendCell(Colors.white.withValues(alpha: 0.03), hasBorder: true),
            const SizedBox(width: 3),
            _buildLegendCell(typeColor.withValues(alpha: 0.25)),
            const SizedBox(width: 3),
            _buildLegendCell(typeColor.withValues(alpha: 0.55)),
            const SizedBox(width: 3),
            _buildLegendCell(typeColor),
            const SizedBox(width: 6),
            Text(
              'More',
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmapCell(_HeatmapCellData cell, Color typeColor) {
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
      // Opacity maps to actual completion percentage to support partial fills
      cellColor = typeColor.withValues(alpha: (cell.completion * 0.75 + 0.15).clamp(0.15, 0.9));
      cellBorder = null;
    } else if (cell.isScheduled) {
      cellColor = Colors.white.withValues(alpha: 0.03);
      cellBorder = Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 1,
      );
    } else {
      cellColor = Colors.white.withValues(alpha: 0.01);
      cellBorder = null;
    }

    if (cell.isToday) {
      cellBorder = Border.all(
        color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildLegendCell(Color color, {bool hasBorder = false}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: hasBorder
            ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5)
            : null,
      ),
    );
  }

  // Completion Line Chart for Trends Tab (Works uniformly for all activities, supports 7D vs 30D selectors)
  Widget _buildTrendsLineGraph(
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
                  color: Colors.white.withValues(alpha: 0.04),
                )),
              ),
              
              // Custom paint curve
              Positioned.fill(
                child: CustomPaint(
                  painter: ActivityGraphPainter(
                    dataPoints: completionRates,
                    lineColor: typeColor,
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
                            ? Colors.white
                            : (isScheduled ? AppTheme.textSecondary : Colors.white24),
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
          // For 30D, show start date, middle date, and today
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(dates.first),
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(dates[15]),
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
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
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: Colors.white,
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

  // Header button builders
  Widget _buildTabButton(int index, String title, Color typeColor) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? typeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
          color: isActive ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = widget.activity.trackingType == 'multiple'
        ? AppTheme.secondaryColor
        : (widget.activity.trackingType == 'milestone' ? AppTheme.warningColor : AppTheme.primaryColor);

    // Calculate dynamic stats
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      return DateTime(date.year, date.month, date.day);
    });

    final List<double> weeklyCompletionRates = last7Days.map((d) => _calculateDailyCompletion(d)).toList();
    final double averageCompletion = weeklyCompletionRates.reduce((a, b) => a + b) / 7.0;
    final int currentStreak = _calculateStreak();

    // Determine the "Best Day"
    int bestDayIndex = 0;
    double maxCompletion = -1.0;
    for (int i = 0; i < 7; i++) {
      if (weeklyCompletionRates[i] > maxCompletion) {
        maxCompletion = weeklyCompletionRates[i];
        bestDayIndex = i;
      }
    }
    final String bestDayLabel = DateFormat('EEEE').format(last7Days[bestDayIndex]);

    // Data points for Trends Graph window
    final List<DateTime> trendsDates = List.generate(_daysWindow, (index) {
      final date = now.subtract(Duration(days: _daysWindow - 1 - index));
      return DateTime(date.year, date.month, date.day);
    });
    final List<double> trendsCompletionRates = trendsDates.map((d) => _calculateDailyCompletion(d)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withValues(alpha: 0.12),
            AppTheme.surfaceColor.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Tab Toggles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      color: typeColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Analytics',
                    style: AppTheme.headingSmall.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              // Tabs (Trends vs Heatmap)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Trends', typeColor),
                    _buildTabButton(1, 'Heatmap', typeColor),
                  ],
                ),
              ),
            ],
          ),

          // Window toggles row (Visible only on Trends tab)
          if (_activeTab == 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildWindowButton(7, '7 Days'),
                const SizedBox(width: 8),
                _buildWindowButton(30, '30 Days'),
              ],
            ),
          ],
          
          const SizedBox(height: 20),

          // Dynamic Body Area
          if (_activeTab == 0) ...[
            _buildTrendsLineGraph(context, trendsCompletionRates, trendsDates, typeColor),
          ] else ...[
            _buildHeatmapGrid(context, typeColor),
          ],
          
          const SizedBox(height: 24),
          
          // Redesigned Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.04),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Streak Stat
                _buildRedesignedStat(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orangeAccent,
                  bgColor: Colors.orange.withValues(alpha: 0.1),
                  label: 'Active Streak',
                  value: currentStreak == 1 ? '1 Day' : '$currentStreak Days',
                ),
                
                // Divider
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                
                // Weekly Rate Stat
                _buildRedesignedStat(
                  icon: Icons.check_circle_rounded,
                  iconColor: typeColor,
                  bgColor: typeColor.withValues(alpha: 0.1),
                  label: 'Weekly Avg',
                  value: '${(averageCompletion * 100).toStringAsFixed(0)}%',
                ),
                
                // Divider (only if best day is shown)
                if (maxCompletion > 0.01) ...[
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  
                  // Best Day Stat
                  _buildRedesignedStat(
                    icon: Icons.star_rounded,
                    iconColor: AppTheme.successColor,
                    bgColor: AppTheme.successColor.withValues(alpha: 0.1),
                    label: 'Best Day',
                    value: bestDayLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedesignedStat({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityGraphPainter extends CustomPainter {
  final List<double> dataPoints; // List of completion rates (0.0 to 1.0)
  final Color lineColor;

  ActivityGraphPainter({
    required this.dataPoints,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double widthBetweenPoints = size.width / (dataPoints.length - 1);
    
    final double topLimit = size.height * 0.1;
    final double bottomLimit = size.height * 0.9;
    final double heightRange = bottomLimit - topLimit;
    
    final List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * widthBetweenPoints;
      final double y = bottomLimit - (dataPoints[i] * heightRange);
      points.add(Offset(x, y));
    }

    // Draw area gradient under the curve
    final Path areaPath = Path();
    areaPath.moveTo(0, bottomLimit);
    areaPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double controlX = p0.dx + (p1.dx - p0.dx) / 2.0;
      areaPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }
    
    areaPath.lineTo(size.width, bottomLimit);
    areaPath.close();

    final Paint areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(0, topLimit, size.width, bottomLimit))
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(areaPath, areaPaint);

    // Draw the main line curve
    final Path linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 0; i < points.length - 1; i++) {
      final Offset p0 = points[i];
      final Offset p1 = points[i + 1];
      final double controlX = p0.dx + (p1.dx - p0.dx) / 2.0;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final Paint shadowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, shadowPaint);
    canvas.drawPath(linePath, linePaint);

    // Draw the circles on points (skip intermediates for 30D to avoid clutter)
    final bool drawCircles = dataPoints.length <= 10;
    
    final Paint pointInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint pointOuterPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      // Draw circles on all points if count <= 10, or only on the last point (today) for 30D
      if (drawCircles || i == points.length - 1) {
        canvas.drawCircle(points[i], 5.0, pointOuterPaint);
        canvas.drawCircle(points[i], 2.5, pointInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ActivityGraphPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || 
        oldDelegate.dataPoints != dataPoints;
  }
}
