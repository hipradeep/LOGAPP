import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_event.dart';
import '../../theme/app_theme.dart';
import '../app_spacers.dart';

/// Screen 4: Week View displaying 7-day schedule with all revisions
class CalendarWeekView extends StatelessWidget {
  final DateTime selectedDate;
  final Map<DateTime, List<CalendarEvent>> weekEvents;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<CalendarEvent> onEventTap;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  const CalendarWeekView({
    super.key,
    required this.selectedDate,
    required this.weekEvents,
    required this.onSelectDate,
    required this.onEventTap,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  static final DateFormat _monthDayFormat = DateFormat('MMM d');
  static final DateFormat _dayOfWeekFormat = DateFormat('E');

  @override
  Widget build(BuildContext context) {
    final days = weekEvents.keys.toList()..sort();
    if (days.isEmpty) return const SizedBox.shrink();

    final firstDay = days.first;
    final lastDay = days.last;
    final rangeText = '${_monthDayFormat.format(firstDay)} – ${_monthDayFormat.format(lastDay)}, ${lastDay.year}';

    return RepaintBoundary(
      child: Column(
        children: [
          // Week Range Navigation: < Oct 6 – Oct 12, 2025 >
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                  onPressed: onPreviousWeek,
                ),
                Text(
                  rangeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                  onPressed: onNextWeek,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.borderColor(context)),
          // Day rows
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: days.length,
              separatorBuilder: (_, __) => Divider(height: 16, color: AppTheme.borderColor(context)),
              itemBuilder: (context, index) {
                final date = days[index];
                final events = weekEvents[date] ?? const [];
                final isSelected = date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;

                return _WeekDayRow(
                  date: date,
                  events: events,
                  isSelected: isSelected,
                  dayOfWeek: _dayOfWeekFormat.format(date),
                  onDayTap: () => onSelectDate(date),
                  onEventTap: onEventTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDayRow extends StatelessWidget {
  final DateTime date;
  final List<CalendarEvent> events;
  final bool isSelected;
  final String dayOfWeek;
  final VoidCallback onDayTap;
  final ValueChanged<CalendarEvent> onEventTap;

  const _WeekDayRow({
    required this.date,
    required this.events,
    required this.isSelected,
    required this.dayOfWeek,
    required this.onDayTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Day badge
        InkWell(
          onTap: onDayTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapXs(),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const HGapMd(),
        // Right Column: Stack of revision pills
        Expanded(
          child: events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'No revisions scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: events.map((event) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Material(
                        color: event.bgTint(context),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => onEventTap(event),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: event.color(context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const HGapSm(),
                                Text(
                                  '${event.levelLabel}: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: event.color(context),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    event.topicTitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
