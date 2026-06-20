import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'budget_progress_bar.dart';

class BudgetDetailsSheet extends StatefulWidget {
  final Budget budget;

  const BudgetDetailsSheet({super.key, required this.budget});

  @override
  State<BudgetDetailsSheet> createState() => _BudgetDetailsSheetState();
}

class _BudgetDetailsSheetState extends State<BudgetDetailsSheet> {
  static final DateFormat _historyFormatter = DateFormat('MMM d, yyyy • h:mm a');
  final BudgetService _budgetService = BudgetService();
  final _limitController = TextEditingController();
  final _expenseDescController = TextEditingController();
  final _expenseAmountController = TextEditingController();

  String _selectedPeriod = 'monthly';
  String _selectedTag = 'Other';
  String _selectedPaymentMethod = 'PNB';
  List<String> _paymentMethods = ['PNB'];

  @override
  void initState() {
    super.initState();
    _limitController.text = widget.budget.limit.toStringAsFixed(0);
    _selectedPeriod = widget.budget.period;
    _loadPaymentMethods();
  }

  void _loadPaymentMethods() async {
    try {
      final list = await CacheService().getPaymentModes();
      list.sort((a, b) => (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
      final modes = list.map((item) => item['label'] as String).toList();
      if (mounted) {
        setState(() {
          _paymentMethods = modes;
          if (modes.isNotEmpty) {
            _selectedPaymentMethod = modes.contains('PNB') ? 'PNB' : modes.first;
          }
        });
      }
    } catch (_) {}
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
    const tags = {
      'grocery': 'Grocery',
      'fast food': 'Fast Food',
      'fastfood': 'Fast Food',
      'supplement': 'Supplements',
      'travel': 'Travel',
      'care': 'Care',
      'home': 'Home',
      'bill': 'Bills',
      'timepass': 'Timepass',
      'transfer': 'Transfer',
      'quickmart': 'QuickMart',
      'shopping': 'Shopping',
      'shoping': 'Shopping',
    };
    for (final entry in tags.entries) {
      if (lower.contains(entry.key)) return entry.value;
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
      paymentMethod: _selectedPaymentMethod,
    );

    await CacheService().incrementPaymentModeCount(_selectedPaymentMethod);

    _expenseDescController.clear();
    _expenseAmountController.clear();
    setState(() {
      _selectedTag = 'Other';
      _selectedPaymentMethod = _paymentMethods.contains('PNB') ? 'PNB' : (_paymentMethods.isNotEmpty ? _paymentMethods.first : 'PNB');
    });
    if (mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  void _deleteBudget() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        title: const Text('Delete Budget Category'),
        content: Text('Are you sure you want to delete "${widget.budget.name}"? This will delete all logged expenses under it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
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
    Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
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
                color: AppTheme.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: AppTheme.borderColor(context),
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
                          color: AppTheme.borderColor(context),
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
                                budget.name,
                                style: AppTheme.headingMedium,
                              ),
                              Text(
                                'Period: ${budget.period.toUpperCase()}',
                                style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12),
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
                        color: AppTheme.background(context).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Spent this ${budget.period.replaceAll('ly', '')}', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹${spent.toStringAsFixed(1)}', style: AppTheme.headingMedium.copyWith(color: statusColor)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Limit', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('₹${budget.limit.toStringAsFixed(0)}', style: AppTheme.headingSmall),
                                ],
                              ),
                            ],
                          ),
                          const VGapSm(),
                          BudgetProgressBar(
                            percent: percent,
                            alertThreshold: budget.alertThreshold,
                            statusColor: statusColor,
                            minHeight: 8,
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
                                  color: isOver ? AppTheme.errorColor : AppTheme.textSecondaryColor(context), 
                                  fontSize: 11,
                                  fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text('${(percent * 100).toInt()}% used', style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 11)),
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
                              color: AppTheme.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderColor(context)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPeriod,
                                dropdownColor: AppTheme.surface(context),
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
                          icon: Icon(Icons.check_circle_rounded, color: AppTheme.primaryAccentColor(context), size: 32),
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
                        color: AppTheme.background(context).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor(context)),
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
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderColor(context)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedTag,
                                      isExpanded: true,
                                      dropdownColor: AppTheme.surface(context),
                                      items: ['Grocery', 'Fast Food', 'Supplements', 'Travel', 'Care', 'Home', 'Bills', 'Timepass', 'Transfer', 'QuickMart', 'Shopping', 'Other'].map((t) {
                                        return DropdownMenuItem(
                                          value: t,
                                          child: Text(t, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context))),
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
                              Expanded(
                                flex: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.borderColor(context)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _paymentMethods.contains(_selectedPaymentMethod) ? _selectedPaymentMethod : (_paymentMethods.isNotEmpty ? _paymentMethods.first : 'PNB'),
                                      isExpanded: true,
                                      dropdownColor: AppTheme.surface(context),
                                      items: _paymentMethods.map((m) {
                                        return DropdownMenuItem(
                                          value: m,
                                          child: Text(m, style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryColor(context))),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedPaymentMethod = val;
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
                                  minimumSize: const Size(46, 46),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No expenses recorded yet.',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context),
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
                          final formattedDate = _historyFormatter.format(expense.expenseDate);
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.subtleFillColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderColor(context)),
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
                                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryAccentColor(context)),
                                            ),
                                            if (expense.description.isNotEmpty) ...[
                                              TextSpan(
                                                text: ' | ',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMutedColor(context)),
                                              ),
                                              TextSpan(
                                                text: expense.description,
                                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimaryColor(context)),
                                              ),
                                            ],
                                            TextSpan(
                                              text: ' [${expense.paymentMethod}]',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textSecondaryColor(context),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 10),
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
                                  icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context), size: 18),
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
