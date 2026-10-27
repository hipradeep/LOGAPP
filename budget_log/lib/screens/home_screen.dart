import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../models/subscription.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../utils/subscription_schedule.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/tab_header.dart';
import '../widgets/transaction_tile.dart';
import 'add_budget_screen.dart';
import 'add_transaction_screen.dart';
import 'subscription_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToLog;
  final VoidCallback onNavigateToBudget;

  const HomeScreen({
    super.key,
    required this.onNavigateToLog,
    required this.onNavigateToBudget,
  });

  Future<void> _editSalary(BuildContext context, FinanceController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _SalarySheet(
          initialSalary: controller.monthlySalary,
          onSave: controller.setMonthlySalary,
        ),
      ),
    );
  }

  void _createBudget(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddBudgetScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.read<FinanceController>(context);
    final subscriptionController = getIt.isRegistered<SubscriptionController>()
        ? getIt<SubscriptionController>()
        : null;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            TabHeader(
              title: 'Budget Log',
              subtitle: AppFormat.monthYear(DateTime.now()),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  if (controller.isLoading &&
                      controller.transactions.isEmpty &&
                      controller.budgets.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final budget = controller.activeBudget;
                  final recent = controller.recentTransactions;

                  return RefreshIndicator(
                    onRefresh: controller.reload,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        96,
                      ),
                      children: [
                        _MonthlySummaryCard(
                          controller: controller,
                          onEditSalary: () => _editSalary(context, controller),
                        ),
                        const VGapLg(),
                        if (budget != null)
                          _ActiveBudgetCard(
                            budget: budget,
                            spent: controller.spentForBudget(budget.id),
                            safeToSpend: controller.safeToSpendForBudget(
                              budget.id,
                            ),
                            onManage: onNavigateToBudget,
                          )
                        else
                          AppEmptyState(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'No active budget',
                            description:
                                'Create a monthly cap to track spending and '
                                'get a safe-to-spend daily allowance.',
                            actionLabel: 'Create budget',
                            onActionPressed: () => _createBudget(context),
                          ),
                        if (subscriptionController != null)
                          _SubscriptionsPreviewCard(
                            controller: subscriptionController,
                            onViewAll: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SubscriptionScreen(),
                                ),
                              );
                            },
                          ),
                        if (controller.topCategorySpend.isNotEmpty) ...[
                          const VGapLg(),
                          _CategorySpendCard(
                            items: controller.topCategorySpend,
                            total: controller.monthlyExpense,
                          ),
                        ],
                        const VGapLg(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent transactions',
                                style: textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: onNavigateToLog,
                              child: const Text('View all'),
                            ),
                          ],
                        ),
                        const VGapXs(),
                        if (recent.isEmpty)
                          const AppEmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Nothing logged yet',
                            description:
                                'Add your first expense or income to see '
                                'it here.',
                            showCard: false,
                          )
                        else
                          ..._buildRecentTransactions(
                            context,
                            controller,
                            recent,
                          ),
                      ],
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

  List<Widget> _buildRecentTransactions(
    BuildContext context,
    FinanceController controller,
    List<BudgetTransaction> recent,
  ) {
    final children = <Widget>[];
    for (var index = 0; index < recent.length; index++) {
      final transaction = recent[index];
      if (index > 0) children.add(const VGapSm());
      children.add(
        TransactionTile(
          transaction: transaction,
          category: controller.categoryById(transaction.categoryId),
          paymentMode: controller.paymentModeById(transaction.paymentModeId),
          onTap: () => AddTransactionScreen.navigate(
            context,
            existingTransaction: transaction,
          ),
        ),
      );
    }
    return children;
  }
}

class _SubscriptionsPreviewCard extends StatelessWidget {
  final SubscriptionController controller;
  final VoidCallback onViewAll;

