import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_payload.dart';
import '../models/notification_settings.dart';
import 'notification_coordinator.dart';

/// Thin wrapper over `flutter_local_notifications` that owns plugin
/// initialization, Android permission negotiation, timezone resolution,
/// and production recurring schedules.
///
/// All methods are defensive: a missing plugin (tests, unsupported platforms)
/// must never crash the app, so failures are swallowed, logged via
/// [debugPrint] and surfaced safely.
class NotificationService {
  /// Enforces that no reminders are scheduled before 4:00 AM.
  static const int minNotificationHour = 4;

  /// Interval boundaries in minutes for recurring same-day reminders.
  static const int minIntervalMinutes = 90;
  static const int maxIntervalMinutes = 120;

  /// Returns a random interval in minutes between 90 and 120 (inclusive).
  static int getNextIntervalMinutes([Random? random]) {
    final r = random ?? Random();
    return minIntervalMinutes + r.nextInt(maxIntervalMinutes - minIntervalMinutes + 1);
  }

  static const String _courseChannelId = 'study_course_channel';
  static const String _courseChannelName = 'Study Reminders';
  static const String _courseChannelDescription =
      'Daily alerts to keep up with active course study.';

  static const String _streakChannelId = 'study_streak_channel';
  static const String _streakChannelName = 'Streak Saver';
  static const String _streakChannelDescription =
      'Reminders to protect your study streak before the day ends.';

  static const String _revisionChannelId = 'study_revision_channel';
  static const String _revisionChannelName = 'Revision Reminders';
  static const String _revisionChannelDescription =
      'Reminders for modules due for spaced repetition today.';

  static const String _deadlineChannelId = 'study_deadline_channel';
  static const String _deadlineChannelName = 'Deadline Alerts';
  static const String _deadlineChannelDescription =
      'Alerts for course deadlines due today.';

  static const int morningBriefingNotificationId = 1000;
  static const int courseNotificationId = 1001;
  static const int streakNotificationId = 1002;
  static const int middayBoostNotificationId = 1003;
  static const int lastCallNotificationId = 1004;
  static const int revisionBaseNotificationId = 2000;
  static const int maxRevisionSlots = 20;
  static const int streakBaseNotificationId = 3000;
  static const int maxStreakSlots = 10;
  static const int deadlineBaseNotificationId = 4000;
  static const int maxDeadlineSlots = 10;
  static const int studySlotBaseId = 5000;
  static const int maxStudySlots = 10;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<NotificationPayload> _payloadStreamController =
      StreamController<NotificationPayload>.broadcast();

  /// Stream of notification tap payloads for deep-linking.
  Stream<NotificationPayload> get onPayloadTapped =>
      _payloadStreamController.stream;

  AndroidFlutterLocalNotificationsPlugin? _android;
  Future<void>? _initFuture;
  bool _isRequestingPermission = false;

  void _onNotificationResponse(NotificationResponse response) {
    final payload = NotificationPayload.fromJson(response.payload);
    if (payload != null) {
      _payloadStreamController.add(payload);
    }
  }

