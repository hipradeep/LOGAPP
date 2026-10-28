import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/active_budget_switcher.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/budget_expense_graph.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/budget_selector_sheet.dart';
import '../widgets/category_breakdown_sheet.dart';
import '../widgets/tab_header.dart';
import '../widgets/transaction_tile.dart';
import 'add_budget_screen.dart';
import 'add_transaction_screen.dart';
import 'budget_transactions_screen.dart';

class BudgetScreen extends StatefulWidget {
  final String? initialBudgetId;

  const BudgetScreen({super.key, this.initialBudgetId});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final initialBudgetId = widget.initialBudgetId;
    if (initialBudgetId != null) {
      final controller = AppProvider.read<FinanceController>(context);
      if (controller.selectedBudgetId != initialBudgetId) {
        controller.setSelectedBudget(initialBudgetId);
      }
    }
  }

  Budget? _resolveSelectedBudget(FinanceController controller) {
    final selected = controller.selectedBudget;
    if (selected != null) return selected;
    return controller.activeBudget ??
        (controller.budgets.isEmpty ? null : controller.budgets.first);
  }

  void _openAddBudget(
    BuildContext context, {
    Budget? budget,
    bool isCopy = false,
  }) {
    final effectiveBudget = isCopy && budget != null
        ? budget.copyWith(id: '', name: '${budget.name} (Copy)')
        : budget;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(existingBudget: effectiveBudget),
      ),
    );
  }

  void _showAddTransaction(
    BuildContext context,
    Budget budget,
    FinanceController controller,
  ) {
    AddTransactionScreen.showModal(
      context,
      controller: controller,
      initialBudgetId: budget.id,
    );
  }

  void _handleExpenseTap(
    BuildContext context,
    BudgetTransaction transaction,
    FinanceController controller,
  ) {
    AddTransactionScreen.showModal(
      context,
      controller: controller,
      existingTransaction: transaction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.read<FinanceController>(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'Budget',
              subtitle: 'Track spending against category limits.',
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  if (controller.isLoading && controller.budgets.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final budgets = controller.budgets;
                  if (budgets.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No Budget Limits Set',
                      description:
                          'Define limits for categories to track and optimize your spending.',
                      actionLabel: 'Set Budget Limit',
                      onActionPressed: () => _openAddBudget(context),
                    );
                  }

                  final selectedBudget = _resolveSelectedBudget(controller);
                  if (selectedBudget == null) {
                    return const SizedBox.shrink();
                  }
                  final activeBudgets = controller.activeBudgets;

                  final bottomPadding = MediaQuery.paddingOf(context).bottom;

                  return RefreshIndicator(
                    onRefresh: controller.reload,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: AppTheme.spacingMd,
                        right: AppTheme.spacingMd,
                        top: AppTheme.spacingSm,
                        bottom: bottomPadding + 96,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activeBudgets.length > 1) ...[
                            ActiveBudgetSwitcher(
                              budgets: activeBudgets,
                              selectedBudgetId: selectedBudget.id,
                              onSelected: controller.setSelectedBudget,
                            ),
                            const VGapSm(),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _buildBudgetDropdown(
                                  budgets,
                                  selectedBudget,
                                ),
                              ),
                              const HGapSm(),
                              _buildCalendarButton(context, selectedBudget),
                              const HGapSm(),
                              _buildProgressButton(
                                context,
                                selectedBudget,
                                controller,
                              ),
                            ],
                          ),
                          const VGapMd(),
                          _buildSelectedBudgetDetails(
                            selectedBudget,
                            controller,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final selectedBudget = _resolveSelectedBudget(controller);
          if (selectedBudget == null || selectedBudget.isPeriodOver) {
            return const SizedBox.shrink();
          }

          return AppFab(
            icon: Icons.add_rounded,
            tooltip: 'Add Transaction',
            onPressed: () =>
                _showAddTransaction(context, selectedBudget, controller),
          );
        },
      ),
    );
  }

  Widget _buildBudgetDropdown(List<Budget> budgets, Budget current) {
    String suffix = '';
    if (current.isPeriodOver) {
      suffix = ' (Ended)';
    } else if (!current.isActive) {
      suffix = ' (Inactive)';
    }

    return InkWell(
      onTap: () {
        BudgetSelectorSheet.show(
          context,
          budgets: budgets,
          selectedBudgetId: current.id,
          onSelected: (id) {
            if (id != null) {
              AppProvider.read<FinanceController>(
                context,
              ).setSelectedBudget(id);
            }
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${current.name}$suffix',
                style: TextStyle(
                  color: current.isActive && !current.isPeriodOver
                      ? AppTheme.textPrimaryColor(context)
                      : AppTheme.textSecondaryColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedBudgetDetails(
    Budget budget,
    FinanceController controller,
  ) {
    final spent = controller.spentForBudget(budget.id);
    final percent = budget.limit > 0
        ? (spent / budget.limit).clamp(0.0, 1.0)
        : 0.0;
    final isOver = controller.isOverBudget(budget.id);
    final isActive = budget.isActive;

    final Color statusColor = !isActive
        ? AppTheme.successColor
        : (isOver
              ? AppTheme.errorColor
              : (percent >= budget.alertThreshold
                    ? AppTheme.warningColor
                    : AppTheme.primaryColor));

    final budgetTransactions = controller.transactionsForBudget(budget.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Visual Progress Card
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                budget.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor(context),
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (budget.categoryName.trim().isNotEmpty) ...[
                              const HGapSm(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  budget.categoryName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AppTheme.primaryLight,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (budget.period == 'weekly'
                                            ? AppTheme.pastelBlueText(context)
                                            : AppTheme.textPrimaryColor(
                                                context,
                                              ))
                                        .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.period.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: budget.period == 'weekly'
                                      ? AppTheme.pastelBlueText(context)
                                      : AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (budget.period == 'custom' &&
                            budget.startDate != null &&
                            budget.endDate != null) ...[
                          const VGapXs(),
                          _buildCardTag(
                            Icons.calendar_today_rounded,
                            '${DateFormat('MMM d').format(budget.startDate!)} - ${DateFormat('MMM d').format(budget.endDate!)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.successColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const HGapSm(),
                      GestureDetector(
                        onTap: () =>
                            _showCategoryBreakdown(budget, budgetTransactions),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.pie_chart_outline_rounded,
                            size: 15,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const VGapMd(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ${AppFormat.currency(spent)}',
                    style: TextStyle(
                      color: isOver && isActive
                          ? AppTheme.errorColor
                          : AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Limit: ${AppFormat.currency(budget.limit)}',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const VGapMd(),
              BudgetProgressBar(
                percent: percent,
                alertThreshold: budget.alertThreshold,
                statusColor: statusColor,
                minHeight: 6,
              ),
            ],
          ),
        ),

        if (budget.isPeriodOver) ...[
          const VGapMd(),
          _buildPeriodOverBanner(budget),
        ],

        const VGapMd(),

        // 2. Expense History Bar Graph
        RepaintBoundary(
          child: BudgetExpenseGraph(
            budget: budget,
            transactions: controller.transactions,
          ),
        ),

        const VGapMd(),

        // 3. Expense History List (Last 15 transactions)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expense History',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const VGapSm(),

        () {
          final sortedExpenses = List<BudgetTransaction>.from(
            budgetTransactions,
          )..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (sortedExpenses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions found for this budget.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          final recentExpenses = sortedExpenses.take(15).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: recentExpenses.length,
                separatorBuilder: (_, _) => const VGapSm(),
                itemBuilder: (context, index) {
                  final expense = recentExpenses[index];
                  return TransactionTile(
                    transaction: expense,
                    category: controller.categoryById(expense.categoryId),
                    paymentMode: controller.paymentModeById(
                      expense.paymentModeId,
                    ),
                    onTap: () =>
                        _handleExpenseTap(context, expense, controller),
                  );
                },
              ),
              const VGapMd(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BudgetTransactionsScreen(
                          initialBudgetId: budget.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text(
                    'View All Transactions (${sortedExpenses.length})',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.cardBorderRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }(),
      ],
    );
  }

  Widget _buildPeriodOverBanner(Budget budget) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.errorColor,
                size: 18,
              ),
              const HGapSm(),
              Text(
                'Budget Period Over',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const VGapSm(),
          Text(
            'This budget period ended on ${DateFormat('MMMM d, yyyy').format(budget.endDate!)}. This budget is now read-only.',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAddBudget(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Budget'),
                ),
              ),
              const HGapSm(),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openAddBudget(context, budget: budget, isCopy: true),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Budget'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textSecondaryColor(context)),
          const HGapXs(),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarButton(BuildContext context, Budget budget) {
    final hasDates = budget.startDate != null || budget.endDate != null;

    return Tooltip(
      message: hasDates ? 'View Budget Dates' : 'No Dates Set',
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface(context),
              title: Text(
                budget.name,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (budget.description.isNotEmpty) ...[
                    Text(
                      budget.description,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 13,
                      ),
                    ),
                    const VGapMd(),
                  ],
                  Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: AppTheme.primaryLight,
                        size: 16,
                      ),
                      const HGapSm(),
                      Text(
                        budget.startDate != null
                            ? 'Start: ${DateFormat('MMM d, yyyy').format(budget.startDate!)}'
                            : 'Start: Not set',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const VGapSm(),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        color: AppTheme.successColor,
                        size: 16,
                      ),
                      const HGapSm(),
                      Text(
                        budget.endDate != null
                            ? 'End: ${DateFormat('MMM d, yyyy').format(budget.endDate!)}'
                            : 'End: Not set',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hasDates
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : AppTheme.surface(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasDates
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: hasDates
                ? AppTheme.primaryLight
                : AppTheme.textSecondaryColor(context),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressButton(
    BuildContext context,
    Budget budget,
    FinanceController controller,
  ) {
    final total = budget.limit;
    final spent = budget.spentForCurrentPeriod(controller.transactions);
    final percent = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget(controller.transactions);
    final isActive = budget.isActive;

    final Color statusColor = !isActive
        ? AppTheme.successColor
        : (isOver
              ? AppTheme.errorColor
              : (percent >= budget.alertThreshold
                    ? AppTheme.warningColor
                    : AppTheme.primaryColor));

    return Tooltip(
      message:
          'Progress: ${AppFormat.currency(spent)} / ${AppFormat.currency(total)} (${(percent * 100).toStringAsFixed(0)}%)',
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Budget Progress: ${AppFormat.currency(spent)} of ${AppFormat.currency(total)} spent (${(percent * 100).toStringAsFixed(0)}%)',
                style: TextStyle(color: AppTheme.textPrimaryColor(context)),
              ),
              backgroundColor: AppTheme.surface(context),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 2.5,
                backgroundColor: AppTheme.surfaceVariant(context),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCategoryBreakdown(
    Budget budget,
    List<BudgetTransaction> transactions,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CategoryBreakdownSheet(
        budget: budget,
        transactions: transactions,
        getTagIcon: _getTagIcon,
        getTagColor: _getTagColor,
        getTagName: _getTagName,
      ),
    );
  }

  static const _tagIcons = <String, IconData>{
    'grocery': Icons.local_grocery_store_rounded,
    'food': Icons.fastfood_rounded,
    'meals': Icons.restaurant_rounded,
    'drinks': Icons.local_bar_rounded,
    'travel': Icons.flight_rounded,
    'home': Icons.home_rounded,
    'bills': Icons.receipt_long_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'health': Icons.medical_services_rounded,
  };

  static const _tagColors = <String, Color>{
    'grocery': Colors.green,
    'food': Colors.orange,
    'meals': Colors.deepOrange,
    'drinks': Colors.cyan,
    'travel': Colors.indigo,
    'home': Colors.blueGrey,
    'bills': Colors.redAccent,
    'shopping': Colors.pinkAccent,
    'fuel': Colors.blue,
    'health': Colors.teal,
  };

  String _getTagName(String name) {
    final lower = name.toLowerCase();
    for (final k in _tagIcons.keys) {
      if (lower.contains(k)) {
        return k[0].toUpperCase() + k.substring(1);
      }
    }
    return name.isNotEmpty ? name : 'General';
  }

  IconData _getTagIcon(String name) {
    final lower = name.toLowerCase();
    for (final e in _tagIcons.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return Icons.payment_rounded;
  }

  Color _getTagColor(String name) {
    final lower = name.toLowerCase();
    for (final e in _tagColors.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return AppTheme.primaryColor;
  }
}
