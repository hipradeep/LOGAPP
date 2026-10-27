import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';
import 'expense_donut_chart.dart';
import 'sheet_action_widgets.dart';

class CategoryBreakdownSheet extends StatelessWidget {
  final Budget budget;
  final List<BudgetTransaction> transactions;
  final IconData Function(String) getTagIcon;
  final Color Function(String) getTagColor;
  final String Function(String) getTagName;

  const CategoryBreakdownSheet({
    super.key,
    required this.budget,
    required this.transactions,
    required this.getTagIcon,
    required this.getTagColor,
    required this.getTagName,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> tagTotals = {};
    final Map<String, IconData> tagIcons = {};
    final Map<String, Color> tagColors = {};

    for (final t in transactions) {
      if (!t.isExpense || t.amount <= 0) continue;
      final lookup = t.title;
      final label = getTagName(lookup);
      tagTotals[label] = (tagTotals[label] ?? 0) + t.amount;
      tagIcons[label] ??= getTagIcon(lookup);
      tagColors[label] ??= getTagColor(lookup);
    }

    final total = tagTotals.values.fold(0.0, (a, b) => a + b);
    final sorted = tagTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final segments = sorted
        .map(
          (e) => DonutSegment(
            label: e.key,
            value: e.value,
            color: tagColors[e.key] ?? AppTheme.primaryColor,
          ),
        )
        .toList();

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Breakdown',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Total: ${AppFormat.currency(total)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const VGapLg(),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No expense records in this budget.',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else ...[
          Center(
            child: ExpenseDonutChart(
              segments: segments,
              total: total,
              size: 150,
              strokeWidth: 20,
              centerLabel: AppFormat.currency(total),
            ),
          ),
          const VGapLg(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const VGapSm(),
              itemBuilder: (context, index) {
                final entry = sorted[index];
                final percent = total > 0 ? (entry.value / total) * 100 : 0.0;
                final icon = tagIcons[entry.key] ?? Icons.category_rounded;
                final color = tagColors[entry.key] ?? AppTheme.primaryColor;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 14),
                      ),
                      const HGapSm(),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                          fontSize: 11,
                        ),
                      ),
                      const HGapMd(),
                      Text(
                        AppFormat.currency(entry.value),
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
