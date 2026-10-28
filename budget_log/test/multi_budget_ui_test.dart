import 'dart:io';

import 'package:budget_log/controllers/finance_controller.dart';
import 'package:budget_log/models/budget_tag_mapping.dart';
import 'package:budget_log/screens/budget_screen.dart';
import 'package:budget_log/screens/home_screen.dart';
import 'package:budget_log/screens/manage_budgets_screen.dart';
import 'package:budget_log/screens/transaction_log_screen.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('multi_budget_ui_');
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
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> createActiveBudgets() async {
    await controller.createBudget(
      name: 'Groceries',
      limit: 1000,
      period: 'monthly',
      isActive: true,
    );
    await controller.createBudget(
      name: 'Travel',
      limit: 2000,
      period: 'monthly',
      isActive: true,
    );
  }

  testWidgets('home switches active budgets and shows tags and threshold', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(() async {
      await createActiveBudgets();
      final groceries = controller.budgets.firstWhere(
        (budget) => budget.name == 'Groceries',
      );
      await controller.updateBudget(
        groceries.copyWith(alertThreshold: 0.9),
        expenseTags: const [BudgetTagMapping.miscExpenseTag],
        incomeTags: const [],
      );
    });

    await tester.pumpWidget(
      wrap(HomeScreen(onNavigateToLog: () {}, onNavigateToBudget: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alert at 90%'), findsOneWidget);
    expect(find.text('Groceries'), findsWidgets);
    expect(find.text('Travel'), findsWidgets);

    final groceries = controller.budgets.firstWhere(
      (budget) => budget.name == 'Groceries',
    );
    final travel = controller.budgets.firstWhere(
      (budget) => budget.name == 'Travel',
    );

    await tester.tap(
      find.byKey(ValueKey('active-budget-pill-${groceries.id}')),
    );
    await tester.pump();

    expect(controller.selectedBudgetId, groceries.id);
    expect(find.text('Misc expense'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('active-budget-pill-${travel.id}')));
    await tester.pump();

    expect(controller.selectedBudgetId, travel.id);
  });

  testWidgets('budget screen shares the controller selection with pills', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(createActiveBudgets);
    final groceries = controller.budgets.firstWhere(
      (budget) => budget.name == 'Groceries',
    );
    final travel = controller.budgets.firstWhere(
      (budget) => budget.name == 'Travel',
    );
    await tester.runAsync(() => controller.setSelectedBudget(travel.id));

    await tester.pumpWidget(wrap(const BudgetScreen()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('active-budget-pill-${groceries.id}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('active-budget-pill-${groceries.id}')),
    );
    await tester.pump();

    expect(controller.selectedBudgetId, groceries.id);
  });

  testWidgets('manage budgets enforces activation limit in the menu', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(() async {
      await createActiveBudgets();
      await controller.createBudget(
        name: 'Housing',
        limit: 3000,
        period: 'monthly',
        isActive: true,
      );
      await controller.createBudget(
        name: 'Archived',
        limit: 500,
        period: 'monthly',
        isActive: false,
      );
    });
    final archived = controller.budgets.firstWhere(
      (budget) => budget.name == 'Archived',
    );

    await tester.pumpWidget(wrap(const ManageBudgetsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 of 3 active'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('budget-menu-${archived.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Maximum 3 budgets'), findsOneWidget);
    expect(controller.budgetById(archived.id)!.isActive, isFalse);
  });

  testWidgets('controller activation succeeds after freeing a slot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await createActiveBudgets();
      await controller.createBudget(
        name: 'Housing',
        limit: 3000,
        period: 'monthly',
        isActive: true,
      );
      await controller.createBudget(
        name: 'Archived',
        limit: 500,
        period: 'monthly',
        isActive: false,
      );
      final groceries = controller.budgets.firstWhere(
        (budget) => budget.name == 'Groceries',
      );
      final archived = controller.budgets.firstWhere(
        (budget) => budget.name == 'Archived',
      );
      await controller.setBudgetActive(groceries.id, false);
      expect(controller.activeBudgets, hasLength(2));
      await controller.setBudgetActive(archived.id, true);
      expect(controller.budgetById(archived.id)!.isActive, isTrue);
      expect(controller.activeBudgets, hasLength(3));
    });
  });

  testWidgets('budget screen selects an inactive budget from all budgets', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(() async {
      await createActiveBudgets();
      await controller.createBudget(
        name: 'Archived',
        limit: 500,
        period: 'monthly',
        isActive: false,
      );
    });
    final archived = controller.budgets.firstWhere(
      (budget) => budget.name == 'Archived',
    );

    await tester.pumpWidget(wrap(const BudgetScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Select Budget'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);

    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();

    expect(controller.selectedBudgetId, archived.id);
    expect(find.text('Archived (Inactive)'), findsOneWidget);
  });

  testWidgets('transaction log filters by budget and includes all budgets', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.runAsync(createActiveBudgets);
    final groceries = controller.budgets.firstWhere(
      (budget) => budget.name == 'Groceries',
    );

    await tester.pumpWidget(wrap(const TransactionLogScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();

    expect(find.text('All budgets'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    expect(controller.logFilter.budgetId, groceries.id);
    expect(find.text('Groceries'), findsOneWidget);
  });
}
