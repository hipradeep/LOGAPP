import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription.dart';
import '../utils/subscription_schedule.dart';
import 'database_service.dart';
import 'subscription_reminder_planner.dart';

const String markSubscriptionPaidActionId = 'mark_subscription_paid';

class NotificationService {
  static const String channelId = 'budget_subscriptions';
  static const String channelName = 'Subscription reminders';
  static const String channelDescription =
      'Reminders for upcoming subscription and bill payments.';

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(
          markSubscriptionPaidActionId,
          'Mark as paid',
          cancelNotification: true,
        ),
      ],
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AndroidFlutterLocalNotificationsPlugin? _android;
  Future<void>? _initFuture;
  bool _isRequestingPermission = false;

  Future<void> init() {
    return _initFuture ??= _doInit().catchError((
      Object error,
      StackTrace stack,
    ) {
      _initFuture = null;
      debugPrint('NotificationService init error: $error\n$stack');
    });
  }

  Future<void> _doInit() async {
    await _initializeTimeZone();
    _android = _resolveAndroid();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_budget'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (_) {},
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );

    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  AndroidFlutterLocalNotificationsPlugin? _resolveAndroid() {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } catch (error) {
      debugPrint('NotificationService resolveAndroid error: $error');
      return null;
    }
  }

  static Future<void> _initializeTimeZone() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_detectTimeZoneName()));
    } catch (error) {
      debugPrint('NotificationService timezone error: $error');
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

  Future<bool> notificationsEnabled() async {
    try {
      await init();
      final android = _android ?? _resolveAndroid();
      if (android == null) return false;
      return await android.areNotificationsEnabled() ?? false;
    } catch (error) {
      debugPrint('NotificationService notificationsEnabled error: $error');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (_isRequestingPermission) return false;
    _isRequestingPermission = true;
    try {
      await init();
      final android = _android ?? _resolveAndroid();
      if (android == null) return false;
      return await android.requestNotificationsPermission() ?? false;
    } catch (error) {
      debugPrint('NotificationService requestPermission error: $error');
      return false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> syncSchedules(List<Subscription> subscriptions) async {
    try {
      await init();
      await _cancelSubscriptionReminders();

      final exactAllowed = await _canScheduleExact();
      final scheduleMode = exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final now = DateTime.now();

      for (final subscription in subscriptions) {
        final reminders = SubscriptionReminderPlanner.plan(
          subscription: subscription,
          now: now,
        );
        for (final reminder in reminders) {
          await _scheduleReminder(
            reminder: reminder,
            scheduleMode: scheduleMode,
          );
        }
      }
    } catch (error, stack) {
      debugPrint('NotificationService syncSchedules error: $error\n$stack');
    }
  }

  Future<void> _cancelSubscriptionReminders() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (_isSubscriptionPayload(request.payload)) {
          await _plugin.cancel(id: request.id);
        }
      }
    } catch (error) {
      debugPrint('NotificationService cancel reminders error: $error');
    }
  }

  Future<void> _scheduleReminder({
    required SubscriptionReminder reminder,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final localDate = reminder.scheduledAt;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      localDate.year,
      localDate.month,
      localDate.day,
      localDate.hour,
      localDate.minute,
    );
    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: scheduleMode,
        payload: reminder.payload,
      );
    } on PlatformException {
      if (scheduleMode == AndroidScheduleMode.exactAllowWhileIdle) {
        await _plugin.zonedSchedule(
          id: reminder.id,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: scheduledDate,
          notificationDetails: _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: reminder.payload,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<bool> _canScheduleExact() async {
    try {
      final android = _android ?? _resolveAndroid();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (error) {
      debugPrint('NotificationService exact alarm error: $error');
      return false;
    }
  }

  static bool _isSubscriptionPayload(String? payload) {
    final decoded = _decodePayload(payload);
    return decoded?['type'] == 'subscription';
  }

  static Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }
}

@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (response.actionId != markSubscriptionPaidActionId) return;
    final payload = NotificationService._decodePayload(response.payload);
    if (payload == null) return;

    final subscriptionId = payload['subscriptionId'] as String?;
    final dueDateValue = payload['dueDate'];
    if (subscriptionId == null || dueDateValue is! num) return;

    final dueDate = DateTime.fromMillisecondsSinceEpoch(dueDateValue.toInt());
    final database = DatabaseService.instance;
    await database.init();
    final updated = await database.markSubscriptionPaid(
      subscriptionId,
      expectedDueDate: SubscriptionSchedule.startOfDay(dueDate),
    );
    if (updated == null) return;

    final subscriptions = await database.getSubscriptions();
    await NotificationService().syncSchedules(subscriptions);
  } catch (error, stack) {
    debugPrint('NotificationService background action error: $error\n$stack');
  }
}
