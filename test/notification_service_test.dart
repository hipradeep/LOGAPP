import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:log/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final List<MethodCall> log = <MethodCall>[];

  setUpAll(() {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (_) {}
  });

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'initialize') {
          return true;
        }
        if (methodCall.method == 'pendingNotificationRequests') {
          return <ActiveNotification>[];
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('NotificationService handleNotificationAction Tests', () {
    test('handleNotificationAction ignores action when actionId or payload is empty', () async {
      // Await each call so their async chains fully complete before the next
      // test's setUp runs — prevents mock-bleed between tests.

      // 1. Empty actionId
      await NotificationService.handleNotificationAction(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 1,
          actionId: null,
          payload: 'Test Title|Test Body',
        ),
      );
      expect(log, isEmpty);

      // 2. Empty payload
      await NotificationService.handleNotificationAction(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 1,
          actionId: 'reschedule_10',
          payload: null,
        ),
      );
      expect(log, isEmpty);

      // 3. Invalid payload parts
      await NotificationService.handleNotificationAction(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 1,
          actionId: 'reschedule_10',
          payload: 'InvalidPayloadNoPipe',
        ),
      );
      expect(log, isEmpty);
    });

    test('handleNotificationAction reschedules notification and shows confirmation on reschedule_10', () async {
      // Await directly — handleNotificationAction returns Future<void> and
      // must be awaited so all async hops (cancel, zonedSchedule, show) complete
      // before we inspect the mock log.
      await NotificationService.handleNotificationAction(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 9999,
          actionId: 'reschedule_10',
          payload: 'Test Title|Test Body',
        ),
      );

      // We expect:
      // 1. cancel (for id: 9999)
      // 2. zonedSchedule (for rescheduled notification with id: 9999)
      // 3. show (for confirmation notification with id: (9999 + 12345) & 0x7FFFFFFF)
      final cancelCalls = log.where((call) => call.method == 'cancel').toList();
      final scheduleCalls = log.where((call) => call.method == 'zonedSchedule').toList();
      final showCalls = log.where((call) => call.method == 'show').toList();

      expect(cancelCalls, hasLength(1));
      expect(cancelCalls.first.arguments['id'], equals(9999));

      expect(scheduleCalls, hasLength(1));
      expect(scheduleCalls.first.arguments['id'], equals(9999));
      expect(scheduleCalls.first.arguments['title'], equals('Test Title'));
      expect(scheduleCalls.first.arguments['body'], equals('Test Body (Rescheduled)'));

      expect(showCalls, hasLength(1));
      final expectedConfirmId = (9999 + 12345) & 0x7FFFFFFF;
      expect(showCalls.first.arguments['id'], equals(expectedConfirmId));
      expect(showCalls.first.arguments['title'], equals('Reminder Rescheduled'));
      expect(showCalls.first.arguments['body'], contains('Test Title'));
    });

    test('handleNotificationAction reschedules notification and shows confirmation on reschedule_30', () async {
      // Await directly — handleNotificationAction returns Future<void>.
      await NotificationService.handleNotificationAction(
        const NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotificationAction,
          id: 123,
          actionId: 'reschedule_30',
          payload: 'Meeting|Team Sync',
        ),
      );

      final cancelCalls = log.where((call) => call.method == 'cancel').toList();
      final scheduleCalls = log.where((call) => call.method == 'zonedSchedule').toList();
      final showCalls = log.where((call) => call.method == 'show').toList();

      expect(cancelCalls, hasLength(1));
      expect(cancelCalls.first.arguments['id'], equals(123));

      expect(scheduleCalls, hasLength(1));
      expect(scheduleCalls.first.arguments['id'], equals(123));
      expect(scheduleCalls.first.arguments['title'], equals('Meeting'));
      expect(scheduleCalls.first.arguments['body'], equals('Team Sync (Rescheduled)'));

      expect(showCalls, hasLength(1));
      final expectedConfirmId = (123 + 12345) & 0x7FFFFFFF;
      expect(showCalls.first.arguments['id'], equals(expectedConfirmId));
    });
  });
}
