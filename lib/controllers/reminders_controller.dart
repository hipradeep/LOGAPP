import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/reminder_item.dart';
import '../models/upcoming_reminder.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../models/check_in.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/activity_notification_sync.dart';

class RemindersController extends ChangeNotifier {
  final CacheService _cacheService = CacheService();
  List<ReminderItem> _reminders = [];
  List<UpcomingReminder> _upcomingReminders = [];

  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<Task>>? _tasksSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;

  List<Activity> _activities = [];
  List<Task> _allTasks = [];
  List<CheckIn> _checkIns = [];

  List<ReminderItem> get reminders => _reminders;
  List<UpcomingReminder> get upcomingReminders => _upcomingReminders;
  
  List<UpcomingReminder> get todayReminders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _upcomingReminders.where((r) =>
        r.scheduledDateTime.year == today.year &&
        r.scheduledDateTime.month == today.month &&
        r.scheduledDateTime.day == today.day &&
        !r.scheduledDateTime.isBefore(now)
    ).toList();
  }

  List<UpcomingReminder> get passedReminders {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _upcomingReminders.where((r) =>
        r.scheduledDateTime.year == today.year &&
        r.scheduledDateTime.month == today.month &&
        r.scheduledDateTime.day == today.day &&
        r.scheduledDateTime.isBefore(now)
    ).toList();
  }

  List<UpcomingReminder> get tomorrowReminders {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _upcomingReminders.where((r) =>
        r.scheduledDateTime.year == tomorrow.year &&
        r.scheduledDateTime.month == tomorrow.month &&
        r.scheduledDateTime.day == tomorrow.day
    ).toList();
  }

  Map<String, List<UpcomingReminder>> get remindersByActivity {
    final Map<String, List<UpcomingReminder>> grouped = {};
    for (final r in _upcomingReminders) {
      final activity = _activities.firstWhere(
        (a) => a.id == r.activityId,
        orElse: () => Activity(id: '', name: 'Unknown', checked: false, timestamp: DateTime.now()),
      );
      final activityName = activity.name.isNotEmpty ? activity.name : 'Unknown';
      if (!grouped.containsKey(activityName)) {
        grouped[activityName] = [];
      }
      grouped[activityName]!.add(r);
    }
    return grouped;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  RemindersController() {
    _loadFromCache();
    _initStreams();
  }

  void _initStreams() {
    final activityService = ActivityService();
    final checkInService = CheckInService();

    _activitiesSub = activityService.getActivitiesStream().listen((activities) {
      _activities = activities;
      _computeUpcomingReminders();
    });

    _tasksSub = activityService.getTasksStream().listen((tasks) {
      _allTasks = tasks;
      _computeUpcomingReminders();
    });

    _checkInsSub = checkInService.getCheckInsStreamForCurrentWeek().listen((checkIns) {
      _checkIns = checkIns;
      _computeUpcomingReminders();
    });
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    _checkInsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      _reminders = await _cacheService.getReminders();
      // Synchronize exact alarms for all active reminders
      for (final item in _reminders) {
        if (item.isActive) {
          _scheduleNotification(item);
        } else {
          _cancelNotification(item);
        }
      }
      await NotificationService.logPendingNotifications();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _computeUpcomingReminders() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final snoozes = await _cacheService.getSnoozedReminders();

    final List<UpcomingReminder> temp = [];

    bool isSameDate(DateTime d1, DateTime d2) {
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    }

    final activeActivities = _activities.where((a) => a.checked).toList();

    for (final date in [today, tomorrow]) {
      final isDateToday = isSameDate(date, today);

      for (final activity in activeActivities) {
        // RepeatDays
        if (!activity.repeatDays.contains(date.weekday)) continue;

        // Date range boundaries check
        if (activity.startDate != null &&
            date.isBefore(DateTime(activity.startDate!.year, activity.startDate!.month, activity.startDate!.day))) {
          continue;
        }
        if (activity.endDate != null &&
            date.isAfter(DateTime(activity.endDate!.year, activity.endDate!.month, activity.endDate!.day))) {
          continue;
        }

        // --- Activity Main Scheduled Reminder ---
        if (activity.scheduledTime != null && activity.scheduledTime!.isNotEmpty) {
          final uniqueId = 'activity_${activity.id}';

          // Check if completed/skipped
          bool isCompleted = false;
          final isSkipped = _checkIns.any((c) =>
              isSameDate(c.timestamp, date) &&
              c.activityId == activity.id &&
              c.skipped == true);

          if (isSkipped) {
            isCompleted = true;
          } else {
            if (activity.trackingType == 'milestone') {
              isCompleted = _allTasks.any((s) => s.activityId == activity.id && isSameDate(s.timestamp, date) && s.checked);
            } else if (activity.trackingType == 'multiple') {
              final taskForDate = _allTasks.firstWhere(
                (s) => s.activityId == activity.id && isSameDate(s.timestamp, date) && s.subTasks.isNotEmpty,
                orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: date, checked: false),
              );
              final completedCount = taskForDate.subTasks.where((st) => st.checked).length;
              isCompleted = completedCount >= activity.targetCount;
            } else {
              final checkInCount = _checkIns.where((c) => c.activityId == activity.id && isSameDate(c.timestamp, date) && c.checked).length;
              isCompleted = checkInCount >= activity.targetCount;
            }
          }

          if (!isCompleted) {
            final parsedTime = NotificationService.parseTimeString(activity.scheduledTime!);
            var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

            if (snoozes.containsKey(uniqueId)) {
              final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
              if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                scheduledTime = snoozeExpiry;
              }
            }

            // Show if it is in the future, or today but overdue/pending
            if (!isDateToday || scheduledTime.isAfter(now) || (isDateToday && !isCompleted)) {
              temp.add(UpcomingReminder(
                uniqueId: uniqueId,
                type: 'activity',
                title: activity.name,
                subtitle: 'Activity Reminder',
                scheduledDateTime: scheduledTime,
                activityId: activity.id,
              ));
            }
          }
        }

        // --- Routine Subtasks Scheduled Reminders ---
        if (activity.trackingType == 'multiple' && activity.subTaskTemplates.isNotEmpty) {
          for (final template in activity.subTaskTemplates) {
            final parts = template.split('|');
            final subTaskTitle = parts.first;
            final timeStr = parts.length > 1 ? parts.last : null;

            if (timeStr != null && timeStr.isNotEmpty) {
              final uniqueId = 'subtask_${activity.id}_$subTaskTitle';

              bool isSubCompleted = false;
              final isSkipped = _checkIns.any((c) =>
                  isSameDate(c.timestamp, date) &&
                  c.activityId == activity.id &&
                  c.subTaskName == subTaskTitle &&
                  c.skipped == true);

              if (isSkipped) {
                isSubCompleted = true;
              } else {
                final taskForDate = _allTasks.firstWhere(
                  (s) => s.activityId == activity.id && isSameDate(s.timestamp, date) && s.subTasks.isNotEmpty,
                  orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: date, checked: false),
                );
                final subTask = taskForDate.subTasks.firstWhere(
                  (st) => st.title == subTaskTitle,
                  orElse: () => SubTask(id: '', title: '', checked: false),
                );
                isSubCompleted = subTask.checked;
              }

              if (!isSubCompleted) {
                final parsedTime = NotificationService.parseTimeString(timeStr);
                var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

                if (snoozes.containsKey(uniqueId)) {
                  final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
                  if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                    scheduledTime = snoozeExpiry;
                  }
                }

                if (!isDateToday || scheduledTime.isAfter(now) || (isDateToday && !isSubCompleted)) {
                  temp.add(UpcomingReminder(
                    uniqueId: uniqueId,
                    type: 'subtask',
                    title: '${activity.name} - $subTaskTitle',
                    subtitle: 'Subtask Reminder',
                    scheduledDateTime: scheduledTime,
                    activityId: activity.id,
                    subTaskTitle: subTaskTitle,
                  ));
                }
              }
            }
          }
        }

        // --- Milestone Tasks One-Shot Reminders ---
        if (activity.trackingType == 'milestone') {
          final milestoneTasks = _allTasks.where((t) => t.activityId == activity.id && isSameDate(t.timestamp, date));
          for (final task in milestoneTasks) {
            if (!task.checked && task.scheduledTime != null && task.scheduledTime!.isNotEmpty) {
              final uniqueId = 'milestone_${task.id}';

              final parsedTime = NotificationService.parseTimeString(task.scheduledTime!);
              var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

              if (snoozes.containsKey(uniqueId)) {
                final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
                if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                  scheduledTime = snoozeExpiry;
                }
              }

              if (!isDateToday || scheduledTime.isAfter(now) || (isDateToday && !task.checked)) {
                temp.add(UpcomingReminder(
                  uniqueId: uniqueId,
                  type: 'task',
                  title: '${activity.name} - ${task.taskName}',
                  subtitle: 'Milestone Task',
                  scheduledDateTime: scheduledTime,
                  activityId: activity.id,
                  task: task,
                ));
              }
            }
          }
        }
      }
    }

    temp.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
    _upcomingReminders = temp;
    notifyListeners();
  }

  Future<void> snoozeReminder(UpcomingReminder reminder, int minutes) async {
    final snoozeExpiry = DateTime.now().add(Duration(minutes: minutes));
    final snoozes = await _cacheService.getSnoozedReminders();
    snoozes[reminder.uniqueId] = snoozeExpiry.toIso8601String();
    await _cacheService.saveSnoozedReminders(snoozes);

    // Update system alarm notifications
    await ActivityNotificationSync.forceSync();

    // Recalculate upcoming reminders list
    await _computeUpcomingReminders();
  }

  Future<void> skipReminderForToday(UpcomingReminder reminder) async {
    final checkInService = CheckInService();

    if (reminder.type == 'activity') {
      await checkInService.createCheckIn(reminder.activityId, reminder.scheduledDateTime, false, skipped: true);
    } else if (reminder.type == 'subtask') {
      await checkInService.createCheckIn(reminder.activityId, reminder.scheduledDateTime, false, skipped: true, subTaskName: reminder.subTaskTitle);
    } else if (reminder.type == 'task' && reminder.task != null) {
      final tomorrowDate = reminder.scheduledDateTime.add(const Duration(days: 1));
      final task = reminder.task!;
      final updatedTask = task.copyWith(
        timestamp: DateTime(
          tomorrowDate.year,
          tomorrowDate.month,
          tomorrowDate.day,
          task.timestamp.hour,
          task.timestamp.minute,
        ),
      );
      await ActivityService().updateTask(updatedTask);
    }

    // Update system alarm notifications
    await ActivityNotificationSync.forceSync();

    // Recalculate upcoming reminders list
    await _computeUpcomingReminders();
  }

  Future<void> refresh() async {
    await _loadFromCache();
    await _computeUpcomingReminders();
  }

  int _getNotificationId(ReminderItem item) {
    return (item.title + item.time).hashCode.toSigned(31);
  }

  void _scheduleNotification(ReminderItem item) {
    NotificationService.scheduleDailyNotification(
      id: _getNotificationId(item),
      title: item.title,
      body: 'Reminder: ${item.title}',
      timeString: item.time,
    );
  }

  void _cancelNotification(ReminderItem item) {
    NotificationService.cancelNotification(_getNotificationId(item));
  }

  void addReminder(ReminderItem item) async {
    _reminders.add(item);
    _scheduleNotification(item);
    await _cacheService.saveReminders(_reminders);
    notifyListeners();
  }

  void removeReminder(int index) async {
    if (index >= 0 && index < _reminders.length) {
      final item = _reminders[index];
      _cancelNotification(item);
      _reminders.removeAt(index);
      await _cacheService.saveReminders(_reminders);
      notifyListeners();
    }
  }

  void toggleReminderActive(int index, bool val) async {
    if (index >= 0 && index < _reminders.length) {
      final item = _reminders[index];
      item.isActive = val;
      if (val) {
        _scheduleNotification(item);
      } else {
        _cancelNotification(item);
      }
      await _cacheService.saveReminders(_reminders);
      notifyListeners();
    }
  }
}
