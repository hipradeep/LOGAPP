import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// 7-day horizontal strip for the Day View (Screen 2).
class CalendarWeekStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const CalendarWeekStrip({
    super.key,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    final clean = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final monday = clean.subtract(Duration(days: clean.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((date) {
          final isSelected = date.year == clean.year &&
              date.month == clean.month &&
              date.day == clean.day;

          return _DayStripCell(
            date: date,
            isSelected: isSelected,
            onTap: () => onSelectDate(date),
          );
        }).toList(),
      ),
    );
  }
}

class _DayStripCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayStripCell({
    required this.date,
    required this.isSelected,
    required this.onTap,
  });

  static final DateFormat _dayNameFormat = DateFormat('E');

  @override
  Widget build(BuildContext context) {
    final dayLabel = _dayNameFormat.format(date); // e.g. Mon, Tue

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
