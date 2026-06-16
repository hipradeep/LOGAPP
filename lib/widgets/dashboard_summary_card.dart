import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import 'app_spacers.dart';

class DashboardSummaryCard extends StatelessWidget {
  final List<Activity> activities;
  final List<CheckIn> checkIns;
  final List<Task> subTasks;

  const DashboardSummaryCard({
    super.key,
    required this.activities,
    required this.checkIns,
    required this.subTasks,
  });

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary, size: 28),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No active activities selected.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Go to Settings > Track Activities to choose.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    int completedActivities = 0;
    final totalActivities = activities.length;

    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();

    for (var activity in activities) {
      final int todayCount;
      if (activity.trackingType == 'multiple') {
        final todayTask = subTasks.firstWhere(
          (s) => s.activityId == activity.id && _isToday(s.timestamp),
          orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
        );
        todayCount = todayTask.subTasks.where((st) => st.checked).length;
      } else {
        todayCount = todayCheckIns.where((c) => c.activityId == activity.id).length;
      }
      if (todayCount >= activity.targetCount) {
        completedActivities++;
      }
    }

    final double completionRate = totalActivities > 0 ? completedActivities / totalActivities : 0.0;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Daily Progress'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      fontSize: 10,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    '$completedActivities of $totalActivities Completed',
                    style: AppTheme.headingSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const HGapMd(),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    value: completionRate,
                    strokeWidth: 5,
                    backgroundColor: AppTheme.borderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionRate >= 1.0 ? AppTheme.successColor : AppTheme.primaryColor,
                    ),
                  ),
                ),
                Text(
                  '${(completionRate * 100).toInt()}%',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.bodySmall!.color,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
