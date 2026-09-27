import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/expense_donut_chart.dart';
import '../widgets/app_premium_fab.dart';
import 'add_transaction_screen.dart';
import '../widgets/app_empty_state.dart';
import 'add_budget_screen.dart';

class HomeScreen extends StatelessWidget {
  final BudgetController controller;
  final VoidCallback onNavigateToLog;
  final VoidCallback onNavigateToBudget;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNavigateToLog,
    required this.onNavigateToBudget,
  });

  // Cached formatters to eliminate expensive allocations in build cycles (Rule 14)
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final DateFormat _transactionDateFormat = DateFormat('d MMM, hh:mm a');

  static String formatInr(double amount) => _currencyFormat.format(amount);
  static String formatTransactionDate(DateTime date) => _transactionDateFormat.format(date);

  void _handleFabPressed(BuildContext context) {
    final budget = controller.selectedBudget;
    if (controller.budgets.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
      );
    } else {
      AddTransactionScreen.navigate(
        context,
        budgetId: budget?.id,
        budgets: controller.budgets,
      );
    }
  }

  void _handleCreateBudget(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
    );
  }

  void _showSalaryDialog(BuildContext context) {
    final textController = TextEditingController(
      text: controller.monthlySalary.toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Monthly Income / Salary', style: AppTheme.headingSmall),
        content: TextField(
          controller: textController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTheme.bodyLarge,
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: '50000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(textController.text.trim());
              if (val != null) {
                controller.updateSalary(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final budget = controller.selectedBudget;
        final transactions = controller.transactions;
        final activeBudgetTransactions = controller.selectedBudgetTransactions;
        final totalSpentMonth = controller.totalSpentCurrentMonth;
        final salary = controller.monthlySalary;
        final salarySavings = (salary - totalSpentMonth).clamp(0.0, double.infinity);

        return Stack(
          children: [
            FullScreenPage(
              showScaffold: false,
              isScrollable: true,
              title: 'Budget/Log',
              headerSpacing: MediaQuery.paddingOf(context).top + 52.0,
              padding: AppTheme.defaultScreenPadding,
              backgroundWidgets: [
                GlowBlob(
                  top: -40,
                  left: -40,
                  size: 220,
                  color: AppTheme.primaryColor,
                  opacity: 0.12,
                ),
                GlowBlob(
                  bottom: -50,
                  right: -50,
                  size: 260,
                  color: AppTheme.secondaryColor,
                  opacity: 0.08,
                ),
              ],
              children: [
                const VGapSm(),
                _HomeSalaryCard(
                  salary: salary,
                  totalSpent: totalSpentMonth,
                  savings: salarySavings,
                  onTap: () => _showSalaryDialog(context),
                ),
                const VGapLg(),
                if (controller.isLoading && budget == null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  const VGapLg(),
                ] else if (budget != null) ...[
                  _HomeActiveBudgetCard(
                    budget: budget,
                    transactions: activeBudgetTransactions,
                  ),
                  const VGapLg(),
                  _HomeCategoryDonutCard(
                    transactions: activeBudgetTransactions,
                    onNavigateToBudget: onNavigateToBudget,
                  ),
                  const VGapLg(),
                ] else ...[
                  AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Active Budget',
                    message: 'Create a budget to track your monthly spending limits and daily allowance.',
                    actionLabel: 'Create Budget',
                    onAction: () => _handleCreateBudget(context),
                  ),
                  const VGapLg(),
                ],
                _HomeRecentTransactionsHeader(onViewAll: onNavigateToLog),
                const VGapSm(),
                _HomeRecentTransactionsList(
                  transactions: transactions,
                  isLoading: controller.isLoading,
                ),
                const VGapBottomNav(),
              ],
            ),
            AppPremiumFab(
              right: 24,
              bottom: 84,
              onPressed: () => _handleFabPressed(context),
            ),
          ],
        );
      },
    );
  }
}

class _HomeRecentTransactionsHeader extends StatelessWidget {
  final VoidCallback onViewAll;

