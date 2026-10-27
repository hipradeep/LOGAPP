import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'budget_daily_expense_graph.dart';
import 'budget_monthly_expense_graph.dart';

class BudgetExpenseGraph extends StatefulWidget {
  final Budget budget;
  final List<BudgetTransaction> transactions;

  const BudgetExpenseGraph({
    super.key,
    required this.budget,
    required this.transactions,
  });

  @override
  State<BudgetExpenseGraph> createState() => _BudgetExpenseGraphState();
}

class _BudgetExpenseGraphState extends State<BudgetExpenseGraph> {
  String _viewType = '7d'; // '7d', 'monthly'

  Widget _buildWindowButton(String viewType, String title) {
    final isActive = _viewType == viewType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewType = viewType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive
                ? AppTheme.primaryLight
                : AppTheme.textSecondaryColor(context),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getGraphTitle() {
    return _viewType == '7d' ? '7-Day Expenses' : 'Monthly Expenses';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getGraphTitle(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _buildWindowButton('7d', '7D'),
              const HGapSm(),
              _buildWindowButton('monthly', 'Month'),
            ],
          ),
          const VGapMd(),
          if (_viewType == '7d')
            BudgetDailyExpenseGraph(
              daysWindow: 7,
              budget: widget.budget,
              transactions: widget.transactions,
            )
          else
            BudgetMonthlyExpenseGraph(
              budget: widget.budget,
              transactions: widget.transactions,
            ),
        ],
      ),
    );
  }
}
