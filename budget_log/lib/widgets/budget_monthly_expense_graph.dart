import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';

class BudgetMonthlyExpenseGraph extends StatefulWidget {
  final Budget budget;
  final List<BudgetTransaction> transactions;
  final bool showLabels;

  const BudgetMonthlyExpenseGraph({
    super.key,
    required this.budget,
    required this.transactions,
    this.showLabels = false,
  });

  @override
  State<BudgetMonthlyExpenseGraph> createState() =>
      _BudgetMonthlyExpenseGraphState();
}

class _BudgetMonthlyExpenseGraphState extends State<BudgetMonthlyExpenseGraph> {
  DateTime? _selectedDate;

  List<DateTime?> _generateMonthGridDates(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final startPadding =
        firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;

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
    final budgetTx = widget.transactions
        .where(
          (t) =>
              t.budgetId == widget.budget.id &&
              t.isExpense &&
              t.amount > 0 &&
              t.timestamp.year == now.year &&
              t.timestamp.month == now.month,
        )
        .toList();

    final Map<int, double> dayTotals = {};
    double totalMonth = 0.0;
    for (final tx in budgetTx) {
      dayTotals[tx.timestamp.day] =
          (dayTotals[tx.timestamp.day] ?? 0.0) + tx.amount;
      totalMonth += tx.amount;
    }

    final gridDates = _generateMonthGridDates(now);
    final maxDaily = dayTotals.values.fold(0.0, (m, a) => a > m ? a : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Month-to-Date: ${AppFormat.currency(totalMonth)}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_selectedDate != null && dayTotals.containsKey(_selectedDate!.day))
              Text(
                '${_selectedDate!.day} ${_monthName(_selectedDate!.month)}: ${AppFormat.currency(dayTotals[_selectedDate!.day] ?? 0)}',
                style: TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const VGapMd(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            final spent = dayTotals[day] ?? 0.0;
            final isToday = date.day == now.day;
            final isSelected =
                _selectedDate != null && _selectedDate!.day == date.day;

            Color tileColor = AppTheme.surfaceVariant(context);
            if (spent > 0 && maxDaily > 0) {
              final intensity = (spent / maxDaily).clamp(0.25, 1.0);
              tileColor = AppTheme.primaryColor.withValues(alpha: intensity);
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryLight
                        : (isToday
                            ? AppTheme.primaryColor
                            : Colors.transparent),
                    width: isSelected || isToday ? 1.5 : 0.0,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday || spent > 0
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: spent > 0 && maxDaily > 0 && (spent / maxDaily) > 0.5
                        ? Colors.white
                        : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return month >= 1 && month <= 12 ? names[month] : '';
  }
}
