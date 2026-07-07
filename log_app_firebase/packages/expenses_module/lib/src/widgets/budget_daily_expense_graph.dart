import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import 'package:core_ui/core_ui.dart';

class BudgetDailyExpenseGraph extends StatelessWidget {
  final int daysWindow;
  final Budget budget;
  final List<Transaction> transactions;

  const BudgetDailyExpenseGraph({
    super.key,
    required this.daysWindow,
    required this.budget,
    required this.transactions,
  });

  String _formatAmount(double amount) {
    if (amount <= 0) return '—';
    if (amount >= 1000000) {
      final double value = amount / 1000000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '₹${formatted}M';
    } else if (amount >= 1000) {
      final double value = amount / 1000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '₹${formatted}k';
    } else {
      return '₹${amount.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(daysWindow, (index) => today.subtract(Duration(days: (daysWindow - 1) - index)));
    final budgetTx = transactions.where((t) => t.budgetId == budget.id && t.amount > 0).toList();

    final Map<DateTime, double> dailySums = {for (var d in days) d: 0.0};
    double totalExpenses = 0.0;
    for (final tx in budgetTx) {
      final txDate = DateTime(tx.expenseDate.year, tx.expenseDate.month, tx.expenseDate.day);
      if (dailySums.containsKey(txDate)) {
        dailySums[txDate] = (dailySums[txDate] ?? 0.0) + tx.amount;
        totalExpenses += tx.amount;
      }
    }

    double maxAmount = dailySums.values.fold(0.0, (max, amt) => amt > max ? amt : max);
    if (maxAmount == 0.0) maxAmount = 1.0;

    final is7Days = daysWindow == 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Avg: ₹${(totalExpenses / daysWindow).toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor(context),
                fontSize: 12,
              ),
            ),
            Text(
              'Total: ₹${totalExpenses.toStringAsFixed(1)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const VGapMd(),
        SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((day) {
              final amount = dailySums[day] ?? 0.0;
              final ratio = amount / maxAmount;
              final tooltip = '${DateFormat('MMM d, yyyy').format(day)}: ₹${amount.toStringAsFixed(1)}';

              if (is7Days) {
                final dayLabel = DateFormat('E').format(day);
                final dateLabel = DateFormat('d').format(day);
                return Expanded(
                  child: Tooltip(
                    message: tooltip,
                    child: _BarWidget(
                      heightRatio: ratio,
                      amount: amount,
                      primaryLabel: dayLabel,
                      secondaryLabel: dateLabel,
                      showAmountLabel: true,
                      barWidth: 14,
                      formattedAmount: _formatAmount(amount),
                    ),
                  ),
                );
              } else {
                return Expanded(
                  child: Tooltip(
                    message: tooltip,
                    child: _BarWidget(
                      heightRatio: ratio,
                      amount: amount,
                      primaryLabel: '',
                      secondaryLabel: '',
                      showAmountLabel: false,
                      barWidth: 6,
                      formattedAmount: _formatAmount(amount),
                    ),
                  ),
                );
              }
            }).toList(),
          ),
        ),
        if (!is7Days) ...[
          const VGapSm(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM d').format(days.first),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MMM d').format(days[14]),
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Today',
                  style: TextStyle(
                    color: AppTheme.primaryAccentColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BarWidget extends StatelessWidget {
  final double heightRatio;
  final double amount;
  final String primaryLabel;
  final String secondaryLabel;
  final bool showAmountLabel;
  final double barWidth;
  final String formattedAmount;

  const _BarWidget({
    required this.heightRatio,
    required this.amount,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.showAmountLabel,
    required this.barWidth,
    required this.formattedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final hasAmount = amount > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (showAmountLabel) ...[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formattedAmount,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: hasAmount
                    ? AppTheme.textPrimaryColor(context)
                    : AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
              ),
            ),
          ),
          const VGapSm(),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final targetHeight = maxHeight * heightRatio;
              final calculatedHeight = hasAmount
                  ? (targetHeight < 6.0 ? 6.0 : targetHeight)
                  : (showAmountLabel ? 3.0 : 1.5);

              return Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: calculatedHeight),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  builder: (context, animHeight, child) {
                    final double alpha = hasAmount ? (0.35 + (0.65 * heightRatio)) : 0.1;
                    return Container(
                      width: barWidth,
                      height: animHeight,
                      decoration: BoxDecoration(
                        gradient: hasAmount
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppTheme.primaryColor.withValues(alpha: alpha),
                                  AppTheme.primaryLight.withValues(alpha: alpha),
                                ],
                              )
                            : null,
                        color: hasAmount
                            ? null
                            : AppTheme.textSecondaryColor(context).withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (primaryLabel.isNotEmpty) ...[
          const VGapSm(),
          Text(
            primaryLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          Text(
            secondaryLabel,
            style: TextStyle(
              fontSize: 8,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}
