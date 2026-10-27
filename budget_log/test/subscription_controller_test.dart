import 'dart:io';

import 'package:budget_log/controllers/subscription_controller.dart';
import 'package:budget_log/models/subscription.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late SubscriptionController controller;
  late int reminderSyncCount;
  late List<Subscription> lastSyncedSubscriptions;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('subscription_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    reminderSyncCount = 0;
    lastSyncedSubscriptions = const [];
    controller = SubscriptionController(
      dbService: databaseService,
      watchDatabase: false,
      onSubscriptionsChanged: (subscriptions) async {
        reminderSyncCount++;
        lastSyncedSubscriptions = subscriptions;
      },
    );
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('groups subscriptions and syncs reminders after changes', () async {
    await controller.addSubscription(
      Subscription(
        id: 'sub_monthly',
        name: 'Internet',
        amount: 799,
        frequency: 'monthly',
        nextDueDate: DateTime(2026, 2, 1),
        isAutopay: true,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await controller.addSubscription(
      Subscription(
        id: 'sub_paused',
        name: 'Gym',
        amount: 1500,
        frequency: 'monthly',
        nextDueDate: DateTime(2026, 2, 5),
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.activeCount, 1);
    expect(controller.nextSubscription?.id, 'sub_monthly');
    expect(controller.pausedSubscriptions.single.id, 'sub_paused');
    expect(controller.subscriptionById('sub_monthly')?.isAutopay, isTrue);
    expect(reminderSyncCount, greaterThan(0));
    expect(lastSyncedSubscriptions, hasLength(2));
  });

  test('marks a subscription paid, advances it, and refreshes state', () async {
    final subscription = Subscription(
      id: 'sub_paid',
      name: 'Music',
      amount: 199,
      frequency: 'monthly',
      nextDueDate: DateTime(2026, 1, 31),
      createdAt: DateTime(2026, 1, 1),
    );
    await controller.addSubscription(subscription);

    final updated = await controller.markPaid(subscription);

    expect(updated, isNotNull);
    expect(updated!.nextDueDate, DateTime(2026, 2, 28));
    expect(controller.nextSubscription?.nextDueDate, DateTime(2026, 2, 28));
    final transactions = await databaseService.getTransactions();
    expect(transactions.single.title, 'Music');
  });

  test('pauses and resumes a subscription', () async {
    await controller.addSubscription(
      Subscription(
        id: 'sub_toggle',
        name: 'Hosting',
        amount: 500,
        frequency: 'monthly',
        nextDueDate: DateTime(2026, 2, 10),
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    await controller.setActive('sub_toggle', false);
    expect(controller.activeSubscriptions, isEmpty);
    expect(controller.pausedSubscriptions, hasLength(1));

    await controller.setActive('sub_toggle', true);
    expect(controller.activeSubscriptions, hasLength(1));
    expect(controller.pausedSubscriptions, isEmpty);
  });
}
