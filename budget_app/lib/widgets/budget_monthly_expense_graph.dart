import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class BudgetMonthlyExpenseGraph extends StatefulWidget {
  final Budget budget;
  final List<Transaction> transactions;
  final bool showLabels;

  const BudgetMonthlyExpenseGraph({
    super.key,
    required this.budget,
    required this.transactions,
    this.showLabels = false,
  });

  @override
  State<BudgetMonthlyExpenseGraph> createState() => _BudgetMonthlyExpenseGraphState();
}

class _BudgetMonthlyExpenseGraphState extends State<BudgetMonthlyExpenseGraph> {
  DateTime? _selectedDate;

  String _formatAmountCompact(double amount) {
    if (amount <= 0) return '';
    if (amount >= 1000000) {
      final double value = amount / 1000000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '${formatted}M';
    } else if (amount >= 1000) {
      final double value = amount / 1000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '${formatted}k';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  List<DateTime?> _generateMonthGridDates(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final startPadding = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;

    final List<DateTime?> gridDates = [];
    for (int i = 0; i < startPadding; i++) {
      gridDates.add(null);
    }
    final totalDays = lastDayOfMonth.day;
    for (int i = 1; i <= totalDays; i++) {
      gridDates.add(DateTime(monthDate.year, monthDate.month, i));
    }
    while (gridDates.length % 7 != 0) {
      gridDates.add(null);
    }
    return gridDates;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final budgetTx = widget.transactions.where((t) => t.budgetId == widget.budget.id && t.isExpense && t.amount > 0).toList();

    final Map<int, double> dailySums = {};
    for (final tx in budgetTx) {
      if (tx.expenseDate.year == now.year && tx.expenseDate.month == now.month) {
        dailySums[tx.expenseDate.day] = (dailySums[tx.expenseDate.day] ?? 0.0) + tx.amount;
      }
    }

    double maxAmount = dailySums.values.fold(0.0, (max, amt) => amt > max ? amt : max);
    if (maxAmount == 0.0) maxAmount = 1.0;

    final gridDates = _generateMonthGridDates(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedDate != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${DateFormat('MMMM d, yyyy').format(_selectedDate!)}: ₹${(dailySums[_selectedDate!.day] ?? 0.0).toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryAccentColor(context),
              ),
            ),
          ),
          const VGapSm(),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1.0,
          ),
          itemCount: gridDates.length,
          itemBuilder: (context, index) {
            final date = gridDates[index];
            if (date == null) {
              return const SizedBox.shrink();
            }

            final day = date.day;
            final amount = dailySums[day] ?? 0.0;
            final hasExpense = amount > 0;
            final isCurrentDay = date.year == today.year && date.month == today.month && date.day == today.day;
            final isFuture = date.isAfter(today);
            final ratio = (amount / maxAmount).clamp(0.15, 1.0);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: hasExpense
                      ? AppTheme.primaryColor.withValues(alpha: ratio * 0.85)
                      : (isFuture
                          ? AppTheme.surface(context).withValues(alpha: 0.1)
                          : AppTheme.surface(context).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(6),
                  border: isCurrentDay
                      ? Border.all(color: AppTheme.primaryAccentColor(context), width: 1.5)
                      : null,
                ),
                alignment: Alignment.center,
                child: widget.showLabels && hasExpense
                    ? Text(
                        _formatAmountCompact(amount),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                          color: hasExpense
                              ? Colors.white
                              : (isFuture ? AppTheme.textMutedColor(context) : AppTheme.textSecondaryColor(context)),
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}
