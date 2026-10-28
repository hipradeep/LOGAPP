import 'dart:io';

import 'package:budget_log/controllers/finance_controller.dart';
import 'package:budget_log/models/budget.dart';
import 'package:budget_log/models/budget_tag_mapping.dart';
import 'package:budget_log/screens/add_budget_screen.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:budget_log/theme/app_theme.dart';
import 'package:budget_log/widgets/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late DatabaseService databaseService;
  late FinanceController controller;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('budget_form_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    controller = FinanceController(
      dbService: databaseService,
      watchDatabase: false,
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

  Widget wrap(Widget child) {
    return AppProvider<FinanceController>(
      notifier: controller,
      child: MaterialApp(theme: AppTheme.themeData, home: child),
    );
  }

  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('new budgets default to all tracked tags', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(wrap(const AddBudgetScreen()));
    await tester.pumpAndSettle();

    final expenseCount = controller.budgetTagOptions(expense: true).length;
    final incomeCount = controller.budgetTagOptions(expense: false).length;

    expect(find.text('Tracked tags'), findsOneWidget);
    expect(find.text('Expense ($expenseCount/$expenseCount)'), findsOneWidget);
    expect(find.text('Income ($incomeCount/$incomeCount)'), findsOneWidget);
    expect(find.text('Misc expense'), findsOneWidget);
  });

  testWidgets('editing loads the saved tag mapping', (tester) async {
    await useTallViewport(tester);
    late String budgetId;
    await tester.runAsync(() async {
      await controller.createBudget(
        name: 'Editable',
        limit: 1000,
        period: 'monthly',
        isActive: false,
      );
      final budget = controller.budgets.first;
      budgetId = budget.id;
      await controller.updateBudget(
        budget,
        expenseTags: [BudgetTagMapping.miscExpenseTag],
        incomeTags: [BudgetTagMapping.miscIncomeTag],
      );
    });
    final updated = controller.budgetById(budgetId)!;

    await tester.pumpWidget(wrap(AddBudgetScreen(existingBudget: updated)));
    await tester.pumpAndSettle();

    final expenseCount = controller.budgetTagOptions(expense: true).length;
    final incomeCount = controller.budgetTagOptions(expense: false).length;

    expect(find.text('Expense (1/$expenseCount)'), findsOneWidget);
    expect(find.text('Income (1/$incomeCount)'), findsOneWidget);
  });

  testWidgets('warns when a fourth active budget would be created', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(() async {
      var index = controller.activeBudgets.length;
      while (controller.activeBudgets.length < 3) {
        index++;
        await controller.createBudget(
          name: 'Active $index',
          limit: 1000,
          period: 'monthly',
          isActive: true,
        );
      }
    });

    await tester.pumpWidget(wrap(const AddBudgetScreen()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Maximum 3 budgets can be active at a time'),
      findsOneWidget,
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Fourth budget');
    await tester.enterText(fields.at(1), '500');
    await tester.tap(find.text('Create budget'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Maximum 3 budgets can be active at a time'),
      findsWidgets,
    );
    expect(controller.activeBudgets, hasLength(3));
    expect(
      controller.budgets.where((budget) => budget.name == 'Fourth budget'),
      isEmpty,
    );
  });

  testWidgets('saving a new budget persists both tag mappings', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(wrap(const AddBudgetScreen()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Tagged budget');
    await tester.enterText(fields.at(1), '1500');

    await tester.runAsync(() async {
      await tester.tap(find.text('Create budget'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final budget = controller.budgets.firstWhere(
      (item) => item.name == 'Tagged budget',
    );
    expect(
      controller.expenseTagsForBudget(budget.id).toSet(),
      controller.budgetTagOptions(expense: true).toSet(),
    );
    expect(
      controller.incomeTagsForBudget(budget.id).toSet(),
      controller.budgetTagOptions(expense: false).toSet(),
    );
  });

  testWidgets('copying a budget preserves source fields and tags', (
    tester,
  ) async {
    await useTallViewport(tester);
    late String sourceId;
    await tester.runAsync(() async {
      await controller.createBudget(
        name: 'Source',
        limit: 1000,
        period: 'monthly',
        isActive: false,
      );
      final source = controller.budgets.first;
      sourceId = source.id;
      await controller.updateBudget(
        source.copyWith(
          repeatDays: const [1, 3, 5],
          scheduledTime: '09:30',
          repeat: false,
          salary: 25000,
          rule: '50/30/20',
          allocations: const [
            BudgetCategoryAllocation(
              name: 'Needs',
              percentage: 50,
              amount: 500,
            ),
          ],
        ),
        expenseTags: [BudgetTagMapping.miscExpenseTag],
        incomeTags: [BudgetTagMapping.miscIncomeTag],
      );
    });

    final source = controller.budgetById(sourceId)!;
    await tester.pumpWidget(
      wrap(AddBudgetScreen(existingBudget: source, isCopy: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy budget'), findsOneWidget);
    expect(find.text('Source (Copy)'), findsOneWidget);
    expect(find.text('Create copy'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Create copy'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final copy = controller.budgets.singleWhere(
      (budget) => budget.name == 'Source (Copy)',
    );
    expect(copy.id, isNot(sourceId));
    expect(copy.repeatDays, [1, 3, 5]);
    expect(copy.scheduledTime, '09:30');
    expect(copy.repeat, isFalse);
    expect(copy.salary, 25000);
    expect(copy.rule, '50/30/20');
    expect(copy.allocations.single.name, 'Needs');
    expect(controller.expenseTagsForBudget(copy.id).toSet(), {
      BudgetTagMapping.miscExpenseTag,
    });
    expect(controller.incomeTagsForBudget(copy.id).toSet(), {
      BudgetTagMapping.miscIncomeTag,
    });
    expect(controller.budgetById(sourceId)!.name, 'Source');
  });

  testWidgets('copying an active budget respects the active limit', (
    tester,
  ) async {
    await useTallViewport(tester);
    late String sourceId;
    await tester.runAsync(() async {
      for (var index = 1; index <= 3; index++) {
        await controller.createBudget(
          name: 'Active $index',
          limit: 1000,
          period: 'monthly',
          isActive: true,
        );
      }
      sourceId = controller.activeBudgets.first.id;
    });

    final source = controller.budgetById(sourceId)!;
    await tester.pumpWidget(
      wrap(AddBudgetScreen(existingBudget: source, isCopy: true)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Maximum 3 budgets can be active at a time'),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Create copy'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(controller.activeBudgets, hasLength(3));
    expect(
      controller.budgets.where((budget) => budget.name.contains('(Copy)')),
      isEmpty,
    );
  });
}
