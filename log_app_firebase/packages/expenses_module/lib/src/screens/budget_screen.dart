import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import 'package:core_services/core_services.dart';
import 'package:core_ui/core_ui.dart';
import '../controllers/budget_controller.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/budget_expense_graph.dart';
import '../widgets/category_breakdown_sheet.dart';
import '../widgets/budget_progress_bar.dart';

class BudgetScreen extends StatefulWidget {
  final String? selectedBudgetId;
  final ValueChanged<Budget?>? onBudgetChanged;

  const BudgetScreen({
    super.key,
    this.selectedBudgetId,
    this.onBudgetChanged,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late BudgetController _controller;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _filterType = 'all'; // 'all', 'debit', 'credit'
  String _filterValidation = 'all'; // 'all', 'validated', 'pending'

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
  void didUpdateWidget(covariant BudgetScreen oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return AppProvider<BudgetController>(
      notifier: _controller,
      child: Stack(
        children: [
          Positioned.fill(
            child: FullScreenPage(
              showScaffold: false,
              isScrollable: false,
              title: 'Budget',
              padding: EdgeInsets.zero,
              backgroundWidgets: [
                GlowBlob(
                  top: -40,
                  left: -40,
                  size: 220,
                  color: AppTheme.primaryColor,
                  opacity: 0.08,
                ),
                GlowBlob(
                  bottom: -50,
                  right: -50,
                  size: 260,
                  color: AppTheme.secondaryColor,
                  opacity: 0.05,
                ),
              ],
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _buildBody(context),
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final hasBudgets = _controller.budgets.isNotEmpty;
              final selectedBudget = _controller.selectedBudget;
              final isPeriodOver = selectedBudget?.isPeriodOver ?? false;
              if (hasBudgets && !_controller.isLoading && _controller.errorMessage == null && !isPeriodOver) {
                return AppPremiumFab(
                  right: 24,
                  onPressed: () {
                    if (_controller.selectedBudget != null) {
                      _showAddTransactionSheet(context, _controller.selectedBudget!);
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_controller.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'Failed to load data:\n${_controller.errorMessage}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
      );
    }

    if (_controller.budgets.isEmpty) {
      return AppEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No Budget Limits Set',
        description: 'Define limits for categories to track and optimize your spending.',
        actionLabel: 'Set Budget Limit',
        onActionPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
          );
        },
      );
    }

    final budgets = _controller.budgets;
    final selectedBudget = _controller.selectedBudget;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: bottomPadding + 100 + viewInsetsBottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VGapSm(),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: _buildBudgetDropdown(budgets, _controller),
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
              _buildSelectedBudgetDetails(selectedBudget, _controller),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodOverBanner(Budget budget) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.errorColor, size: 20),
              const HGapSm(),
              Text(
                'Budget Period Over',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const VGapSm(),
          Text(
            'This budget period ended on ${DateFormat('MMMM d, yyyy').format(budget.endDate!)}. This budget is now read-only.',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddBudgetScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: const Text('New Budget', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const HGapSm(),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddBudgetScreen(
                          existingBudget: budget,
                          isCopy: true,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy_rounded, size: 16, color: AppTheme.primaryAccentColor(context)),
                  label: Text(
                    'Copy Budget',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryAccentColor(context)),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTransactionSheet(BuildContext context, Budget budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        budgetId: budget.id,
        categoryName: budget.categoryName,
        onAddTransaction: (tag, desc, amount, date, paymentMethod) async {
          await BudgetService().addTransaction(budget.id, tag, desc, amount, timestamp: date, paymentMethod: paymentMethod);
        },
      ),
    );
  }

  Widget _buildBudgetDropdown(List<Budget> budgets, BudgetController controller) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppTheme.surface(context),
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
            String suffix = '';
            if (budget.isPeriodOver) {
              suffix = ' (Ended)';
            } else if (!budget.isActive) {
              suffix = ' (Completed)';
            }
            return DropdownMenuItem<String>(
              value: budget.id,
              child: Text(
                '${budget.name}$suffix',
                style: TextStyle(
                  color: budget.isActive && !budget.isPeriodOver
                      ? AppTheme.textPrimaryColor(context)
                      : AppTheme.textSecondaryColor(context),
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
    final isActive = budget.isActive;

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
            color: AppTheme.surface(context).withValues(alpha: 0.35),
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
                              budget.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor(context),
                                fontSize: 15,
                              ),
                            ),
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.categoryName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.primaryAccentColor(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const HGapSm(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                budget.period.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (budget.period == 'custom' && budget.startDate != null && budget.endDate != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildCardTag(
                                Icons.calendar_today_rounded,
                                '${DateFormat('MMM d').format(budget.startDate!)} - ${DateFormat('MMM d').format(budget.endDate!)}',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const HGapSm(),
                      GestureDetector(
                        onTap: () => _showCategoryBreakdownSheet(budget, controller.selectedBudgetTransactions),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1),
                          ),
                          child: Icon(Icons.pie_chart_outline_rounded, size: 14, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const VGapMd(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: ₹${spent.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: isOver && isActive
                          ? AppTheme.errorColor
                          : AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Limit: ₹${budget.limit.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const VGapMd(),
              BudgetProgressBar(
                percent: percent,
                alertThreshold: budget.alertThreshold,
                statusColor: statusColor,
                minHeight: 6,
              ),
            ],
          ),
        ),
        if (budget.isPeriodOver) ...[
          const VGapMd(),
          _buildPeriodOverBanner(budget),
        ],
        const VGapMd(),

        // Expense History Bar Graph
        RepaintBoundary(
          child: BudgetExpenseGraph(
            budget: budget,
            transactions: controller.transactions,
          ),
        ),
        const VGapMd(),

        // Expenses list
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expense History',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.filter_list_rounded,
                color: (_filterStartDate != null || _filterType != 'all' || _filterValidation != 'all')
                    ? AppTheme.primaryAccentColor(context)
                    : AppTheme.textSecondaryColor(context),
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
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No matching expenses found.',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
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
            padding: EdgeInsets.zero,
            itemCount: displayExpenses.length,
            itemBuilder: (context, index) {
              final expense = displayExpenses[index];
              final formattedDate = DateFormat('d MMM yyyy - h:mm a').format(expense.expenseDate);
              final lookup = expense.tag.isNotEmpty ? expense.tag : expense.description;
              final iconColor = _getTagColor(lookup);
              final iconData = _getTagIcon(lookup);
              final tagName = expense.tag.isNotEmpty ? expense.tag : _getTagName(expense.description);
              final isGain = expense.amount < 0;
              return GestureDetector(
                onTap: () => _handleExpenseTap(budget, expense),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: expense.isValidated ? AppTheme.surface(context).withValues(alpha: 0.5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: expense.isValidated 
                          ? AppTheme.borderColor(context) 
                          : AppTheme.warningColor.withValues(alpha: 0.35),
                      width: expense.isValidated ? 1.0 : 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          expense.description.isNotEmpty
                                              ? '$tagName | ${expense.description} [${expense.paymentMethod}]'
                                              : '$tagName [${expense.paymentMethod}]',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimaryColor(context),
                                            fontSize: 13,
                                          ),
                                        ),
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
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor(context),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const HGapMd(),
                      Text(
                        '${isGain ? '+' : '-'}₹${expense.amount.abs().toStringAsFixed(1)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isGain ? AppTheme.successColor : AppTheme.errorColor,
                          fontSize: 14,
                        ),
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
        color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: AppTheme.textSecondaryColor(context),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: AppTheme.textSecondaryColor(context),
            ),
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
              backgroundColor: AppTheme.surface(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                budget.name,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (budget.description.isNotEmpty) ...[
                    Text(
                      budget.description,
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor(context),
                        fontSize: 13,
                      ),
                    ),
                    const VGapMd(),
                  ],
                  Row(
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        color: AppTheme.primaryAccentColor(context),
                        size: 18,
                      ),
                      const HGapSm(),
                      Text(
                        budget.startDate != null
                            ? 'Start: ${DateFormat('MMM d, yyyy').format(budget.startDate!)}'
                            : 'Start: Not set',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 13,
                        ),
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
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (budget.repeatDays.isNotEmpty) ...[
                    const VGapSm(),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          color: AppTheme.primaryAccentColor(context),
                          size: 18,
                        ),
                        const HGapSm(),
                        Expanded(
                          child: Text(
                            'Repeat: ${budget.repeatDays.join(', ')}',
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (budget.scheduledTime != null) ...[
                    const VGapSm(),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: AppTheme.primaryAccentColor(context),
                          size: 18,
                        ),
                        const HGapSm(),
                        Text(
                          'Reminder: ${budget.scheduledTime!}',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(color: AppTheme.primaryColor)),
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
                : AppTheme.surface(context).withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasDates
                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                  : AppTheme.borderColor(context),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: hasDates
                ? AppTheme.primaryAccentColor(context)
                : AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
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
    final isActive = budget.isActive;

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
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              backgroundColor: AppTheme.surface(context),
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
                backgroundColor: AppTheme.textPrimaryColor(context).withValues(alpha: 0.1),
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
          child: Icon(
            Icons.notifications_active_rounded,
            color: AppTheme.primaryAccentColor(context),
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
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Notification Scanner Access',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'LOG requires Notification Access to automatically scan and import transaction alerts from banking and UPI apps in real time. Your messages are parsed locally on your device.',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _handleDismissSetupDialog,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
            TextButton(
              onPressed: _handleEnableScannerAccess,
              child: Text(
                'Enable Access',
                style: TextStyle(
                  color: AppTheme.primaryAccentColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
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

  void _showCategoryBreakdownSheet(Budget budget, List<Transaction> transactions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CategoryBreakdownSheet(
        budget: budget,
        transactions: transactions,
        getTagIcon: _getTagIcon,
        getTagColor: _getTagColor,
        getTagName: _getTagName,
      ),
    );
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddTransactionSheet(
        budgetId: budget.id,
        categoryName: budget.categoryName,
        existingTransaction: expense,
        budgets: _controller.budgets,
        onAddTransaction: (tag, desc, amount, date, paymentMethod) async {},
      ),
    );
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
    'grocery': Icons.local_grocery_store_rounded,
    'fast food': Icons.fastfood_rounded,
    'meals': Icons.restaurant_rounded,
    'drinks': Icons.local_bar_rounded,
    'supplements': Icons.medication_rounded,
    'travel': Icons.flight_rounded,
    'care': Icons.favorite_rounded,
    'home': Icons.home_rounded,
    'bills': Icons.receipt_long_rounded,
    'timepass': Icons.sports_esports_rounded,
    'transfer': Icons.compare_arrows_rounded,
    'quickmart': Icons.storefront_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'receive': Icons.call_received_rounded,
    'other': Icons.more_horiz_rounded,
    // Keep backward compatible tags
    'bill': Icons.receipt_long_rounded,
    'credit card': Icons.credit_card_rounded,
    'dinner': Icons.dinner_dining_rounded,
    'drink': Icons.local_cafe_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'health': Icons.medical_services_rounded,
    'snack': Icons.fastfood_rounded,
  };

  static const _tagColors = <String, Color>{
    'grocery': Colors.green,
    'fast food': Colors.orange,
    'meals': Colors.deepOrange,
    'drinks': Colors.cyan,
    'supplements': Colors.teal,
    'travel': Colors.indigo,
    'care': Colors.pink,
    'home': Colors.blueGrey,
    'bills': Colors.redAccent,
    'timepass': Colors.purple,
    'transfer': Colors.blue,
    'quickmart': Colors.deepPurpleAccent,
    'shopping': Colors.pinkAccent,
    'receive': Colors.greenAccent,
    'other': Colors.grey,
    // Keep backward compatible tags
    'bill': Colors.redAccent,
    'credit card': Colors.indigo,
    'dinner': Colors.amber,
    'drink': Colors.brown,
    'fuel': Colors.blue,
    'health': Colors.teal,
    'snack': Colors.orange,
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
