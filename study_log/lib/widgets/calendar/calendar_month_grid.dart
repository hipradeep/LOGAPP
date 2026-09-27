import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Month grid displaying Sunday through Saturday with colored indicators for revisions.
class CalendarMonthGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<Color> Function(DateTime date, BuildContext context) dotsForDate;
  final ValueChanged<DateTime> onSelectDate;

  const CalendarMonthGrid({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.dotsForDate,
    required this.onSelectDate,
  });

  static const List<String> _weekdays = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    // Sunday is 0 in this 0-indexed offset (DateTime weekday: Mon=1..Sun=7)
    final startOffset = firstDay.weekday % 7;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalizedSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    return RepaintBoundary(
      child: Column(
        children: [
          // Weekday header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((day) {
                return SizedBox(
                  width: 38,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Month grid cells
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - startOffset + 1;
                final isCurrentMonth = dayNumber >= 1 && dayNumber <= daysInMonth;

                if (!isCurrentMonth) {
                  return const SizedBox.shrink();
                }

                final cellDate = DateTime(focusedMonth.year, focusedMonth.month, dayNumber);
                final isSelected = cellDate == normalizedSelected;
                final isToday = cellDate == today;
                final dots = dotsForDate(cellDate, context);

                return _CalendarDayCell(
                  dayNumber: dayNumber,
                  cellDate: cellDate,
                  isSelected: isSelected,
                  isToday: isToday,
                  dots: dots,
                  onTap: () => onSelectDate(cellDate),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final DateTime cellDate;
  final bool isSelected;
  final bool isToday;
  final List<Color> dots;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.dayNumber,
    required this.cellDate,
    required this.isSelected,
    required this.isToday,
    required this.dots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppTheme.primaryColor
        : isToday
            ? const Color(0xFFF3F0FF)
            : Colors.transparent;

    final textColor = isSelected
        ? Colors.white
        : isToday
            ? AppTheme.primaryColor
            : AppTheme.textPrimaryColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: (isToday && !isSelected)
                    ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4), width: 1.2)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Dots indicator row
            SizedBox(
              height: 6,
              child: dots.isEmpty
                  ? const SizedBox(height: 6)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: dots.map((color) {
                        return Container(
                          width: 4.5,
                          height: 4.5,
                          margin: const EdgeInsets.symmetric(horizontal: 1.0),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
