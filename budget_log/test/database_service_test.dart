import 'dart:io';

import 'package:budget_log/models/budget.dart';
import 'package:budget_log/models/budget_transaction.dart';
import 'package:budget_log/models/contact.dart';
import 'package:budget_log/models/debt_record.dart';
import 'package:budget_log/models/staged_sms_transaction.dart';
import 'package:budget_log/models/subscription.dart';
import 'package:budget_log/services/database_backup_service.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late DatabaseBackupService backupService;
  final fixedDate = DateTime(2026, 1, 15, 10, 30);

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('budget_log_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    backupService = DatabaseBackupService(dbService: databaseService);
    await databaseService.init();
  });

  tearDown(() async {
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Budget createBudget(String id) => Budget(
    id: id,
    name: 'Monthly Budget',
    categoryName: 'Expenses',
    limit: 20000,
    period: 'monthly',
    createdAt: fixedDate,
    updatedAt: fixedDate,
  );

  BudgetTransaction createTransaction(String id, {String? budgetId}) =>
      BudgetTransaction(
        id: id,
        amount: 250,
        categoryId: 'cat_food',
        paymentModeId: 'pm_cash',
        budgetId: budgetId,
        title: 'Lunch',
        timestamp: fixedDate,
        createdAt: fixedDate,
      );

  test('creates schema, indexes, and seed data', () async {
    expect(await databaseService.getPaymentModes(), hasLength(6));
    expect(await databaseService.getCategories(), hasLength(11));
    expect(await databaseService.getTransactions(), isEmpty);
    expect(await databaseService.getSetting('active_account_email'), isNull);
  });

  test(
    'performs transaction CRUD and budget deletion nulls the link',
    () async {
      final budget = createBudget('bud_1');
      await databaseService.addBudget(budget, activate: true);

      final transaction = createTransaction('txn_1', budgetId: budget.id);
      final change = databaseService.onDatabaseChanged.first;
      await databaseService.addTransaction(transaction);
      expect(await change, 'transactions');

      var rows = await databaseService.getTransactions();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Lunch');

      await databaseService.deleteBudget(budget.id);
      rows = await databaseService.getTransactions();
      expect(rows.single.budgetId, isNull);
    },
  );

  test('settles debt records partially and fully', () async {
    final contact = Contact(id: 'cnt_1', name: 'Alex', createdAt: fixedDate);
    await databaseService.addContact(contact);

    final record = DebtRecord(
      id: 'debt_1',
      contactId: contact.id,
      direction: 'give',
      amount: 500,
      createdAt: fixedDate,
    );
    await databaseService.addDebtRecord(record);

    await databaseService.settleDebt(record.id, 200);
    var rows = await databaseService.getDebtRecords();
    expect(rows.single.settledAmount, 200);
    expect(rows.single.status, 'partially_settled');
    expect(rows.single.outstanding, 300);

    await databaseService.settleDebt(record.id, 400);
    rows = await databaseService.getDebtRecords();
    expect(rows.single.settledAmount, 500);
    expect(rows.single.status, 'settled');
    expect(rows.single.outstanding, 0);
  });

  test('adds a split expense and linked debts atomically', () async {
    final contact = Contact(
      id: 'cnt_split',
      name: 'Alex',
      createdAt: fixedDate,
    );
    await databaseService.addContact(contact);

    final transaction = createTransaction(
      'txn_split',
    ).copyWith(amount: 300, title: 'Dinner');
    final debts = [
      DebtRecord(
        id: 'debt_split_1',
        contactId: contact.id,
        transactionId: transaction.id,
        direction: 'give',
        amount: 150,
        notes: 'Split expense: Dinner',
        createdAt: fixedDate,
      ),
      DebtRecord(
        id: 'debt_split_2',
        contactId: contact.id,
        transactionId: transaction.id,
        direction: 'give',
        amount: 100,
        notes: 'Split expense: Dinner',
        createdAt: fixedDate,
      ),
    ];

    await databaseService.addTransactionWithDebtRecords(transaction, debts);

    final transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, 300);
    final records = await databaseService.getDebtRecords();
    expect(records, hasLength(2));
    expect(
      records.every((item) => item.transactionId == transaction.id),
      isTrue,
    );
    expect(records.every((item) => item.direction == 'give'), isTrue);
  });

  test('settles a debt with a linked settlement transaction', () async {
    final contact = Contact(id: 'cnt_2', name: 'Sam', createdAt: fixedDate);
    await databaseService.addContact(contact);
    final record = DebtRecord(
      id: 'debt_2',
      contactId: contact.id,
      direction: 'give',
      amount: 500,
      createdAt: fixedDate,
    );
    await databaseService.addDebtRecord(record);

    await databaseService.settleDebt(
      record.id,
      200,
      settlementTransaction: BudgetTransaction(
        id: 'txn_settlement',
        amount: 200,
        type: 'income',
        paymentModeId: 'pm_upi',
        title: 'Sam repaid',
        timestamp: fixedDate,
        createdAt: fixedDate,
      ),
    );

    final debts = await databaseService.getDebtRecords();
    expect(debts.single.settledAmount, 200);
    expect(debts.single.status, 'partially_settled');
    final transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.id, 'txn_settlement');
    expect(transactions.single.type, 'income');
  });

  test('finds upcoming subscriptions', () async {
    final subscription = Subscription(
      id: 'sub_1',
      name: 'Music',
      amount: 199,
      frequency: 'monthly',
      nextDueDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: fixedDate,
    );
    await databaseService.addSubscription(subscription);

    final upcoming = await databaseService.getUpcomingSubscriptions(
      to: DateTime.now().add(const Duration(days: 7)),
    );
    expect(upcoming, hasLength(1));
    expect(upcoming.single.id, subscription.id);
  });

  test('marks a subscription paid and advances its due date', () async {
    final dueDate = DateTime(2026, 1, 31);
    await databaseService.addSubscription(
      Subscription(
        id: 'sub_paid',
        name: 'Internet',
        amount: 799,
        frequency: 'monthly',
        nextDueDate: dueDate,
        isAutopay: true,
        createdAt: fixedDate,
      ),
    );

    final updated = await databaseService.markSubscriptionPaid(
      'sub_paid',
      expectedDueDate: dueDate,
      paidAt: fixedDate,
    );

    expect(updated, isNotNull);
    expect(updated!.nextDueDate, DateTime(2026, 2, 28));
    final transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.title, 'Internet');
    expect(transactions.single.amount, 799);
    expect(transactions.single.type, 'expense');
    expect(transactions.single.note, 'Subscription payment');

    final stale = await databaseService.markSubscriptionPaid(
      'sub_paid',
      expectedDueDate: dueDate,
    );
    expect(stale, isNull);
    expect(await databaseService.getTransactions(), hasLength(1));
  });

  test('does not mark paused subscriptions as paid', () async {
    await databaseService.addSubscription(
      Subscription(
        id: 'sub_paused',
        name: 'Gym',
        amount: 1500,
        frequency: 'monthly',
        nextDueDate: fixedDate,
        isActive: false,
        createdAt: fixedDate,
      ),
    );

    final updated = await databaseService.markSubscriptionPaid('sub_paused');

    expect(updated, isNull);
    expect(await databaseService.getTransactions(), isEmpty);
  });

  test('detects duplicate staged SMS records', () async {
    final timestamp = DateTime.now();
    final staged = StagedSmsTransaction(
      id: 'sms_1',
      smsSender: 'BANK',
      rawBody: 'Rs 100 debited',
      extractedAmount: 100,
      extractedType: 'debit',
      accountRef: '1234',
      smsTimestamp: timestamp,
      createdAt: fixedDate,
    );
    await databaseService.addStagedSms(staged);

    final duplicate = await databaseService.findDuplicateStagedSms(
      accountRef: '1234',
      amount: 100,
      smsTimestamp: timestamp.add(const Duration(seconds: 2)),
    );
    expect(duplicate, isNotNull);
    expect(duplicate!.id, staged.id);
  });

  test('inserts staged SMS in a batch and ignores duplicates', () async {
    final timestamp = DateTime.now();
    final first = StagedSmsTransaction(
      id: 'sms_batch_1',
      smsSender: 'HDFCBK',
      rawBody: 'Rs 100 debited',
      extractedAmount: 100,
      extractedType: 'debit',
      smsTimestamp: timestamp,
      createdAt: fixedDate,
    );
    final second = StagedSmsTransaction(
      id: 'sms_batch_2',
      smsSender: 'ICICIB',
      rawBody: 'Rs 200 credited',
      extractedAmount: 200,
      extractedType: 'credit',
      smsTimestamp: timestamp,
      createdAt: fixedDate,
    );

    final inserted = await databaseService.addStagedSmsBatch([
      first,
      first,
      second,
    ]);

    expect(inserted, 2);
    expect(await databaseService.getPendingStagedSmsIds(), {
      'sms_batch_1',
      'sms_batch_2',
    });
    expect(await databaseService.getStagedSmsTransactions(), hasLength(2));
  });

  test(
    'accepts a staged SMS with its transaction and debts atomically',
    () async {
      final timestamp = DateTime(2026, 1, 15, 10, 30);
      await databaseService.addContact(
        Contact(id: 'cnt_accept', name: 'Alex', createdAt: fixedDate),
      );
      final staged = StagedSmsTransaction(
        id: 'sms_accept',
        smsSender: 'HDFCBK',
        rawBody: 'Rs 300 debited',
        extractedAmount: 300,
        extractedType: 'debit',
        smsTimestamp: timestamp,
        createdAt: fixedDate,
      );
      await databaseService.addStagedSms(staged);

      final transaction = BudgetTransaction(
        id: 'txn_accept',
        amount: 300,
        categoryId: 'cat_food',
        paymentModeId: 'pm_bank',
        title: 'Dinner',
        timestamp: timestamp,
        createdAt: fixedDate,
      );
      final debt = DebtRecord(
        id: 'debt_accept',
        contactId: 'cnt_accept',
        transactionId: transaction.id,
        direction: 'give',
        amount: 150,
        createdAt: fixedDate,
      );

      final accepted = await databaseService.acceptStagedSms(
        stagedSmsId: staged.id,
        transaction: transaction,
        debtRecords: [debt],
      );

      expect(accepted?.id, transaction.id);
      expect(
        (await databaseService.getTransactions()).single.id,
        transaction.id,
      );
      expect((await databaseService.getDebtRecords()).single.id, debt.id);
      expect(
        (await databaseService.getStagedSmsById(staged.id))!.isAccepted,
        isTrue,
      );
      expect(await databaseService.getPendingStagedSmsIds(), isEmpty);

      final duplicate = await databaseService.acceptStagedSms(
        stagedSmsId: staged.id,
        transaction: transaction.copyWith(id: 'txn_duplicate'),
      );
      expect(duplicate, isNull);
      expect(await databaseService.getTransactions(), hasLength(1));
    },
  );

  test('round-trips a versioned JSON backup', () async {
    final budget = createBudget('bud_1');
    await databaseService.addBudget(budget, activate: true);
    await databaseService.addTransaction(
      createTransaction('txn_1', budgetId: budget.id),
    );
    await databaseService.addContact(
      Contact(id: 'cnt_1', name: 'Alex', createdAt: fixedDate),
    );
    await databaseService.addDebtRecord(
      DebtRecord(
        id: 'debt_1',
        contactId: 'cnt_1',
        direction: 'give',
        amount: 500,
        createdAt: fixedDate,
      ),
    );
    await databaseService.addSubscription(
      Subscription(
        id: 'sub_1',
        name: 'Music',
        amount: 199,
        nextDueDate: DateTime.now().add(const Duration(days: 2)),
        isAutopay: true,
        createdAt: fixedDate,
      ),
    );
    await databaseService.addStagedSms(
      StagedSmsTransaction(
        id: 'sms_1',
        smsSender: 'BANK',
        rawBody: 'Rs 100 debited',
        extractedAmount: 100,
        smsTimestamp: DateTime.now(),
        createdAt: fixedDate,
      ),
    );
    await databaseService.setSetting('monthly_salary', '50000', notify: false);
    await databaseService.setSetting(
      'active_account_email',
      'me@example.com',
      notify: false,
    );

    final payload = await backupService.exportAllToJson();
    expect(payload['format'], 'budget_log');
    expect(payload['version'], 1);
    expect(
      (payload['appSettings'] as List<Map<String, Object?>>).any(
        (row) => row['key'] == 'active_account_email',
      ),
      isFalse,
    );
    final stagedRows =
        payload['stagedSmsTransactions'] as List<Map<String, Object?>>;
    expect(stagedRows.single['raw_body'], '');

    await databaseService.addTransaction(createTransaction('txn_extra'));
    await backupService.importAllFromJson(payload);

    final transactions = await databaseService.getTransactions();
    expect(transactions, hasLength(1));
    expect(transactions.single.id, 'txn_1');
    expect(await databaseService.getSetting('monthly_salary'), '50000');
    expect(await databaseService.getSetting('active_account_email'), isNull);
    expect(await databaseService.getPaymentModes(), hasLength(6));
    expect(await databaseService.getCategories(), hasLength(11));
    final subscriptions = await databaseService.getSubscriptions();
    expect(subscriptions.single.isAutopay, isTrue);
  });

  test('clears user data and restores default seed data', () async {
    await databaseService.addTransaction(createTransaction('txn_1'));
    await databaseService.setSetting('monthly_salary', '50000', notify: false);

    await databaseService.clearAllData();

    expect(await databaseService.getTransactions(), isEmpty);
    expect(await databaseService.getPaymentModes(), hasLength(6));
    expect(await databaseService.getCategories(), hasLength(11));
    expect(await databaseService.getSetting('monthly_salary'), isNull);
  });

  test('rejects an incompatible backup payload', () async {
    await expectLater(
      backupService.importAllFromJson({'format': 'study_log'}),
      throwsA(isA<FormatException>()),
    );
  });
}