  const _SubscriptionsPreviewCard({
    required this.controller,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.subscriptions.isEmpty) return const SizedBox.shrink();

        final upcoming = controller.activeSubscriptions.take(3).toList();
        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Upcoming bills', style: textTheme.titleMedium),
                  ),
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('View all'),
                  ),
                ],
              ),
              const VGapXs(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: upcoming.isEmpty
                      ? Text(
                          'No active subscriptions. '
                          'Resume one or add a new bill.',
                          style: textTheme.bodyMedium,
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < upcoming.length;
                              index++
                            ) ...[
                              if (index > 0) ...[
                                const VGapSm(),
                                Divider(
                                  color: AppTheme.borderColor(context),
                                  height: 1,
                                ),
                                const VGapSm(),
                              ],
                              _SubscriptionPreviewRow(
                                subscription: upcoming[index],
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubscriptionPreviewRow extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionPreviewRow({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final daysUntil = SubscriptionSchedule.daysUntil(subscription.nextDueDate);
    final dueColor = daysUntil < 0
        ? AppTheme.expenseColor
        : daysUntil <= 3
        ? AppTheme.warningColor
        : AppTheme.textSecondaryColor(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.autorenew_rounded,
            size: 17,
            color: AppTheme.primaryColor,
          ),
        ),
        const HGapSm(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subscription.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
              const VGapXs(),
              Text(
                SubscriptionSchedule.dueLabel(subscription.nextDueDate),
                style: textTheme.labelSmall?.copyWith(color: dueColor),
              ),
            ],
          ),
        ),
        const HGapSm(),
        Text(
          AppFormat.currency(subscription.amount),
          style: textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _MonthlySummaryCard extends StatelessWidget {
  final FinanceController controller;
  final VoidCallback onEditSalary;

  const _MonthlySummaryCard({
    required this.controller,
    required this.onEditSalary,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final available = controller.availableToSpend;
    final accent = available < 0 ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Available this month',
                    style: textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onEditSalary,
                  child: const Text('Edit income'),
                ),
              ],
            ),
            Text(
              AppFormat.currency(available),
              style: textTheme.displaySmall?.copyWith(color: accent),
            ),
            const VGapMd(),
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapMd(),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Income logged',
                    value: AppFormat.currency(controller.monthlyIncome),
                    color: AppTheme.incomeColor,
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Spent this month',
                    value: AppFormat.currency(controller.monthlyExpense),
                    color: AppTheme.expenseColor,
                  ),
                ),
              ],
            ),
            if (controller.monthlySalary > 0) ...[
              const VGapMd(),
              Text(
                'Planned income ${AppFormat.currency(controller.monthlySalary)}',
                style: textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall),
        const VGapXs(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _ActiveBudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double safeToSpend;
  final VoidCallback onManage;

  const _ActiveBudgetCard({
    required this.budget,
    required this.spent,
    required this.safeToSpend,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final percentage = budget.limit > 0
        ? (spent / budget.limit).clamp(0.0, 1.0)
        : 0.0;
    final isOver = spent > budget.limit;
    final statusColor = isOver
        ? AppTheme.expenseColor
        : percentage >= budget.alertThreshold
        ? AppTheme.warningColor
        : AppTheme.primaryColor;
    final statusText = isOver
        ? 'Over budget'
        : '${(percentage * 100).round()}% used';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name, style: textTheme.titleMedium),
                      const VGapXs(),
                      Text(
                        '${_periodLabel(budget.period)} budget',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSm,
                    vertical: AppTheme.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      AppTheme.pillBorderRadius,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const VGapMd(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(AppFormat.currency(spent), style: textTheme.headlineSmall),
                const HGapXs(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'of ${AppFormat.currency(budget.limit)}',
                    style: textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const VGapSm(),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 6,
                color: statusColor,
                backgroundColor: AppTheme.surfaceVariant(context),
              ),
            ),
            const VGapMd(),
            Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  size: 16,
                  color: AppTheme.textSecondaryColor(context),
                ),
                const HGapXs(),
                Expanded(
                  child: Text(
                    'Safe to spend ${AppFormat.currency(safeToSpend)}/day',
                    style: textTheme.bodySmall,
                  ),
                ),
                TextButton(onPressed: onManage, child: const Text('Manage')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySpendCard extends StatelessWidget {
  final List<CategorySpend> items;
  final double total;

  const _CategorySpendCard({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spending by category', style: textTheme.titleMedium),
        const VGapSm(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const VGapMd(),
                  _CategorySpendRow(item: items[index], total: total),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySpendRow extends StatelessWidget {
  final CategorySpend item;
  final double total;

  const _CategorySpendRow({required this.item, required this.total});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tint = AppTheme.tintFor(context, item.category?.colorIndex ?? 0);
    final ratio = total > 0 ? (item.amount / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: tint.$2, shape: BoxShape.circle),
            ),
            const HGapSm(),
            Expanded(
              child: Text(
                item.category?.name ?? 'Uncategorized',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            const HGapSm(),
            Text(AppFormat.currency(item.amount), style: textTheme.titleMedium),
          ],
        ),
        const VGapXs(),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            color: tint.$2,
            backgroundColor: AppTheme.surfaceVariant(context),
          ),
        ),
      ],
    );
  }
}

class _SalarySheet extends StatefulWidget {
  final double initialSalary;
  final Future<void> Function(double salary) onSave;

  const _SalarySheet({required this.initialSalary, required this.onSave});

  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialSalary > 0
          ? widget.initialSalary.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_controller.text.trim().replaceAll(',', ''));
    if (value == null || value < 0) return;
    setState(() => _isSaving = true);
    await widget.onSave(value);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        const SheetHeader(
          title: 'Monthly income',
          subtitle:
              'Used to calculate available money and safe-to-spend amounts.',
        ),
        const VGapMd(),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Income after tax',
            prefixText: '₹ ',
            hintText: '50000',
          ),
        ),
        const VGapMd(),
        SheetSubmitButton(
          text: 'Save income',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
        const VGapXs(),
        Text(
          'Enter 0 to rely only on logged income.',
          style: textTheme.labelSmall,
        ),
        const VGapXs(),
        SheetCancelButton(),
      ],
    );
  }
}

String _periodLabel(String period) {
  return switch (period) {
    'daily' => 'Daily',
    'weekly' => 'Weekly',
    'custom' => 'Custom',
    _ => 'Monthly',
  };
}
