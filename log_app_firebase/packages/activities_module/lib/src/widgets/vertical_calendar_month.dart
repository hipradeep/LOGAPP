import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:core_ui/core_ui.dart';

class VerticalCalendarMonth extends StatelessWidget {
  final DateTime month;
  final List<int> attendedDays;

  const VerticalCalendarMonth({
    super.key,
    required this.month,
    required this.attendedDays,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)
    
    // Adjust for Monday start (if weekday is 7, it's Sunday, we want 0-6)
    // Actually standard Flutter/Dart weekday is 1=Mon, 7=Sun.
    // We want Mon-Sun: 0, 1, 2, 3, 4, 5, 6
    int prefixEmptyDays = firstWeekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            DateFormat('MMMM yyyy').format(month).toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: daysInMonth + prefixEmptyDays,
          itemBuilder: (context, index) {
            if (index < prefixEmptyDays) {
              return const SizedBox.shrink();
            }
            
            final day = index - prefixEmptyDays + 1;
            final isAttended = attendedDays.contains(day);
            final isToday = DateTime.now().day == day && 
                           DateTime.now().month == month.month && 
                           DateTime.now().year == month.year;

            return Container(
              decoration: BoxDecoration(
                color: isAttended 
                    ? AppTheme.primaryColor.withValues(alpha: 0.2) 
                    : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAttended 
                      ? AppTheme.primaryColor 
                      : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
                  width: isToday ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isAttended || isToday ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: isAttended || isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
