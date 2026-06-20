import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import 'activity_heatmap.dart';
import 'activity_bar_graph.dart';
import 'activity_burnup_chart.dart';
import '../services/milestone_service.dart';
import '../services/service_locator.dart';


class ActivityGraphCard extends StatefulWidget {
  final Activity activity;
  final List<CheckIn> checkIns;
  final List<Task> tasks;
  final int initialTab;
  final MilestoneService milestoneService;

  ActivityGraphCard({
    super.key,
    required this.activity,
    required this.checkIns,
    required this.tasks,
    this.initialTab = 0,
    MilestoneService? milestoneService,
  }) : milestoneService = milestoneService ?? getIt<MilestoneService>();

  @override
  State<ActivityGraphCard> createState() => _ActivityGraphCardState();
}

class _ActivityGraphCardState extends State<ActivityGraphCard> {
  int _daysWindow = 7; // 7 or 30 days for graph window

  @override
  void initState() {
    super.initState();
  }

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

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Registers this component to rebuild on theme switch
    Theme.of(context);

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

    // Milestone-specific stats calculations
    final milestoneStats = widget.milestoneService.calculateMilestoneStats(widget.tasks);
    final int milestoneTotal = milestoneStats.total;
    final int milestoneCompleted = milestoneStats.completed;
    final int milestonePending = milestoneStats.pending;
    final double milestoneProgress = milestoneStats.progress;

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
          // Header Row with Title and optional Window Toggles
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
              // Window toggles (Visible for multiple and milestone types)
              if (widget.activity.trackingType == 'multiple' || widget.activity.trackingType == 'milestone')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWindowButton(7, '7 Days'),
                    const SizedBox(width: 8),
                    _buildWindowButton(30, '30 Days'),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Body Area matching check-in sheet
          if (widget.activity.trackingType == 'single')
            ActivityHeatmap(
              activity: widget.activity,
              checkIns: widget.checkIns,
              tasks: widget.tasks,
              heatmapWeeks: 12,
              showTitle: false,
            )
          else if (widget.activity.trackingType == 'multiple')
            ActivityBarGraph(
              activity: widget.activity,
              checkIns: widget.checkIns,
              tasks: widget.tasks,
              daysWindow: _daysWindow,
              showTitle: false,
              showWindowButtons: false,
            )
          else
            ActivityBurnupChart(
              activity: widget.activity,
              checkIns: widget.checkIns,
              tasks: widget.tasks,
              daysWindow: _daysWindow,
              showTitle: false,
            ),
          
          const SizedBox(height: 24),
          
          // Redesigned Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppTheme.subtleFillColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 1,
              ),
            ),
            child: widget.activity.trackingType == 'milestone'
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Overall Progress
                      _buildRedesignedStat(
                        icon: Icons.track_changes_rounded,
                        iconColor: AppTheme.warningColor,
                        bgColor: AppTheme.warningColor.withValues(alpha: 0.1),
                        label: 'Overall Progress',
                        value: '${(milestoneProgress * 100).toStringAsFixed(0)}%',
                      ),
                      
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.borderColor(context),
                      ),
                      
                      // Completed / Total Milestones
                      _buildRedesignedStat(
                        icon: Icons.playlist_add_check_rounded,
                        iconColor: AppTheme.successColor,
                        bgColor: AppTheme.successColor.withValues(alpha: 0.1),
                        label: 'Milestones',
                        value: '$milestoneCompleted/$milestoneTotal',
                      ),
                      
                      // Divider
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.borderColor(context),
                      ),
                      
                      // Active Tasks pending
                      _buildRedesignedStat(
                        icon: Icons.hourglass_empty_rounded,
                        iconColor: AppTheme.secondaryColor,
                        bgColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        label: 'Active Tasks',
                        value: milestonePending == 1 ? '1 Pending' : '$milestonePending Pending',
                      ),
                    ],
                  )
                : Row(
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
                        color: AppTheme.borderColor(context),
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
                          color: AppTheme.borderColor(context),
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
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
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
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
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
