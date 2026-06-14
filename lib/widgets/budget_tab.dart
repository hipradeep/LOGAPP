import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/notification_transaction_service.dart';
import '../theme/app_theme.dart';
import 'base_management_tab.dart';
import '../controllers/budget_controller.dart';
import 'app_spacers.dart';
import 'transaction_filter_sheet.dart';
import 'add_transaction_sheet.dart';
import 'app_provider.dart';

class BudgetTab extends StatefulWidget {
  final String? selectedBudgetId;
  final ValueChanged<Budget?>? onBudgetChanged;

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
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _filterType = 'all'; // 'all', 'debit', 'credit'
  String _filterValidation = 'all'; // 'all', 'validated', 'pending'
  String? _deletingExpenseId;

  @override
  void initState() {
    super.initState();
    _controller = BudgetController(
      onBudgetChanged: widget.onBudgetChanged,
      initialSelectedBudgetId: widget.selectedBudgetId,
    );
    _filterStartDate = DateTime.now().subtract(const Duration(days: 30));
    _filterEndDate = DateTime.now();

    _initNotificationScannerService();
  }

  void _initNotificationScannerService() async {
    final granted = await NotificationTransactionService.isPermissionGranted();
    if (granted) {
      await NotificationTransactionService.startService();
    }
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

  void _deleteTransaction(Budget budget, String expenseId) async {
    await _controller.deleteTransaction(budget, expenseId);
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
                  _buildScannerStatusButton(context, selectedBudget),
                  const Spacer(),
                ],
              ),
              const VGapMd(),

              // Render selected budget details
              if (selectedBudget == null)
                _buildEmptyState('Select a budget category above.')
              else ...[
                _buildSelectedBudgetDetails(selectedBudget, controller),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showAddTransactionSheet(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        budgetId: budget.id,
        categoryName: budget.category,
        onAddTransaction: (tag, desc, amount, date) async {
          await BudgetService().addTransaction(budget.id, tag, desc, amount, timestamp: date);
        },
      ),
    );
  }

  Widget _buildBudgetDropdown(List<Budget> budgets, BudgetController controller) {
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

  Widget _buildSelectedBudgetDetails(Budget budget, BudgetController controller) {
    final spent = budget.spentForCurrentPeriod(controller.transactions);
    final percent = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget(controller.transactions);
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
                    'Spent: ₹${spent.toStringAsFixed(1)}',
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Expense History', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: (_filterStartDate != null || _filterType != 'all' || _filterValidation != 'all')
                    ? AppTheme.primaryLight
                    : AppTheme.textSecondary,
                size: 20,
              ),
              onPressed: _showFilterSheet,
            ),
          ],
        ),
        const VGapSm(),
        () {
          final filteredExpenses = controller.selectedBudgetTransactions.where((expense) {
            if (_filterStartDate != null && expense.expenseDate.isBefore(_filterStartDate!)) {
              return false;
            }
            if (_filterEndDate != null && expense.expenseDate.isAfter(_filterEndDate!.add(const Duration(days: 1)))) {
              return false;
            }
            final isGain = expense.amount < 0;
            if (_filterType == 'debit' && isGain) return false;
            if (_filterType == 'credit' && !isGain) return false;
            if (_filterValidation == 'validated' && !expense.isValidated) return false;
            if (_filterValidation == 'pending' && expense.isValidated) return false;
            return true;
          }).toList();

          filteredExpenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
          final displayExpenses = filteredExpenses;

          if (displayExpenses.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No matching expenses found.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayExpenses.length,
            itemBuilder: (context, index) {
              final expense = displayExpenses[index];
              final formattedDate = DateFormat('d MMM yyyy - h:mm a').format(expense.expenseDate);
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
                onTap: () => _handleExpenseTap(budget, expense),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDeletingThis 
                        ? AppTheme.errorColor.withValues(alpha: 0.1) 
                        : (expense.isValidated ? Colors.white.withValues(alpha: 0.02) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDeletingThis 
                          ? AppTheme.errorColor 
                          : (expense.isValidated 
                              ? Colors.white.withValues(alpha: 0.03) 
                              : AppTheme.warningColor.withValues(alpha: 0.35)),
                      width: expense.isValidated ? 1.0 : 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 16),
                          ),
                          const HGapMd(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    tagName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 13),
                                  ),
                                  if (!expense.isValidated) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
                                      ),
                                      child: const Text(
                                        'Pending',
                                        style: TextStyle(color: AppTheme.warningColor, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                formattedDate,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '${isGain ? '+' : '-'}₹${expense.amount.abs().toStringAsFixed(1)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isGain ? AppTheme.successColor : AppTheme.errorColor,
                              fontSize: 14,
                            ),
                          ),
                          if (isDeletingThis) ...[
                            const HGapMd(),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorColor, size: 20),
                              onPressed: () => _deleteTransaction(budget, expense.id),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }(),
      ],
    );
  }

  Widget _buildCardTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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

  Widget _buildCalendarButton(BuildContext context, Budget? budget) {
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

  Widget _buildProgressButton(BuildContext context, Budget? budget) {
    if (budget == null) return const SizedBox.shrink();
    final controller = AppProvider.watch<BudgetController>(context);
    final total = budget.limit;
    final spent = budget.spentForCurrentPeriod(controller.transactions);
    final percent = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final isOver = budget.isOverBudget(controller.transactions);
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

  Widget _buildScannerStatusButton(BuildContext context, Budget? budget) {
    return Tooltip(
      message: 'Notification Scanner Settings',
      child: GestureDetector(
        onTap: _handleNotificationScannerSetup,
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
            Icons.notifications_active_rounded,
            color: AppTheme.primaryLight,
            size: 16,
          ),
        ),
      ),
    );
  }

  void _handleNotificationScannerSetup() async {
    final hasPermission = await NotificationTransactionService.isPermissionGranted();
    if (!mounted) return;

    if (!hasPermission) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Notification Scanner Access',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'LOG requires Notification Access to automatically scan and import transaction alerts from banking, UPI, and SMS apps in real time. Your messages are parsed locally on your device.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: _handleDismissSetupDialog,
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: _handleEnableScannerAccess,
              child: const Text('Enable Access', style: TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      await NotificationTransactionService.startService();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification transaction scanner is running in the background.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _handleDismissSetupDialog() {
    Navigator.pop(context);
  }

  void _handleEnableScannerAccess() async {
    Navigator.pop(context);
    await NotificationTransactionService.requestPermission();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TransactionFilterSheet(
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        initialType: _filterType,
        initialValidation: _filterValidation,
        onApply: _handleApplyFilters,
      ),
    );
  }

  void _handleApplyFilters(DateTime? start, DateTime? end, String type, String validation) {
    setState(() {
      _filterStartDate = start;
      _filterEndDate = end;
      _filterType = type;
      _filterValidation = validation;
    });
  }

  void _handleExpenseTap(Budget budget, Transaction expense) {
    if (_deletingExpenseId != null) {
      setState(() => _deletingExpenseId = null);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => AddTransactionSheet(
          budgetId: budget.id,
          categoryName: budget.category,
          existingTransaction: expense,
          budgets: _controller.budgets,
          onAddTransaction: (tag, desc, amount, date) async {},
        ),
      );
    }
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
    'quickmart': Icons.storefront_rounded,
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
    'quickmart': Colors.deepPurpleAccent,
    'shopping': Colors.pinkAccent,
    'snack': Colors.orange,
    'travel': Colors.indigo,
    'other': Colors.grey,
  };

  String _getTagName(String description) {
    final key = description.toLowerCase();
    if (key.contains('quickmart')) return 'QuickMart';
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
