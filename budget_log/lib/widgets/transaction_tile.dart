import 'package:flutter/material.dart';

import '../models/budget_transaction.dart';
import '../models/category.dart';
import '../models/payment_mode.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import '../utils/format_utils.dart';
import 'app_spacers.dart';

class TransactionTile extends StatelessWidget {
  final BudgetTransaction transaction;
  final Category? category;
  final PaymentMode? paymentMode;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.paymentMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isExpense = transaction.isExpense;
    final tintIndex = category?.colorIndex ?? (isExpense ? 6 : 1);
    final tint = AppTheme.tintFor(context, tintIndex);
    final categoryName = category?.name ?? 'Uncategorized';
    final paymentName = paymentMode?.name;
    final subtitle = paymentName == null
        ? categoryName
        : '$categoryName · $paymentName';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.$1,
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallBorderRadius,
                  ),
                ),
                child: Icon(
                  CategoryVisuals.categoryIcon(category?.name),
                  color: tint.$2,
                  size: 18,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge,
                    ),
                    const VGapXs(),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const HGapSm(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppFormat.signedCurrency(
                      transaction.amount,
                      isExpense: isExpense,
                    ),
                    style: textTheme.titleMedium?.copyWith(
                      color: isExpense
                          ? AppTheme.expenseColor
                          : AppTheme.incomeColor,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    AppFormat.relativeDate(transaction.timestamp),
                    style: textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
