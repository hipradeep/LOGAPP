import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class BudgetDetailsSheet extends StatefulWidget {
  final Budget budget;

  const BudgetDetailsSheet({super.key, required this.budget});

  @override
  State<BudgetDetailsSheet> createState() => _BudgetDetailsSheetState();
}

class _BudgetDetailsSheetState extends State<BudgetDetailsSheet> {
  final BudgetService _budgetService = BudgetService();
  final _limitController = TextEditingController();
  final _expenseDescController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  String _selectedPeriod = 'monthly';
  String _selectedTag = 'Other';

  @override
  void initState() {
    super.initState();
    _limitController.text = widget.budget.limit.toStringAsFixed(0);
    _selectedPeriod = widget.budget.period;
  }

  @override
  void dispose() {
    _limitController.dispose();
    _expenseDescController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _saveBudgetSettings() async {
    final limit = double.tryParse(_limitController.text) ?? 0.0;
    if (limit > 0) {
      await _budgetService.updateBudget(
        widget.budget.id,
        limit: limit,
        period: _selectedPeriod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget updated successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  String _extractTag(String text) {
    final lower = text.toLowerCase();
    const tags = ['bill', 'dinner', 'drink', 'fuel', 'grocery', 'health', 'shopping', 'snack', 'travel'];
    for (final t in tags) {
      if (lower.contains(t)) return t[0].toUpperCase() + t.substring(1);
    }
    return '';
  }

  void _addExpense() async {
    if (_expenseDescController.text.isEmpty) return;
    final amount = double.tryParse(_expenseAmountController.text) ?? 0.0;
    if (amount <= 0) return;
    final descText = _expenseDescController.text.trim();

    await _budgetService.addTransaction(
      widget.budget.id,
      _selectedTag,
      descText,
      amount,
    );

    _expenseDescController.clear();
    _expenseAmountController.clear();
    setState(() {
      _selectedTag = 'Other';
    });
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  void _deleteBudget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Budget Category'),
        content: Text('Are you sure you want to delete "${widget.budget.category}"? This will delete all logged expenses under it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _budgetService.deleteBudget(widget.budget.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return StreamBuilder<List<Budget>>(
      stream: _budgetService.getBudgetsStream(),
      builder: (context, budgetsSnapshot) {
        final budgets = budgetsSnapshot.data ?? [];
        final budget = budgets.firstWhere((b) => b.id == widget.budget.id, orElse: () => widget.budget);

        return StreamBuilder<List<Transaction>>(
          stream: _budgetService.getTransactionsStream(),
          builder: (context, transactionsSnapshot) {
            final transactions = transactionsSnapshot.data ?? [];
            final budgetTransactions = transactions.where((t) => t.budgetId == budget.id).toList();

            final sortedExpenses = List<Transaction>.from(budgetTransactions)
              ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

            final spent = budget.spentForCurrentPeriod(transactions);
            final percent = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
            final isOver = spent > budget.limit;
            final Color statusColor = isOver 
                ? AppTheme.errorColor 
                : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor);

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: bottomInset + 32,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const VGapMd(),
                    
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                budget.category,
                                style: AppTheme.headingMedium,
                              ),
                              Text(
                                'Period: ${budget.period.toUpperCase()}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor, size: 24),
                          onPressed: _deleteBudget,
                        ),
                      ],
                    ),
                    const VGapMd(),
                    
                    // Visual Progress card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Spent this ${budget.period.replaceAll('ly', '')}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹${spent.toStringAsFixed(1)}', style: AppTheme.headingMedium.copyWith(color: statusColor)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Limit', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹${budget.limit.toStringAsFixed(0)}', style: AppTheme.headingSmall),
                                ],
                              ),
                            ],
                          ),
                          const VGapSm(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              minHeight: 8,
                            ),
                          ),
                          const VGapXs(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOver 
                                    ? 'Exceeded by ₹${(spent - budget.limit).toStringAsFixed(1)}'
                                    : '₹${(budget.limit - spent).toStringAsFixed(1)} remaining',
                                style: TextStyle(
                                  color: isOver ? AppTheme.errorColor : AppTheme.textSecondary, 
                                  fontSize: 11,
                                  fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text('${(percent * 100).toInt()}% used', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const VGapMd(),
                    
                    // Settings editing section
                    Text('Budget Settings', style: AppTheme.headingSmall),
                    const VGapSm(),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _limitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Limit (₹)',
                              hintText: 'e.g. 150',
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const HGapSm(),
                        Expanded(
                          flex: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPeriod,
                                dropdownColor: AppTheme.surfaceColor,
                                items: ['daily', 'weekly', 'monthly'].map((p) {
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 14)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedPeriod = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const HGapSm(),
                        IconButton(
                          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.primaryLight, size: 32),
                          onPressed: _saveBudgetSettings,
                        ),
                      ],
                    ),
                    const VGapMd(),
                    
                    // Add expense form
                    Text('Log New Expense', style: AppTheme.headingSmall),
                    const VGapSm(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: TextField(
                                  controller: _expenseDescController,
                                  onChanged: (text) {
                                    final extracted = _extractTag(text);
                                    if (extracted.isNotEmpty) {
                                      setState(() {
                                        _selectedTag = extracted;
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. Lunch',
                                    labelText: 'Description',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const HGapSm(),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _expenseAmountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 15',
                                    labelText: 'Amount (₹)',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VGapSm(),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTag,
                                      isExpanded: true,
                                      dropdownColor: AppTheme.surfaceColor,
                                      items: ['Bill', 'Dinner', 'Drink', 'Fuel', 'Grocery', 'Health', 'Other', 'Shopping', 'Snack', 'Travel'].map((t) {
                                        return DropdownMenuItem(
                                          value: t,
                                          child: Text(t, style: const TextStyle(fontSize: 13, color: Colors.white)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedTag = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const HGapSm(),
                              ElevatedButton(
                                onPressed: _addExpense,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(54, 46),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const VGapMd(),
                    
                    // Expenses list
                    Text('Expense History', style: AppTheme.headingSmall),
                    const VGapSm(),
                    if (sortedExpenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No expenses recorded yet.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = sortedExpenses[index];
                          final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(expense.expenseDate);
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: expense.tag,
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight),
                                            ),
                                            if (expense.description.isNotEmpty) ...[
                                              TextSpan(
                                                text: ' | ',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white38),
                                              ),
                                              TextSpan(
                                                text: expense.description,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${expense.amount.toStringAsFixed(1)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 14),
                                ),
                                const HGapSm(),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 18),
                                  onPressed: () {
                                    _budgetService.deleteTransaction(expense.id);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
