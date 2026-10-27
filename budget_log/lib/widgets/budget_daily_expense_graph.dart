import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class BudgetDailyExpenseGraph extends StatelessWidget {
  final int daysWindow;
  final Budget budget;
  final List<BudgetTransaction> transactions;

  const BudgetDailyExpenseGraph({
    super.key,
    required this.daysWindow,
    required this.budget,
    required this.transactions,
  });

  String _formatAmount(double amount) {
    if (amount <= 0) return '—';
    if (amount >= 10000000) {
      final double value = amount / 10000000;
      return '₹${value.toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      final double value = amount / 100000;
      return '₹${value.toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      final double value = amount / 1000;
      return '₹${value.toStringAsFixed(1)}k';
    } else {
      return '₹${amount.toStringAsFixed(0)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      daysWindow,
      (index) => today.subtract(Duration(days: (daysWindow - 1) - index)),
    );
    final budgetTx = transactions
        .where((t) => t.budgetId == budget.id && t.isExpense && t.amount > 0)
        .toList();

    final Map<DateTime, double> dailySums = {for (var d in days) d: 0.0};
    double totalExpenses = 0.0;
    for (final tx in budgetTx) {
      final txDate = DateTime(
        tx.timestamp.year,
        tx.timestamp.month,
        tx.timestamp.day,
      );
      if (dailySums.containsKey(txDate)) {
        dailySums[txDate] = (dailySums[txDate] ?? 0.0) + tx.amount;
        totalExpenses += tx.amount;
      }
    }

    double maxAmount = dailySums.values.fold(
      0.0,
      (max, amt) => amt > max ? amt : max,
    );
    if (maxAmount == 0.0) maxAmount = 1.0;

    final is7Days = daysWindow == 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${is7Days ? "7-Day" : "14-Day"} Total: ₹${totalExpenses.toStringAsFixed(0)}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Peak: ${_formatAmount(maxAmount)}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const VGapMd(),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((day) {
              final amt = dailySums[day] ?? 0.0;
              final heightFactor = (amt / maxAmount).clamp(0.04, 1.0);
              final isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (amt > 0)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatAmount(amt),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? AppTheme.primaryLight
                                  : AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      const VGapXs(),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          child: Container(
                            decoration: BoxDecoration(
                              color: amt == 0
                                  ? AppTheme.borderColor(context)
                                  : (isToday
                                      ? AppTheme.primaryColor
                                      : AppTheme.primaryColor.withValues(
                                          alpha: 0.65,
                                        )),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const VGapXs(),
                      Text(
                        is7Days
                            ? _weekdayName(day.weekday)
                            : '${day.day}/${day.month}',
                        style: TextStyle(
                          fontSize: 9,
                          color: isToday
                              ? AppTheme.primaryLight
                              : AppTheme.textSecondaryColor(context),
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'T';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'S';
      default:
        return '';
    }
  }
}
