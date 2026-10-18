import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/service_locator.dart';
import 'revision_controller.dart';
import 'topic_revision_controller.dart';
import 'ongoing_modules_controller.dart';
import 'courses_controller.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/notification_coordinator.dart';

/// Controller managing user notification preferences and schedules.
/// Adheres strictly to the ChangeNotifier pattern without external state dependencies.
/// Synchronizes alarms across Course Study, Streak Saver, Revision, and Deadline schedules.
class NotificationController extends ChangeNotifier {
  final NotificationService _notificationService;
  final RevisionController? _revisionController;
  final TopicRevisionController? _topicRevisionController;
  final OngoingModulesController? _ongoingController;
  final CoursesController? _coursesController;

  NotificationSettings _settings = const NotificationSettings();
  bool _isLoading = true;

  NotificationController({
    NotificationService? notificationService,
    RevisionController? revisionController,
    TopicRevisionController? topicRevisionController,
    OngoingModulesController? ongoingController,
    CoursesController? coursesController,
  })  : _notificationService = notificationService ?? getIt<NotificationService>(),
        _revisionController = revisionController ??
            (getIt.isRegistered<RevisionController>()
                ? getIt<RevisionController>()
                : null),
        _topicRevisionController = topicRevisionController ??
            (getIt.isRegistered<TopicRevisionController>()
                ? getIt<TopicRevisionController>()
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
    _topicRevisionController?.addListener(_onTopicRevisionChanged);
    _ongoingController?.addListener(_onOngoingChanged);
    _coursesController?.addListener(_onCoursesChanged);
    _load();
  }

