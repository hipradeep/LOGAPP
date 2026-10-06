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

  static const String _courseChannelId = 'study_course_channel';
  static const String _courseChannelName = 'Course Study Reminders';
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

  static const String _testChannelId = 'study_test_channel';
  static const String _testChannelName = 'Test Notifications';
  static const String _testChannelDescription =
      'Diagnostics notifications used to verify reminder delivery.';

  static const int courseNotificationId = 1001;
  static const int streakNotificationId = 1002;
  static const int revisionBaseNotificationId = 2000;
  static const int maxRevisionSlots = 20;

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
    String title = 'Course Study Time 📚',
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

  /// Schedules the recurring daily streak saver reminder at [time] (starting from 4 AM minimum).
  Future<void> scheduleDailyStreakReminder({
    required TimeOfDay time,
    String title = 'Protect Your Study Streak! 🔥',
    String body = 'Keep your daily momentum alive by completing a topic or revision today.',
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
        id: streakNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _streakDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'streak_saver_daily',
      );
      debugPrint('NotificationService: Scheduled daily streak reminder at ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')}');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleDailyStreakReminder error: $e\n$stack');
    }
  }

  /// Cancels the daily streak saver reminder.
  Future<void> cancelStreakReminder() async {
    try {
      await init();
      await _plugin.cancel(id: streakNotificationId);
    } catch (e) {
      debugPrint('NotificationService cancelStreakReminder error: $e');
    }
  }

  /// Schedules reminder notifications throughout the CURRENT DAY ONLY for modules due for revision today.
  ///
  /// Reminders start from [startTime] (strictly clamped to 4:00 AM or later) and repeat every [intervalHours]
  /// up to 10:00 PM (22:00) today.
  Future<void> scheduleRevisionRemindersForToday({
    required TimeOfDay startTime,
    required int intervalHours,
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

      // Rule 1: All notifications must start from 4 AM onwards
      final int startHour = startTime.hour < minNotificationHour ? minNotificationHour : startTime.hour;
      final int startMinute = startTime.hour < minNotificationHour ? 0 : startTime.minute;

      final int stepHours = intervalHours.clamp(1, 12);
      int slotIndex = 0;

      // Rule 2: For any due date revision (only for current day), send reminder notifications for configured hours
      // Generates reminder slots for today up to 22:00
      for (int h = startHour; h <= 22 && slotIndex < maxRevisionSlots; h += stepHours) {
        final slotTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          h,
          startMinute,
        );

        // Only schedule if slotTime is still in the future for today
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
      debugPrint('NotificationService: Scheduled $slotIndex revision reminder slots for today (every ${stepHours}h starting after 4 AM)');
    } catch (e, stack) {
      debugPrint('NotificationService scheduleRevisionRemindersForToday error: $e\n$stack');
    }
  }

  /// Cancels all scheduled revision reminder slots for the current day.
  Future<void> cancelAllRevisionReminders() async {
    try {
      await init();
      for (int i = 0; i < maxRevisionSlots; i++) {
        await _plugin.cancel(id: revisionBaseNotificationId + i);
      }
    } catch (e) {
      debugPrint('NotificationService cancelAllRevisionReminders error: $e');
    }
  }

  /// Cancels all production reminders (Course, Streak, and Revisions).
  Future<void> cancelAllReminders() async {
    try {
      await init();
      await cancelCourseReminder();
      await cancelStreakReminder();
      await cancelAllRevisionReminders();
      debugPrint('NotificationService: Cancelled all production reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelAllReminders error: $e');
    }
  }
}