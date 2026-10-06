import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../services/local_notification_storage.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import 'revision_controller.dart';
import 'ongoing_modules_controller.dart';
import 'courses_controller.dart';

/// Controller managing user notification preferences and schedules.
/// Adheres strictly to the ChangeNotifier pattern without external state dependencies.
/// Synchronizes alarms across Course Study, Streak Saver, Revision, and Deadline schedules.
class NotificationController extends ChangeNotifier {
  final NotificationService _notificationService;
  final RevisionController? _revisionController;
  final OngoingModulesController? _ongoingController;
  final CoursesController? _coursesController;

  NotificationSettings _settings = const NotificationSettings();
  bool _isLoading = true;

  NotificationController({
    NotificationService? notificationService,
    RevisionController? revisionController,
    OngoingModulesController? ongoingController,
    CoursesController? coursesController,
  })  : _notificationService = notificationService ?? getIt<NotificationService>(),
        _revisionController = revisionController ??
            (getIt.isRegistered<RevisionController>()
                ? getIt<RevisionController>()
                : null),
        _ongoingController = ongoingController ??
            (getIt.isRegistered<OngoingModulesController>()
                ? getIt<OngoingModulesController>()
                : null),
        _coursesController = coursesController ??
            (getIt.isRegistered<CoursesController>()
                ? getIt<CoursesController>()
                : null) {
    _revisionController?.addListener(_onRevisionChanged);
    _ongoingController?.addListener(_onOngoingChanged);
    _coursesController?.addListener(_onCoursesChanged);
    _load();
  }

