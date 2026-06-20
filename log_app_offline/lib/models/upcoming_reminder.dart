import '../models/task.dart';

class UpcomingReminder {
  final String uniqueId;
  final String type; // 'activity', 'subtask', 'task'
  final String title;
  final String subtitle;
  final DateTime scheduledDateTime;
  final String activityId;
  final String? subTaskTitle;
  final Task? task;

  UpcomingReminder({
    required this.uniqueId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.scheduledDateTime,
    required this.activityId,
    this.subTaskTitle,
    this.task,
  });
}
