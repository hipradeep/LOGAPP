import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:log/controllers/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path provider channel for getApplicationDocumentsDirectory
  const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.'; // Use current directory as mock documents directory
      }
      return null;
    },
  );

  group('SettingsController Tests', () {
    late SettingsController controller;

    setUp(() {
      controller = SettingsController();
    });

    test('initial state is correct', () {
      expect(controller.isLoading, isTrue);
      expect(controller.userName, equals('Log User'));
      expect(controller.userAvatar, equals('🦁'));
      expect(controller.dailyReminder, isFalse);
    });

    test('updateProfile updates values and notifies listeners', () async {
      int listenerCalls = 0;
      controller.addListener(() {
        listenerCalls++;
      });

      await controller.updateProfile('New User', '🦊');

      expect(controller.userName, equals('New User'));
      expect(controller.userAvatar, equals('🦊'));
      expect(listenerCalls, greaterThanOrEqualTo(1));
    });

    test('toggleReminder updates value and notifies listeners', () async {
      int listenerCalls = 0;
      controller.addListener(() {
        listenerCalls++;
      });

      await controller.toggleReminder(true);

      expect(controller.dailyReminder, isTrue);
      expect(listenerCalls, greaterThanOrEqualTo(1));
    });
  });
}
