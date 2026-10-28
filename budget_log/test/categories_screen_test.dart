import 'dart:io';

import 'package:budget_log/controllers/finance_controller.dart';
import 'package:budget_log/screens/categories_screen.dart';
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
    tempDirectory = await Directory.systemTemp.createTemp('categories_test_');
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

  testWidgets('category form offers expense, income, and both relations', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(Scaffold(body: CategoryFormSheet(controller: controller))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);

    await tester.tap(find.text('Both'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Shared categories can be used in both expense and income logs.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shared categories render in both sections with a badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(
      () => controller.createCategory(name: 'Joint', type: 'both'),
    );

    await tester.pumpWidget(wrap(const CategoriesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Joint'), findsNWidgets(2));
    expect(find.text('Shared'), findsNWidgets(2));
    expect(find.text('Expense & income'), findsNWidgets(2));
    expect(find.text('EXPENSE'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
  });
}
