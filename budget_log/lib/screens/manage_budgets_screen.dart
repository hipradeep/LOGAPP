import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import 'add_budget_screen.dart';

class ManageBudgetsScreen extends StatelessWidget {
  const ManageBudgetsScreen({super.key});

  void _openAddBudget(
    BuildContext context, {
    Budget? budget,
    bool isCopy = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(existingBudget: budget, isCopy: isCopy),
      ),
    );
  }

  Future<void> _deleteBudget(BuildContext context, Budget budget) async {
    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'budget',
      message:
          'Transactions stay in your log, but they will no longer be linked to this budget.',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppProvider.read<FinanceController>(
        context,
      ).deleteBudget(budget.id);
      messenger.showSnackBar(
        SnackBar(content: Text('Budget "${budget.name}" deleted')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete budget: $e')),
      );
    }
  }

  Future<void> _setBudgetActive(
    BuildContext context,
    Budget budget,
    bool active,
  ) async {
    final controller = AppProvider.read<FinanceController>(context);
    final messenger = ScaffoldMessenger.of(context);
    if (active &&
        !budget.isActive &&
        controller.activeBudgets.length >= DatabaseService.maxActiveBudgets) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Maximum ${DatabaseService.maxActiveBudgets} budgets can be '
            'active at a time. Deactivate one first.',
          ),
        ),
      );
      return;
    }

    try {
      await controller.setBudgetActive(budget.id, active);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Budget "${budget.name}" activated'
                : 'Budget "${budget.name}" deactivated',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update this budget. Maximum '
            '${DatabaseService.maxActiveBudgets} budgets can be active.',
          ),
        ),
      );
    }
  }

  String _formatBudgetDates(Budget budget) {
    if (budget.startDate != null && budget.endDate != null) {
      final startStr = DateFormat('MMM d, yyyy').format(budget.startDate!);
      final endStr = DateFormat('MMM d, yyyy').format(budget.endDate!);
      return '$startStr – $endStr';
    } else if (budget.startDate != null) {
      return 'Starts ${DateFormat('MMM d, yyyy').format(budget.startDate!)}';
    } else if (budget.endDate != null) {
      return 'Ends ${DateFormat('MMM d, yyyy').format(budget.endDate!)}';
    }
    return '${budget.period[0].toUpperCase()}${budget.period.substring(1)} period';
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<FinanceController>(context);
    final budgets = controller.budgets;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Manage Budgets',
              subtitle:
                  '${controller.activeBudgets.length} of '
                  '${DatabaseService.maxActiveBudgets} active. Create, modify, '
                  'or remove budgets.',
            ),
            Expanded(
              child: budgets.isEmpty
                  ? AppEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No Budgets Configured',
                      description:
                          'Create spending limits to keep track of your expenses.',
                      actionLabel: 'Create Budget',
                      onActionPressed: () => _openAddBudget(context),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacingMd,
                        AppTheme.spacingSm,
                        AppTheme.spacingMd,
                        96,
                      ),
                      itemCount: budgets.length,
                      separatorBuilder: (_, _) => const VGapSm(),
                      itemBuilder: (context, index) {
                        final budget = budgets[index];
                        final spent = budget.spentForCurrentPeriod(
                          controller.transactions,
                        );
                        final percent = budget.limit > 0
                            ? (spent / budget.limit).clamp(0.0, 1.0)
                            : 0.0;
                        final isOver = budget.isOverBudget(
                          controller.transactions,
                        );

                        Color badgeColor;
                        String badgeText;
                        if (budget.isPeriodOver) {
                          badgeText = 'Ended';
                          badgeColor = AppTheme.errorColor;
                        } else if (!budget.isActive) {
                          badgeText = 'Inactive';
                          badgeColor = AppTheme.textSecondaryColor(context);
                        } else if (isOver) {
                          badgeText = 'Over limit';
                          badgeColor = AppTheme.errorColor;
                        } else {
                          badgeText = 'Active';
                          badgeColor = AppTheme.successColor;
                        }

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                _openAddBudget(context, budget: budget),
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardBorderRadius,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacingMd),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: badgeColor,
                                          size: 20,
                                        ),
                                      ),
                                      const HGapSm(),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    budget.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const HGapSm(),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    border: Border.all(
                                                      color: badgeColor
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    badgeText,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: badgeColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const VGapXs(),
                                            Text(
                                              _formatBudgetDates(budget),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppTheme.textSecondaryColor(
                                                      context,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        key: ValueKey(
                                          'budget-menu-${budget.id}',
                                        ),
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: AppTheme.textSecondaryColor(
                                            context,
                                          ),
                                          size: 20,
                                        ),
                                        onSelected: (action) {
                                          if (action == 'edit') {
                                            _openAddBudget(
                                              context,
                                              budget: budget,
                                            );
                                          } else if (action == 'copy') {
                                            _openAddBudget(
                                              context,
                                              budget: budget,
                                              isCopy: true,
                                            );
                                          } else if (action == 'toggle') {
                                            _setBudgetActive(
                                              context,
                                              budget,
                                              !budget.isActive,
                                            );
                                          } else if (action == 'delete') {
                                            _deleteBudget(context, budget);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  budget.isActive
                                                      ? Icons
                                                            .toggle_off_outlined
                                                      : Icons
                                                            .toggle_on_outlined,
                                                  size: 18,
                                                ),
                                                const HGapSm(),
                                                Text(
                                                  budget.isActive
                                                      ? 'Deactivate'
                                                      : 'Activate',
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 18,
                                                ),
                                                HGapSm(),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'copy',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.copy_rounded,
                                                  size: 18,
                                                ),
                                                HGapSm(),
                                                Text('Copy'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: AppTheme.errorColor,
                                                ),
                                                HGapSm(),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: AppTheme.errorColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const VGapMd(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Spent: ${AppFormat.currency(spent)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isOver
                                              ? AppTheme.errorColor
                                              : AppTheme.textSecondaryColor(
                                                  context,
                                                ),
                                        ),
                                      ),
                                      Text(
                                        'Limit: ${AppFormat.currency(budget.limit)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const VGapSm(),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 5,
                                      backgroundColor: AppTheme.surfaceVariant(
                                        context,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isOver
                                            ? AppTheme.errorColor
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () => _openAddBudget(context),
        icon: Icons.add_rounded,
        label: 'Budget',
        tooltip: 'Create Budget',
      ),
    );
  }
}
