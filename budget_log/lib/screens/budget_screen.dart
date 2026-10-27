import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/budget_expense_graph.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/category_breakdown_sheet.dart';
import '../widgets/tab_header.dart';
import '../widgets/transaction_filter_sheet.dart';
import 'add_budget_screen.dart';
import 'add_transaction_screen.dart';

class BudgetScreen extends StatefulWidget {
  final String? initialBudgetId;

  const BudgetScreen({super.key, this.initialBudgetId});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  String? _selectedBudgetId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _filterType = 'all'; // 'all', 'debit', 'credit'

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.initialBudgetId;
    _filterStartDate = DateTime.now().subtract(const Duration(days: 30));
    _filterEndDate = DateTime.now();
  }

  void _openAddBudget(BuildContext context, {Budget? budget, bool isCopy = false}) {
    final effectiveBudget = isCopy && budget != null
        ? budget.copyWith(id: '', name: '${budget.name} (Copy)')
        : budget;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(
          existingBudget: effectiveBudget,
        ),
      ),
    );
  }

  void _showAddTransaction(
    BuildContext context,
    Budget budget,
    FinanceController controller,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          controller: controller,
          initialBudgetId: budget.id,
        ),
      ),
    );
  }

  void _handleExpenseTap(
    BuildContext context,
    BudgetTransaction transaction,
    FinanceController controller,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          controller: controller,
          existingTransaction: transaction,
        ),
      ),
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

                  // Default selected budget
                  Budget? selectedBudget;
                  if (_selectedBudgetId != null) {
                    for (final b in budgets) {
                      if (b.id == _selectedBudgetId) {
                        selectedBudget = b;
                        break;
                      }
                    }
                  }
                  selectedBudget ??= budgets.first;

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
                          Row(
                            children: [
                              Expanded(
                                child: _buildBudgetDropdown(budgets, selectedBudget),
                              ),
                              const HGapSm(),
                              _buildCalendarButton(context, selectedBudget),
                              const HGapSm(),
                              _buildProgressButton(context, selectedBudget, controller),
                            ],
                          ),
                          const VGapMd(),
                          _buildSelectedBudgetDetails(selectedBudget, controller),
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
          final budgets = controller.budgets;
          if (budgets.isEmpty) return const SizedBox.shrink();

          Budget? selectedBudget;
          if (_selectedBudgetId != null) {
            for (final b in budgets) {
              if (b.id == _selectedBudgetId) {
                selectedBudget = b;
                break;
              }
            }
          }
          selectedBudget ??= budgets.first;

          if (selectedBudget.isPeriodOver) {
            return const SizedBox.shrink();
          }

          return AppFab(
            icon: Icons.add_rounded,
            tooltip: 'Add Transaction',
            onPressed: () => _showAddTransaction(context, selectedBudget!, controller),
          );
        },
      ),
    );
  }

  Widget _buildBudgetDropdown(List<Budget> budgets, Budget current) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppTheme.surface(context),
          isExpanded: true,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondaryColor(context),
            size: 20,
          ),
          value: current.id,
          items: budgets.map((budget) {
            String suffix = '';
            if (budget.isPeriodOver) {
              suffix = ' (Ended)';
            } else if (!budget.isActive) {
              suffix = ' (Inactive)';
            }
            return DropdownMenuItem<String>(
              value: budget.id,
              child: Text(
                '${budget.name}$suffix',
                style: TextStyle(
                  color: budget.isActive && !budget.isPeriodOver
                      ? AppTheme.textPrimaryColor(context)
                      : AppTheme.textSecondaryColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              setState(() => _selectedBudgetId = id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectedBudgetDetails(Budget budget, FinanceController controller) {
    final spent = budget.spentForCurrentPeriod(controller.transactions);
    final percent = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget(controller.transactions);
    final isActive = budget.isActive;

    final Color statusColor = !isActive
        ? AppTheme.successColor
        : (isOver
            ? AppTheme.errorColor
            : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor));

    final budgetTransactions = controller.transactions
        .where((t) => t.budgetId == budget.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Visual Progress Card
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
              width: 1.0,
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
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.categoryName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.primaryLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.period.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondaryColor(context),
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
                            color: AppTheme.successColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.successColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const HGapSm(),
                      GestureDetector(
                        onTap: () => _showCategoryBreakdown(budget, budgetTransactions),
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

        // 3. Filtered Expenses History List
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
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: (_filterStartDate != null || _filterType != 'all')
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondaryColor(context),
                size: 20,
              ),
              onPressed: _showFilterSheet,
              tooltip: 'Filter Expenses',
            ),
          ],
        ),
        const VGapSm(),

        () {
          final filteredExpenses = budgetTransactions.where((expense) {
            if (_filterStartDate != null &&
                expense.timestamp.isBefore(_filterStartDate!)) {
              return false;
            }
            if (_filterEndDate != null &&
                expense.timestamp.isAfter(
                  _filterEndDate!.add(const Duration(days: 1)),
                )) {
              return false;
            }
            if (_filterType == 'debit' && !expense.isExpense) return false;
            if (_filterType == 'credit' && expense.isExpense) return false;
            return true;
          }).toList();

          filteredExpenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (filteredExpenses.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No matching expenses found.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filteredExpenses.length,
            itemBuilder: (context, index) {
              final expense = filteredExpenses[index];
              final formattedDate =
                  DateFormat('d MMM yyyy · h:mm a').format(expense.timestamp);
              final isGain = !expense.isExpense;
              final categoryName = _getTagName(expense.title);
              final icon = _getTagIcon(categoryName);
              final color = _getTagColor(categoryName);

              return GestureDetector(
                onTap: () => _handleExpenseTap(context, expense, controller),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      const HGapMd(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor(context),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const VGapXs(),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const HGapMd(),
                      Text(
                        '${isGain ? '+' : '-'}${AppFormat.currency(expense.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isGain
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
                  onPressed: () => _openAddBudget(context, budget: budget, isCopy: true),
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
          Icon(
            icon,
            size: 10,
            color: AppTheme.textSecondaryColor(context),
          ),
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
            : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor));

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
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                ),
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
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
            ),
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TransactionFilterSheet(
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        initialType: _filterType,
        onApply: (start, end, type) {
          setState(() {
            _filterStartDate = start;
            _filterEndDate = end;
            _filterType = type;
          });
        },
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
