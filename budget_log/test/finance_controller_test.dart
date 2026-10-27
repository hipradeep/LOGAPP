import 'dart:io';

import 'package:budget_log/controllers/finance_controller.dart';
import 'package:budget_log/models/budget_transaction.dart';
import 'package:budget_log/models/contact.dart';
import 'package:budget_log/models/debt_record.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late FinanceController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('finance_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    controller = FinanceController(dbService: databaseService);
    await controller.load();
  });

  tearDown(() async {
    controller.dispose();
    await databaseService.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('loads seed data and creates the first active budget', () async {
    expect(controller.isLoading, isFalse);
    expect(controller.categories, hasLength(11));
    expect(controller.paymentModes, hasLength(6));
    expect(controller.categoriesForType('expense'), hasLength(10));
    expect(controller.categoriesForType('income'), hasLength(1));

    await controller.setMonthlySalary(50000);
    await controller.createBudget(
      name: 'Monthly living',
      limit: 20000,
      period: 'monthly',
      categoryName: 'Expenses',
    );

    expect(controller.monthlySalary, 50000);
    expect(controller.budgets, hasLength(1));
    expect(controller.selectedBudget, isNotNull);
    expect(controller.selectedBudget!.isActive, isTrue);
  });

  test('aggregates monthly totals and filters the transaction log', () async {
    await controller.setMonthlySalary(50000);
    await controller.createBudget(
      name: 'Monthly living',
      limit: 20000,
      period: 'monthly',
    );
    final budgetId = controller.selectedBudgetId!;
    final now = DateTime.now();

    await controller.saveTransaction(
      BudgetTransaction(
        id: 'txn_expense',
        amount: 1200,
        type: 'expense',
        categoryId: 'cat_food',
        paymentModeId: 'pm_upi',
        budgetId: budgetId,
        title: 'Lunch',
        note: 'Office lunch',
        timestamp: now.subtract(const Duration(hours: 2)),
        createdAt: now,
      ),
    );
    await controller.saveTransaction(
      BudgetTransaction(
        id: 'txn_income',
        amount: 50000,
        type: 'income',
        categoryId: 'cat_salary',
        paymentModeId: 'pm_bank',
        title: 'Salary',
        timestamp: now,
        createdAt: now,
      ),
    );

    expect(controller.monthlyExpense, 1200);
    expect(controller.monthlyIncome, 50000);
    expect(controller.availableToSpend, 48800);
    expect(controller.selectedBudgetSpent, 1200);
    expect(controller.recentTransactions.first.title, 'Salary');
    expect(controller.topCategorySpend.first.category?.name, 'Food');

    controller.setLogFilter(const LogFilter(query: 'office'));
    expect(controller.filteredTransactions, hasLength(1));
    expect(controller.filteredTransactions.single.id, 'txn_expense');

    controller.setLogFilter(const LogFilter(type: 'income'));
    expect(controller.filteredTransactions, hasLength(1));
    expect(controller.filteredTransactions.single.id, 'txn_income');

    controller.setLogFilter(
      LogFilter(startDate: now.subtract(const Duration(days: 1)), endDate: now),
    );
    expect(controller.filteredTransactions, hasLength(2));

    controller.clearLogFilter();
    expect(controller.filteredTransactions, hasLength(2));
  });

  test('updates and deletes transactions and budgets', () async {
    await controller.createBudget(
      name: 'Monthly living',
      limit: 20000,
      period: 'monthly',
    );
    final budgetId = controller.selectedBudgetId!;
    final now = DateTime.now();

    await controller.saveTransaction(
      BudgetTransaction(
        id: 'txn_edit',
        amount: 300,
        type: 'expense',
        categoryId: 'cat_transport',
        paymentModeId: 'pm_cash',
        budgetId: budgetId,
        title: 'Auto',
        timestamp: now,
        createdAt: now,
      ),
    );

    final saved = controller.transactions.single;
    await controller.saveTransaction(
      saved.copyWith(amount: 450, title: 'Auto fare'),
    );
    expect(controller.transactions.single.amount, 450);
    expect(controller.transactions.single.title, 'Auto fare');

    await controller.deleteBudget(budgetId);
    expect(controller.budgets, isEmpty);
    expect(controller.transactions.single.budgetId, isNull);

    await controller.deleteTransaction('txn_edit');
    expect(controller.transactions, isEmpty);
    expect(controller.monthlyExpense, 0);
  });

  test('creates, updates, validates and deletes catalog entries', () async {
    final category = await controller.createCategory(
      name: '  Travel ',
      type: 'expense',
      colorIndex: 3,
    );
    expect(category.name, 'Travel');
    expect(controller.categories.any((item) => item.id == category.id), isTrue);

    await expectLater(
      controller.createCategory(name: 'travel', type: 'expense'),
      throwsArgumentError,
    );
    await expectLater(
      controller.createCategory(name: 'Invalid', type: 'other'),
      throwsArgumentError,
    );

    await controller.updateCategory(
      category.copyWith(name: ' Trips ', colorIndex: 4),
    );
    final updatedCategory = controller.categories.firstWhere(
      (item) => item.id == category.id,
    );
    expect(updatedCategory.name, 'Trips');
    expect(updatedCategory.colorIndex, 4);

    final mode = await controller.createPaymentMode(
      name: ' HDFC ',
      type: 'bank',
    );
    expect(mode.name, 'HDFC');
    expect(controller.paymentModes.any((item) => item.id == mode.id), isTrue);

    await expectLater(
      controller.createPaymentMode(name: 'hdfc', type: 'bank'),
      throwsArgumentError,
    );
    await expectLater(
      controller.createPaymentMode(name: 'Invalid', type: 'crypto'),
      throwsArgumentError,
    );

    await controller.updatePaymentMode(
      mode.copyWith(name: 'HDFC UPI', type: 'wallet'),
    );
    final updatedMode = controller.paymentModes.firstWhere(
      (item) => item.id == mode.id,
    );
    expect(updatedMode.name, 'HDFC UPI');
    expect(updatedMode.type, 'wallet');

    await controller.deleteCategory(category.id);
    await controller.deletePaymentMode(mode.id);
    expect(
      controller.categories.any((item) => item.id == category.id),
      isFalse,
    );
    expect(controller.paymentModes.any((item) => item.id == mode.id), isFalse);
  });

  test('saves a split expense with linked debt records', () async {
    final contact = Contact(
      id: 'cnt_split',
      name: 'Alex',
      createdAt: DateTime.now(),
    );
    await databaseService.addContact(contact);
    final now = DateTime.now();
    final transaction = BudgetTransaction(
      id: 'txn_split',
      amount: 600,
      type: 'expense',
      categoryId: 'cat_food',
      paymentModeId: 'pm_upi',
      title: 'Dinner',
      timestamp: now,
      createdAt: now,
    );

    await controller.saveTransactionWithDebts(transaction, [
      DebtRecord(
        id: 'debt_split',
        contactId: contact.id,
        transactionId: transaction.id,
        direction: 'give',
        amount: 300,
        createdAt: now,
      ),
    ]);

    expect(controller.transactions, hasLength(1));
    expect(controller.monthlyExpense, 600);
    final debts = await databaseService.getDebtRecords();
    expect(debts, hasLength(1));
    expect(debts.single.transactionId, transaction.id);
  });
}
