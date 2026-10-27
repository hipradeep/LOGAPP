import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import 'add_budget_screen.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  void _openBudget(BuildContext context, {Budget? budget}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(existingBudget: budget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.read<FinanceController>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Budgets',
              subtitle: 'Keep recurring spending caps in one place.',
              showBackButton: false,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  if (controller.isLoading && controller.budgets.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final budgets = controller.budgets;
                  if (budgets.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        AppEmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'No budgets yet',
                          description:
                              'Create a cap for your monthly spending, '
                              'groceries, travel or anything else.',
                          actionLabel: 'Create budget',
                          onActionPressed: () => _openBudget(context),
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: controller.reload,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        96,
                      ),
                      itemCount: budgets.length + 1,
                      separatorBuilder: (_, _) => const VGapMd(),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final activeCount = budgets
                              .where((item) => item.isActive)
                              .length;
                          return Text(
                            '${budgets.length} budgets · '
                            '$activeCount active',
                            style: textTheme.labelSmall,
                          );
                        }
                        final budget = budgets[index - 1];
                        return _BudgetCard(
                          budget: budget,
                          spent: controller.spentForBudget(budget.id),
                          safeToSpend: controller.safeToSpendForBudget(
                            budget.id,
                          ),
                          onTap: () => _openBudget(context, budget: budget),
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
        onPressed: () => _openBudget(context),
        icon: Icons.add_rounded,
        label: 'New budget',
        tooltip: 'Create budget',
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final double spent;
  final double safeToSpend;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.safeToSpend,
    required this.onTap,
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
    final statusLabel = isOver
        ? 'Over budget'
        : '${(percentage * 100).round()}% used';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: budget.isActive
                          ? AppTheme.incomeColor
                          : AppTheme.textMutedColor(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: Text(
                      budget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (budget.isActive)
                    Text(
                      'Active',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppTheme.incomeColor,
                      ),
                    )
                  else
                    Text('Inactive', style: textTheme.labelSmall),
                ],
              ),
              const VGapXs(),
              Text(
                '${_periodLabel(budget.period)} · '
                'Safe to spend ${AppFormat.currency(safeToSpend)}/day',
                style: textTheme.bodySmall,
              ),
              const VGapMd(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AppFormat.currency(spent)} of '
                      '${AppFormat.currency(budget.limit)}',
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: textTheme.labelSmall?.copyWith(color: statusColor),
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
              if (budget.description.isNotEmpty) ...[
                const VGapSm(),
                Text(
                  budget.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
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
