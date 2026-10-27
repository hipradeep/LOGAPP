import 'dart:io';

import 'package:budget_log/controllers/contacts_controller.dart';
import 'package:budget_log/controllers/debt_controller.dart';
import 'package:budget_log/controllers/finance_controller.dart';
import 'package:budget_log/controllers/subscription_controller.dart';
import 'package:budget_log/models/subscription.dart';
import 'package:budget_log/screens/add_budget_screen.dart';
import 'package:budget_log/screens/add_contact_screen.dart';
import 'package:budget_log/screens/add_transaction_screen.dart';
import 'package:budget_log/screens/budget_screen.dart';
import 'package:budget_log/screens/categories_screen.dart';
import 'package:budget_log/screens/contact_detail_screen.dart';
import 'package:budget_log/screens/home_screen.dart';
import 'package:budget_log/screens/payment_modes_screen.dart';
import 'package:budget_log/screens/profile_screen.dart';
import 'package:budget_log/screens/subscription_screen.dart';
import 'package:budget_log/screens/transaction_log_screen.dart';
import 'package:budget_log/screens/udar_screen.dart';
import 'package:budget_log/services/database_service.dart';
import 'package:budget_log/services/notification_service.dart';
import 'package:budget_log/services/service_locator.dart';
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
  late ContactsController contactsController;
  late DebtController debtController;
  late SubscriptionController subscriptionController;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('screen_test_');
    databaseService = DatabaseService(
      factory: databaseFactoryFfi,
      path: path.join(tempDirectory.path, 'budget_log.db'),
    );
    await databaseService.init();
    controller = FinanceController(
      dbService: databaseService,
      watchDatabase: false,
    );
    contactsController = ContactsController(
      dbService: databaseService,
      watchDatabase: false,
    );
    debtController = DebtController(
      dbService: databaseService,
      watchDatabase: false,
    );
    subscriptionController = SubscriptionController(
      dbService: databaseService,
      watchDatabase: false,
    );
    await controller.load();
    await contactsController.load();
    await debtController.load();
    await subscriptionController.load();
    getIt.registerSingleton<ContactsController>(contactsController);
    getIt.registerSingleton<DebtController>(debtController);
    getIt.registerSingleton<SubscriptionController>(subscriptionController);
    getIt.registerSingleton<NotificationService>(NotificationService());
  });

  tearDown(() async {
    getIt.reset();
    contactsController.dispose();
    debtController.dispose();
    subscriptionController.dispose();
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

  testWidgets('home, log and budget render their empty states', (tester) async {
    await tester.pumpWidget(
      wrap(HomeScreen(onNavigateToLog: () {}, onNavigateToBudget: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Budget Log'), findsOneWidget);
    expect(find.text('Available this month'), findsOneWidget);
    expect(find.text('No active budget'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const BudgetScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No budgets yet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const TransactionLogScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add transaction and budget forms render', (tester) async {
    await tester.pumpWidget(wrap(AddTransactionScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('Add transaction'), findsWidgets);
    expect(find.text('Category'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const AddBudgetScreen()));
    await tester.pumpAndSettle();
    expect(find.text('New budget'), findsOneWidget);
    expect(find.text('Spending cap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('udar, contact form, and contact ledger render', (tester) async {
    await tester.pumpWidget(wrap(const UdarScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No contacts yet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const AddContactScreen()));
    await tester.pumpAndSettle();
    expect(find.text('New contact'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final contact = await tester.runAsync(
      () => contactsController.createContact(name: 'Alex'),
    );
    await tester.pumpWidget(wrap(ContactDetailScreen(contactId: contact!.id)));
    await tester.pumpAndSettle();
    expect(find.text('Alex'), findsWidgets);
    expect(find.text('No ledger entries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home shows upcoming bills and subscriptions flow renders', (
    tester,
  ) async {
    await tester.runAsync(
      () => subscriptionController.addSubscription(
        Subscription(
          id: 'sub_music',
          name: 'Music',
          amount: 199,
          frequency: 'monthly',
          nextDueDate: DateTime.now().add(const Duration(days: 2)),
          createdAt: DateTime.now(),
        ),
      ),
    );

    await tester.pumpWidget(
      wrap(HomeScreen(onNavigateToLog: () {}, onNavigateToBudget: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Upcoming bills'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final viewAll = find.text('View all').first;
    await tester.ensureVisible(viewAll);
    await tester.pumpAndSettle();
    await tester.tap(viewAll);
    await tester.pumpAndSettle();
    expect(find.byType(SubscriptionScreen), findsOneWidget);
    expect(find.text('Recurring bills'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New subscription'), findsOneWidget);
    expect(find.text('Subscription name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and catalog screens render seeded data', (tester) async {
    await tester.pumpWidget(wrap(const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Guest Spender'), findsOneWidget);
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Subs'), findsOneWidget);
    expect(find.text('Udar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const CategoriesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('EXPENSE'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.runAsync(
      () => controller.createCategory(name: 'Travel', type: 'expense'),
    );
    await tester.pumpWidget(wrap(const CategoriesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Travel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const PaymentModesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Payment modes'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);

    await tester.runAsync(
      () => controller.createPaymentMode(name: 'HDFC', type: 'bank'),
    );
    await tester.pumpWidget(wrap(const PaymentModesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('HDFC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
