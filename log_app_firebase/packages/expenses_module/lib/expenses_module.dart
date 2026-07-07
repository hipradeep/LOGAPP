
import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';
import 'src/screens/budget_screen.dart';

export 'src/models/budget.dart';
export 'src/services/budget_service.dart';
export 'src/controllers/budget_controller.dart';
export 'src/screens/budget_screen.dart';
export 'src/screens/add_budget_screen.dart';
export 'src/screens/manage_budget_screen.dart';
export 'src/screens/expense_category_screen.dart';
export 'src/screens/payment_mode_screen.dart';
export 'src/widgets/add_transaction_sheet.dart';
export 'src/widgets/budget_daily_expense_graph.dart';
export 'src/widgets/budget_details_sheet.dart';
export 'src/widgets/budget_expense_graph.dart';
export 'src/widgets/budget_monthly_expense_graph.dart';
export 'src/widgets/budget_progress_bar.dart';
export 'src/widgets/category_breakdown_sheet.dart';
export 'src/widgets/expense_donut_chart.dart';
export 'src/widgets/transaction_filter_sheet.dart';

class ExpensesModule implements AppModule {
  @override
  String get id => 'expenses';

  @override
  String get name => 'Budget & Expenses';

  @override
  String get description => 'Track budgets, categories, payment modes and transaction history';

  @override
  bool get isPremium => false;

  @override
  Future<void> initialize() async {
    // No specific global initialization needed as services are instantiated on-demand
  }

  @override
  Future<void> shutdown() async {
    // No global cleanup needed
  }

  @override
  Widget buildDashboardWidget(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  List<NavigationItem> getNavigationItems(BuildContext context) {
    return [
      NavigationItem(
        icon: Icons.account_balance_wallet,
        label: 'Budget',
        route: '/budget',
        builder: (context) => const BudgetScreen(),
      ),
    ];
  }
}
