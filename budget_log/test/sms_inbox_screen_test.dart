import 'dart:io';

import 'package:budget_log/controllers/sms_inbox_controller.dart';
import 'package:budget_log/models/sms_record.dart';
import 'package:budget_log/models/staged_sms_transaction.dart';
import 'package:budget_log/screens/sms_inbox_screen.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:budget_log/services/sms_inbox_service.dart';
import 'package:budget_log/services/sms_native_bridge.dart';
import 'package:budget_log/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSmsBridge extends SmsNativeBridge {
  final List<String> removedIds = [];

  @override
  Future<List<SmsInboxRecord>> scanInbox({
    int days = 30,
    int limit = 500,
  }) async => const [];

  @override
  Future<List<SmsInboxRecord>> drainCaptured() async => const [];

  @override
  Future<void> syncPendingValidations(List<SmsValidationEntry> entries) async {}

  @override
  Future<void> removeValidation(String id) async {
    removedIds.add(id);
  }

  @override
  Future<bool> getBackgroundEnabled() async => true;

  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}

  @override
  Stream<SmsValidationTarget> get validationTargets =>
      Stream<SmsValidationTarget>.empty();
}

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late _FakeSmsBridge bridge;
  late SmsInboxController controller;
  final fixedDate = DateTime.now().subtract(const Duration(days: 1));

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('sms_screen_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    bridge = _FakeSmsBridge();
    controller = SmsInboxController(
      service: SmsInboxService(
        bridge: bridge,
        dbService: databaseService,
        hasPermission: () async => true,
        requestPermission: () async => true,
      ),
      dbService: databaseService,
    );
    await databaseService.addStagedSms(
      StagedSmsTransaction(
        id: 'sms_screen_1',
        smsSender: 'HDFCBK',
        rawBody: 'Rs 100 debited at Amazon on 15-01-26.',
        extractedAmount: 100,
        extractedMerchant: 'Amazon',
        extractedType: 'debit',
        accountRef: '1234',
        smsTimestamp: fixedDate,
        createdAt: fixedDate,
      ),
    );
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    controller.dispose();
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('shows pending SMS and its review action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: SmsInboxScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SMS inbox'), findsOneWidget);
    expect(find.text('PENDING · 1'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Nothing waiting'), findsNothing);
    expect(controller.pendingCount, 1);
    expect(bridge.removedIds, isEmpty);
  });
}
