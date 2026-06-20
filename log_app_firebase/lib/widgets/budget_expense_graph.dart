import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'budget_daily_expense_graph.dart';
import 'budget_monthly_expense_graph.dart';

class BudgetExpenseGraph extends StatefulWidget {
  final Budget budget;
  final List<Transaction> transactions;

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
  bool _showLabels = false;

  Widget _buildWindowButton(String viewType, String title) {
    final isActive = _viewType == viewType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewType = viewType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.subtleFillColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.borderColor(context) : AppTheme.borderColor(context).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
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
            children: [
              Text(
                _getGraphTitle(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_viewType == 'monthly') ...[
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showLabels = !_showLabels;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _showLabels ? AppTheme.subtleFillColor(context) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _showLabels ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 16,
                      color: _showLabels 
                          ? AppTheme.primaryAccentColor(context) 
                          : AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const HGapSm(),
              ],
              _buildWindowButton('7d', 'W'),
              const HGapSm(),
              _buildWindowButton('monthly', 'M'),
            ],
          ),
          const VGapMd(),
          if (_viewType == 'monthly')
            BudgetMonthlyExpenseGraph(
              budget: widget.budget,
              transactions: widget.transactions,
              showLabels: _showLabels,
            )
          else
            BudgetDailyExpenseGraph(
              daysWindow: 7,
              budget: widget.budget,
              transactions: widget.transactions,
            ),
        ],
      ),
    );
  }
}