  Timer? _debounceTimer;
  bool _isSyncing = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _revisionController?.removeListener(_onRevisionChanged);
    _topicRevisionController?.removeListener(_onTopicRevisionChanged);
    _ongoingController?.removeListener(_onOngoingChanged);
    _coursesController?.removeListener(_onCoursesChanged);
    super.dispose();
  }

  void _onRevisionChanged() {
    if (_settings.enabled) {
      final now = DateTime.now();
      final revisedToday = _revisionController?.revisions.any((r) =>
              DateUtils.isSameDay(r.lastRevisionAt ?? r.updatedAt, now)) ??
          false;
      if (revisedToday) {
        _notificationService.cancelStreakAndLastCall();
      }
      if (_settings.revisionDueEnabled) {
        _scheduleDebouncedSync();
      }
    }
  }

  void _onTopicRevisionChanged() {
    if (_settings.enabled) {
      final now = DateTime.now();
      final revisedToday = _topicRevisionController?.topicRevisions.any((tr) =>
              (tr.isLevelCompleted || tr.isFinished) &&
              DateUtils.isSameDay(tr.updatedAt, now)) ??
          false;
      if (revisedToday) {
        _notificationService.cancelStreakAndLastCall();
      }
      if (_settings.revisionDueEnabled) {
        _scheduleDebouncedSync();
      }
    }
  }

  void _onOngoingChanged() {
    if (_settings.enabled) {
      final completed = (_ongoingController?.completedTodayCount ?? 0) > 0;
      if (completed) {
        _notificationService.cancelStreakAndLastCall();
      }
      if (_settings.streakSaverEnabled) {
        _scheduleDebouncedSync();
      }
    }
  }

  void _onCoursesChanged() {
    if (_settings.enabled && _settings.deadlineEnabled) {
      _scheduleDebouncedSync();
    }
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      syncAllNotifications();
    });
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
    final settings = await DatabaseService.instance.getNotificationSettings();
    _settings = settings ?? const NotificationSettings();
    _isLoading = false;
    notifyListeners();
    _scheduleDebouncedSync();
  }

  Future<void> _update(NotificationSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();
    unawaited(DatabaseService.instance.saveNotificationSettings(_settings));
    _scheduleDebouncedSync();
  }

  /// Synchronizes all native notification schedules based on current settings and today's status.
  Future<void> syncAllNotifications() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      if (!_settings.enabled) {
        await _notificationService.cancelAllReminders();
        return;
      }

      final ongoingCtrl = _ongoingController ??
          (getIt.isRegistered<OngoingModulesController>()
              ? getIt<OngoingModulesController>()
              : null);
      final topicRevCtrl = _topicRevisionController ??
          (getIt.isRegistered<TopicRevisionController>()
              ? getIt<TopicRevisionController>()
              : null);
      final revCtrl = _revisionController ??
          (getIt.isRegistered<RevisionController>()
              ? getIt<RevisionController>()
              : null);
      final coursesCtrl = _coursesController ??
          (getIt.isRegistered<CoursesController>()
              ? getIt<CoursesController>()
              : null);

      final completedTopicsToday = (ongoingCtrl?.completedTodayCount ?? 0) > 0;
      final now = DateTime.now();
      final hasRevisedTopicToday = topicRevCtrl?.topicRevisions.any((tr) =>
              (tr.isLevelCompleted || tr.isFinished) &&
              DateUtils.isSameDay(tr.updatedAt, now)) ??
          false;
      final hasRevisedModuleToday = revCtrl?.revisions.any((r) =>
              DateUtils.isSameDay(r.lastRevisionAt ?? r.updatedAt, now)) ??
          false;

      final hasStudiedToday =
          completedTopicsToday || hasRevisedTopicToday || hasRevisedModuleToday;

      final dueTopics = topicRevCtrl?.topicsDueToday ?? const [];
      final dueModules = revCtrl?.revisionsDueToday ?? const [];

      final deadlineCourses = (coursesCtrl?.courses ?? const []).where((c) {
        if (c.isArchived || c.isCompleted || c.deadline == null) return false;
        final d = c.deadline!;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      final currentStreak = ongoingCtrl?.dayStreakCount ?? 0;

      // 1. User-Configured Daily Study Reminder Slots
      if (_settings.courseDueEnabled) {
        await _notificationService.scheduleStudyReminderSlots(
          slots: _settings.studyReminderSlots,
        );
      } else {
        await _notificationService.cancelStudyReminderSlots();
      }

      // 2. Coordinated Ambient Notifications (Morning Briefing, Midday Boost, Streak Saver, Last Call, Deadlines)
      final tzNow = tz.TZDateTime.now(tz.local);
      final dailyPlan = NotificationCoordinator.buildDailyPlan(
        now: tzNow,
        dueTopics: dueTopics,
        dueModules: dueModules,
        deadlineCourses: deadlineCourses,
        hasStudiedToday: hasStudiedToday,
        currentStreak: currentStreak,
        settings: _settings,
      );

      await _notificationService.scheduleCoordinatedPlan(dailyPlan);
    } finally {
      _isSyncing = false;
    }
  }

  /// Real-time cancellation hook invoked as soon as user marks a topic or revision complete.
  Future<void> onStudyActivityLogged() async {
    await _notificationService.cancelStreakAndLastCall();
    _scheduleDebouncedSync();
  }

  /// Evaluates today's study progress across topics and revisions.
  /// If no topic or revision has been logged today, schedules streak reminder notifications.
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
    final topicRevCtrl = _topicRevisionController ??
        (getIt.isRegistered<TopicRevisionController>()
            ? getIt<TopicRevisionController>()
            : null);
    final revCtrl = _revisionController ??
        (getIt.isRegistered<RevisionController>()
            ? getIt<RevisionController>()
            : null);

    final completedTopicsToday = (ongoingCtrl?.completedTodayCount ?? 0) > 0;
    final now = DateTime.now();
    final hasRevisedTopicToday = topicRevCtrl?.topicRevisions.any((tr) =>
            (tr.isLevelCompleted || tr.isFinished) &&
            DateUtils.isSameDay(tr.updatedAt, now)) ??
        false;
    final hasRevisedModuleToday = revCtrl?.revisions.any((r) =>
            DateUtils.isSameDay(r.lastRevisionAt ?? r.updatedAt, now)) ??
        false;

    final hasStudiedToday =
        completedTopicsToday || hasRevisedTopicToday || hasRevisedModuleToday;

    if (hasStudiedToday) {
      // User has already studied today -> streak is safe, cancel alerts for today
      await _notificationService.cancelAllStreakReminders();
      return;
    }

    // User forgot / has not completed any study today -> schedule streak reminders
    await _notificationService.scheduleStreakRemindersForToday();
  }

  /// Evaluates both topics and modules due for revision today and schedules interval reminders.
  Future<void> syncRevisionReminders() async {
    if (!_settings.enabled || !_settings.revisionDueEnabled) {
      await _notificationService.cancelAllRevisionReminders();
      return;
    }

    final revCtrl = _revisionController ??
        (getIt.isRegistered<RevisionController>()
            ? getIt<RevisionController>()
            : null);
    final topicRevCtrl = _topicRevisionController ??
        (getIt.isRegistered<TopicRevisionController>()
            ? getIt<TopicRevisionController>()
            : null);

    final dueModules = revCtrl?.revisionsDueToday ?? const [];
    final moduleTitles = revCtrl?.moduleTitlesDueToday ?? const [];

    final dueTopics = topicRevCtrl?.topicsDueToday ?? const [];
    final topicTitles = dueTopics.map((tr) => tr.title).toList();

    final totalDueCount = dueModules.length + dueTopics.length;

    // By default, revision reminders start from 4:00 AM onwards for the current day
    await _notificationService.scheduleRevisionRemindersForToday(
      dueCount: totalDueCount,
      moduleTitles: moduleTitles,
      topicTitles: topicTitles,
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

  bool get morningBriefingEnabled => _settings.morningBriefingEnabled;
  TimeOfDay get morningBriefingTime => _settings.morningBriefingTime;
  List<StudyReminderSlot> get studyReminderSlots => _settings.studyReminderSlots;

  Future<void> setMorningBriefing(bool value) async {
    if (_settings.morningBriefingEnabled == value) return;
    await _update(_settings.copyWith(morningBriefingEnabled: value));
  }

  Future<void> setMorningBriefingTime(TimeOfDay time) async {
    final clamped = _clampTo4Am(time);
    if (_settings.morningBriefingTime == clamped) return;
    await _update(_settings.copyWith(morningBriefingTime: clamped));
  }

  Future<void> addStudyReminderSlot({
    required String title,
    required TimeOfDay time,
  }) async {
    final newSlot = StudyReminderSlot(
      id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim().isEmpty ? 'Study Session' : title.trim(),
      time: time,
      isEnabled: true,
    );
    final updated = [..._settings.studyReminderSlots, newSlot];
    await _update(_settings.copyWith(studyReminderSlots: updated));
  }

  Future<void> updateStudyReminderSlot(StudyReminderSlot slot) async {
    final updated = _settings.studyReminderSlots.map((s) {
      return s.id == slot.id ? slot : s;
    }).toList();
    await _update(_settings.copyWith(studyReminderSlots: updated));
  }

  Future<void> toggleStudyReminderSlot(String id, bool isEnabled) async {
    final updated = _settings.studyReminderSlots.map((s) {
      return s.id == id ? s.copyWith(isEnabled: isEnabled) : s;
    }).toList();
    await _update(_settings.copyWith(studyReminderSlots: updated));
  }

  Future<void> deleteStudyReminderSlot(String id) async {
    final updated =
        _settings.studyReminderSlots.where((s) => s.id != id).toList();
    await _update(_settings.copyWith(studyReminderSlots: updated));
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
