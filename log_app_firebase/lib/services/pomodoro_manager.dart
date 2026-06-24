import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'cache_service.dart';
import 'activity_service.dart';
import 'note_service.dart';
import 'service_locator.dart';
import 'notification_service.dart';

class PomodoroManager with WidgetsBindingObserver {
  static final PomodoroManager instance = PomodoroManager._internal();
  factory PomodoroManager() => instance;
  PomodoroManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  Activity? activity;
  List<Activity> remainingQueue = [];
  int totalSeconds = 0;
  int secondsRemaining = 0;
  bool isRunning = false;
  bool isCompleted = false;
  bool trackSession = true;
  bool followUpNext = true;
  bool allowPause = true;
  bool isRestrictMode = true;
  List<String>? focusedSubTaskIds;
  Task? milestoneTask;
  DateTime? startTime;

  Timer? _timer;
  final ValueNotifier<int> secondsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCompletedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSessionActiveNotifier = ValueNotifier<bool>(false);

  void init({
    required Activity activity,
    required List<Activity> remainingQueue,
    required int totalSeconds,
    required bool trackSession,
    required bool followUpNext,
    required bool allowPause,
    required bool isRestrictMode,
    List<String>? focusedSubTaskIds,
    Task? milestoneTask,
    int? initialSecondsRemaining,
    bool? initialIsRunning,
  }) {
    this.activity = activity;
    this.remainingQueue = remainingQueue;
    this.totalSeconds = totalSeconds;
    secondsRemaining = initialSecondsRemaining ?? totalSeconds;
    isRunning = initialIsRunning ?? false;
    this.trackSession = trackSession;
    this.followUpNext = followUpNext;
    this.allowPause = allowPause;
    this.isRestrictMode = isRestrictMode;
    focusedSubTaskIds = focusedSubTaskIds;
    milestoneTask = milestoneTask;
    isCompleted = false;
    startTime = DateTime.now().subtract(Duration(seconds: totalSeconds - secondsRemaining));

    secondsNotifier.value = secondsRemaining;
    isRunningNotifier.value = isRunning;
    isCompletedNotifier.value = false;
    isSessionActiveNotifier.value = true;

    if (isRunning) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    isRunning = true;
    isRunningNotifier.value = true;
    _saveSessionToCache();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining > 0) {
        secondsRemaining--;
        secondsNotifier.value = secondsRemaining;
      } else {
        t.cancel();
        _handleSessionComplete();
      }
    });
  }

  void startFocusTimer() {
    _startTimer();
  }

  void pauseTimer() {
    _timer?.cancel();
    isRunning = false;
    isRunningNotifier.value = false;
    _cancelBackgroundNotifications();
    _saveSessionToCache();
  }

  void resetTimer() {
    _timer?.cancel();
    _cancelBackgroundNotifications();
    secondsRemaining = totalSeconds;
    secondsNotifier.value = totalSeconds;
    isRunning = false;
    isRunningNotifier.value = false;
    isCompleted = false;
    isCompletedNotifier.value = false;
    isSessionActiveNotifier.value = false;
    CacheService().clearActivePomodoroSession();
  }

  void cancelTimer() {
    _timer?.cancel();
    _cancelBackgroundNotifications();
    isRunning = false;
    isRunningNotifier.value = false;
    isSessionActiveNotifier.value = false;
    isCompletedNotifier.value = false;
    CacheService().clearActivePomodoroSession();
    activity = null;
  }

  void _saveSessionToCache() async {
    if (activity == null) return;
    final endTimestamp = DateTime.now().millisecondsSinceEpoch + secondsRemaining * 1000;
    final sessionData = {
      'activity': activity!.toJson(),
      'remainingQueue': remainingQueue.map((a) => a.toJson()).toList(),
      'endTimestamp': endTimestamp,
      'trackSession': trackSession,
      'followUpNext': followUpNext,
      'isRunning': isRunning,
      'secondsRemaining': secondsRemaining,
      'startTimestamp': startTime?.millisecondsSinceEpoch,
      'isRestrictMode': isRestrictMode,
    };
    await CacheService().saveActivePomodoroSession(sessionData);
  }

  void _handleSessionComplete() {
    _cancelBackgroundNotifications();
    isRunning = false;
    isRunningNotifier.value = false;
    isCompleted = true;
    isCompletedNotifier.value = true;
    isSessionActiveNotifier.value = false;
    CacheService().clearActivePomodoroSession();

    if (activity == null) return;

    // Auto-complete (check off) the focused subtask or parent milestone task in Firestore on focus completion
    if (activity!.hasSubTasks) {
      final activityService = getIt<ActivityService>();
      final taskId = milestoneTask?.id ?? activity!.id;
      activityService.getTaskById(taskId).then((task) {
        if (task != null) {
          final focusedIds = focusedSubTaskIds;
          List<SubTask> updatedSubTasks = task.subTasks;
          bool parentShouldBeChecked = task.checked;
          DateTime? completionTime = task.completionTime;

          if (focusedIds != null && focusedIds.isNotEmpty && task.subTasks.isNotEmpty) {
            String? firstSelectedId;
            for (final st in task.subTasks) {
              if (focusedIds.contains(st.id) && !st.checked) {
                firstSelectedId = st.id;
                break;
              }
            }

            if (firstSelectedId != null) {
              updatedSubTasks = task.subTasks.map((st) {
                if (st.id == firstSelectedId) {
                  return st.copyWith(checked: true);
                }
                return st;
              }).toList();
            }
            
            // Auto-check parent only if all subtasks are checked
            if (updatedSubTasks.every((st) => st.checked)) {
              parentShouldBeChecked = true;
              completionTime = DateTime.now();
            }
          } else {
            // No focused subtasks selected, auto-complete parent task
            parentShouldBeChecked = true;
            completionTime = DateTime.now();
          }
          
          final updatedTask = task.copyWith(
            subTasks: updatedSubTasks,
            checked: parentShouldBeChecked,
            completionTime: completionTime,
          );
          activityService.updateTask(updatedTask);
        }
      }).catchError((e) {
        debugPrint('Error updating focus milestone task check: $e');
      });
    }

    if (!trackSession) return;
    final minutes = totalSeconds ~/ 60;
    final String displayName = (activity!.trackingType == 'milestone' && activity!.category != null)
        ? '${activity!.category} - ${activity!.name}'
        : activity!.name;

    getIt<NoteService>()
        .createEntry(
          'Completed Pomodoro Session',
          'Successfully completed a $minutes-minute Pomodoro focus session on "$displayName".',
          activity!.symbolValue ?? '🎯',
          ['FocusSession', 'Pomodoro', displayName],
        );
  }

  void _showBackgroundNotifications() async {
    if (!isRunning || secondsRemaining <= 0 || activity == null) return;

    final endTimestamp = DateTime.now().millisecondsSinceEpoch + secondsRemaining * 1000;

    String startTimeFormatted = '';
    if (startTime != null) {
      startTimeFormatted = ' (${DateFormat.jm().format(startTime!)})';
    }

    final androidDetails = AndroidNotificationDetails(
      'pomodoro_timer_channel_v3',
      'Pomodoro Active Timer',
      channelDescription: 'Real-time countdown for running Pomodoro sessions',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: true,
      when: endTimestamp,
      usesChronometer: true,
      chronometerCountDown: true,
      visibility: NotificationVisibility.public,
      icon: 'ic_timer',
      playSound: false,
      enableVibration: false,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'pause_pomodoro',
          'Pause',
          icon: DrawableResourceAndroidBitmap('ic_pause'),
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'cancel_pomodoro',
          'Cancel',
          icon: DrawableResourceAndroidBitmap('ic_cancel'),
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        8888,
        'Focusing: ${activity!.name}$startTimeFormatted',
        'Session is running in the background.',
        notificationDetails,
        payload: 'open_pomodoro',
      );

      // Schedule the one-shot completion notification at the exact completion time
      await NotificationService.scheduleOneShotNotification(
        id: 8889,
        title: 'Session Completed! 🎉',
        body: 'Successfully completed focus session on "${activity!.name}".',
        dateTime: DateTime.now().add(Duration(seconds: secondsRemaining)),
        skipPermissionCheck: true,
      );
    } catch (e) {
      debugPrint('Error showing background notifications: $e');
    }
  }

  void _cancelBackgroundNotifications() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(8888);
      await flutterLocalNotificationsPlugin.cancel(8889);
    } catch (e) {
      debugPrint('Error cancelling background notifications: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (activity != null) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _showBackgroundNotifications();
      } else if (state == AppLifecycleState.resumed) {
        _cancelBackgroundNotifications();
        
        final activeSession = await CacheService().getActivePomodoroSession();
        if (activeSession != null) {
          final isRunning = activeSession['isRunning'] as bool? ?? false;
          final endTimestamp = activeSession['endTimestamp'] as int? ?? 0;
          final savedSeconds = activeSession['secondsRemaining'] as int? ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          this.isRunning = isRunning;
          isRunningNotifier.value = isRunning;
          if (this.isRunning) {
            final remaining = ((endTimestamp - now) / 1000).round();
            secondsRemaining = remaining;
            secondsNotifier.value = remaining;
            if (secondsRemaining <= 0) {
              secondsRemaining = 0;
              secondsNotifier.value = 0;
              this.isRunning = false;
              isRunningNotifier.value = false;
              _timer?.cancel();
              _handleSessionComplete();
            } else {
              _timer?.cancel();
              _startTimer();
            }
          } else {
            secondsRemaining = savedSeconds;
            secondsNotifier.value = savedSeconds;
            _timer?.cancel();
          }
        }
      }
    }
  }
}
