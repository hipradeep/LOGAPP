import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class WeeklyCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  static final DateFormat _dayFormat = DateFormat('E');

  const WeeklyCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Registers this component to rebuild on theme switch
    Theme.of(context);

    // Find the Monday of the week containing selectedDate
    DateTime weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

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

          final Color dayTextColor = isSelected
              ? AppTheme.selectedChipTextColor(context)
              : (isToday ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context));

          final Color weekdayColor = isSelected || isToday
              ? AppTheme.primaryAccentColor(context)
              : AppTheme.textSecondaryColor(context).withValues(alpha: 0.6);

          final Color boxBgColor = isSelected
              ? AppTheme.primaryColor
              : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.surface(context));

          final Color boxBorderColor = isSelected
              ? Colors.transparent
              : (isToday ? AppTheme.primaryColor.withValues(alpha: 0.5) : AppTheme.borderColor(context));

          return Expanded(
            child: GestureDetector(
              onTap: () => onDateSelected(date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _dayFormat.format(date).substring(0, 1),
                    style: GoogleFonts.outfit(
                      color: weekdayColor,
                      fontSize: 12,
                      fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: boxBgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: boxBorderColor,
                        width: isToday ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ] : [],
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: GoogleFonts.outfit(
                          color: dayTextColor,
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
