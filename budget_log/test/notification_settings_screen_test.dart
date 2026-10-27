import 'package:budget_log/screens/notification_settings_screen.dart';
import 'package:budget_log/services/notification_service.dart';
import 'package:budget_log/services/service_locator.dart';
import 'package:budget_log/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService({required this.enabled});

  bool enabled;

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    enabled = true;
    return true;
  }
}

void main() {
  tearDown(getIt.reset);

  testWidgets('shows permission status and enables notifications', (
    tester,
  ) async {
    getIt.registerSingleton<NotificationService>(
      _FakeNotificationService(enabled: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: const NotificationSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(find.text('Enable notifications'), findsOneWidget);

    await tester.tap(find.text('Enable notifications'));
    await tester.pumpAndSettle();

    expect(find.text('Notifications are on'), findsOneWidget);
    expect(find.text('Enable notifications'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