  /// Inspects launch details when the app was launched directly by tapping a notification.
  Future<NotificationPayload?> getLaunchPayload() async {
    try {
      await init();
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final raw = details.notificationResponse?.payload;
        return NotificationPayload.fromJson(raw);
      }
    } catch (e) {
      debugPrint('NotificationService getLaunchPayload error: $e');
    }
    return null;
  }

  static const NotificationDetails _courseDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _courseChannelId,
      _courseChannelName,
      channelDescription: _courseChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static const NotificationDetails _streakDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _streakChannelId,
      _streakChannelName,
      channelDescription: _streakChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static const NotificationDetails _revisionDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _revisionChannelId,
      _revisionChannelName,
      channelDescription: _revisionChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  static const NotificationDetails _deadlineDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _deadlineChannelId,
      _deadlineChannelName,
      channelDescription: _deadlineChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    ),
  );

  /// Whether [init] has already completed successfully.
  bool get isInitialized => _initFuture != null;

  /// Initializes the plugin exactly once, no matter how many callers race in.
  ///
  /// Safe to call from `main()` and again lazily before any delivery call.
  Future<void> init() {
    return _initFuture ??= _doInit().catchError((Object error, StackTrace stack) {
      // Allow a later retry: a transient failure should not poison the app.
      _initFuture = null;
      debugPrint('NotificationService init error: $error\n$stack');
    });
  }

  Future<void> _doInit() async {
    await _initializeTimeZone();

    _android = _resolveAndroid();

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android = _android ??= _resolveAndroid();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _courseChannelId,
          _courseChannelName,
          description: _courseChannelDescription,
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _streakChannelId,
          _streakChannelName,
          description: _streakChannelDescription,
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _revisionChannelId,
          _revisionChannelName,
          description: _revisionChannelDescription,
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _deadlineChannelId,
          _deadlineChannelName,
          description: _deadlineChannelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  AndroidFlutterLocalNotificationsPlugin? _resolveAndroid() {
    try {
      return _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
    } catch (error) {
      debugPrint('NotificationService resolvePlatform error: $error');
      return null;
    }
  }

  /// Initializes the timezone database and pins the local location to the
  /// first zone matching the device's current UTC offset.
  ///
  /// Falls back to UTC so scheduling still functions (offset-accurately) rather
  /// than throwing on devices with an unusual offset.
  static Future<void> _initializeTimeZone() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_detectTimeZoneName()));
    } catch (error) {
      debugPrint('NotificationService _initializeTimeZone error: $error');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (fallbackError) {
        debugPrint('NotificationService UTC fallback error: $fallbackError');
      }
    }
  }

  static String _detectTimeZoneName() {
    final offset = DateTime.now().timeZoneOffset;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      try {
        if (tz.getLocation(name).timeZone(nowMs).offset.inMilliseconds ==
            offset.inMilliseconds) {
          return name;
        }
      } catch (_) {
        continue;
      }
    }
    return 'UTC';
  }

  /// Requests the Android 13+ `POST_NOTIFICATIONS` permission.
  ///
  /// Returns `true` when notifications may be posted. Re-entrant calls return
  /// `false` so a double tap cannot open two system dialogs.
  Future<bool> requestPermission() async {
    if (_isRequestingPermission) return false;
    _isRequestingPermission = true;
    try {
      await init();
      final android = _android ??= _resolveAndroid();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (error, stack) {
      debugPrint('NotificationService requestPermission error: $error\n$stack');
      return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  static Future<bool> _canScheduleExact(
      AndroidFlutterLocalNotificationsPlugin? android) async {
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (error) {
      debugPrint('NotificationService canScheduleExactNotifications error: $error');
      return false;
    }
  }

  /// Generates pseudo-random reminder slots spaced 90–120 minutes apart
  /// starting from 4:00 AM up to 10:00 PM (22:00) on the current calendar day.
  ///
  /// Uses a seed based on the date and [salt] so slots are consistent across
  /// repeated syncs on the same day, while varying each day.
  static List<tz.TZDateTime> _generateRandomDaySlots({
    required tz.TZDateTime now,
    int salt = 0,
  }) {
    final seed = now.year * 10000 + now.month * 100 + now.day + salt;
    final random = Random(seed);

    final slots = <tz.TZDateTime>[];
    tz.TZDateTime current = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minNotificationHour, // 4:00 AM
      0,
    );

    final endOfDay = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22, // 10:00 PM
      0,
    );

    // Initial 4:00 AM slot
    slots.add(current);

    while (true) {
      // Random gap between 90 and 120 minutes (inclusive)
      final gapMinutes = getNextIntervalMinutes(random);
      current = current.add(Duration(minutes: gapMinutes));
      if (current.isAfter(endOfDay)) break;
      slots.add(current);
    }

    return slots;
  }

  /// Calculates the next instance of a daily time, enforcing that no
  /// notification can ever be scheduled earlier than 4:00 AM.
  static tz.TZDateTime _nextInstanceOfDailyTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // All notifications must start from 4 AM onwards
    final int hour = time.hour < minNotificationHour ? minNotificationHour : time.hour;
    final int minute = time.hour < minNotificationHour ? 0 : time.minute;

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedules the recurring daily course study reminder at [time] (starting from 4 AM minimum).
  Future<void> scheduleDailyCourseReminder({
    required TimeOfDay time,
    String title = 'Study Time 📚',
    String body = 'Take some time to continue your course modules today!',
  }) async {
    try {
      await init();
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final scheduled = _nextInstanceOfDailyTime(time);

      await _plugin.zonedSchedule(
        id: courseNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _courseDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'course_due_daily',
      );
      debugPrint('NotificationService: Scheduled daily course reminder at ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')}');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleDailyCourseReminder error: $e\n$stack');
    }
  }

  /// Cancels the daily course study reminder.
  Future<void> cancelCourseReminder() async {
    try {
      await init();
      await _plugin.cancel(id: courseNotificationId);
    } catch (e) {
      debugPrint('NotificationService cancelCourseReminder error: $e');
    }
  }

  /// Schedules streak reminders for today when study has not been logged.
  ///
  /// Reminders repeat at random 90–120 minute intervals starting from 4:00 AM up to 10:00 PM (22:00) today.
  Future<void> scheduleStreakRemindersForToday() async {
    try {
      await init();
      await cancelAllStreakReminders();
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final now = tz.TZDateTime.now(tz.local);
      final slots = _generateRandomDaySlots(now: now, salt: 202);

      int slotIndex = 0;
      for (final slotTime in slots) {
        if (slotIndex >= maxStreakSlots) break;
        if (slotTime.isAfter(now)) {
          final isEvening = slotTime.hour >= 19;
          final title = isEvening
              ? 'Protect Your Streak Tonight! 🔥'
              : 'Keep Your Study Streak Alive! 🔥';
          final body = isEvening
              ? 'You haven\'t logged any study sessions today. Save your streak before the day ends!'
              : 'Don\'t break the chain! Complete a quick topic or revision to keep your streak going.';

          await _plugin.zonedSchedule(
            id: streakBaseNotificationId + slotIndex,
            title: title,
            body: body,
            scheduledDate: slotTime,
            notificationDetails: _streakDetails,
            androidScheduleMode: scheduleMode,
            payload: 'streak_saver_reminder',
          );
          slotIndex++;
        }
      }
      debugPrint('NotificationService: Scheduled $slotIndex streak saver reminder slots for today (random 90–120 min gap from 4 AM)');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleStreakRemindersForToday error: $e\n$stack');
    }
  }

  /// Cancels all scheduled streak saver reminders.
  Future<void> cancelAllStreakReminders() async {
    try {
      await init();
      await Future.wait([
        _plugin.cancel(id: streakNotificationId),
        for (int i = 0; i < maxStreakSlots; i++)
          _plugin.cancel(id: streakBaseNotificationId + i),
      ]);
      debugPrint('NotificationService: Cancelled all streak saver reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelAllStreakReminders error: $e');
    }
  }

  /// Cancels the daily streak saver reminder.
  Future<void> cancelStreakReminder() async => cancelAllStreakReminders();

  /// Schedules reminder notifications throughout the CURRENT DAY ONLY for modules and topics due for revision today.
  ///
  /// Reminders start from 4:00 AM and repeat at random 90–120 minute intervals up to 10:00 PM (22:00) today.
  Future<void> scheduleRevisionRemindersForToday({
    required int dueCount,
    List<String> moduleTitles = const [],
    List<String> topicTitles = const [],
  }) async {
    try {
      await init();
      // Always cancel existing revision slots for today first
      await cancelAllRevisionReminders();

      if (dueCount <= 0) return;
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final now = tz.TZDateTime.now(tz.local);
      final slots = _generateRandomDaySlots(now: now, salt: 101);

      int slotIndex = 0;
      for (final slotTime in slots) {
        if (slotIndex >= maxRevisionSlots) break;
        if (slotTime.isAfter(now)) {
          final id = revisionBaseNotificationId + slotIndex;
          final String body;
          if (topicTitles.isNotEmpty && moduleTitles.isNotEmpty) {
            body = 'Revision due today: ${topicTitles.length} topic(s) and ${moduleTitles.length} module(s). Don\'t forget spaced repetition!';
          } else if (topicTitles.isNotEmpty) {
            final desc = topicTitles.length == 1
                ? '"${topicTitles.first}"'
                : '"${topicTitles.first}" and ${topicTitles.length - 1} other(s)';
            body = 'Topic revision due today for $desc. Lock in your spaced repetition memory!';
          } else if (moduleTitles.isNotEmpty) {
            final desc = moduleTitles.length == 1
                ? '"${moduleTitles.first}"'
                : '"${moduleTitles.first}" and ${moduleTitles.length - 1} other(s)';
            body = 'Revision due today for $desc. Don\'t forget spaced repetition!';
          } else {
            body = '$dueCount revision item(s) due for spaced repetition today.';
          }

          await _plugin.zonedSchedule(
            id: id,
            title: 'Revision Due Today 🧠',
            body: body,
            scheduledDate: slotTime,
            notificationDetails: _revisionDetails,
            androidScheduleMode: scheduleMode,
            payload: 'revision_due_today',
          );
          slotIndex++;
        }
      }
      debugPrint('NotificationService: Scheduled $slotIndex revision reminder slots for today (random 90–120 min gap from 4 AM)');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleRevisionRemindersForToday error: $e\n$stack');
    }
  }

  /// Cancels all scheduled revision reminder slots for the current day.
  Future<void> cancelAllRevisionReminders() async {
    try {
      await init();
      await Future.wait([
        for (int i = 0; i < maxRevisionSlots; i++)
          _plugin.cancel(id: revisionBaseNotificationId + i),
      ]);
    } catch (e) {
      debugPrint('NotificationService cancelAllRevisionReminders error: $e');
    }
  }

  /// Schedules deadline reminder notifications throughout the CURRENT DAY ONLY for courses with a deadline today.
  ///
  /// Reminders start from 4:00 AM and repeat at random 90–120 minute intervals up to 10:00 PM (22:00) today.
  Future<void> scheduleDeadlineRemindersForToday({
    required List<String> courseTitles,
  }) async {
    try {
      await init();
      await cancelAllDeadlineReminders();

      if (courseTitles.isEmpty) return;
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final now = tz.TZDateTime.now(tz.local);
      final slots = _generateRandomDaySlots(now: now, salt: 303);

      int slotIndex = 0;
      for (final slotTime in slots) {
        if (slotIndex >= maxDeadlineSlots) break;
        if (slotTime.isAfter(now)) {
          final id = deadlineBaseNotificationId + slotIndex;
          final titleDesc = courseTitles.length == 1
              ? '"${courseTitles.first}"'
              : '"${courseTitles.first}" and ${courseTitles.length - 1} other(s)';

          await _plugin.zonedSchedule(
            id: id,
            title: 'Deadline Today! ⚠️',
            body: 'Target deadline for $titleDesc is today. Stay focused and finish on time!',
            scheduledDate: slotTime,
            notificationDetails: _deadlineDetails,
            androidScheduleMode: scheduleMode,
            payload: 'deadline_due_today',
          );
          slotIndex++;
        }
      }
      debugPrint('NotificationService: Scheduled $slotIndex deadline reminder slots for today (random 90–120 min gap from 4 AM)');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleDeadlineRemindersForToday error: $e\n$stack');
    }
  }

  /// Cancels all scheduled deadline reminders.
  Future<void> cancelAllDeadlineReminders() async {
    try {
      await init();
      await Future.wait([
        for (int i = 0; i < maxDeadlineSlots; i++)
          _plugin.cancel(id: deadlineBaseNotificationId + i),
      ]);
      debugPrint('NotificationService: Cancelled all deadline reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelAllDeadlineReminders error: $e');
    }
  }

  /// Schedules the single-pass coordinated plan computed by [NotificationCoordinator].
  Future<void> scheduleCoordinatedPlan(List<CoordinatedNotification> plan) async {
    try {
      await init();
      // Cancel previous coordinated notification IDs
      await Future.wait([
        _plugin.cancel(id: morningBriefingNotificationId),
        _plugin.cancel(id: streakNotificationId),
        _plugin.cancel(id: middayBoostNotificationId),
        _plugin.cancel(id: lastCallNotificationId),
        _plugin.cancel(id: deadlineBaseNotificationId),
        for (int i = 0; i < maxStreakSlots; i++)
          _plugin.cancel(id: streakBaseNotificationId + i),
        for (int i = 0; i < maxRevisionSlots; i++)
          _plugin.cancel(id: revisionBaseNotificationId + i),
      ]);

      if (plan.isEmpty) return;
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      for (final alert in plan) {
        final NotificationDetails details;
        switch (alert.channelId) {
          case NotificationCoordinator.revisionChannelId:
            details = _revisionDetails;
            break;
          case NotificationCoordinator.streakChannelId:
            details = _streakDetails;
            break;
          case NotificationCoordinator.deadlineChannelId:
            details = _deadlineDetails;
            break;
          default:
            details = _courseDetails;
        }

        await _plugin.zonedSchedule(
          id: alert.id,
          title: alert.title,
          body: alert.body,
          scheduledDate: alert.scheduledTime,
          notificationDetails: details,
          androidScheduleMode: scheduleMode,
          payload: alert.payload.toJson(),
        );
        debugPrint(
            'NotificationService: Scheduled coordinated alert "${alert.title}" [ID: ${alert.id}] at ${alert.scheduledTime}');
      }
    } catch (e, stack) {
      debugPrint('NotificationService scheduleCoordinatedPlan error: $e\n$stack');
    }
  }

  /// Schedules daily study reminders for each active slot configured by the user.
  Future<void> scheduleStudyReminderSlots({
    required List<StudyReminderSlot> slots,
  }) async {
    try {
      await init();
      await cancelStudyReminderSlots();

      final activeSlots = slots.where((s) => s.isEnabled).toList();
      if (activeSlots.isEmpty) return;
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      for (int i = 0; i < activeSlots.length && i < maxStudySlots; i++) {
        final slot = activeSlots[i];
        final scheduled = _nextInstanceOfDailyTime(slot.time);
        final payload = NotificationPayload.morningBriefing().toJson();

        await _plugin.zonedSchedule(
          id: studySlotBaseId + i,
          title: '${slot.title} 📚',
          body: 'Take some time to continue your course modules today!',
          scheduledDate: scheduled,
          notificationDetails: _courseDetails,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        debugPrint(
            'NotificationService: Scheduled study slot "${slot.title}" at ${slot.time.hour}:${slot.time.minute.toString().padLeft(2, '0')}');
      }
    } catch (e, stack) {
      debugPrint('NotificationService scheduleStudyReminderSlots error: $e\n$stack');
    }
  }

  /// Cancels all scheduled user study reminder slots.
  Future<void> cancelStudyReminderSlots() async {
    try {
      await init();
      await Future.wait([
        for (int i = 0; i < maxStudySlots; i++)
          _plugin.cancel(id: studySlotBaseId + i),
      ]);
    } catch (e) {
      debugPrint('NotificationService cancelStudyReminderSlots error: $e');
    }
  }

  /// Real-time cancellation hook: immediately cancels streak saver and last call alerts
  /// as soon as study activity or a revision is logged today.
  Future<void> cancelStreakAndLastCall() async {
    try {
      await init();
      await Future.wait([
        _plugin.cancel(id: streakNotificationId),
        _plugin.cancel(id: lastCallNotificationId),
        for (int i = 0; i < maxStreakSlots; i++)
          _plugin.cancel(id: streakBaseNotificationId + i),
      ]);
      debugPrint('NotificationService: Cancelled streak saver and last call alerts.');
    } catch (e) {
      debugPrint('NotificationService cancelStreakAndLastCall error: $e');
    }
  }

  static const int todoBaseNotificationId = 5000;

  /// Schedules an explicit reminder alert for a task.
  Future<void> scheduleTodoReminder({
    required String todoId,
    required String title,
    required DateTime reminderTime,
  }) async {
    try {
      if (reminderTime.isBefore(DateTime.now())) return;
      await init();
      if (!await requestPermission()) return;

      final android = _android ??= _resolveAndroid();
      final canExact = await _canScheduleExact(android);
      final scheduleMode = canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final alertId = todoBaseNotificationId + (todoId.hashCode.abs() % 4000);
      final tzScheduled = tz.TZDateTime.from(reminderTime, tz.local);
      final payload = const NotificationPayload(action: 'open_todo', tabIndex: 1).toJson();

      await _plugin.zonedSchedule(
        id: alertId,
        title: 'Task Reminder ⏰',
        body: title,
        scheduledDate: tzScheduled,
        notificationDetails: _deadlineDetails,
        androidScheduleMode: scheduleMode,
        payload: payload,
      );
      debugPrint('NotificationService: Scheduled todo reminder for "$title" at $reminderTime');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleTodoReminder error: $e\n$stack');
    }
  }

  /// Cancels an explicit reminder alert for a task.
  Future<void> cancelTodoReminder(String todoId) async {
    try {
      await init();
      final alertId = todoBaseNotificationId + (todoId.hashCode.abs() % 4000);
      await _plugin.cancel(id: alertId);
      debugPrint('NotificationService: Cancelled todo reminder for task $todoId');
    } catch (e) {
      debugPrint('NotificationService cancelTodoReminder error: $e');
    }
  }

  /// Cancels all production reminders (Course, Streak, Revisions, Deadlines, and Tiers).
  Future<void> cancelAllReminders() async {
    try {
      await init();
      await cancelCourseReminder();
      await cancelStudyReminderSlots();
      await cancelStreakReminder();
      await cancelStreakAndLastCall();
      await cancelAllRevisionReminders();
      await cancelAllDeadlineReminders();
      await _plugin.cancel(id: morningBriefingNotificationId);
      await _plugin.cancel(id: middayBoostNotificationId);
      debugPrint('NotificationService: Cancelled all production reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelAllReminders error: $e');
    }
  }
}