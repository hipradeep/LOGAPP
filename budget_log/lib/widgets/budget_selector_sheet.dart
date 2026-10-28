import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/budget.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

class BudgetSelectorSheet extends StatelessWidget {
  final List<Budget> budgets;
  final String? selectedBudgetId;
  final ValueChanged<String?> onSelected;
  final bool includeAll;
  final String allLabel;

  const BudgetSelectorSheet({
    super.key,
    required this.budgets,
    required this.selectedBudgetId,
    required this.onSelected,
    this.includeAll = false,
    this.allLabel = 'All budgets',
  });

  static Future<void> show(
    BuildContext context, {
    required List<Budget> budgets,
    required String? selectedBudgetId,
    required ValueChanged<String?> onSelected,
    bool includeAll = false,
    String allLabel = 'All budgets',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BudgetSelectorSheet(
        budgets: budgets,
        selectedBudgetId: selectedBudgetId,
        onSelected: onSelected,
        includeAll: includeAll,
        allLabel: allLabel,
      ),
    );
  }

  String _formatDateRange(Budget budget) {
    final start = budget.startDate;
    final end = budget.endDate;

    if (start != null && end != null) {
      final startStr = DateFormat('MMM d, yyyy').format(start);
      final endStr = DateFormat('MMM d, yyyy').format(end);
      return '$startStr – $endStr';
    } else if (start != null) {
      return 'Starts ${DateFormat('MMM d, yyyy').format(start)}';
    } else if (end != null) {
      return 'Ends ${DateFormat('MMM d, yyyy').format(end)}';
    }

    // Fallback to budget period / schedule
    final periodName = budget.period.isNotEmpty
        ? '${budget.period[0].toUpperCase()}${budget.period.substring(1)} budget'
        : 'Ongoing budget';
    return periodName;
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        const SheetHeader(
          title: 'Select Budget',
          subtitle: 'Choose an active or archived budget period',
        ),
        const VGapMd(),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (includeAll)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: _BudgetOptionTile(
                      title: allLabel,
                      subtitle: 'Include transactions from every budget',
                      isSelected: selectedBudgetId == null,
                      leadingIcon: Icons.account_balance_wallet_outlined,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(null);
                      },
                    ),
                  ),
                for (var i = 0; i < budgets.length; i++) ...[
                  () {
                    final budget = budgets[i];
                    final isSelected = budget.id == selectedBudgetId;

                    String? badgeText;
                    Color? badgeColor;
                    if (budget.isPeriodOver) {
                      badgeText = 'Ended';
                      badgeColor = AppTheme.errorColor;
                    } else if (!budget.isActive) {
                      badgeText = 'Inactive';
                      badgeColor = AppTheme.textSecondaryColor(context);
                    } else {
                      badgeText = 'Active';
                      badgeColor = AppTheme.successColor;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _BudgetOptionTile(
                        title: budget.name,
                        subtitle: _formatDateRange(budget),
                        isSelected: isSelected,
                        badgeText: badgeText,
                        badgeColor: badgeColor,
                        limitAmount: budget.limit,
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(budget.id);
                        },
                      ),
                    );
                  }(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final String? badgeText;
  final Color? badgeColor;
  final double? limitAmount;
  final IconData leadingIcon;
  final VoidCallback onTap;

  const _BudgetOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.badgeText,
    this.badgeColor,
    this.limitAmount,
    this.leadingIcon = Icons.account_balance_wallet_outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.surface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.check_circle_rounded : leadingIcon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor(context),
                size: 20,
              ),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isSelected
                                ? AppTheme.primaryLight
                                : AppTheme.textPrimaryColor(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeText != null && badgeColor != null) ...[
                        const HGapSm(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor!.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: badgeColor!.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (limitAmount != null && limitAmount! > 0) ...[
              const HGapSm(),
              Text(
                '₹${limitAmount!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
