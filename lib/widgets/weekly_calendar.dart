import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const WeeklyCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Find the Monday of the week containing selectedDate
    DateTime weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final surfaceColor = const Color(0xFF1E293B);

    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          DateTime date = weekStart.add(Duration(days: index));
          bool isSelected = date.day == selectedDate.day &&
                           date.month == selectedDate.month &&
                           date.year == selectedDate.year;

          DateTime now = DateTime.now();
          bool isToday = date.day == now.day && date.month == now.month && date.year == now.year;

          return Expanded(
            child: GestureDetector(
              onTap: () => onDateSelected(date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 1),
                    style: GoogleFonts.outfit(
                      color: isSelected || isToday ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.1) : surfaceColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.transparent : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
                        width: isToday ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ] : [],
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: GoogleFonts.outfit(
                          color: isSelected || isToday ? Colors.white : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
