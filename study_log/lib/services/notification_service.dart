import 'package:flutter/foundation.dart';
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
/// initialization, Android permission negotiation, timezone resolution and
/// test-notification delivery.
///
/// All methods are defensive: a missing plugin (tests, unsupported platforms)
/// must never crash the app, so failures are swallowed, logged via
/// [debugPrint] and surfaced as a result enum.
class NotificationService {
  static const String _testChannelId = 'study_test_channel';
  static const String _testChannelName = 'Test Notifications';
  static const String _testChannelDescription =
      'Diagnostics notifications used to verify reminder delivery.';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? _android;
  Future<void>? _initFuture;
  bool _isRequestingPermission = false;

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
}