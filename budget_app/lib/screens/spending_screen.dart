import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/budget.dart';
import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_empty_state.dart';
import 'add_transaction_screen.dart';
import '../widgets/app_premium_fab.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_modal_sheet.dart';
import 'add_budget_screen.dart';

class SpendingScreen extends StatefulWidget {
  final BudgetController controller;

  const SpendingScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SpendingScreen> createState() => _SpendingScreenState();
}

class _SpendingScreenState extends State<SpendingScreen> {
  late DateTime _selectedMonth;

  static final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _showMonthPicker() {
    int pickerYear = _selectedMonth.year;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            const months = [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December',
            ];
            final now = DateTime.now();

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: AppTheme.borderColor(context),
                  width: 0.8,
                ),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const VGapMd(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 28),
                        color: AppTheme.textPrimaryColor(context),
                        onPressed: () {
                          setSheetState(() => pickerYear--);
                        },
                      ),
                      Text(
                        '$pickerYear',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 28),
                        color: AppTheme.textPrimaryColor(context),
                        onPressed: () {
                          setSheetState(() => pickerYear++);
                        },
                      ),
                    ],
                  ),
                  const VGapMd(),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected =
                          _selectedMonth.year == pickerYear && _selectedMonth.month == monthNum;
                      final isCurrentMonth = now.year == pickerYear && now.month == monthNum;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMonth = DateTime(pickerYear, monthNum, 1);
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.surface(context).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : (isCurrentMonth
                                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                      : AppTheme.borderColor(context)),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            months[index].substring(0, 3),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isSelected || isCurrentMonth ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isCurrentMonth
                                      ? AppTheme.primaryLight
                                      : AppTheme.textPrimaryColor(context)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEditTransaction(Transaction tx) {
    AddTransactionScreen.navigate(
      context,
      existingTransaction: tx,
      budgetId: tx.budgetId,
      budgets: widget.controller.budgets,
    );
  }

  void _openDownloadReport(
    BuildContext context,
    Budget? budget,
    List<Transaction> transactions,
  ) {
    final monthStr = DateFormat('MMMM yyyy').format(_selectedMonth);
    final totalSpent = transactions.fold(0.0, (sum, t) => sum + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassModalSheet(
        title: 'Spending Report',
        subtitle: '$monthStr • ${budget?.name ?? "All Spending"}',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Expenses',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(totalSpent),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      const VGapSm(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transactions',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor(context),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${transactions.length}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      if (budget != null) ...[
                        const VGapSm(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget Limit',
                              style: TextStyle(
                                color: AppTheme.textSecondaryColor(context),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(budget.limit),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const VGapLg(),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _exportCsvReport(context, budget, transactions, _selectedMonth);
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    'Download CSV Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const VGapMd(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsvReport(
    BuildContext context,
    Budget? budget,
    List<Transaction> transactions,
    DateTime month,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Merchant,Category,Payment Method,Amount');
    for (final tx in transactions) {
      final date = DateFormat('yyyy-MM-dd').format(tx.expenseDate);
      final merchant = '"${(tx.merchant ?? tx.description).replaceAll('"', '""')}"';
      final category = '"${tx.tag.replaceAll('"', '""')}"';
      final method = '"${tx.paymentMethod.replaceAll('"', '""')}"';
      buffer.writeln('$date,$merchant,$category,$method,${tx.amount}');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final budgetTag = budget != null ? '_${budget.name.replaceAll(' ', '_')}' : '';
      final fileName = 'Spending_Report_${DateFormat('yyyy_MM').format(month)}$budgetTag.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buffer.toString());
      if (context.mounted) {
        AppToast.show(context, 'Report saved: $fileName');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, 'Report exported for ${DateFormat('MMMM yyyy').format(month)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final budgets = widget.controller.budgets;
        final selectedBudget = widget.controller.selectedBudget;
        final transactions = _filterTransactions(widget.controller.transactions, selectedBudget);

        return Stack(
          children: [
            FullScreenPage(
              showScaffold: false,
              isScrollable: true,
              title: 'Spending',
              headerSpacing: MediaQuery.paddingOf(context).top + 52.0,
              padding: AppTheme.defaultScreenPadding,
              actions: [
                _MonthPillButton(
                  selectedMonth: _selectedMonth,
                  onTap: _showMonthPicker,
                ),
              ],
              backgroundWidgets: [
                GlowBlob(
                  top: -40,
                  left: -40,
                  size: 220,
                  color: AppTheme.primaryColor,
                  opacity: 0.10,
                ),
                GlowBlob(
                  bottom: -50,
                  right: -50,
                  size: 260,
                  color: AppTheme.secondaryColor,
                  opacity: 0.06,
                ),
              ],
              children: [
                const VGapSm(),
                Row(
                  children: [
                    Expanded(
                      child: _BudgetDropdown(
                        budgets: budgets,
                        selectedBudgetId: widget.controller.selectedBudgetId,
                        onChanged: widget.controller.updateSelectedBudgetId,
                      ),
                    ),
                    const HGapSm(),
                    _DownloadReportButton(
                      onTap: () => _openDownloadReport(context, selectedBudget, transactions),
                    ),
                  ],
                ),
                const VGapMd(),
                _MonthlyBudgetCard(
                  budget: selectedBudget,
                  transactions: transactions,
                  formatCurrency: _currencyFormat.format,
                ),
                const VGapMd(),
                _SpendingByCategoryCard(
                  transactions: transactions,
                  formatCurrency: _currencyFormat.format,
                ),
                const VGapMd(),
                _SpendingBreakdownCard(
                  transactions: transactions,
                  formatCurrency: _currencyFormat.format,
                  onTapTransaction: _openEditTransaction,
                ),
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
                  AddTransactionScreen.navigate(
                    context,
                    budgetId: selectedBudget?.id,
                    budgets: budgets,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> all, Budget? budget) {
    return all.where((t) {
      if (!t.isExpense) return false;
      if (budget != null && t.budgetId != budget.id) return false;
      return t.expenseDate.year == _selectedMonth.year &&
          t.expenseDate.month == _selectedMonth.month;
    }).toList();
  }
}

class _MonthPillButton extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onTap;

  const _MonthPillButton({
    required this.selectedMonth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM').format(selectedMonth);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.textSecondaryColor(context),
              ),
              const HGapSm(),
              Text(
                monthName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadReportButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DownloadReportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.file_download_outlined,
          color: AppTheme.primaryLight,
          size: 20,
        ),
        tooltip: 'Download Report',
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }
}

class _BudgetDropdown extends StatelessWidget {
  final List<Budget> budgets;
  final String? selectedBudgetId;
  final ValueChanged<String?> onChanged;

  const _BudgetDropdown({
    required this.budgets,
    required this.selectedBudgetId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            size: 20,
          ),
          value: selectedBudgetId,
          hint: Text(
            budgets.isEmpty ? 'No budgets' : 'Select a budget',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
              fontSize: 13,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MonthlyBudgetCard extends StatelessWidget {
  final Budget? budget;
  final List<Transaction> transactions;
  final String Function(double) formatCurrency;

  const _MonthlyBudgetCard({
    required this.budget,
    required this.transactions,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final double limit = budget?.limit ?? 0.0;
    final double spent = transactions.fold(0.0, (sum, t) => sum + t.amount);
    final double remaining = (limit - spent).clamp(0.0, double.infinity);
    final double progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            budget?.name ?? 'Monthly Budget',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapXs(),
          Text(
            '${formatCurrency(remaining)} remaining',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapMd(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  color: AppTheme.borderColor(context).withValues(alpha: 0.35),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C48C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.credit_card_rounded,
                    size: 18,
                    color: Color(0xFFFF4B72),
                  ),
                  const HGapSm(),
                  Text(
                    formatCurrency(spent),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4B72),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_circle_down_rounded,
                    size: 18,
                    color: Color(0xFF1E6BFB),
                  ),
                  const HGapSm(),
                  Text(
                    formatCurrency(limit),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E6BFB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingByCategoryCard extends StatelessWidget {
  final List<Transaction> transactions;
  final String Function(double) formatCurrency;

  const _SpendingByCategoryCard({
    required this.transactions,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> categorySums = {};
    for (final t in transactions) {
      final key = t.tag.isNotEmpty ? t.tag : (t.merchant ?? 'Other');
      categorySums[key] = (categorySums[key] ?? 0.0) + t.amount;
    }

    final totalSpent = categorySums.values.fold(0.0, (sum, val) => sum + val);
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final segments = <_CategoryDonutSegment>[];
    for (int i = 0; i < sortedCategories.length; i++) {
      final item = sortedCategories[i];
      segments.add(
        _CategoryDonutSegment(
          label: item.key,
          value: item.value,
          color: _CategoryHelper.getColor(item.key, i),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending by Category',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapMd(),
          if (sortedCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No expenses recorded for this period.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(120, 120),
                    painter: _DonutChartPainter(
                      segments: segments,
                      total: totalSpent,
                      strokeWidth: 20,
                      gapColor: AppTheme.surface(context),
                    ),
                  ),
                ),
                const HGapLg(),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      min(sortedCategories.length, 6),
                      (index) {
                        final seg = segments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: seg.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const HGapSm(),
                              Expanded(
                                child: Text(
                                  seg.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatCurrency(seg.value),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SpendingBreakdownCard extends StatelessWidget {
  final List<Transaction> transactions;
  final String Function(double) formatCurrency;
  final ValueChanged<Transaction> onTapTransaction;

  const _SpendingBreakdownCard({
    required this.transactions,
    required this.formatCurrency,
    required this.onTapTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final sortedList = List<Transaction>.from(transactions)
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapMd(),
          if (sortedList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Spending Breakdown',
                message: 'No transactions found for the selected month.',
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: sortedList.length,
              itemBuilder: (context, index) {
                final tx = sortedList[index];
                return _SpendingItemTile(
                  transaction: tx,
                  formatCurrency: formatCurrency,
                  onTap: () => onTapTransaction(tx),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SpendingItemTile extends StatelessWidget {
  final Transaction transaction;
  final String Function(double) formatCurrency;
  final VoidCallback onTap;

  const _SpendingItemTile({
    required this.transaction,
    required this.formatCurrency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = transaction.tag.isNotEmpty ? transaction.tag : 'Other';
    final merchant = transaction.merchant?.isNotEmpty == true
        ? transaction.merchant!
        : (transaction.description.isNotEmpty ? transaction.description : category);
    final iconData = _CategoryHelper.getIcon(category, transaction.merchant);
    final color = _CategoryHelper.getColor(category, 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconData, color: color, size: 22),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const VGap2(),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const HGapSm(),
              Text(
                formatCurrency(transaction.amount),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDonutSegment {
  final String label;
  final double value;
  final Color color;

  const _CategoryDonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_CategoryDonutSegment> segments;
  final double total;
  final double strokeWidth;
  final Color gapColor;

  const _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.strokeWidth,
    required this.gapColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - (strokeWidth / 2);
    const gapAngle = 0.04;

    if (total <= 0 || segments.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = gapColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    double startAngle = -pi / 2;

    for (final seg in segments) {
      final sweep = (seg.value / total) * (2 * pi) - gapAngle;
      if (sweep <= 0) continue;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.total != total;
}

class _CategoryHelper {
  static IconData getIcon(String categoryOrTag, String? merchant) {
    final term = '${categoryOrTag.toLowerCase()} ${(merchant ?? '').toLowerCase()}';
    if (term.contains('rent') ||
        term.contains('house') ||
        term.contains('housing') ||
        term.contains('home')) {
      return Icons.home_rounded;
    }
    if (term.contains('gas') ||
        term.contains('fuel') ||
        term.contains('car') ||
        term.contains('transport') ||
        term.contains('travel')) {
      return Icons.directions_car_rounded;
    }
    if (term.contains('grocer') ||
        term.contains('eat') ||
        term.contains('food') ||
        term.contains('restaurant') ||
        term.contains('meal') ||
        term.contains('snack')) {
      return Icons.restaurant_rounded;
    }
    if (term.contains('clothe') ||
        term.contains('cloth') ||
        term.contains('shopping') ||
        term.contains('mart')) {
      return Icons.shopping_bag_rounded;
    }
    if (term.contains('spotify') || term.contains('music')) {
      return Icons.music_note_rounded;
    }
    if (term.contains('netflix') ||
        term.contains('movie') ||
        term.contains('entertain') ||
        term.contains('tv') ||
        term.contains('sub')) {
      return Icons.tv_rounded;
    }
    if (term.contains('bill') ||
        term.contains('utility') ||
        term.contains('electric')) {
      return Icons.receipt_long_rounded;
    }
    if (term.contains('health') ||
        term.contains('care') ||
        term.contains('med')) {
      return Icons.favorite_rounded;
    }
    return Icons.credit_card_rounded;
  }

  static Color getColor(String categoryOrTag, int fallbackIndex) {
    final term = categoryOrTag.toLowerCase();
    if (term.contains('rent') ||
        term.contains('house') ||
        term.contains('housing') ||
        term.contains('home')) {
      return const Color(0xFF2B7FFF);
    }
    if (term.contains('food') ||
        term.contains('grocer') ||
        term.contains('eat') ||
        term.contains('meal')) {
      return const Color(0xFFFF4B72);
    }
    if (term.contains('gas') ||
        term.contains('transport') ||
        term.contains('car') ||
        term.contains('fuel')) {
      return const Color(0xFF8B5CF6);
    }
    if (term.contains('clothe') || term.contains('shopping')) {
      return const Color(0xFFFFA03A);
    }
    if (term.contains('entertain') ||
        term.contains('netflix') ||
        term.contains('spotify')) {
      return const Color(0xFF00C48C);
    }

    const palette = [
      Color(0xFF2B7FFF),
      Color(0xFFFF4B72),
      Color(0xFF8B5CF6),
      Color(0xFFFFA03A),
      Color(0xFF00C48C),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
      Color(0xFF6366F1),
    ];
    return palette[fallbackIndex % palette.length];
  }
}
