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
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary, size: 40),
            const VGapSm(),
            Text(
              'No active activities selected.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const VGapXs(),
            Text(
              'Go to Settings > Track Activities to choose activities for your daily layout.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
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
    
    String motivationalMessage = 'Start your day by checking in to an activity!';
    if (completionRate > 0 && completionRate < 0.5) {
      motivationalMessage = 'Off to a good start! Keep it going!';
    } else if (completionRate >= 0.5 && completionRate < 1.0) {
      motivationalMessage = 'More than halfway there! Almost done!';
    } else if (completionRate == 1.0) {
      motivationalMessage = 'Perfect day! You\'ve completed all active activities! 🎉';
    }

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Progress'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const VGapSm(),
                  Text(
                    '$completedActivities of $totalActivities Completed',
                    style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const VGapSm(),
                  Text(
                    motivationalMessage,
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const HGapMd(),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: completionRate,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completionRate >= 1.0 ? AppTheme.successColor : AppTheme.primaryColor,
                    ),
                  ),
                ),
                Text(
                  '${(completionRate * 100).toInt()}%',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
