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
  List<Activity> get activities => _activities;
  
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

  Map<String, List<UpcomingReminder>> get remindersByActivity {
    final Map<String, List<UpcomingReminder>> grouped = {};
    for (final r in _upcomingReminders) {
      final activity = _activities.firstWhere(
        (a) => a.id == r.activityId,
        orElse: () => Activity(id: '', name: 'Unknown', isActive: false, timestamp: DateTime.now()),
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

    final snoozes = await _cacheService.getSnoozedReminders();
    final List<UpcomingReminder> temp = [];

    bool isSameDate(DateTime d1, DateTime d2) {
      return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    }

    final activeActivities = _activities.where((a) => a.isActive).toList();

    for (final date in [today]) {
      for (final activity in activeActivities) {
        
        // RepeatDays
        if (!activity.repeatDays.contains(date.weekday)) {
          continue;
        }

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

          final isSkipped = _checkIns.any((c) =>
              isSameDate(c.timestamp, date) &&
              c.activityId == activity.id &&
              c.subTaskName == null &&
              c.skipped == true);

          if (!isSkipped) {
            final parsedTime = NotificationService.parseTimeString(activity.scheduledTime!);
            var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

            if (snoozes.containsKey(uniqueId)) {
              final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
              if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                scheduledTime = snoozeExpiry;
              }
            }

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

        // --- Routine Subtasks Scheduled Reminders ---
        if (activity.trackingType == 'multiple' && activity.subTaskTemplates.isNotEmpty) {
          for (final template in activity.subTaskTemplates) {
            final parts = template.split('|');
            final subTaskTitle = parts.first;
            final timeStr = parts.length > 1 ? parts.last : null;

            if (timeStr != null && timeStr.isNotEmpty) {
              final uniqueId = 'subtask_${activity.id}_$subTaskTitle';

              final isSkipped = _checkIns.any((c) =>
                  isSameDate(c.timestamp, date) &&
                  c.activityId == activity.id &&
                  c.subTaskName == subTaskTitle &&
                  c.skipped == true);

              if (!isSkipped) {
                final parsedTime = NotificationService.parseTimeString(timeStr);
                var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

                if (snoozes.containsKey(uniqueId)) {
                  final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
                  if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                    scheduledTime = snoozeExpiry;
                  }
                }

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

        // --- Milestone Tasks One-Shot Reminders ---
        if (activity.trackingType == 'milestone') {
          final milestoneTasks = _allTasks.where((t) => t.activityId == activity.id && isSameDate(t.timestamp, date));
          for (final task in milestoneTasks) {
            if (task.scheduledTime != null && task.scheduledTime!.isNotEmpty) {
              final uniqueId = 'milestone_${task.id}';

              final parsedTime = NotificationService.parseTimeString(task.scheduledTime!);
              var scheduledTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);

              if (snoozes.containsKey(uniqueId)) {
                final snoozeExpiry = DateTime.parse(snoozes[uniqueId]!);
                if (isSameDate(snoozeExpiry, date) && snoozeExpiry.isAfter(now)) {
                  scheduledTime = snoozeExpiry;
                }
              }

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

  Future<void> checkInReminder(UpcomingReminder reminder) async {
    final checkInNow = DateTime.now();
    final checkInService = CheckInService();
    final activityService = ActivityService();

    if (reminder.type == 'activity') {
      await checkInService.createCheckIn(reminder.activityId, checkInNow, true);
    } else if (reminder.type == 'subtask' && reminder.subTaskTitle != null) {
      final todayTask = _allTasks.firstWhere(
        (s) => _isToday(s.timestamp) && s.subTasks.isNotEmpty && s.activityId == reminder.activityId,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
      );

      if (todayTask.id.isEmpty) {
        final activity = _activities.firstWhere((a) => a.id == reminder.activityId);
        final List<SubTask> initialSubTasks = activity.subTaskTemplates.map((template) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          return SubTask(
            id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}',
            title: title,
            checked: title == reminder.subTaskTitle,
            scheduledTime: timeStr,
          );
        }).toList();

        await activityService.createTask(
          reminder.activityId,
          activity.name,
          DateTime.now(),
          initialSubTasks.every((st) => st.checked),
          subTasks: initialSubTasks,
        );

        await checkInService.createCheckIn(
          reminder.activityId,
          checkInNow,
          true,
          subTaskName: reminder.subTaskTitle,
        );
      } else {
        final List<SubTask> updatedSubTasks = List<SubTask>.from(todayTask.subTasks);
        bool modified = false;
        for (int i = 0; i < updatedSubTasks.length; i++) {
          final cleanTitle = updatedSubTasks[i].title.contains('|') 
              ? updatedSubTasks[i].title.split('|').first 
              : updatedSubTasks[i].title;
          if (cleanTitle == reminder.subTaskTitle && !updatedSubTasks[i].checked) {
            updatedSubTasks[i] = updatedSubTasks[i].copyWith(checked: true);
            modified = true;

            await checkInService.createCheckIn(
              reminder.activityId,
              checkInNow,
              true,
              subTaskName: reminder.subTaskTitle,
            );
          }
        }
        if (modified) {
          final allChecked = updatedSubTasks.every((st) => st.checked);
          final updatedTask = todayTask.copyWith(subTasks: updatedSubTasks, checked: allChecked);
          await activityService.updateTask(updatedTask);
        }
      }
    } else if (reminder.type == 'task' && reminder.task != null) {
      await activityService.toggleTask(reminder.task!.id, true);
    }

    await _computeUpcomingReminders();
  }

  Future<void> toggleActivity(Activity activity, bool isActive) async {
    await ActivityService().toggleActivity(activity.id, isActive);
    await _computeUpcomingReminders();
  }

  Future<void> toggleReminderEnabled(Activity activity, bool enabled) async {
    await ActivityService().toggleReminderEnabled(activity.id, enabled);
    await _computeUpcomingReminders();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }
}
