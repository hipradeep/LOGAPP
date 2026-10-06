import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../services/local_notification_storage.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import 'revision_controller.dart';
import 'ongoing_modules_controller.dart';

/// Controller managing user notification preferences and schedules.
/// Adheres strictly to the ChangeNotifier pattern without external state dependencies.
class NotificationController extends ChangeNotifier {
  final NotificationService _notificationService;
  final RevisionController? _revisionController;
  final OngoingModulesController? _ongoingController;

  NotificationSettings _settings = const NotificationSettings();
  bool _isLoading = true;

  NotificationController({
    NotificationService? notificationService,
    RevisionController? revisionController,
    OngoingModulesController? ongoingController,
  })  : _notificationService = notificationService ?? getIt<NotificationService>(),
        _revisionController = revisionController ??
            (getIt.isRegistered<RevisionController>()
                ? getIt<RevisionController>()
                : null),
        _ongoingController = ongoingController ??
            (getIt.isRegistered<OngoingModulesController>()
                ? getIt<OngoingModulesController>()
                : null) {
    _revisionController?.addListener(_onRevisionChanged);
    _load();
  }

  @override
  void dispose() {
    _revisionController?.removeListener(_onRevisionChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (_settings.enabled && _settings.revisionDueEnabled) {
      unawaited(syncRevisionReminders());
    }
  }

  NotificationSettings get settings => _settings;
  bool get isLoading => _isLoading;

  bool get enabled => _settings.enabled;
  bool get revisionDueEnabled => _settings.revisionDueEnabled;
  int get revisionIntervalHours => _settings.revisionIntervalHours;
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

    // 2. Streak Saver reminder (daily repeating)
    if (_settings.streakSaverEnabled) {
      await _notificationService.scheduleDailyStreakReminder(
        time: _clampTo4Am(_settings.streakSaverTime),
      );
    } else {
      await _notificationService.cancelStreakReminder();
    }

    // 3. Revision reminders for current day
    if (_settings.revisionDueEnabled) {
      await syncRevisionReminders();
    } else {
      await _notificationService.cancelAllRevisionReminders();
    }
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

    await _notificationService.scheduleRevisionRemindersForToday(
      startTime: _clampTo4Am(_settings.revisionDueTime),
      intervalHours: _settings.revisionIntervalHours,
      dueCount: dueToday.length,
      moduleTitles: titles,
    );
  }

  Future<void> setMasterEnabled(bool value) async {
    if (_settings.enabled == value) return;
    await _update(_settings.copyWith(enabled: value));
  }

  Future<void> setRevisionDue(bool value) async {
    if (_settings.revisionDueEnabled == value) return;
    await _update(_settings.copyWith(revisionDueEnabled: value));
  }

  Future<void> setRevisionIntervalHours(int hours) async {
    if (_settings.revisionIntervalHours == hours) return;
    await _update(_settings.copyWith(revisionIntervalHours: hours));
  }

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
