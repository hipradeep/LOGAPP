import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/budget_selector_sheet.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class BudgetTransactionsScreen extends StatefulWidget {
  final String? initialBudgetId;

  const BudgetTransactionsScreen({super.key, this.initialBudgetId});

  @override
  State<BudgetTransactionsScreen> createState() =>
      _BudgetTransactionsScreenState();
}

class _BudgetTransactionsScreenState extends State<BudgetTransactionsScreen> {
  String? _selectedBudgetId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _filterType = 'all'; // 'all', 'debit', 'credit'

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.initialBudgetId;
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
        onApply: (start, end, type) {
          setState(() {
            _filterStartDate = start;
            _filterEndDate = end;
            _filterType = type;
          });
        },
      ),
    );
  }

  Widget _buildBudgetDropdown(List<Budget> budgets) {
    if (budgets.isEmpty) return const SizedBox.shrink();

    // Ensure a specific budget is always selected
    final activeId = _selectedBudgetId ?? budgets.first.id;
    final selectedBudget =
        budgets.where((b) => b.id == activeId).firstOrNull ?? budgets.first;

    String suffix = '';
    if (selectedBudget.isPeriodOver) {
      suffix = ' (Ended)';
    } else if (!selectedBudget.isActive) {
      suffix = ' (Inactive)';
    }
    final displayText = '${selectedBudget.name}$suffix';

    return InkWell(
      onTap: () {
        BudgetSelectorSheet.show(
          context,
          budgets: budgets,
          selectedBudgetId: activeId,
          onSelected: (id) {
            if (id != null) {
              setState(() => _selectedBudgetId = id);
            }
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<FinanceController>(context);
    final budgets = controller.budgets;

    final activeBudgetId =
        _selectedBudgetId ?? (budgets.isNotEmpty ? budgets.first.id : null);
    List<BudgetTransaction> transactions = activeBudgetId != null
        ? controller.transactionsForBudget(activeBudgetId)
        : const [];

    final filteredTransactions = transactions.where((tx) {
      if (_filterStartDate != null &&
          tx.timestamp.isBefore(_filterStartDate!)) {
        return false;
      }
      if (_filterEndDate != null &&
          tx.timestamp.isAfter(_filterEndDate!.add(const Duration(days: 1)))) {
        return false;
      }
      if (_filterType == 'debit' && !tx.isExpense) return false;
      if (_filterType == 'credit' && tx.isExpense) return false;
      return true;
    }).toList();

    filteredTransactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final isFiltered =
        _filterStartDate != null ||
        _filterEndDate != null ||
        _filterType != 'all';

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Budget Transactions',
              subtitle: 'Transactions for selected budget',
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: isFiltered
                        ? AppTheme.primaryLight
                        : AppTheme.textSecondaryColor(context),
                    size: 20,
                  ),
                  onPressed: _showFilterSheet,
                  tooltip: 'Filter Transactions',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
                vertical: AppTheme.spacingXs,
              ),
              child: _buildBudgetDropdown(budgets),
            ),
            const VGapSm(),
            Expanded(
              child: filteredTransactions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingLg,
                        ),
                        child: AppEmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No matching transactions',
                          description: isFiltered
                              ? 'Try clearing or adjusting your filters.'
                              : 'No transactions recorded for this budget yet.',
                          actionLabel: isFiltered ? 'Clear Filters' : null,
                          onActionPressed: isFiltered
                              ? () {
                                  setState(() {
                                    _filterStartDate = null;
                                    _filterEndDate = null;
                                    _filterType = 'all';
                                  });
                                }
                              : null,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        40,
                      ),
                      itemCount: filteredTransactions.length,
                      separatorBuilder: (_, _) => const VGapSm(),
                      itemBuilder: (context, index) {
                        final tx = filteredTransactions[index];
                        return TransactionTile(
                          transaction: tx,
                          category: controller.categoryById(tx.categoryId),
                          paymentMode: controller.paymentModeById(
                            tx.paymentModeId,
                          ),
                          onTap: () => AddTransactionScreen.showModal(
                            context,
                            controller: controller,
                            existingTransaction: tx,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
