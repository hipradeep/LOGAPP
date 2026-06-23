import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import 'app_spacers.dart';
import '../services/milestone_service.dart';
import '../services/service_locator.dart';

class DashboardWeeklyCalendar extends StatelessWidget {
  final List<Activity> activities;
  final List<CheckIn> checkIns;
  final List<Task> subTasks;
  final MilestoneService milestoneService;

  DashboardWeeklyCalendar({
    super.key,
    required this.activities,
    required this.checkIns,
    required this.subTasks,
    MilestoneService? milestoneService,
  }) : milestoneService = milestoneService ?? getIt<MilestoneService>();

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Registers this component to rebuild on theme switch
    Theme.of(context);
    
    if (activities.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    // Calculate Monday of current week (DateTime.monday == 1 in Dart)
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Generate 7 days starting from Monday
    final weekDays = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final dayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppTheme.primaryAccentColor(context),
                  size: 14,
                ),
                const HGapSm(),
                Text(
                  'Weekly Progress'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryAccentColor(context),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const VGapMd(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final day = weekDays[index];
                final isToday = _isSameDay(day, now);
                final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

                // Calculate completion for this day
                double totalWeight = 0.0;
                double weightedCompletionSum = 0.0;

                for (var activity in activities) {
                  double completionRateOfActivity = 0.0;

                  if (activity.trackingType == 'milestone') {
                    final milestoneProgress = milestoneService.getMilestoneDailyCompletion(activity, subTasks, day);
                    if (milestoneProgress == -1.0) {
                      continue; // Exclude from score today as no tasks are scheduled
                    }
                    completionRateOfActivity = milestoneProgress;
                  } else {
                    final double activityProgress;
                    if (activity.trackingType == 'multiple') {
                      final dayTask = subTasks.firstWhere(
                        (s) => s.activityId == activity.id && _isSameDay(s.timestamp, day),
                        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
                      );
                      final totalSub = dayTask.subTasks.length;
                      final checkedSub = dayTask.subTasks.where((st) => st.checked).length;
                      activityProgress = totalSub > 0 ? checkedSub / totalSub : 0.0;
                    } else {
                      final todayCount = checkIns
                          .where((c) =>
                              c.activityId == activity.id &&
                              _isSameDay(c.timestamp, day) &&
                              c.checked)
                          .length;
                      activityProgress = activity.targetCount > 0
                          ? (todayCount / activity.targetCount).clamp(0.0, 1.0)
                          : 0.0;
                    }
                    completionRateOfActivity = activityProgress;
                  }

                  weightedCompletionSum += (completionRateOfActivity * activity.weight);
                  totalWeight += activity.weight;
                }

                final double completionRate =
                    totalWeight > 0 ? weightedCompletionSum / totalWeight : 0.0;

                return _DashboardDayCircle(
                  label: dayLabels[index],
                  date: day.day.toString(),
                  progress: isFuture ? 0.0 : completionRate,
                  isToday: isToday,
                  isFuture: isFuture,
                  isCompleted: completionRate >= 1.0 && !isFuture,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardDayCircle extends StatelessWidget {
  final String label;
  final String date;
  final double progress;
  final bool isToday;
  final bool isFuture;
  final bool isCompleted;

  const _DashboardDayCircle({
    required this.label,
    required this.date,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Registers this component to rebuild on theme switch
    Theme.of(context);

    final Color progressColor = isCompleted
        ? AppTheme.successColor
        : (progress > 0 ? AppTheme.primaryAccentColor(context) : AppTheme.subtleFillColor(context));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isToday ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const VGapXs(),
        Container(
          decoration: isToday
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: isFuture ? 0.0 : (progress > 0 ? progress : 0.0),
                  strokeWidth: 3,
                  backgroundColor: isFuture
                      ? AppTheme.subtleFillColor(context).withValues(alpha: 0.3)
                      : AppTheme.subtleFillColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Text(
                date,
                style: AppTheme.bodySmall.copyWith(
                  color: isToday
                      ? AppTheme.selectedChipTextColor(context)
                      : (isFuture
                          ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                          : AppTheme.textSecondaryColor(context)),
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const VGapXs(),
        // Today indicator dot
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isToday ? AppTheme.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
      ],
    );
  }
}
