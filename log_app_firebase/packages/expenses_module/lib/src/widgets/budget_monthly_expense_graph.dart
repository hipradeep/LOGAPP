import 'package:flutter/material.dart';
import '../models/budget.dart';
import 'package:core_ui/core_ui.dart';

class BudgetMonthlyExpenseGraph extends StatefulWidget {
  final Budget budget;
  final List<Transaction> transactions;
  final bool showLabels;

  const BudgetMonthlyExpenseGraph({
    super.key,
    required this.budget,
    required this.transactions,
    this.showLabels = false,
  });

  @override
  State<BudgetMonthlyExpenseGraph> createState() => _BudgetMonthlyExpenseGraphState();
}

class _BudgetMonthlyExpenseGraphState extends State<BudgetMonthlyExpenseGraph> {
  DateTime? _selectedDate;

  String _formatAmountCompact(double amount) {
    if (amount <= 0) return '';
    if (amount >= 1000000) {
      final double value = amount / 1000000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '${formatted}M';
    } else if (amount >= 1000) {
      final double value = amount / 1000;
      final String formatted = value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
      return '${formatted}k';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  String _formatTooltipAmount(double amount) {
    if (amount % 1 == 0) {
      return '₹${amount.toInt()}';
    } else {
      return '₹${amount.toStringAsFixed(1)}';
    }
  }

  List<DateTime?> _generateMonthGridDates(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    
    final startPadding = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    final List<DateTime?> gridDates = [];
    for (int i = 0; i < startPadding; i++) {
      gridDates.add(null);
    }
    
    final totalDays = lastDayOfMonth.day;
    for (int i = 1; i <= totalDays; i++) {
      gridDates.add(DateTime(monthDate.year, monthDate.month, i));
    }
    
    while (gridDates.length % 7 != 0) {
      gridDates.add(null);
    }
    
    return gridDates;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final budgetTx = widget.transactions.where((t) => t.budgetId == widget.budget.id && t.amount > 0).toList();

    final Map<int, double> dailySums = {};
    for (final tx in budgetTx) {
      if (tx.expenseDate.year == now.year && tx.expenseDate.month == now.month) {
        dailySums[tx.expenseDate.day] = (dailySums[tx.expenseDate.day] ?? 0.0) + tx.amount;
      }
    }

    double maxAmount = dailySums.values.fold(0.0, (max, amt) => amt > max ? amt : max);
    if (maxAmount == 0.0) {
      maxAmount = 1.0;
    }

    final double totalExpenses = dailySums.values.fold(0.0, (sum, amt) => sum + amt);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;

    final gridDates = _generateMonthGridDates(now);
    const weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    final List<Widget> gridRows = [];
    for (int i = 0; i < gridDates.length; i += 7) {
      final weekDates = gridDates.sublist(i, i + 7);
      gridRows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: weekDates.map((date) {
            if (date == null) {
              return const SizedBox(width: 36, height: 28);
            }

            final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
            final amount = dailySums[date.day] ?? 0.0;
            final hasExpense = amount > 0;
            final ratio = amount / maxAmount;
            final amountText = _formatAmountCompact(amount);

            Color cellColor;
            Color textColor;
            BoxBorder? cellBorder;

            if (isToday) {
              cellColor = AppTheme.isDark ? Colors.black : Colors.white;
              textColor = AppTheme.isDark ? Colors.white : Colors.black;
              cellBorder = Border.all(
                color: AppTheme.primaryColor,
                width: 1.5,
              );
            } else if (hasExpense) {
              final double alpha = 0.25 + (0.75 * ratio);
              cellColor = AppTheme.primaryColor.withValues(alpha: alpha);
              textColor = Colors.white;
              cellBorder = null;
            } else {
              cellColor = AppTheme.isDark 
                  ? Colors.white.withValues(alpha: 0.06) 
                  : Colors.black.withValues(alpha: 0.05);
              textColor = AppTheme.textSecondaryColor(context).withValues(alpha: 0.7);
              cellBorder = null;
            }

            final isSelected = _selectedDate != null &&
                _selectedDate!.year == date.year &&
                _selectedDate!.month == date.month &&
                _selectedDate!.day == date.day;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDate = null;
                  } else {
                    _selectedDate = date;
                  }
                });
              },
              child: SizedBox(
                width: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cellColor,
                            shape: BoxShape.circle,
                            border: cellBorder,
                          ),
                          child: Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday || hasExpense ? FontWeight.bold : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            bottom: 33, // 28px height + 5px gap
                            left: -50,
                            right: -50,
                            child: Center(
                              child: _AmountTooltip(
                                text: _formatTooltipAmount(amount),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (widget.showLabels && hasExpense) ...[
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 10,
                        child: Text(
                          amountText,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
      if (i + 7 < gridDates.length) {
        gridRows.add(const VGapXs());
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        setState(() {
          _selectedDate = null;
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Avg Daily: ₹${(totalExpenses / lastDayOfMonth).toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 12,
                ),
              ),
              Text(
                'Total Month: ₹${totalExpenses.toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) {
              return SizedBox(
                width: 36,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                  ),
                ),
              );
            }).toList(),
          ),
          const VGapSm(),
          // Calendar Grid
          ...gridRows,
        ],
      ),
    );
  }
}

class _AmountTooltip extends StatelessWidget {
  final String text;

  const _AmountTooltip({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark;
    final bgColor = isDark ? AppTheme.surface(context) : Colors.white;
    final borderColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.4)
        : AppTheme.primaryColor.withValues(alpha: 0.25);
    final textColor = AppTheme.textPrimaryColor(context);

    return Container(
      decoration: ShapeDecoration(
        color: bgColor,
        shape: BubbleShapeBorder(
          borderColor: borderColor,
          borderWidth: 1.0,
          arrowHeight: 5,
          arrowWidth: 8,
          borderRadius: 6,
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class BubbleShapeBorder extends ShapeBorder {
  final double arrowHeight;
  final double arrowWidth;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;

  const BubbleShapeBorder({
    this.arrowHeight = 5,
    this.arrowWidth = 8,
    this.borderRadius = 6,
    this.borderColor = Colors.grey,
    this.borderWidth = 1.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: arrowHeight);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double width = rect.width;
    final double height = rect.height;
    final double bubbleHeight = height - arrowHeight;
    final double arrowLeft = (width - arrowWidth) / 2;

    final path = Path();
    // Start top-left
    path.moveTo(borderRadius, 0);
    // Top border
    path.lineTo(width - borderRadius, 0);
    path.arcToPoint(Offset(width, borderRadius), radius: Radius.circular(borderRadius));
    // Right border
    path.lineTo(width, bubbleHeight - borderRadius);
    path.arcToPoint(Offset(width - borderRadius, bubbleHeight), radius: Radius.circular(borderRadius));
    // Bottom border right part
    path.lineTo(arrowLeft + arrowWidth, bubbleHeight);
    // Arrow
    path.lineTo(width / 2, height);
    path.lineTo(arrowLeft, bubbleHeight);
    // Bottom border left part
    path.lineTo(borderRadius, bubbleHeight);
    path.arcToPoint(Offset(0, bubbleHeight - borderRadius), radius: Radius.circular(borderRadius));
    // Left border
    path.lineTo(0, borderRadius);
    path.arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius));
    path.close();

    return path.shift(rect.topLeft);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
