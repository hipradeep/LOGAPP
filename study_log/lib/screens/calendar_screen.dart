import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_event.dart';
import '../theme/app_theme.dart';
import '../controllers/calendar_controller.dart';
import '../services/service_locator.dart';
import '../widgets/app_spacers.dart';
import '../widgets/calendar/calendar_month_grid.dart';
import '../widgets/calendar/calendar_week_strip.dart';
import '../widgets/calendar/calendar_legend.dart';
import '../widgets/calendar/calendar_filter_sheet.dart';
import '../widgets/calendar/calendar_week_view.dart';
import '../widgets/calendar/calendar_agenda_view.dart';
import 'calendar_date_detail_screen.dart';
import 'calendar_revision_detail_screen.dart';

/// Complete Calendar Screen supporting:
/// - Screen 1: Month View with color-coded revision dots & due level summary cards
/// - Screen 2: Day View with 7-day horizontal strip & scheduled topics list
/// - Screen 3: Filter & View options bottom sheet
/// - Screen 4: Week View timeline schedule
/// - Screen 5: Agenda View chronological upcoming list
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarController get _controller => getIt<CalendarController>();
  bool _isDayViewActive = false;

  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _dateHeaderFormat = DateFormat('d MMM yyyy');

  void _openFilterSheet() {
    CalendarFilterSheet.show(
      context,
      currentViewMode: _controller.viewMode,
      currentLevels: _controller.enabledLevels,
      currentShowCompletions: _controller.showCompletions,
      currentCourseId: _controller.selectedCourseId,
      onApply: ({
        required CalendarViewMode viewMode,
        required Set<int> levels,
        required bool showCompletions,
        required String? courseId,
      }) {
        _controller.setViewMode(viewMode);
        _controller.applyFilters(
          levels: levels,
          showCompletions: showCompletions,
          courseId: courseId,
        );
        if (viewMode == CalendarViewMode.month) {
          setState(() => _isDayViewActive = false);
        }
      },
    );
  }

  void _openEventDetail(CalendarEvent event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarRevisionDetailScreen(event: event),
      ),
    );
  }

  void _openDateDetail(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarDateDetailScreen(date: date),
      ),
    );
  }

  void _handleDateSelect(DateTime date) {
    _controller.selectDate(date);
    setState(() => _isDayViewActive = true);
  }

  void _backToMonthView() {
    setState(() => _isDayViewActive = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            // Mode dispatch: Week, Agenda, or Month / Day
            if (_controller.viewMode == CalendarViewMode.week) {
              return _buildWeekView();
            }
            if (_controller.viewMode == CalendarViewMode.agenda) {
              return _buildAgendaView();
            }

            // Month View (Screen 1) or Day View (Screen 2)
            return _isDayViewActive ? _buildDayView() : _buildMonthView();
          },
        ),
      ),
    );
  }

  // === Screen 1: Month View ===
  Widget _buildMonthView() {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final monthLabel = _monthYearFormat.format(_controller.focusedMonth);
    final selectedDate = _controller.selectedDate;
    final levelCounts = _controller.levelCountsForDate(selectedDate);
    final isToday = _isSameDay(selectedDate, DateTime.now());
    final dateHeading = '${isToday ? 'Today • ' : ''}${_dateHeaderFormat.format(selectedDate)}';

    return Column(
      children: [
        // Top Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: AppTheme.textPrimaryColor(context), size: 22),
                onPressed: _openFilterSheet,
                tooltip: 'Filter',
              ),
              IconButton(
                icon: const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 22),
                onPressed: _controller.jumpToToday,
                tooltip: 'Today',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomSafe + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month Navigation: < October 2025 >
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                        onPressed: _controller.previousMonth,
                      ),
                      Text(
                        monthLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                        onPressed: _controller.nextMonth,
                      ),
                    ],
                  ),
                ),
                // 7x6 Calendar Grid
                CalendarMonthGrid(
                  focusedMonth: _controller.focusedMonth,
                  selectedDate: _controller.selectedDate,
                  dotsForDate: _controller.dotsForDate,
                  onSelectDate: _handleDateSelect,
                ),
                const VGapSm(),
                // Color Legend
                const CalendarLegend(),
                const VGapMd(),
                // Date Summary Cards Header: Today • 10 Oct 2025
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateHeading,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openDateDetail(selectedDate),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VGapXs(),
                // Due Level Cards (e.g. [ R1 ] 3 revisions due >)
                if (levelCounts.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Text(
                      'No revisions due for this day.',
                      style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 13),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: levelCounts.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _DueLevelSummaryCard(
                            level: entry.key,
                            count: entry.value,
                            onTap: () => setState(() => _isDayViewActive = true),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // === Screen 2: Day View (Selected Date) ===
  Widget _buildDayView() {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final selectedDate = _controller.selectedDate;
    final events = _controller.eventsForDate(selectedDate);
    final monthLabel = _monthYearFormat.format(_controller.focusedMonth);
    final isToday = _isSameDay(selectedDate, DateTime.now());
    final dateHeading = '${isToday ? 'Today • ' : ''}${_dateHeaderFormat.format(selectedDate)}';

    return Column(
      children: [
        // Top Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 28),
                onPressed: _backToMonthView,
                tooltip: 'Back to Month',
              ),
              const HGapXs(),
              Text(
                'Calendar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: AppTheme.textPrimaryColor(context), size: 22),
                onPressed: _openFilterSheet,
                tooltip: 'Filter',
              ),
            ],
          ),
        ),
        // Month Selector: < October 2025 >
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: AppTheme.textPrimaryColor(context), size: 26),
                onPressed: _controller.previousMonth,
              ),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: AppTheme.textPrimaryColor(context), size: 26),
                onPressed: _controller.nextMonth,
              ),
            ],
          ),
        ),
        // 7-day horizontal strip
        CalendarWeekStrip(
          selectedDate: _controller.selectedDate,
          onSelectDate: (d) => _controller.selectDate(d),
        ),
        Divider(height: 16, color: AppTheme.borderColor(context)),
        // Day Schedule Header: Today • 10 Oct 2025       5 items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateHeading,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                '${events.length} ${events.length == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
        ),
        // Schedule List
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text(
                    'No items scheduled for this day.',
                    style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 13),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomSafe + 24),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const VGapSm(),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _DayScheduleItemCard(
                      event: event,
                      onTap: () => _openEventDetail(event),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // === Screen 4: Week View ===
  Widget _buildWeekView() {
    return Column(
      children: [
        _buildViewSwitcherBar(),
        Expanded(
          child: CalendarWeekView(
            selectedDate: _controller.selectedDate,
            weekEvents: _controller.eventsForWeekOf(_controller.selectedDate),
            onSelectDate: (d) {
              _controller.selectDate(d);
              setState(() => _isDayViewActive = true);
              _controller.setViewMode(CalendarViewMode.month);
            },
            onEventTap: _openEventDetail,
            onPreviousWeek: _controller.previousWeek,
            onNextWeek: _controller.nextWeek,
          ),
        ),
      ],
    );
  }

  // === Screen 5: Agenda View ===
  Widget _buildAgendaView() {
    return Column(
      children: [
        _buildViewSwitcherBar(),
        Expanded(
          child: CalendarAgendaView(
            agendaGroups: _controller.agendaGroupedEvents(),
            onEventTap: _openEventDetail,
          ),
        ),
      ],
    );
  }

  Widget _buildViewSwitcherBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Text(
            'Calendar',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          // Mode buttons
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: CalendarViewMode.values.map((mode) {
                final isSelected = mode == _controller.viewMode;
                return GestureDetector(
                  onTap: () {
                    _controller.setViewMode(mode);
                    if (mode == CalendarViewMode.month) {
                      setState(() => _isDayViewActive = false);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const HGapSm(),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: AppTheme.textPrimaryColor(context), size: 20),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DueLevelSummaryCard extends StatelessWidget {
  final int level;
  final int count;
  final VoidCallback onTap;

  const _DueLevelSummaryCard({
    required this.level,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = RevisionLevelPalette.of(context, level);
    final color = colors.foreground;
    final bg = colors.background;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'R$level',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? 'revision' : 'revisions'} due',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayScheduleItemCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _DayScheduleItemCard({
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowColor(context),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: event.bgTint(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.levelLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: event.color(context),
                  ),
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.topicTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: event.isCompleted ? AppTheme.textSecondaryColor(context) : AppTheme.textPrimaryColor(context),
                        decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const VGapXs(),
                    Text(
                      event.breadcrumb,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const HGapSm(),
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const HGapXs(),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
