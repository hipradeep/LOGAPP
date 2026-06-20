import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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

  List<DateTime> _generateMonthGridDates(DateTime monthDate) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    
    // Monday-start padding (weekday: 1=Mon, 7=Sun)
    final startPadding = firstDayOfMonth.weekday - 1;
    
    final List<DateTime> gridDates = [];
    
    // Trailing days of previous month
    final prevMonthLastDay = DateTime(monthDate.year, monthDate.month, 0);
    for (int i = startPadding - 1; i >= 0; i--) {
      gridDates.add(DateTime(prevMonthLastDay.year, prevMonthLastDay.month, prevMonthLastDay.day - i));
    }
    
    // Days of current month
    final totalDays = lastDayOfMonth.day;
    for (int i = 1; i <= totalDays; i++) {
      gridDates.add(DateTime(monthDate.year, monthDate.month, i));
    }
    
    // Leading days of next month
    int nextMonthDay = 1;
    while (gridDates.length % 7 != 0) {
      gridDates.add(DateTime(monthDate.year, monthDate.month + 1, nextMonthDay++));
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
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
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
    final isCurrentMonth = date.month == _currentMonth.month;
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isTodayDate = _isSameDay(date, today);
    final isFuture = _isFutureDay(date);
    
    final hasLog = widget.logs.any((l) => _isSameDay(l.timestamp, date));
    final hasCheckIn = widget.checkIns.any((c) => _isSameDay(c.timestamp, date) && c.checked);
    
    final dayNumber = date.day.toString();
    
    final isDark = AppTheme.isDarkMode(context);
    
    final Color textColor;
    final Color bgColor;
    final Border? border;
    
    if (!isCurrentMonth) {
      textColor = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
      bgColor = Colors.transparent;
      border = null;
    } else if (isSelected) {
      textColor = Colors.white;
      bgColor = isDark ? AppTheme.primaryColor : const Color(0xFF1E293B);
      border = null;
    } else if (isTodayDate) {
      textColor = isDark ? Colors.white : const Color(0xFF1E293B);
      bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
      border = Border.all(
        color: isDark ? AppTheme.primaryColor : Colors.black.withValues(alpha: 0.25),
        width: 1.2,
      );
    } else {
      textColor = isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.8);
      bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
      border = null;
    }
    
    return GestureDetector(
      onTap: isFuture
          ? null
          : () {
              if (date.month != _currentMonth.month) {
                setState(() {
                  _currentMonth = date;
                });
              }
              widget.onDateSelected(date);
            },
      child: Opacity(
        opacity: isFuture && isCurrentMonth ? 0.3 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayNumber,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected || isTodayDate ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (isCurrentMonth && (hasLog || hasCheckIn)) ...[
                const SizedBox(height: 1),
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
                          color: isSelected ? Colors.white : AppTheme.primaryLight,
                        ),
                      ),
                    if (hasCheckIn)
                      Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : AppTheme.successColor,
                        ),
                      ),
                  ],
                ),
              ],
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
    final isDark = AppTheme.isDarkMode(context);
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
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
