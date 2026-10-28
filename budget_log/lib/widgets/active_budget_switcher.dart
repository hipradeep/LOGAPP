import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class ActiveBudgetSwitcher extends StatelessWidget {
  final List<Budget> budgets;
  final String? selectedBudgetId;
  final ValueChanged<String> onSelected;

  const ActiveBudgetSwitcher({
    super.key,
    required this.budgets,
    required this.selectedBudgetId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < budgets.length; index++) ...[
            if (index > 0) const HGapXs(),
            _ActiveBudgetPill(
              key: ValueKey('active-budget-pill-${budgets[index].id}'),
              budget: budgets[index],
              selected: budgets[index].id == selectedBudgetId,
              onTap: () => onSelected(budgets[index].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveBudgetPill extends StatelessWidget {
  final Budget budget;
  final bool selected;
  final VoidCallback onTap;

  const _ActiveBudgetPill({
    super.key,
    required this.budget,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryColor.withValues(alpha: 0.38)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Text(
            budget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? AppTheme.primaryLight
                  : AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
