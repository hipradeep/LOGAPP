import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/expense_donut_chart.dart';

class CategoryBreakdownSheet extends StatelessWidget {
  final Budget budget;
  final List<Transaction> transactions;
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
    // Group by tag label → sum amounts (positive only)
    final Map<String, double> tagTotals = {};
    final Map<String, IconData> tagIcons = {};
    final Map<String, Color> tagColors = {};

    for (final t in transactions) {
      if (t.amount <= 0) continue; // skip gains/refunds
      final lookup = t.tag.isNotEmpty ? t.tag : t.description;
      final label = getTagName(lookup);
      tagTotals[label] = (tagTotals[label] ?? 0) + t.amount;
      tagIcons[label] ??= getTagIcon(lookup);
      tagColors[label] ??= getTagColor(lookup);
    }

    final total = tagTotals.values.fold(0.0, (a, b) => a + b);
    final sorted = tagTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const VGapMd(),
          Text(
            budget.name,
            style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const VGapXs(),
          Text(
            'Spend by category',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondaryColor(context),
              letterSpacing: 0.5,
            ),
          ),
          const VGapMd(),
          // Donut chart
          if (sorted.isNotEmpty)
            Center(
              child: ExpenseDonutChart(
                segments: sorted
                    .map((e) => DonutSegment(
                          label: e.key,
                          value: e.value,
                          color: tagColors[e.key] ?? AppTheme.primaryColor,
                        ))
                    .toList(),
                total: total,
                size: 150,
                strokeWidth: 20,
                centerLabel: '₹${total.toStringAsFixed(0)}',
              ),
            ),
          const VGapMd(),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No transactions yet.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final entry = sorted[index];
                  final label = entry.key;
                  final amount = entry.value;
                  final pct = total > 0 ? (amount / total) : 0.0;
                  final icon = tagIcons[label] ?? Icons.more_horiz_rounded;
                  final color = tagColors[label] ?? AppTheme.primaryColor;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 16),
                        ),
                        const HGapMd(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '₹${amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimaryColor(context),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: pct,
                                        minHeight: 4,
                                        backgroundColor:
                                            color.withValues(alpha: 0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                color),
                                      ),
                                    ),
                                  ),
                                  const HGapSm(),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color:
                                          AppTheme.textSecondaryColor(context),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (sorted.isNotEmpty) ...[
            const VGapSm(),
            Divider(color: AppTheme.borderColor(context), height: 1),
            const VGapSm(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
