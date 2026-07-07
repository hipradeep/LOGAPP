import 'package:core_services/core_services.dart' show Activity, Task;

class MilestoneService {
  // Check if a milestone is completed on a specific day
  bool isMilestoneCompletedOnDay(Activity activity, List<Task> tasks, DateTime day) {
    if (activity.trackingType != 'milestone') return false;

    final dayTasks = tasks.where((t) =>
        t.activityId == activity.id &&
        t.timestamp.year == day.year &&
        t.timestamp.month == day.month &&
        t.timestamp.day == day.day
    ).toList();

    return dayTasks.isNotEmpty && dayTasks.every((t) => t.checked);
  }

  // Get the fractional completion rate of a milestone on a specific day.
  // Returns -1.0 if there are no tasks scheduled for that day.
  double getMilestoneDailyCompletion(Activity activity, List<Task> tasks, DateTime day) {
    if (activity.trackingType != 'milestone') return -1.0;

    final dayTasks = tasks.where((t) =>
        t.activityId == activity.id &&
        t.timestamp.year == day.year &&
        t.timestamp.month == day.month &&
        t.timestamp.day == day.day
    ).toList();

    if (dayTasks.isEmpty) return -1.0;

    final completedCount = dayTasks.where((t) => t.checked).length;
    return completedCount / dayTasks.length;
  }

  // Check if a milestone is completed today
  bool isMilestoneCompletedToday(Activity activity, List<Task> tasks) {
    return isMilestoneCompletedOnDay(activity, tasks, DateTime.now());
  }

  // Calculate milestone-specific stats (total, completed, pending, progress rate)
  ({int total, int completed, int pending, double progress}) calculateMilestoneStats(List<Task> tasks) {
    int milestoneTotal = 0;
    int milestoneCompleted = 0;

    for (var t in tasks) {
      if (t.subTasks.isEmpty) {
        milestoneTotal += 1;
        if (t.checked) milestoneCompleted += 1;
      } else {
        milestoneTotal += t.subTasks.length;
        milestoneCompleted += t.subTasks.where((st) => st.checked).length;
      }
    }

    final int milestonePending = milestoneTotal - milestoneCompleted;
    final double milestoneProgress = milestoneTotal > 0 ? (milestoneCompleted / milestoneTotal) : 0.0;

    return (
      total: milestoneTotal,
      completed: milestoneCompleted,
      pending: milestonePending,
      progress: milestoneProgress,
    );
  }
}
