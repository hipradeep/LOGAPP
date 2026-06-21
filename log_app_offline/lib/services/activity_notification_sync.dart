import 'dart:async';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../utils/date_utils.dart';
import 'activity_service.dart';
import 'check_in_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';

class ActivityNotificationSync {
  static StreamSubscription<List<Activity>>? _activitiesSub;
  static StreamSubscription<List<Task>>? _tasksSub;
  static StreamSubscription<List<CheckIn>>? _checkInsSub;

  static List<Activity> _latestActivities = [];
  static List<Task> _latestTasks = [];
  static List<CheckIn> _latestCheckIns = [];

  static Timer? _debounceTimer;
  static Completer<void>? _syncCompleter;

  static final ActivityService _activityService = ActivityService();
  static final CheckInService _checkInService = CheckInService();
  static final CacheService _cacheService = CacheService();


  static void init() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    _checkInsSub?.cancel();

    _activitiesSub = _activityService.getActivitiesStream().listen((activities) {
      _latestActivities = activities;
      _sync();
    });

    _tasksSub = _activityService.getTasksStream().listen((tasks) {
      _latestTasks = tasks;
      _sync();
    });

    _checkInsSub = _checkInService.getCheckInsStreamForCurrentWeek().listen((checkIns) {
      _latestCheckIns = checkIns;
      _sync();
    });
  }

  /// Cancel all subscriptions
  static void dispose() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    _checkInsSub?.cancel();
    _activitiesSub = null;
    _tasksSub = null;
    _checkInsSub = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Public entry point to force synchronizing notifications
  static Future<void> forceSync() async {
    await _sync();
  }

  /// Run the notification scheduling/cancellation logic with debouncing
  static Future<void> _sync() {
    _debounceTimer?.cancel();
    
    if (_syncCompleter == null || _syncCompleter!.isCompleted) {
      _syncCompleter = Completer<void>();
    }
    
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _syncInternal();
        if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
          _syncCompleter!.complete();
        }
      } catch (e, stackTrace) {
        if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
          _syncCompleter!.completeError(e, stackTrace);
        }
      }
    });
    
    return _syncCompleter!.future;
  }

  static Future<void> _syncInternal() async {
    if (_latestActivities.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Load and clean snoozes from cache
    final snoozes = await _cacheService.getSnoozedReminders();
    bool snoozesChanged = false;
    final Map<String, String> cleanSnoozes = {};
    snoozes.forEach((key, val) {
      try {
        final expiry = DateTime.parse(val);
        if (expiry.isAfter(now)) {
          cleanSnoozes[key] = val;
        } else {
          snoozesChanged = true;
        }
      } catch (_) {
        snoozesChanged = true;
      }
    });
    if (snoozesChanged) {
      await _cacheService.saveSnoozedReminders(cleanSnoozes);
    }

    // 2. Identify all activities that are active (isActive == true)
    final activeActivities = _latestActivities.where((a) => a.isActive).toList();

    // 3. Build map of notifications that SHOULD be scheduled
    final Map<String, _TargetNotification> targetNotifications = {};

    for (final activity in activeActivities) {
      if (activity.reminderEnabled == false) {
        continue;
      }

      // Check if activity runs today
      if (!activity.repeatDays.contains(today.weekday)) {
        continue;
      }

      // --- Activity Main Scheduled Reminder ---
      if (activity.scheduledTime != null && activity.scheduledTime!.isNotEmpty) {
        // Parse main activity schedule time to compare hours/minutes
        DateTime? mainParsedTime;
        try {
          mainParsedTime = NotificationService.parseTimeString(activity.scheduledTime!);
        } catch (_) {}

        // Check if there is any subtask reminder scheduled at the exact same hour and minute
        bool hasMatchingSubtaskTime = false;
        if (activity.trackingType == 'multiple' && activity.subTaskTemplates.isNotEmpty && mainParsedTime != null) {
          for (final template in activity.subTaskTemplates) {
            final parts = template.split('|');
            final timeStr = parts.length > 1 ? parts.last : null;
            if (timeStr != null && timeStr.isNotEmpty) {
              try {
                final subParsedTime = NotificationService.parseTimeString(timeStr);
                if (subParsedTime.hour == mainParsedTime.hour && subParsedTime.minute == mainParsedTime.minute) {
                  hasMatchingSubtaskTime = true;
                  break;
                }
              } catch (_) {}
            }
          }
        }

        if (!hasMatchingSubtaskTime) {
          final isCompleted = _isActivityCompletedToday(activity, today);
          final uniqueId = 'activity_${activity.id}';

          DateTime? finalDateTime;
          String? finalTimeString = activity.scheduledTime!;
          if (cleanSnoozes.containsKey(uniqueId)) {
            finalDateTime = DateTime.parse(cleanSnoozes[uniqueId]!);
            finalTimeString = null;
          }

          targetNotifications[uniqueId] = _TargetNotification(
            uniqueId: uniqueId,
            title: activity.name,
            body: 'Time for your activity: ${activity.name}',
            timeString: finalTimeString,
            dateTime: finalDateTime,
            forceTomorrow: isCompleted,
          );
        }
      }

      // --- Routine Subtasks Scheduled Reminders ---
      if (activity.trackingType == 'multiple' && activity.subTaskTemplates.isNotEmpty) {
        for (final template in activity.subTaskTemplates) {
          final parts = template.split('|');
          final subTaskTitle = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;

          if (timeStr != null && timeStr.isNotEmpty) {
            final isCompleted = _isSubTaskCompletedToday(activity, subTaskTitle, today);
            final uniqueId = 'subtask_${activity.id}_$subTaskTitle';

            DateTime? finalDateTime;
            String? finalTimeString = timeStr;
            if (cleanSnoozes.containsKey(uniqueId)) {
              finalDateTime = DateTime.parse(cleanSnoozes[uniqueId]!);
              finalTimeString = null;
            }

            targetNotifications[uniqueId] = _TargetNotification(
              uniqueId: uniqueId,
              title: activity.name,
              body: subTaskTitle,
              timeString: finalTimeString,
              dateTime: finalDateTime,
              forceTomorrow: isCompleted,
            );
          }
        }
      }

      // --- Milestone Tasks One-Shot Reminders ---
      if (activity.trackingType == 'milestone') {
        final milestoneTasks = _latestTasks.where((t) => t.activityId == activity.id);
        for (final task in milestoneTasks) {
          if (task.scheduledTime != null && task.scheduledTime!.isNotEmpty) {
            var scheduledDateTime = _getTaskScheduledDateTime(task);
            final uniqueId = 'milestone_${task.id}';

            if (cleanSnoozes.containsKey(uniqueId)) {
              scheduledDateTime = DateTime.parse(cleanSnoozes[uniqueId]!);
            }

            if (scheduledDateTime.isAfter(now)) {
              targetNotifications[uniqueId] = _TargetNotification(
                uniqueId: uniqueId,
                title: activity.name,
                body: task.taskName,
                dateTime: scheduledDateTime,
                forceTomorrow: false,
              );
            }
          }
        }
      }
    }

    // 3. Load previously scheduled IDs from cache
    final previouslyScheduledIds = await _cacheService.getScheduledActivityIds();
    final previouslyScheduledSet = previouslyScheduledIds.toSet();

    // 4. Cancel notifications that are no longer active/present
    for (final oldId in previouslyScheduledSet) {
      if (!targetNotifications.containsKey(oldId)) {
        final int hashId = oldId.hashCode.toSigned(31);
        await NotificationService.cancelNotification(hashId);
      }
    }

    // 5. Schedule/reschedule target notifications
    for (final target in targetNotifications.values) {
      final int hashId = target.uniqueId.hashCode.toSigned(31);
      if (target.dateTime != null) {
        // One-shot scheduling
        await NotificationService.scheduleOneShotNotification(
          id: hashId,
          title: target.title,
          body: target.body,
          dateTime: target.dateTime!,
        );
      } else {
        // Daily recurring scheduling
        await NotificationService.scheduleDailyNotification(
          id: hashId,
          title: target.title,
          body: target.body,
          timeString: target.timeString!,
          forceTomorrow: target.forceTomorrow,
        );
      }
    }

    // 6. Save current target notification IDs to cache
    await _cacheService.saveScheduledActivityIds(targetNotifications.keys.toList());
  }

  // ==================== HELPERS ====================

  static bool _isActivityCompletedToday(Activity activity, DateTime today) {
    // Check-in skip status
    final bool isSkipped = _latestCheckIns.any((c) =>
        AppDateUtils.isSameDay(c.timestamp, today) &&
        c.activityId == activity.id &&
        c.skipped == true);
    if (isSkipped) return true;

    // We no longer care if the activity is completed/checked-in/tracked for alarm scheduling.
    return false;
  }

  static bool _isSubTaskCompletedToday(Activity activity, String subTaskTitle, DateTime today) {
    final isSkipped = _latestCheckIns.any((c) =>
        AppDateUtils.isSameDay(c.timestamp, today) &&
        c.activityId == activity.id &&
        c.subTaskName == subTaskTitle &&
        c.skipped == true);
    if (isSkipped) return true;

    // We no longer care if the subtask is checked for alarm scheduling.
    return false;
  }

  static DateTime _getTaskScheduledDateTime(Task task) {
    final parsedTime = NotificationService.parseTimeString(task.scheduledTime!);
    return DateTime(
      task.timestamp.year,
      task.timestamp.month,
      task.timestamp.day,
      parsedTime.hour,
      parsedTime.minute,
    );
  }
}

class _TargetNotification {
  final String uniqueId;
  final String title;
  final String body;
  final String? timeString;
  final DateTime? dateTime;
  final bool forceTomorrow;

  _TargetNotification({
    required this.uniqueId,
    required this.title,
    required this.body,
    this.timeString,
    this.dateTime,
    required this.forceTomorrow,
  });
}