  @override
  void dispose() {
    _revisionController?.removeListener(_onRevisionChanged);
    _ongoingController?.removeListener(_onOngoingChanged);
    _coursesController?.removeListener(_onCoursesChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (_settings.enabled && _settings.revisionDueEnabled) {
      unawaited(syncRevisionReminders());
    }
  }

  void _onOngoingChanged() {
    if (_settings.enabled && _settings.streakSaverEnabled) {
      unawaited(syncStreakSaverReminders());
    }
  }

  void _onCoursesChanged() {
    if (_settings.enabled && _settings.deadlineEnabled) {
      unawaited(syncDeadlineReminders());
    }
  }

  NotificationSettings get settings => _settings;
  bool get isLoading => _isLoading;

  bool get enabled => _settings.enabled;
  int get repeatIntervalHours => _settings.repeatIntervalHours;
  int get revisionIntervalHours => _settings.repeatIntervalHours;
  bool get revisionDueEnabled => _settings.revisionDueEnabled;
  TimeOfDay get revisionDueTime => _settings.revisionDueTime;
  bool get courseDueEnabled => _settings.courseDueEnabled;
  TimeOfDay get courseDueTime => _settings.courseDueTime;
  bool get streakSaverEnabled => _settings.streakSaverEnabled;
  TimeOfDay get streakSaverTime => _settings.streakSaverTime;
  bool get deadlineEnabled => _settings.deadlineEnabled;
  int get deadlineDaysBefore => _settings.deadlineDaysBefore;

  /// Enforces that notification times start at 4:00 AM onwards.
  static TimeOfDay _clampTo4Am(TimeOfDay time) {
    if (time.hour < NotificationService.minNotificationHour) {
      return const TimeOfDay(hour: NotificationService.minNotificationHour, minute: 0);
    }
    return time;
  }

  Future<void> _load() async {
    _settings = await LocalNotificationStorage.loadSettings();
    _isLoading = false;
    notifyListeners();
    unawaited(syncAllNotifications());
  }

  Future<void> _update(NotificationSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    unawaited(LocalNotificationStorage.saveSettings(_settings));
    unawaited(syncAllNotifications());
  }

  /// Synchronizes all native notification schedules based on current settings and today's status.
  Future<void> syncAllNotifications() async {
    if (!_settings.enabled) {
      await _notificationService.cancelAllReminders();
      return;
    }

    // 1. Course Study reminder (daily repeating)
    if (_settings.courseDueEnabled) {
      await _notificationService.scheduleDailyCourseReminder(
        time: _clampTo4Am(_settings.courseDueTime),
      );
    } else {
      await _notificationService.cancelCourseReminder();
    }

    // 2. Streak Saver reminder (every repeatIntervalHours from 4 AM if study not logged today, including evening alert)
    if (_settings.streakSaverEnabled) {
      await syncStreakSaverReminders();
    } else {
      await _notificationService.cancelAllStreakReminders();
    }

    // 3. Revision reminders for current day (every repeatIntervalHours from 4 AM)
    if (_settings.revisionDueEnabled) {
      await syncRevisionReminders();
    } else {
      await _notificationService.cancelAllRevisionReminders();
    }

    // 4. On Current Date Deadline alerts (every repeatIntervalHours from 4 AM)
    if (_settings.deadlineEnabled) {
      await syncDeadlineReminders();
    } else {
      await _notificationService.cancelAllDeadlineReminders();
    }
  }

  /// Evaluates today's study progress. If no topic or revision has been logged today,
  /// schedules streak reminder notifications spaced random 90–120 minutes starting from 4:00 AM.
  /// If study was already logged today, cancels all streak reminders.
  Future<void> syncStreakSaverReminders() async {
    if (!_settings.enabled || !_settings.streakSaverEnabled) {
      await _notificationService.cancelAllStreakReminders();
      return;
    }

    final ongoingCtrl = _ongoingController ??
        (getIt.isRegistered<OngoingModulesController>()
            ? getIt<OngoingModulesController>()
            : null);

    final hasStudiedToday = (ongoingCtrl?.completedTodayCount ?? 0) > 0;
    if (hasStudiedToday) {
      // User has already studied today -> streak is safe, cancel alerts for today
      await _notificationService.cancelAllStreakReminders();
      return;
    }

    // User forgot / has not completed any study today -> schedule 90-120 min gap reminders from 4 AM
    await _notificationService.scheduleStreakRemindersForToday();
  }

  /// Evaluates modules due for revision today and schedules interval reminders for the current day.
  Future<void> syncRevisionReminders() async {
    if (!_settings.enabled || !_settings.revisionDueEnabled) {
      await _notificationService.cancelAllRevisionReminders();
      return;
    }

    final revCtrl = _revisionController ??
        (getIt.isRegistered<RevisionController>()
            ? getIt<RevisionController>()
            : null);

    if (revCtrl == null) return;

    final dueToday = revCtrl.revisionsDueToday;
    final titles = revCtrl.moduleTitlesDueToday;

    // By default, revision reminders start from 4:00 AM onwards for the current day
    await _notificationService.scheduleRevisionRemindersForToday(
      dueCount: dueToday.length,
      moduleTitles: titles,
    );
  }

  /// Evaluates active courses with deadlines on the current date and schedules interval reminders.
  Future<void> syncDeadlineReminders() async {
    if (!_settings.enabled || !_settings.deadlineEnabled) {
      await _notificationService.cancelAllDeadlineReminders();
      return;
    }

    final coursesCtrl = _coursesController ??
        (getIt.isRegistered<CoursesController>()
            ? getIt<CoursesController>()
            : null);

    if (coursesCtrl == null) return;

    final now = DateTime.now();
    final coursesDueToday = coursesCtrl.courses.where((c) {
      if (c.isArchived || c.isCompleted || c.deadline == null) return false;
      final d = c.deadline!;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    if (coursesDueToday.isEmpty) {
      await _notificationService.cancelAllDeadlineReminders();
      return;
    }

    final titles = coursesDueToday.map((c) => c.title).toList();
    await _notificationService.scheduleDeadlineRemindersForToday(
      courseTitles: titles,
    );
  }

  Future<void> setMasterEnabled(bool value) async {
    if (_settings.enabled == value) return;
    await _update(_settings.copyWith(enabled: value));
  }

  Future<void> setRepeatIntervalHours(int hours) async {
    if (_settings.repeatIntervalHours == hours) return;
    await _update(_settings.copyWith(repeatIntervalHours: hours));
  }

  Future<void> setRevisionDue(bool value) async {
    if (_settings.revisionDueEnabled == value) return;
    await _update(_settings.copyWith(revisionDueEnabled: value));
  }

  Future<void> setRevisionIntervalHours(int hours) => setRepeatIntervalHours(hours);

  Future<void> setRevisionDueTime(TimeOfDay time) async {
    final clamped = _clampTo4Am(time);
    if (_settings.revisionDueTime == clamped) return;
    await _update(_settings.copyWith(revisionDueTime: clamped));
  }

  Future<void> setCourseDue(bool value) async {
    if (_settings.courseDueEnabled == value) return;
    await _update(_settings.copyWith(courseDueEnabled: value));
  }

  Future<void> setCourseDueTime(TimeOfDay time) async {
    final clamped = _clampTo4Am(time);
    if (_settings.courseDueTime == clamped) return;
    await _update(_settings.copyWith(courseDueTime: clamped));
  }

  Future<void> setStreakSaver(bool value) async {
    if (_settings.streakSaverEnabled == value) return;
    await _update(_settings.copyWith(streakSaverEnabled: value));
  }

  Future<void> setStreakSaverTime(TimeOfDay time) async {
    final clamped = _clampTo4Am(time);
    if (_settings.streakSaverTime == clamped) return;
    await _update(_settings.copyWith(streakSaverTime: clamped));
  }

  Future<void> setDeadlineEnabled(bool value) async {
    if (_settings.deadlineEnabled == value) return;
    await _update(_settings.copyWith(deadlineEnabled: value));
  }

  Future<void> setDeadlineDaysBefore(int days) async {
    if (_settings.deadlineDaysBefore == days) return;
    await _update(_settings.copyWith(deadlineDaysBefore: days));
  }
}
