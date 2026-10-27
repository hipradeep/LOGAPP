import 'dart:io';

import 'package:budget_log/controllers/sms_inbox_controller.dart';
import 'package:budget_log/models/budget_transaction.dart';
import 'package:budget_log/models/sms_record.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:budget_log/services/sms_inbox_service.dart';
import 'package:budget_log/services/sms_native_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeSmsBridge extends SmsNativeBridge {
  List<SmsInboxRecord> inbox = const [];
  List<SmsInboxRecord> captured = const [];
  Set<String> pendingIds = const {};
  final List<String> removedIds = [];
  bool backgroundEnabled = true;

  @override
  Future<List<SmsInboxRecord>> scanInbox({
    int days = 30,
    int limit = 500,
  }) async {
    return inbox;
  }

  @override
  Future<List<SmsInboxRecord>> drainCaptured() async {
    final records = captured;
    captured = const [];
    return records;
  }

  @override
  Future<void> syncPendingValidations(List<SmsValidationEntry> entries) async {
    pendingIds = entries.map((e) => e.id).toSet();
  }

  @override
  Future<void> removeValidation(String id) async {
    removedIds.add(id);
  }

  @override
  Future<bool> getBackgroundEnabled() async => backgroundEnabled;

  @override
  Future<void> setBackgroundEnabled(bool enabled) async {
    backgroundEnabled = enabled;
  }

  @override
  Stream<SmsValidationTarget> get validationTargets =>
      Stream<SmsValidationTarget>.empty();
}

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late FakeSmsBridge bridge;
  late SmsInboxController controller;
  final fixedDate = DateTime.now().subtract(const Duration(days: 1));

  SmsInboxRecord record(
    String body, {
    String sender = 'HDFCBK',
    int minute = 0,
    String sourceKey = 'native',
    DateTime? timestamp,
  }) {
    return SmsInboxRecord(
      sourceKey: sourceKey,
      sender: sender,
      body: body,
      timestamp:
          timestamp ??
          DateTime(fixedDate.year, fixedDate.month, fixedDate.day, 10, minute),
    );
  }

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('sms_inbox_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    bridge = FakeSmsBridge();
    controller = SmsInboxController(
      service: SmsInboxService(
        bridge: bridge,
        dbService: databaseService,
        hasPermission: () async => true,
        requestPermission: () async => true,
      ),
      dbService: databaseService,
    );
    await controller.initialize();
  });

  tearDown(() async {
    controller.dispose();
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('scans and stages only valid bank transactions', () async {
    bridge.inbox = [
      record('Rs 100 debited at Amazon on 15-01-26.', minute: 1),
      record('123456 is your OTP for a transaction of Rs 500.', minute: 2),
      record(
        'INR 2,000 credited from Acme Corp via UPI.',
        minute: 3,
        sourceKey: 'credit',
      ),
    ];

    final result = await controller.scanNow();
    await Future<void>.delayed(Duration.zero);

    expect(result, isNotNull);
    expect(result!.staged, 2);
    expect(controller.pendingCount, 2);
    expect(bridge.pendingIds, hasLength(2));
  });

  test('ignores SMS older than 30 days', () async {
    bridge.inbox = [
      record('Rs 100 debited at Amazon on 15-01-26.', minute: 1),
      record(
        'Rs 900 debited at Old Store on 15-01-26.',
        sourceKey: 'old',
        timestamp: DateTime.now().subtract(const Duration(days: 31)),
      ),
    ];

    final result = await controller.scanNow();
    await Future<void>.delayed(Duration.zero);

    expect(result!.staged, 1);
    expect(controller.pendingCount, 1);
  });

  test('does not stage the same SMS twice', () async {
    bridge.inbox = [record('Rs 100 debited at Amazon on 15-01-26.')];
    await controller.scanNow();
    await Future<void>.delayed(Duration.zero);

    final second = await controller.scanNow();
    await Future<void>.delayed(Duration.zero);

    expect(second!.staged, 0);
    expect(controller.pendingCount, 1);
  });

  test('drains background candidates and clears invalid ones', () async {
    bridge.captured = [
      record(
        'Rs 100 debited at Amazon on 15-01-26.',
        minute: 1,
        sourceKey: 'candidate_valid',
      ),
      record(
        'Rs 500 debited failed. Try again.',
        minute: 2,
        sourceKey: 'candidate_invalid',
      ),
    ];

    await controller.drainBackground();
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingCount, 1);
    expect(
      bridge.removedIds,
      containsAll(['candidate_valid', 'candidate_invalid']),
    );
    expect(bridge.pendingIds, hasLength(1));
  });

  test('accepts a staged SMS atomically', () async {
    bridge.inbox = [record('Rs 100 debited at Amazon on 15-01-26.')];
    await controller.scanNow();
    await Future<void>.delayed(Duration.zero);
    final staged = controller.pending.single;

    final accepted = await controller.accept(
      staged: staged,
      transaction: BudgetTransaction(
        id: 'txn_sms',
        amount: 100,
        type: 'expense',
        categoryId: 'cat_shopping',
        paymentModeId: 'pm_bank',
        title: 'Amazon',
        timestamp: staged.smsTimestamp,
        createdAt: fixedDate,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(accepted, isTrue);
    expect(controller.pendingCount, 0);
    expect(bridge.removedIds, contains(staged.id));
    expect((await databaseService.getTransactions()).single.id, 'txn_sms');
    expect(
      (await databaseService.getStagedSmsById(staged.id))!.isAccepted,
      isTrue,
    );
  });

  test('rejects a staged SMS and removes its notification', () async {
    bridge.inbox = [record('Rs 100 debited at Amazon on 15-01-26.')];
    await controller.scanNow();
    await Future<void>.delayed(Duration.zero);
    final staged = controller.pending.single;

    await controller.reject(staged.id);
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingCount, 0);
    expect(bridge.removedIds, contains(staged.id));
    expect(
      (await databaseService.getStagedSmsById(staged.id))!.isRejected,
      isTrue,
    );
  });

  test('toggles background capture', () async {
    await controller.setBackgroundEnabled(false);
    expect(controller.backgroundEnabled, isFalse);
    expect(bridge.backgroundEnabled, isFalse);

    await controller.setBackgroundEnabled(true);
    expect(controller.backgroundEnabled, isTrue);
    expect(bridge.backgroundEnabled, isTrue);
  });
}
