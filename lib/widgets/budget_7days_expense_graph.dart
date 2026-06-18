import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class Budget7DaysExpenseGraph extends StatelessWidget {
  final Budget budget;
  final List<Transaction> transactions;

  const Budget7DaysExpenseGraph({
    super.key,
    required this.budget,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate the last 7 calendar days (including today)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last7Days = List.generate(7, (index) {
      return today.subtract(Duration(days: 6 - index));
    });

    // 2. Filter transactions belonging to this budget and containing debit expenses (amount > 0)
    final budgetTx = transactions.where((t) => t.budgetId == budget.id && t.amount > 0).toList();

    // 3. Aggregate sum per day
    final Map<DateTime, double> dailySums = {};
    for (final day in last7Days) {
      dailySums[day] = 0.0;
    }

    double total7Days = 0.0;
    for (final tx in budgetTx) {
      final txDate = DateTime(tx.expenseDate.year, tx.expenseDate.month, tx.expenseDate.day);
      if (dailySums.containsKey(txDate)) {
        dailySums[txDate] = (dailySums[txDate] ?? 0.0) + tx.amount;
        total7Days += tx.amount;
      }
    }

    // 4. Find max amount to calculate heights
    double maxAmount = dailySums.values.fold(0.0, (max, amt) => amt > max ? amt : max);
    if (maxAmount == 0.0) {
      maxAmount = 1.0;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Expenses',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 14,
                ),
              ),
              Text(
                'Avg: ₹${(total7Days / 7.0).toStringAsFixed(1)}',
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
              children: last7Days.map((day) {
                final amount = dailySums[day] ?? 0.0;
                final ratio = amount / maxAmount;
                final dayLabel = DateFormat('E').format(day);
                final dateLabel = DateFormat('d').format(day);

                return Expanded(
                  child: _BarWidget(
                    heightRatio: ratio,
                    amount: amount,
                    dayLabel: dayLabel,
                    dateLabel: dateLabel,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarWidget extends StatelessWidget {
  final double heightRatio;
  final double amount;
  final String dayLabel;
  final String dateLabel;

  const _BarWidget({
    required this.heightRatio,
    required this.amount,
    required this.dayLabel,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasAmount = amount > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Amount label
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            hasAmount ? '₹${amount.toStringAsFixed(0)}' : '—',
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
        // Bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxHeight = constraints.maxHeight;
              final targetHeight = maxHeight * heightRatio;
              final calculatedHeight = hasAmount
                  ? (targetHeight < 6.0 ? 6.0 : targetHeight)
                  : 3.0;

              return Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: calculatedHeight),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutQuart,
                  builder: (context, animHeight, child) {
                    return Container(
                      width: 14,
                      height: animHeight,
                      decoration: BoxDecoration(
                        gradient: hasAmount
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  AppTheme.primaryColor,
                                  AppTheme.primaryLight,
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
        const VGapSm(),
        // Day name (e.g. "Mon")
        Text(
          dayLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        // Date number (e.g. "17")
        Text(
          dateLabel,
          style: TextStyle(
            fontSize: 8,
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
