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
import '../widgets/add_transaction_sheet.dart';
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

  String _formatInr(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(amount);
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
          actions: [
            IconButton(
              icon: Icon(Icons.account_balance_rounded, color: AppTheme.primaryLight, size: 22),
              tooltip: 'Update Salary',
              onPressed: () => _showSalaryDialog(context),
            ),
          ],
          children: [
            const VGapSm(),
            // Income & Net Savings Overview Banner
            _buildSalaryCard(context, salary, totalSpentMonth, salarySavings),
            const VGapLg(),
            // Active Budget Card with Safe-to-Spend Daily Allowance
            if (budget != null) ...[
              _buildActiveBudgetCard(context, budget, activeBudgetTransactions),
              const VGapLg(),
              // Category Breakdown Donut Summary Card
              _buildCategoryDonutCard(context, activeBudgetTransactions),
              const VGapLg(),
            ] else if (!controller.isLoading) ...[
              AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Active Budget',
                message: 'Create a budget to track your monthly spending limits and daily allowance.',
                actionLabel: 'Create Budget',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
                  );
                },
              ),
              const VGapLg(),
            ],
            // Recent Transactions Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: onNavigateToLog,
                  child: Text(
                    'View All',
                    style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const VGapSm(),
            _buildRecentTransactionsList(context, transactions),
            const VGapBottomNav(),
          ],
        ),
        AppPremiumFab(
          right: 24,
          bottom: 84,
          onPressed: () {
            if (controller.budgets.isEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
              );
            } else {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => AddTransactionSheet(
                  budgetId: budget?.id,
                  budgets: controller.budgets,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildSalaryCard(BuildContext context, double salary, double totalSpent, double savings) {
    return Container(
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
                    _formatInr(salary),
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
                  'Remaining ₹${_formatInr(savings).replaceFirst('₹', '')}',
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
                _formatInr(totalSpent),
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
    );
  }

  Widget _buildActiveBudgetCard(BuildContext context, Budget budget, List<Transaction> transactions) {
    final spent = budget.spentForCurrentPeriod(transactions);
    final limit = budget.limit;
    final remaining = (limit - spent).clamp(0.0, double.infinity);
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
                    _formatInr(spent),
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
                    _formatInr(limit),
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
          // Safe to spend daily highlight
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
                  '${_formatInr(dailySafe)}/day',
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

  Widget _buildCategoryDonutCard(BuildContext context, List<Transaction> transactions) {
    final Map<String, double> categorySums = {};
    for (final tx in transactions) {
      if (tx.isExpense && tx.amount > 0) {
        final key = tx.tag.isNotEmpty ? tx.tag : 'Other';
        categorySums[key] = (categorySums[key] ?? 0) + tx.amount;
      }
    }

    final total = categorySums.values.fold(0.0, (a, b) => a + b);
    final sorted = categorySums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final List<Color> palette = [
      AppTheme.primaryColor,
      AppTheme.secondaryColor,
      Colors.orange,
      Colors.teal,
      Colors.pinkAccent,
      Colors.amber,
      Colors.blueGrey,
    ];

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
                ExpenseDonutChart(
                  segments: sorted.take(6).map((e) {
                    final idx = sorted.indexOf(e);
                    return DonutSegment(
                      label: e.key,
                      value: e.value,
                      color: palette[idx % palette.length],
                    );
                  }).toList(),
                  total: total,
                  size: 130,
                  strokeWidth: 16,
                  centerLabel: _formatInr(total),
                ),
                const HGapLg(),
                Expanded(
                  child: Column(
                    children: sorted.take(4).map((e) {
                      final idx = sorted.indexOf(e);
                      final color = palette[idx % palette.length];
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
                              _formatInr(e.value),
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

  Widget _buildRecentTransactionsList(BuildContext context, List<Transaction> transactions) {
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

    final recent = transactions.take(5).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final tx = recent[index];
        final isDebit = tx.isExpense;

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
                      tx.merchant != null && tx.merchant!.isNotEmpty ? tx.merchant! : tx.tag,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const VGap2(),
                    Text(
                      '${tx.description.isNotEmpty ? '${tx.description} • ' : ''}${DateFormat('d MMM, hh:mm a').format(tx.expenseDate)}',
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
                '${isDebit ? '-' : '+'}${_formatInr(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
