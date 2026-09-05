import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget.dart';
import '../controllers/budget_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/add_transaction_sheet.dart';
import '../widgets/app_premium_fab.dart';
import '../widgets/app_empty_state.dart';

class LogScreen extends StatefulWidget {
  final BudgetController controller;

  const LogScreen({
    super.key,
    required this.controller,
  });

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  String _searchQuery = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _filterType = 'all'; // 'all', 'debit', 'credit'
  String _filterValidation = 'all';

  String _formatInr(double amount) {
    final format = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return format.format(amount);
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionFilterSheet(
        initialStartDate: _filterStartDate,
        initialEndDate: _filterEndDate,
        initialType: _filterType,
        initialValidation: _filterValidation,
        onApply: (start, end, type, validation) {
          setState(() {
            _filterStartDate = start;
            _filterEndDate = end;
            _filterType = type;
            _filterValidation = validation;
          });
        },
      ),
    );
  }

  void _openEditTransaction(Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(
        existingTransaction: tx,
        budgetId: tx.budgetId,
        budgets: widget.controller.budgets,
      ),
    );
  }

  List<Transaction> _filterTransactions(List<Transaction> all) {
    return all.where((t) {
      // Search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesDesc = t.description.toLowerCase().contains(query);
        final matchesTag = t.tag.toLowerCase().contains(query);
        final matchesMerchant = (t.merchant ?? '').toLowerCase().contains(query);
        final matchesMethod = t.paymentMethod.toLowerCase().contains(query);
        if (!matchesDesc && !matchesTag && !matchesMerchant && !matchesMethod) {
          return false;
        }
      }

      // Date range filter
      if (_filterStartDate != null && t.expenseDate.isBefore(_filterStartDate!)) {
        return false;
      }
      if (_filterEndDate != null) {
        final endOfDay = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (t.expenseDate.isAfter(endOfDay)) return false;
      }

      // Type filter
      if (_filterType == 'debit' && !t.isExpense) return false;
      if (_filterType == 'credit' && !t.isIncome) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allTransactions = widget.controller.transactions;
    final filtered = _filterTransactions(allTransactions);

    return Stack(
      children: [
        FullScreenPage(
          showScaffold: false,
          isScrollable: true,
          title: 'Transaction Log',
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
              icon: Icon(Icons.filter_list_rounded, color: AppTheme.primaryLight, size: 24),
              onPressed: _openFilterSheet,
              tooltip: 'Filter',
            ),
          ],
          children: [
            const VGapSm(),
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                decoration: InputDecoration(
                  hintText: 'Search merchant, category, notes...',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor(context)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const VGapMd(),
            // Summary count & active filter tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} Entries found',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                if (_filterStartDate != null || _filterType != 'all')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStartDate = null;
                        _filterEndDate = null;
                        _filterType = 'all';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: AppTheme.primaryLight),
                          const HGapXs(),
                          Text(
                            'Clear Filter',
                            style: TextStyle(fontSize: 10, color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const VGapSm(),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No Transactions',
                  message: 'No entries match your search or filter criteria.',
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final tx = filtered[index];
                  return _buildTransactionCard(context, tx);
                },
              ),
            const VGapBottomNav(),
          ],
        ),
        AppPremiumFab(
          right: 24,
          bottom: 84,
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => AddTransactionSheet(
                budgetId: widget.controller.selectedBudget?.id,
                budgets: widget.controller.budgets,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionCard(BuildContext context, Transaction tx) {
    final isDebit = tx.isExpense;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context).withValues(alpha: 0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEditTransaction(tx),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (isDebit ? AppTheme.errorColor : AppTheme.successColor).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDebit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
                    size: 22,
                  ),
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
                              tx.merchant != null && tx.merchant!.isNotEmpty ? tx.merchant! : tx.tag,
                              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${isDebit ? '-' : '+'}${_formatInr(tx.amount)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDebit ? AppTheme.errorColor : AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      const VGapXs(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${tx.tag} • ${tx.paymentMethod}',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('d MMM yyyy').format(tx.expenseDate),
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context)),
                          ),
                        ],
                      ),
                      if (tx.description.isNotEmpty) ...[
                        const VGapXs(),
                        Text(
                          tx.description,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