  const _HomeRecentTransactionsHeader({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Transactions',
          style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onViewAll,
          child: Text(
            'View All',
            style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _HomeSalaryCard extends StatelessWidget {
  final double salary;
  final double totalSpent;
  final double savings;
  final VoidCallback onTap;

  const _HomeSalaryCard({
    required this.salary,
    required this.totalSpent,
    required this.savings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius * 1.2),
          border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor(context),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Income (₹)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      HomeScreen.formatInr(salary),
                      style: AppTheme.headingMedium.copyWith(
                        color: AppTheme.primaryAccentColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Remaining ₹${HomeScreen.formatInr(savings).replaceFirst('₹', '')}',
                    style: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const VGapMd(),
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapSm(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Spent this Month',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                ),
                Text(
                  HomeScreen.formatInr(totalSpent),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActiveBudgetCard extends StatelessWidget {
  final Budget budget;
  final List<Transaction> transactions;

  const _HomeActiveBudgetCard({
    required this.budget,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final spent = budget.spentForCurrentPeriod(transactions);
    final limit = budget.limit;
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;
    final dailySafe = budget.safeToSpendDaily(transactions);

    final statusColor = isOver
        ? AppTheme.errorColor
        : (pct >= budget.alertThreshold ? AppTheme.warningColor : AppTheme.primaryColor);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius * 1.2),
        border: Border.all(
          color: isOver ? AppTheme.errorColor.withValues(alpha: 0.5) : AppTheme.borderColor(context),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.wallet_rounded, color: AppTheme.primaryColor, size: 18),
                  ),
                  const HGapSm(),
                  Text(
                    budget.name,
                    style: AppTheme.headingSmall.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isOver ? 'OVER BUDGET' : '${(pct * 100).toStringAsFixed(0)}% Used',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context)),
                  ),
                  Text(
                    HomeScreen.formatInr(spent),
                    style: AppTheme.headingMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Limit / Cap',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context)),
                  ),
                  Text(
                    HomeScreen.formatInr(limit),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const VGapMd(),
          BudgetProgressBar(
            percent: pct,
            alertThreshold: budget.alertThreshold,
            statusColor: statusColor,
            minHeight: 8,
          ),
          const VGapMd(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryLight),
                const HGapSm(),
                Expanded(
                  child: Text(
                    'Safe-to-Spend Daily Allowance:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                  ),
                ),
                Text(
                  '${HomeScreen.formatInr(dailySafe)}/day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryAccentColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCategoryDonutCard extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback onNavigateToBudget;

  const _HomeCategoryDonutCard({
    required this.transactions,
    required this.onNavigateToBudget,
  });

  static const List<Color> _palette = [
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Colors.orange,
    Colors.teal,
    Colors.pinkAccent,
    Colors.amber,
    Colors.blueGrey,
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categorySums = {};
    for (final tx in transactions) {
      if (tx.isExpense && tx.amount > 0) {
        final key = tx.tag.isNotEmpty ? tx.tag : 'Other';
        categorySums[key] = (categorySums[key] ?? 0) + tx.amount;
      }
    }

    final total = categorySums.values.fold(0.0, (a, b) => a + b);
    final sorted = categorySums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius * 1.2),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spending by Category',
                style: AppTheme.headingSmall.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: onNavigateToBudget,
                child: Text('Details', style: TextStyle(color: AppTheme.primaryLight, fontSize: 12)),
              ),
            ],
          ),
          const VGapMd(),
          if (sorted.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No expenses recorded yet.',
                  style: TextStyle(color: AppTheme.textSecondaryColor(context)),
                ),
              ),
            )
          else
            Row(
              children: [
                // RepaintBoundary isolates chart custom painter from parent scrolling/rebuilds (Rule 7)
                RepaintBoundary(
                  child: ExpenseDonutChart(
                    segments: sorted.take(6).map((e) {
                      final idx = sorted.indexOf(e);
                      return DonutSegment(
                        label: e.key,
                        value: e.value,
                        color: _palette[idx % _palette.length],
                      );
                    }).toList(),
                    total: total,
                    size: 130,
                    strokeWidth: 16,
                    centerLabel: HomeScreen.formatInr(total),
                  ),
                ),
                const HGapLg(),
                Expanded(
                  child: Column(
                    children: sorted.take(4).map((e) {
                      final idx = sorted.indexOf(e);
                      final color = _palette[idx % _palette.length];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const HGapSm(),
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              HomeScreen.formatInr(e.value),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HomeRecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final bool isLoading;

  const _HomeRecentTransactionsList({
    required this.transactions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'No recent transactions.',
          style: TextStyle(color: AppTheme.textSecondaryColor(context)),
        ),
      );
    }

    final recent = transactions.take(5).toList(growable: false);

    // Rule 5: ListView.builder with stable keys (Rule 12)
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final tx = recent[index];
        return _HomeTransactionTile(
          key: ValueKey(tx.id),
          transaction: tx,
        );
      },
    );
  }
}

class _HomeTransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _HomeTransactionTile({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.isExpense;
    final formattedDate = HomeScreen.formatTransactionDate(transaction.expenseDate);
    final merchantOrTag = transaction.merchant != null && transaction.merchant!.isNotEmpty
        ? transaction.merchant!
        : transaction.tag;
    final subtitleText =
        '${transaction.description.isNotEmpty ? '${transaction.description} • ' : ''}$formattedDate';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isDebit ? AppTheme.errorColor : AppTheme.successColor).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDebit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
              size: 20,
            ),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  merchantOrTag,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const VGap2(),
                Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${isDebit ? '-' : '+'}${HomeScreen.formatInr(transaction.amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }
}
