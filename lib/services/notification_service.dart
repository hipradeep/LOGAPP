import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'cache_service.dart';

@pragma('vm:entry-point')
Future<void> onNotificationActionCallback(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  // Await the handler so the background isolate is NOT terminated prematurely
  // before async operations (cancel + reschedule + confirmation) complete.
  await NotificationService.handleNotificationAction(details);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static AndroidFlutterLocalNotificationsPlugin? _androidImplementation;

  // Cached DateFormats and RegExp for timezone/time parsing optimizations
  static final DateFormat _jmFormat = DateFormat.jm();
  static final DateFormat _hmFormat = DateFormat.Hm();
  static final RegExp _ampmRegExp = RegExp(r'[ap]m');

  // Pre-configured const notification details to prevent memory re-allocations
  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    'reminder_channel_v3',
    'Reminders',
    channelDescription: 'Notifications for reminders and tasks',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'dismiss',
        'Dismiss',
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        'reschedule_10',
        '10 Min',
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        'reschedule_30',
        '30 Min',
        cancelNotification: true,
      ),
    ],
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  static const AndroidNotificationDetails _simpleAndroidDetails = AndroidNotificationDetails(
    'reminder_channel_v3_simple',
    'Alerts',
    channelDescription: 'Simple status alerts and confirmations',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    playSound: true,
    enableVibration: true,
  );

  static const NotificationDetails _simpleNotificationDetails = NotificationDetails(
    android: _simpleAndroidDetails,
  );

  /// Initialize the notification service
  static Future<void> init() async {
    try {
      await _initializeTimeZone();
      
      _androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: onNotificationActionCallback,
      );
    } catch (_) {}
  }

  static Future<void> _handleNotificationResponse(NotificationResponse details) async {
    // Fire-and-forget is acceptable here since we are on the main isolate
    // and the app is foregrounded – the process will not be killed.
    await handleNotificationAction(details);
  }

  static Future<void> handleNotificationAction(NotificationResponse details) async {
    final actionId = details.actionId;
    final payload = details.payload;
    
    // Log the incoming action details for easier debugging
    debugPrint('Notification Action Triggered: actionId=$actionId, payload=$payload, id=${details.id}');

    if (actionId == null || payload == null || payload.isEmpty) {
      debugPrint('Action aborted: actionId or payload is null/empty.');
      return;
    }

    // Check and prevent duplicate action execution within 3 seconds (cross-isolate)
    if (await CacheService().isDuplicateAction(details.id, actionId)) {
      debugPrint('Action aborted: duplicate event detected for notification ${details.id} with action $actionId.');
      return;
    }

    final parts = payload.split('|');
    if (parts.length < 2) {
      debugPrint('Action aborted: payload could not be parsed: $payload');
      return;
    }
    final title = parts[0];
    final body = parts[1];

    if (actionId.startsWith('reschedule_')) {
      final minsStr = actionId.split('_').last; // "10" or "30"
      final minutes = int.tryParse(minsStr);
      if (minutes != null && details.id != null) {
        debugPrint('Rescheduling notification "$title" (ID: ${details.id}) by $minutes minutes...');
        // Dynamically initialize timezones in this background isolate
        await _initializeTimeZone();

        final newTime = DateTime.now().add(Duration(minutes: minutes));
        await cancelNotification(details.id!);
        await scheduleOneShotNotification(
          id: details.id!,
          title: title,
          body: '$body (Rescheduled)',
          dateTime: newTime,
          skipPermissionCheck: true,
        );

        // Show instant confirmation notification using simple details (no action buttons)
        final confirmationId = (details.id! + 12345) & 0x7FFFFFFF;
        await showSimpleInstantNotification(
          id: confirmationId,
          title: 'Reminder Rescheduled',
          body: '"$title" has been rescheduled for $minutes min.',
        );
        debugPrint('Confirmation notification triggered for rescheduling.');
      }
    }
  }

  /// Initializes timezone data and sets the local location dynamically
  /// based on the device's current UTC offset.
  static Future<void> _initializeTimeZone() async {
    try {
      tz.initializeTimeZones();
      final detectedName = _detectTimeZoneName();
      tz.setLocalLocation(tz.getLocation(detectedName));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
  }

  static String _detectTimeZoneName() {
    final offset = DateTime.now().timeZoneOffset;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final name in tz.timeZoneDatabase.locations.keys) {
      final loc = tz.getLocation(name);
      final timeZone = loc.timeZone(nowMs);
      if (timeZone.offset == offset.inMilliseconds) {
        return name;
      }
    }
    return 'UTC'; // Fallback
  }

  static bool _isRequestingPermission = false;

  /// Request permissions for showing notifications.
  /// Note: Opening app settings when denied is intentionally omitted here;
  /// that action is handled explicitly in permission_screen.dart.
  static Future<bool> requestPermissions() async {
    if (_isRequestingPermission) {
      return false;
    }
    _isRequestingPermission = true;
    try {
      final androidImpl = _androidImplementation ??=
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        await androidImpl.requestExactAlarmsPermission();
        return (granted ?? false);
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  /// Robust parser for different time formats (e.g. 5:03 PM, 17:03, etc.)
  static DateTime parseTimeString(String timeString) {
    try {
      return _jmFormat.parse(timeString);
    } catch (_) {
      try {
        return _hmFormat.parse(timeString);
      } catch (_) {
        final cleanString = timeString.trim().toLowerCase();
        final isPm = cleanString.contains('pm');
        final isAm = cleanString.contains('am');
        final parts = cleanString.replaceAll(_ampmRegExp, '').trim().split(':');
        int hour = int.parse(parts[0]);
        final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
        
        if (isPm && hour < 12) {
          hour += 12;
        } else if (isAm && hour == 12) {
          hour = 0;
        }
        
        return DateTime(2000, 1, 1, hour, minute);
      }
    }
  }

  /// Schedule a daily recurring notification at a specific time
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required String timeString,
    bool forceTomorrow = false,
    bool skipPermissionCheck = false,
  }) async {
    try {
      if (!skipPermissionCheck) {
        await requestPermissions();
      }

      await _initializeTimeZone();

      final parsedTime = parseTimeString(timeString);
      
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      if (forceTomorrow) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      } else {
        if (scheduledDate.hour == now.hour && scheduledDate.minute == now.minute) {
          scheduledDate = scheduledDate.add(const Duration(minutes: 1));
        } else if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
      }

      // Use exact alarm if permitted, fall back to inexact on Android 14+.
      // Wrap in try-catch to guard against MissingPluginException in tests
      // and background isolates where permission_handler may not be available.
      AndroidScheduleMode scheduleMode;
      try {
        scheduleMode = await Permission.scheduleExactAlarm.isGranted
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } catch (_) {
        scheduleMode = AndroidScheduleMode.alarmClock;
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '$title|$body',
      );
    } catch (_) {}
  }

  /// Schedule a single one-shot notification at a specific date and time
  static Future<void> scheduleOneShotNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    bool skipPermissionCheck = false,
  }) async {
    try {
      if (!skipPermissionCheck) {
        await requestPermissions();
      }

      await _initializeTimeZone();

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime.from(dateTime, tz.local);

      if (scheduledDate.isBefore(now)) {
        return;
      }

      // Use exact alarm if permitted, fall back to inexact on Android 14+.
      AndroidScheduleMode scheduleMode;
      try {
        scheduleMode = await Permission.scheduleExactAlarm.isGranted
            ? AndroidScheduleMode.alarmClock
            : AndroidScheduleMode.inexactAllowWhileIdle;
      } catch (_) {
        scheduleMode = AndroidScheduleMode.alarmClock;
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$title|$body',
      );
    } catch (_) {}
  }

  /// Log all currently scheduled pending notifications (silent now)
  static Future<void> logPendingNotifications() async {}

  /// Display a notification immediately (instant trigger for testing)
  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await requestPermissions();

      await _notificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails,
        payload: '$title|$body',
      );
    } catch (_) {}
  }

  /// Display a simple notification immediately without action buttons
  static Future<void> showSimpleInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _simpleNotificationDetails,
      );
    } catch (_) {}
  }

  /// Cancel a scheduled notification by ID
  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
