import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/note_entity.dart';
import '../models/check_in.dart';

class MonthlyCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final List<NoteEntity> logs;
  final List<CheckIn> checkIns;
  final ValueChanged<DateTime> onDateSelected;

  const MonthlyCalendar({
    super.key,
    required this.selectedDate,
    required this.logs,
    required this.checkIns,
    required this.onDateSelected,
  });

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.selectedDate;
  }

  @override
  void didUpdateWidget(covariant MonthlyCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate.month != oldWidget.selectedDate.month ||
        widget.selectedDate.year != oldWidget.selectedDate.year) {
      _currentMonth = widget.selectedDate;
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

  bool _isFutureDay(DateTime date) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    return dateMidnight.isAfter(todayMidnight);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  Widget _buildCalendarHeader() {
    final dateStr = DateFormat('d MMM, yy').format(widget.selectedDate);
    final weekdayStr = DateFormat('EEEE').format(widget.selectedDate);
    
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 2, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  dateStr,
                  style: AppTheme.headingSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    weekdayStr,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(Icons.chevron_left_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                DateFormat('MMM yyyy').format(_currentMonth),
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdaysHeader() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekdays.map((day) {
          return SizedBox(
            width: 36,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isTodayDate = _isSameDay(date, today);
    final isFuture = _isFutureDay(date);
    
    final hasLog = widget.logs.any((l) => _isSameDay(l.timestamp, date));
    final hasCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, date) && c.checked);
    
    final dayNumber = DateFormat('d').format(date);
    
    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              setState(() {
                _currentMonth = date;
              });
              widget.onDateSelected(date);
            },
      child: Opacity(
        opacity: isFuture ? 0.3 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            border: isTodayDate && !isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 1.2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayNumber,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isTodayDate ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.lightTextPrimary  // always dark on white circle
                      : Theme.of(context).textTheme.bodySmall!.color,
                ),
              ),
              const SizedBox(height: 0.5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasLog)
                    Container(
                      width: 2.5,
                      height: 2.5,
                      margin: const EdgeInsets.only(right: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppTheme.primaryDark : AppTheme.primaryLight,
                      ),
                    ),
                  if (hasCheckIn)
                    Container(
                      width: 2.5,
                      height: 2.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.successColor,
                      ),
                    ),
                  if (!hasLog && !hasCheckIn)
                    const SizedBox(height: 2.5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid() {
    final gridDates = _generateMonthGridDates(_currentMonth);
    final today = DateTime.now();
    
    final List<Widget> rows = [];
    for (int i = 0; i < gridDates.length; i += 7) {
      final weekDates = gridDates.sublist(i, i + 7);
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDates.map((date) {
            if (date == null) {
              return const SizedBox(width: 36, height: 36);
            }
            return _buildDayCell(date, today);
          }).toList(),
        ),
      );
      if (i + 7 < gridDates.length) {
        rows.add(const SizedBox(height: 4));
      }
    }
    
    return Column(
      children: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          _buildWeekdaysHeader(),
          const SizedBox(height: 4),
          _buildMonthGrid(),
        ],
      ),
    );
  }
}
