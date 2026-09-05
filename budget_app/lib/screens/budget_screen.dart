import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/budget_progress_bar.dart';
import '../widgets/budget_expense_graph.dart';
import '../widgets/category_breakdown_sheet.dart';
import '../widgets/app_premium_fab.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/app_empty_state.dart';
import '../services/preferences_service.dart';
import 'add_budget_screen.dart';
import 'manage_budget_screen.dart';

class BudgetScreen extends StatefulWidget {
  final BudgetController controller;

  const BudgetScreen({
    super.key,
    required this.controller,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final PreferencesService _prefs = PreferencesService();
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _prefs.getExpenseCategories();
    if (mounted) setState(() => _categories = cats);
  }

  String _formatInr(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(amount);
  }

  IconData _getTagIcon(String tag) {
    for (var c in _categories) {
      if (c['label'].toString().toLowerCase() == tag.toLowerCase()) {
        return Icons.local_grocery_store_rounded;
      }
    }
    return Icons.category_rounded;
  }

  Color _getTagColor(String tag) {
    for (var c in _categories) {
      if (c['label'].toString().toLowerCase() == tag.toLowerCase()) {
        return Color(c['color'] as int? ?? 0xFF8B5CF6);
      }
    }
    return AppTheme.primaryColor;
  }

  void _showCategoryBreakdown(Budget budget, List<Transaction> transactions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryBreakdownSheet(
        budget: budget,
        transactions: transactions,
        getTagIcon: _getTagIcon,
        getTagColor: _getTagColor,
        getTagName: (tag) => tag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.controller.selectedBudget;
    final budgets = widget.controller.budgets;
    final transactions = widget.controller.selectedBudgetTransactions;

    return Stack(
      children: [
        FullScreenPage(
          showScaffold: false,
          isScrollable: true,
          title: 'Budget',
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
              icon: Icon(Icons.tune_rounded, color: AppTheme.primaryLight, size: 22),
              tooltip: 'Manage Budgets',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageBudgetScreen()),
                );
              },
            ),
          ],
          children: [
            const VGapSm(),
            if (budgets.isNotEmpty) ...[
              // Budget switcher selector
              _buildBudgetSelector(budgets, budget),
              const VGapLg(),
            ],
            if (budget != null) ...[
              _buildDetailedCard(budget, transactions),
              const VGapLg(),
              // Multi-period / 7-Day & Monthly Expense Graph
              BudgetExpenseGraph(
                budget: budget,
                transactions: transactions,
              ),
              const VGapLg(),
              // Breakdown sheet button
              OutlinedButton.icon(
                onPressed: () => _showCategoryBreakdown(budget, transactions),
                icon: const Icon(Icons.pie_chart_outline_rounded, size: 18),
                label: const Text('View Category Breakdown'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                  ),
                ),
              ),
            ] else if (!widget.controller.isLoading) ...[
              AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Budgets Configured',
                message: 'Create your first budget cap in ₹ to start monitoring expenses.',
                actionLabel: 'Add Budget',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
                  );
                },
              ),
            ],
            const VGapBottomNav(),
          ],
        ),
        AppPremiumFab(
          right: 24,
          bottom: 84,
          onPressed: () {
            if (budgets.isEmpty) {
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
                  budgets: budgets,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildBudgetSelector(List<Budget> budgets, Budget? selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.id,
          isExpanded: true,
          dropdownColor: AppTheme.surface(context),
          items: budgets.map((b) {
            return DropdownMenuItem(
              value: b.id,
              child: Row(
                children: [
                  Text(
                    b.name,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    'Limit: ${_formatInr(b.limit)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              widget.controller.updateSelectedBudgetId(id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDetailedCard(Budget budget, List<Transaction> transactions) {
    final spent = budget.spentForCurrentPeriod(transactions);
    final limit = budget.limit;
    final remaining = (limit - spent).clamp(0.0, double.infinity);
    final pct = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;

    final statusColor = isOver
        ? AppTheme.errorColor
        : (pct >= budget.alertThreshold ? AppTheme.warningColor : AppTheme.primaryColor);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.6),
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
                'Period: ${budget.period.toUpperCase()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.primaryLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isOver ? 'OVER BUDGET' : '${(pct * 100).toStringAsFixed(0)}% USED',
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spent', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
                    const VGapXs(),
                    Text(_formatInr(spent), style: AppTheme.headingMedium.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Remaining Balance', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context))),
                    const VGapXs(),
                    Text(
                      _formatInr(remaining),
                      style: AppTheme.headingMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOver ? AppTheme.errorColor : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
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
        ],
      ),
    );
  }
}
