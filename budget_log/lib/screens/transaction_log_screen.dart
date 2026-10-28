import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/budget_selector_sheet.dart';
import '../widgets/tab_header.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionLogScreen extends StatefulWidget {
  const TransactionLogScreen({super.key});

  @override
  State<TransactionLogScreen> createState() => _TransactionLogScreenState();
}

class _TransactionLogScreenState extends State<TransactionLogScreen> {
  final _searchController = TextEditingController();
  String _type = 'all';
  String? _budgetId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final filter = AppProvider.read<FinanceController>(context).logFilter;
    _searchController.text = filter.query;
    _type = filter.type;
    _budgetId = filter.budgetId;
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _initialized = true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    AppProvider.read<FinanceController>(context).setLogFilter(
      LogFilter(
        query: _searchController.text,
        type: _type,
        budgetId: _budgetId,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  void _setType(String type) {
    if (_type == type) return;
    setState(() => _type = type);
    _applyFilter();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
    _applyFilter();
  }

  Future<void> _pickBudget() async {
    final controller = AppProvider.read<FinanceController>(context);
    final budgets = [...controller.activeBudgets];
    final selectedBudget = _budgetId == null
        ? null
        : controller.budgetById(_budgetId!);
    if (selectedBudget != null &&
        !budgets.any((budget) => budget.id == selectedBudget.id)) {
      budgets.add(selectedBudget);
    }

    await BudgetSelectorSheet.show(
      context,
      budgets: budgets,
      selectedBudgetId: _budgetId,
      includeAll: true,
      onSelected: (id) {
        if (!mounted) return;
        setState(() => _budgetId = id);
        _applyFilter();
      },
    );
  }

  void _clearFilter() {
    setState(() {
      _searchController.clear();
      _type = 'all';
      _budgetId = null;
      _startDate = null;
      _endDate = null;
    });
    AppProvider.read<FinanceController>(context).clearLogFilter();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.read<FinanceController>(context);
    final selectedBudget = _budgetId == null
        ? null
        : controller.budgetById(_budgetId!);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'Transaction log',
              subtitle: 'Search, filter and edit every entry.',
              actions: [
                IconButton(
                  onPressed: _clearFilter,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  tooltip: 'Clear filters',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  setState(() {});
                  _applyFilter();
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search title, note, category or mode',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            _applyFilter();
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear search',
                        ),
                ),
              ),
            ),
            const VGapSm(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _type == 'all',
                    onSelected: () => _setType('all'),
                  ),
                  const HGapSm(),
                  _FilterChip(
                    label: 'Expense',
                    selected: _type == 'expense',
                    onSelected: () => _setType('expense'),
                  ),
                  const HGapSm(),
                  _FilterChip(
                    label: 'Income',
                    selected: _type == 'income',
                    onSelected: () => _setType('income'),
                  ),
                  const HGapSm(),
                  FilterChip(
                    selected: _budgetId != null,
                    showCheckmark: false,
                    avatar: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                    ),
                    label: Text(selectedBudget?.name ?? 'Budget'),
                    onSelected: (_) => _pickBudget(),
                  ),
                  const HGapSm(),
                  FilterChip(
                    selected: _startDate != null,
                    showCheckmark: false,
                    avatar: const Icon(Icons.date_range_outlined, size: 16),
                    label: Text(
                      _startDate == null
                          ? 'Date range'
                          : '${_formatFilterDate(_startDate!)} – '
                                '${_formatFilterDate(_endDate!)}',
                    ),
                    onSelected: (_) => _pickDateRange(),
                  ),
                ],
              ),
            ),
            const VGapSm(),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final transactions = controller.filteredTransactions;
                  return RefreshIndicator(
                    onRefresh: controller.reload,
                    child: transactions.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 96),
                            children: [
                              AppEmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: controller.logFilter.isActive
                                    ? 'No matching transactions'
                                    : 'No transactions yet',
                                description: controller.logFilter.isActive
                                    ? 'Try clearing the search or filters.'
                                    : 'Add an expense or income entry to '
                                          'start your log.',
                                actionLabel: controller.logFilter.isActive
                                    ? 'Clear filters'
                                    : 'Add transaction',
                                onActionPressed: controller.logFilter.isActive
                                    ? _clearFilter
                                    : () => AddTransactionScreen.navigate(
                                        context,
                                      ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingMd,
                              AppTheme.spacingSm,
                              AppTheme.spacingMd,
                              96,
                            ),
                            itemCount: transactions.length,
                            separatorBuilder: (_, _) => const VGapSm(),
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              return TransactionTile(
                                transaction: transaction,
                                category: controller.categoryById(
                                  transaction.categoryId,
                                ),
                                paymentMode: controller.paymentModeById(
                                  transaction.paymentModeId,
                                ),
                                onTap: () => AddTransactionScreen.navigate(
                                  context,
                                  existingTransaction: transaction,
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => AddTransactionScreen.navigate(context),
        icon: Icons.add_rounded,
        label: 'Add',
        tooltip: 'Add transaction',
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

String _formatFilterDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
