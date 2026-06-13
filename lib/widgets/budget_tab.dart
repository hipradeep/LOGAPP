import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_item.dart';
import '../services/budget_service.dart';
import '../services/sms_transaction_service.dart';
import '../theme/app_theme.dart';
import 'base_management_tab.dart';
import '../controllers/budget_controller.dart';
import 'app_spacers.dart';
import '../screens/sms_import_sheet.dart';
import 'add_transaction_sheet.dart';
import 'app_premium_fab.dart';

class BudgetTab extends StatefulWidget {
  final String? selectedBudgetId;
  final ValueChanged<BudgetItem?>? onBudgetChanged;

  const BudgetTab({
    super.key,
    this.selectedBudgetId,
    this.onBudgetChanged,
  });

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  late BudgetController _controller;
  String? _deletingExpenseId;

  @override
  void initState() {
    super.initState();
    _controller = BudgetController(
      initialSelectedBudgetId: widget.selectedBudgetId,
      onBudgetChanged: widget.onBudgetChanged,
    );
  }

  @override
  void didUpdateWidget(covariant BudgetTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBudgetId != oldWidget.selectedBudgetId) {
      _controller.setSelectedBudgetIdSilently(widget.selectedBudgetId);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deleteExpense(BudgetItem budget, String expenseId) async {
    await _controller.deleteExpense(budget, expenseId);
  }

  @override
  Widget build(BuildContext context) {
    return BaseManagementTab<BudgetController>(
      controller: _controller,
      isLoading: (ctrl) => ctrl.isLoading,
      errorMessage: (ctrl) => ctrl.errorMessage,
      isEmpty: (ctrl) => ctrl.budgets.isEmpty,
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyMessage: 'No budget limits added yet.',
      onRefresh: () async => await _controller.refresh(),
      onFabPressed: () {
        if (_controller.selectedBudget != null) {
          _showAddTransactionSheet(context, _controller.selectedBudget!);
        }
      },
      builder: (context, controller) {
        final budgets = controller.budgets;
        final selectedBudget = controller.selectedBudget;

        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(bottom: bottomPadding + 100 + viewInsetsBottom),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown Selector Row
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: _buildBudgetDropdown(budgets, controller),
                ),
                const HGapSm(),
                _buildCalendarButton(context, selectedBudget),
                const HGapSm(),
                _buildProgressButton(context, selectedBudget),
                const HGapSm(),
                _buildSmsImportButton(context, selectedBudget),
                const Spacer(),
              ],
            ),
            const VGapMd(),

            // Render selected budget details
            if (selectedBudget == null)
              _buildEmptyState('Select a budget category above.')
            else ...[
              _buildSelectedBudgetDetails(selectedBudget),
            ],
          ],
        ),
        );
      },
    );
  }


  void _showAddTransactionSheet(BuildContext context, BudgetItem budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        budgetId: budget.id,
        categoryName: budget.category,
        onAddTransaction: (tag, desc, amount, date) async {
          // Keep BudgetService direct usage here for adding transaction to avoid passing too much to controller
          await BudgetService().addExpenseToBudget(budget.id, tag, desc, amount, timestamp: date);
        },
      ),
    );
  }


  Widget _buildBudgetDropdown(List<BudgetItem> budgets, BudgetController controller) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppTheme.surfaceColor,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.7), size: 20),
          value: controller.selectedBudgetId,
          hint: Text(
            budgets.isEmpty ? 'No budgets' : 'Select a budget',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          items: budgets.map((budget) {
            final suffix = budget.checked ? '' : ' (Completed)';
            return DropdownMenuItem<String>(
              value: budget.id,
              child: Text(
                '${budget.category}$suffix',
                style: TextStyle(
                  color: budget.checked ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              controller.updateSelectedBudgetId(id);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectedBudgetDetails(BudgetItem budget) {
    final percent = budget.limit > 0 ? (budget.spentForCurrentPeriod / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget;
    final isActive = budget.checked;

    final Color statusColor = !isActive
        ? AppTheme.successColor
        : (isOver 
            ? AppTheme.errorColor 
            : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Visual Progress Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              budget.category,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15),
                            ),
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.textPrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.period.toUpperCase(),
                                style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (budget.period == 'custom' || budget.scheduledTime != null || (budget.repeatDays.isNotEmpty && budget.repeatDays.length < 7)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (budget.startDate != null && budget.endDate != null)
                                _buildCardTag(
                                  Icons.calendar_today_rounded,
                                  '${DateFormat('MMM d').format(budget.startDate!)} - ${DateFormat('MMM d').format(budget.endDate!)}',
                                ),
                              if (budget.repeatDays.isNotEmpty && budget.repeatDays.length < 7)
                                _buildCardTag(
                                  Icons.repeat_rounded,
                                  '${budget.repeatDays.length} days/wk',
                                ),
                              if (budget.scheduledTime != null)
                                _buildCardTag(
                                  Icons.notifications_active_outlined,
                                  budget.scheduledTime!,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'COMPLETED',
                        style: TextStyle(color: AppTheme.successColor, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const VGapMd(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ₹${budget.spentForCurrentPeriod.toStringAsFixed(1)}',
                    style: TextStyle(color: isOver && isActive ? AppTheme.errorColor : AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    'Limit: ₹${budget.limit.toStringAsFixed(1)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const VGapSm(),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: AppTheme.textPrimary.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const VGapMd(),

        // Expenses list
        const Text('Expense History', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const VGapSm(),
        if (budget.expenses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No expenses recorded yet.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: budget.expenses.length,
            itemBuilder: (context, index) {
              final expense = budget.expenses[budget.expenses.length - 1 - index];
              final formattedDate = DateFormat('d MMM yyyy - h:mm a').format(expense.timestamp);
              final lookup = expense.tag.isNotEmpty ? expense.tag : expense.description;
              final iconColor = _getTagColor(lookup);
              final iconData = _getTagIcon(lookup);
              final tagName = expense.tag.isNotEmpty ? expense.tag : _getTagName(expense.description);
              final isDeletingThis = _deletingExpenseId == expense.id;
              final isGain = expense.amount < 0;

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    _deletingExpenseId = isDeletingThis ? null : expense.id;
                  });
                },
                onTap: () {
                  if (_deletingExpenseId != null) {
                    setState(() => _deletingExpenseId = null);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDeletingThis
                        ? AppTheme.errorColor.withValues(alpha: 0.08)
                        : AppTheme.surfaceColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDeletingThis
                          ? AppTheme.errorColor.withValues(alpha: 0.2)
                          : AppTheme.textPrimary.withValues(alpha: 0.04),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Icon(
                          iconData,
                          color: iconColor,
                          size: 18,
                        ),
                      ),
                      const HGapMd(),
                      // Title and Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: tagName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight, fontSize: 13),
                                  ),
                                  if (expense.description.isNotEmpty) ...[
                                    TextSpan(
                                      text: ' | ',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                    TextSpan(
                                      text: expense.description,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const VGapXs(),
                            Text(
                              formattedDate,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        isGain
                            ? '+₹${expense.amount.abs().toStringAsFixed(1)}'
                            : '-₹${expense.amount.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isGain ? AppTheme.successColor : AppTheme.errorColor,
                          fontSize: 13,
                        ),
                      ),
                      // Delete Button (only on long press)
                      if (isDeletingThis) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _deleteExpense(budget, expense.id);
                            setState(() => _deletingExpenseId = null);
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: AppTheme.errorColor.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCardTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }



  Widget _buildCalendarButton(BuildContext context, BudgetItem? budget) {
    final hasDates = budget != null && (budget.startDate != null || budget.endDate != null);

    return Tooltip(
      message: hasDates ? 'View Budget Dates' : 'No Dates Set',
      child: GestureDetector(
        onTap: () {
          if (budget == null) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(budget.category, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (budget.description.isNotEmpty) ...[
                    Text(
                      budget.description,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const VGapMd(),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, color: AppTheme.primaryLight, size: 18),
                      const HGapSm(),
                      Text(
                        budget.startDate != null
                            ? 'Start: ${DateFormat('MMM d, yyyy').format(budget.startDate!)}'
                            : 'Start: Not set',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ],
                  ),
                  const VGapSm(),
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, color: AppTheme.successColor, size: 18),
                      const HGapSm(),
                      Text(
                        budget.endDate != null
                            ? 'End: ${DateFormat('MMM d, yyyy').format(budget.endDate!)}'
                            : 'End: Not set',
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ],
                  ),
                  if (budget.repeatDays.isNotEmpty) ...[
                    const VGapSm(),
                    Row(
                      children: [
                        const Icon(Icons.repeat_rounded, color: AppTheme.primaryLight, size: 18),
                        const HGapSm(),
                        Expanded(
                          child: Text(
                            'Repeat: ${budget.repeatDays.join(', ')}',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (budget.scheduledTime != null) ...[
                    const VGapSm(),
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryLight, size: 18),
                        const HGapSm(),
                        Text(
                          'Reminder: ${budget.scheduledTime!}',
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: hasDates
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.surfaceColor.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasDates
                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                  : AppTheme.textPrimary.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: hasDates ? AppTheme.primaryLight : AppTheme.textSecondary.withValues(alpha: 0.5),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressButton(BuildContext context, BudgetItem? budget) {
    if (budget == null) return const SizedBox.shrink();
    final total = budget.limit;
    final spent = budget.spentForCurrentPeriod;
    final percent = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget;
    final isActive = budget.checked;

    final Color statusColor = !isActive
        ? AppTheme.successColor
        : (isOver 
            ? AppTheme.errorColor 
            : (percent >= 0.7 ? AppTheme.warningColor : AppTheme.primaryColor));

    return Tooltip(
      message: 'Progress: ₹${spent.toStringAsFixed(1)}/₹${total.toStringAsFixed(1)} spent (${(percent * 100).toStringAsFixed(0)}%)',
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Budget Progress: ₹${spent.toStringAsFixed(1)} of ₹${total.toStringAsFixed(1)} spent (${(percent * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              backgroundColor: AppTheme.surfaceColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: statusColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 2.5,
                backgroundColor: AppTheme.textPrimary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmsImportButton(BuildContext context, BudgetItem? budget) {
    return Tooltip(
      message: 'Import from SMS',
      child: GestureDetector(
        onTap: () async {
          if (budget == null) return;
          final granted = await SmsTransactionService().requestPermission();
          if (!mounted) return;
          if (!granted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS permission is required to read transactions'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
            return;
          }
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SmsImportSheet(
              budgetId: budget.id,
              existingExpenses: budget.expenses,
            ),
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.sms_rounded,
            color: AppTheme.primaryLight,
            size: 16,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('eat') || cat.contains('restaurant') || cat.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('travel') || cat.contains('transport') || cat.contains('cab') || cat.contains('fuel') || cat.contains('car') || cat.contains('bike')) {
      return Icons.directions_car_rounded;
    }
    if (cat.contains('shopping') || cat.contains('cloth') || cat.contains('grocer')) {
      return Icons.shopping_bag_rounded;
    }
    if (cat.contains('bill') || cat.contains('rent') || cat.contains('utility') || cat.contains('phone') || cat.contains('recharge')) {
      return Icons.receipt_rounded;
    }
    if (cat.contains('entertainment') || cat.contains('movie') || cat.contains('game') || cat.contains('show')) {
      return Icons.movie_rounded;
    }
    if (cat.contains('health') || cat.contains('medical') || cat.contains('gym') || cat.contains('doctor')) {
      return Icons.medical_services_rounded;
    }
    if (cat.contains('education') || cat.contains('book') || cat.contains('class') || cat.contains('study')) {
      return Icons.menu_book_rounded;
    }
    if (cat.contains('gift') || cat.contains('present')) {
      return Icons.card_giftcard_rounded;
    }
    if (cat.contains('invest') || cat.contains('save') || cat.contains('stock') || cat.contains('mutual')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (cat.contains('pet') || cat.contains('dog') || cat.contains('cat')) {
      return Icons.pets_rounded;
    }
    return Icons.payment_rounded;
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('eat') || cat.contains('restaurant') || cat.contains('cafe')) {
      return Colors.amber;
    }
    if (cat.contains('travel') || cat.contains('transport') || cat.contains('cab') || cat.contains('fuel') || cat.contains('car') || cat.contains('bike')) {
      return Colors.blue;
    }
    if (cat.contains('shopping') || cat.contains('cloth') || cat.contains('grocer')) {
      return Colors.orange;
    }
    if (cat.contains('bill') || cat.contains('rent') || cat.contains('utility') || cat.contains('phone') || cat.contains('recharge')) {
      return Colors.redAccent;
    }
    if (cat.contains('entertainment') || cat.contains('movie') || cat.contains('game') || cat.contains('show')) {
      return Colors.purpleAccent;
    }
    if (cat.contains('health') || cat.contains('medical') || cat.contains('gym') || cat.contains('doctor')) {
      return Colors.green;
    }
    if (cat.contains('education') || cat.contains('book') || cat.contains('class') || cat.contains('study')) {
      return Colors.cyan;
    }
    if (cat.contains('gift') || cat.contains('present')) {
      return Colors.pinkAccent;
    }
    if (cat.contains('invest') || cat.contains('save') || cat.contains('stock') || cat.contains('mutual')) {
      return Colors.yellow;
    }
    if (cat.contains('pet') || cat.contains('dog') || cat.contains('cat')) {
      return Colors.teal;
    }
    return AppTheme.primaryColor;
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // ── Tag-based icon/color lookup (matches expense description) ──

  static const _tagIcons = <String, IconData>{
    'bill': Icons.receipt_long_rounded,
    'credit card': Icons.credit_card_rounded,
    'dinner': Icons.dinner_dining_rounded,
    'drink': Icons.local_cafe_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'grocery': Icons.local_grocery_store_rounded,
    'health': Icons.medical_services_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'snack': Icons.fastfood_rounded,
    'travel': Icons.flight_rounded,
    'other': Icons.more_horiz_rounded,
  };

  static const _tagColors = <String, Color>{
    'bill': Colors.redAccent,
    'credit card': Colors.indigo,
    'dinner': Colors.amber,
    'drink': Colors.brown,
    'fuel': Colors.blue,
    'grocery': Colors.green,
    'health': Colors.teal,
    'shopping': Colors.pinkAccent,
    'snack': Colors.orange,
    'travel': Colors.indigo,
    'other': Colors.grey,
  };

  String _getTagName(String description) {
    final key = description.toLowerCase();
    for (final entry in _tagIcons.entries) {
      if (key.contains(entry.key)) {
        return entry.key
            .split(' ')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
      }
    }
    return 'Other';
  }

  IconData _getTagIcon(String description) {
    final key = description.toLowerCase();
    for (final entry in _tagIcons.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return Icons.payment_rounded;
  }

  Color _getTagColor(String description) {
    final key = description.toLowerCase();
    for (final entry in _tagColors.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return AppTheme.primaryColor;
  }
}
