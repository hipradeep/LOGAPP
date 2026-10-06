import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Outcome of attempting to deliver a test notification, so the UI can report
/// the real outcome instead of assuming success.
enum TestNotificationResult {
  /// Delivered immediately via `show()`.
  instantSent,

  /// Scheduled and will fire with exact timing.
  scheduledExact,

  /// Scheduled without exact-alarm permission; Android may batch and delay it.
  scheduledInexact,

  /// The user has not granted the Android 13+ notification permission.
  permissionDenied,

  /// The plugin or platform channel threw.
  failed,
}

/// Thin wrapper over `flutter_local_notifications` that owns plugin
/// initialization, Android permission negotiation, timezone resolution,
/// production recurring schedules, and test-notification delivery.
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

  static const String _testChannelId = 'study_test_channel';
  static const String _testChannelName = 'Test Notifications';
  static const String _testChannelDescription =
      'Diagnostics notifications used to verify reminder delivery.';

  static const int courseNotificationId = 1001;
  static const int streakNotificationId = 1002;
  static const int revisionBaseNotificationId = 2000;
  static const int maxRevisionSlots = 20;
  static const int streakBaseNotificationId = 3000;
  static const int maxStreakSlots = 10;
  static const int deadlineBaseNotificationId = 4000;
  static const int maxDeadlineSlots = 10;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? _android;
  Future<void>? _initFuture;
  bool _isRequestingPermission = false;

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

  static const NotificationDetails _testDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _testChannelId,
      _testChannelName,
      channelDescription: _testChannelDescription,
      importance: Importance.max,
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

    await _plugin.initialize(settings: settings);

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
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _testChannelId,
          _testChannelName,
          description: _testChannelDescription,
          importance: Importance.max,
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

  /// Posts a dummy notification immediately, requesting permission if needed.
  ///
  /// [id] is reused to replace any previously shown test notification instead
  /// of stacking duplicates.
  Future<TestNotificationResult> showInstantNotification({
    int id = 9999,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      if (!await requestPermission()) {
        return TestNotificationResult.permissionDenied;
      }

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _testDetails,
        payload: 'test_instant',
      );
      return TestNotificationResult.instantSent;
    } catch (error, stack) {
      debugPrint('NotificationService showInstantNotification error: $error\n$stack');
      return TestNotificationResult.failed;
    }
  }

  /// Schedules a dummy notification to fire after [delay].
  ///
  /// Uses exact timing when the `SCHEDULE_EXACT_ALARM` grant is held so the
  /// alarm actually lands on time; otherwise falls back to inexact mode, which
  /// Android is free to batch. The returned enum lets the caller surface that
  /// caveat rather than promising a precise fire time.
  Future<TestNotificationResult> scheduleTestNotification({
    int id = 9998,
    required String title,
    required String body,
    Duration delay = const Duration(seconds: 10),
  }) async {
    try {
      await init();
      if (!await requestPermission()) {
        return TestNotificationResult.permissionDenied;
      }

      final android = _android ??= _resolveAndroid();

      // Don't open the system alarm settings screen unprompted; just report
      // whether exact timing is available.
      final canScheduleExact = await _canScheduleExact(android);
      final scheduleMode = canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
        notificationDetails: _testDetails,
        androidScheduleMode: scheduleMode,
        payload: 'test_scheduled',
      );

      return canScheduleExact
          ? TestNotificationResult.scheduledExact
          : TestNotificationResult.scheduledInexact;
    } catch (error, stack) {
      debugPrint('NotificationService scheduleTestNotification error: $error\n$stack');
      return TestNotificationResult.failed;
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

  /// Cancels a pending or displayed test notification.
  Future<void> cancelTestNotification(int id) async {
    try {
      await init();
      await _plugin.cancel(id: id);
    } catch (error, stack) {
      debugPrint('NotificationService cancelTestNotification error: $error\n$stack');
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

  /// Schedules reminder notifications throughout the CURRENT DAY ONLY for modules due for revision today.
  ///
  /// Reminders start from 4:00 AM and repeat at random 90–120 minute intervals up to 10:00 PM (22:00) today.
  Future<void> scheduleRevisionRemindersForToday({
    required int dueCount,
    List<String> moduleTitles = const [],
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
          final moduleDesc = moduleTitles.isNotEmpty
              ? (moduleTitles.length == 1
                  ? '"${moduleTitles.first}"'
                  : '"${moduleTitles.first}" and ${moduleTitles.length - 1} other(s)')
              : '';

          final body = moduleDesc.isNotEmpty
              ? 'Revision due today for $moduleDesc. Don\'t forget spaced repetition!'
              : '$dueCount module(s) due for spaced repetition today.';

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

  /// Cancels all production reminders (Course, Streak, Revisions, and Deadlines).
  Future<void> cancelAllReminders() async {
    try {
      await init();
      await cancelCourseReminder();
      await cancelStreakReminder();
      await cancelAllRevisionReminders();
      await cancelAllDeadlineReminders();
      debugPrint('NotificationService: Cancelled all production reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelAllReminders error: $e');
    }
  }
}