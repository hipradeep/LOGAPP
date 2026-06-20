import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_provider.dart';
import '../widgets/timeline_event_card.dart';
import '../widgets/activity_check_in_sheet.dart';
import '../models/activity.dart';
import '../controllers/calendar_scheduler_controller.dart';

class EventGroup {
  final List<TimelineEvent> events = [];

  double get startHour => events.map((e) => e.startHour).reduce((a, b) => a < b ? a : b);
  double get endHour => events.map((e) => e.endHour).reduce((a, b) => a > b ? a : b);
  double get durationHours => endHour - startHour;
}

class TimelineSlot {
  final double startHour;
  final double endHour;
  final bool isMerged;
  final double height;
  final double topOffset;

  const TimelineSlot({
    required this.startHour,
    required this.endHour,
    required this.isMerged,
    required this.height,
    required this.topOffset,
  });
}

enum CalendarTransitionType {
  horizontal,
  vertical;
}

class CalendarAnimationProvider extends InheritedWidget {
  final Animation<double> animation;
  final CalendarTransitionType transitionType;
  final bool isExpanding;

  const CalendarAnimationProvider({
    super.key,
    required this.animation,
    required this.transitionType,
    required this.isExpanding,
    required super.child,
  });

  static CalendarAnimationProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalendarAnimationProvider>();
  }

  @override
  bool updateShouldNotify(CalendarAnimationProvider oldWidget) {
    return animation != oldWidget.animation ||
        transitionType != oldWidget.transitionType ||
        isExpanding != oldWidget.isExpanding;
  }
}

class CalendarSchedulerScreen extends StatefulWidget {
  const CalendarSchedulerScreen({super.key});

  @override
  State<CalendarSchedulerScreen> createState() => _CalendarSchedulerScreenState();
}

class _CalendarSchedulerScreenState extends State<CalendarSchedulerScreen> {
  late final CalendarSchedulerController _controller;
  late final ScrollController _scrollController;
  bool _hasAutoScrolled = false;
  bool _isMonthViewExpanded = false;
  CalendarTransitionType _transitionType = CalendarTransitionType.horizontal;
  bool _isExpanding = true;

  static const double _hourHeight = 70.0;
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');



  void _handleVerticalDragExpand(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      setState(() {
        _transitionType = CalendarTransitionType.vertical;
        _isExpanding = true;
        _isMonthViewExpanded = true;
      });
    }
  }

  void _handleVerticalDragCollapse(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
      setState(() {
        _transitionType = CalendarTransitionType.vertical;
        _isExpanding = false;
        _isMonthViewExpanded = false;
      });
    }
  }

  void _toggleMonthView() {
    setState(() {
      _transitionType = CalendarTransitionType.vertical;
      _isExpanding = !_isMonthViewExpanded;
      _isMonthViewExpanded = !_isMonthViewExpanded;
    });
  }

  void _handleHorizontalDragEndExpanded(DragEndDetails details) {
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! < 0) {
        // Swipe left -> Next month (enforced)
        _controller.addMonths(1, enforceLimit: true);
      } else if (details.primaryVelocity! > 0) {
        // Swipe right -> Prev month (enforced)
        _controller.addMonths(-1, enforceLimit: true);
      }
    }
  }

  void _handleTodayTap() {
    _controller.setSelectedDate(DateTime.now());
  }

  bool _isNavigatingForward = true;
  DateTime? _lastSelectedDate;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = CalendarSchedulerController();
    _lastSelectedDate = _controller.selectedDate;
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (_lastSelectedDate != null && _controller.selectedDate != _lastSelectedDate) {
      _transitionType = CalendarTransitionType.horizontal;
      _isNavigatingForward = _controller.selectedDate.isAfter(_lastSelectedDate!);
      _lastSelectedDate = _controller.selectedDate;
    }
    if (!_hasAutoScrolled && !_controller.isLoading) {
      _hasAutoScrolled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialPosition();
      });
    }
  }

  Widget _transitionBuilder(Widget child, Animation<double> animation) {
    if (_transitionType == CalendarTransitionType.vertical) {
      return CalendarAnimationProvider(
        animation: animation,
        transitionType: _transitionType,
        isExpanding: _isExpanding,
        child: child,
      );
    } else {
      // Horizontal navigation transition
      final isIncoming = animation.status == AnimationStatus.forward || animation.status == AnimationStatus.completed;
      final Offset beginOffset;
      if (_isNavigatingForward) {
        // Swipe left / Next date: slides right to left
        // Incoming widget starts at right (positive X)
        // Outgoing widget starts at 0.0 and ends at left (negative X)
        beginOffset = isIncoming ? const Offset(0.15, 0.0) : const Offset(-0.15, 0.0);
      } else {
        // Swipe right / Prev date: slides left to right
        // Incoming widget starts at left (negative X)
        // Outgoing widget starts at 0.0 and ends at right (positive X)
        beginOffset = isIncoming ? const Offset(-0.15, 0.0) : const Offset(0.15, 0.0);
      }

      final slideAnimation = Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return CalendarAnimationProvider(
        animation: animation,
        transitionType: _transitionType,
        isExpanding: _isExpanding,
        child: SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    }
  }

  void _scrollToInitialPosition() {
    if (!_scrollController.hasClients) return;

    double targetHour = 8.0; // Default: 8 AM

    final isToday = _controller.selectedDate.day == DateTime.now().day &&
        _controller.selectedDate.month == DateTime.now().month &&
        _controller.selectedDate.year == DateTime.now().year;

    if (isToday) {
      final now = DateTime.now();
      targetHour = (now.hour + now.minute / 60.0) - 1.5;
    } else if (_controller.events.isNotEmpty) {
      final earliest = _controller.events.first;
      targetHour = earliest.startHour - 1.0;
    }

    final slots = _generateSlots(_controller.events);
    final targetOffset = _getYOffsetForHour(targetHour, slots).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  List<EventGroup> _groupEvents(List<TimelineEvent> events) {
    final List<EventGroup> groups = [];
    final sorted = List<TimelineEvent>.from(events)
      ..sort((a, b) => a.startHour.compareTo(b.startHour));

    for (var event in sorted) {
      EventGroup? targetGroup;
      for (var group in groups) {
        final overlaps = event.startHour < group.endHour && event.endHour > group.startHour;
        if (overlaps) {
          targetGroup = group;
          break;
        }
      }

      if (targetGroup != null) {
        targetGroup.events.add(event);
      } else {
        final newGroup = EventGroup()..events.add(event);
        groups.add(newGroup);
      }
    }

    return groups;
  }

  List<TimelineSlot> _generateSlots(List<TimelineEvent> events) {
    if (events.isEmpty) {
      final List<TimelineSlot> slots = [];
      double currentOffset = 0.0;
      for (int h = 0; h < 24; h++) {
        slots.add(TimelineSlot(
          startHour: h.toDouble(),
          endHour: (h + 1).toDouble(),
          isMerged: false,
          height: _hourHeight,
          topOffset: currentOffset,
        ));
        currentOffset += _hourHeight;
      }
      return slots;
    }

    final groups = _groupEvents(events);
    // Sort groups by start hour
    groups.sort((a, b) => a.startHour.compareTo(b.startHour));

    final List<TimelineSlot> slots = [];
    double currentOffset = 0.0;
    double lastHour = 0.0;

    for (var group in groups) {
      final start = group.startHour;
      final end = group.endHour;

      if (start > lastHour) {
        // There is an empty range before this group. Insert an empty/merged slot.
        slots.add(TimelineSlot(
          startHour: lastHour,
          endHour: start,
          isMerged: true,
          height: _hourHeight,
          topOffset: currentOffset,
        ));
        currentOffset += _hourHeight;
      }

      // Insert the busy slot for this event group
      final double slotHeight = group.events.length * _hourHeight;
      slots.add(TimelineSlot(
        startHour: start,
        endHour: end,
        isMerged: false,
        height: slotHeight,
        topOffset: currentOffset,
      ));
      currentOffset += slotHeight;
      lastHour = end;
    }

    // Insert trailing empty slot if needed
    if (lastHour < 24.0) {
      slots.add(TimelineSlot(
        startHour: lastHour,
        endHour: 24.0,
        isMerged: true,
        height: _hourHeight,
        topOffset: currentOffset,
      ));
    }

    return slots;
  }

  double _getYOffsetForHour(double hour, List<TimelineSlot> slots) {
    for (var slot in slots) {
      if (hour >= slot.startHour && hour <= slot.endHour) {
        final double range = slot.endHour - slot.startHour;
        if (range <= 0) return slot.topOffset;
        final ratio = (hour - slot.startHour) / range;
        return slot.topOffset + ratio * slot.height;
      }
    }
    if (slots.isNotEmpty) {
      final lastSlot = slots.last;
      return lastSlot.topOffset + lastSlot.height;
    }
    return 0.0;
  }

  void _handleCardTap(BuildContext context, CalendarSchedulerController controller, TimelineEvent event) {
    Activity? activity;
    try {
      activity = controller.activities.firstWhere((a) => a.id == event.activityId);
    } catch (_) {}

    if (activity != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ActivityCheckInSheet(
          activity: activity!,
          selectedDate: controller.selectedDate,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<CalendarSchedulerController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<CalendarSchedulerController>(context);
          final isTodaySelected = controller.selectedDate.day == DateTime.now().day &&
              controller.selectedDate.month == DateTime.now().month &&
              controller.selectedDate.year == DateTime.now().year;

          return FullScreenPage(
            showScaffold: true,
            isScrollable: false,
            title: _monthYearFormat.format(controller.selectedDate),
            showBackButton: true,
            headerSpacing: 56.0,
            actions: [
              if (_isMonthViewExpanded &&
                  (controller.selectedDate.month != DateTime.now().month ||
                      controller.selectedDate.year != DateTime.now().year))
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: GestureDetector(
                    onTap: _handleTodayTap,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.surface(context).withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        DateTime.now().day.toString(),
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryAccentColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: AppTheme.surface(context).withValues(alpha: 0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fixed Weekdays initials header: M T W T F S S (shown only once and completely static)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final isSelectedWeekDay = controller.selectedDate.weekday - 1 == index;
                          return Expanded(
                            child: Center(
                              child: Text(
                                WeeklyHeader.weekdays[index],
                                style: GoogleFonts.outfit(
                                  color: isSelectedWeekDay
                                      ? AppTheme.primaryAccentColor(context)
                                      : AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: isSelectedWeekDay ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppTheme.borderColor(context),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final monday = controller.selectedDate.subtract(Duration(days: controller.selectedDate.weekday - 1));
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          reverseDuration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOutCubic,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            reverseDuration: const Duration(milliseconds: 200),
                            transitionBuilder: _transitionBuilder,
                            child: !_isMonthViewExpanded
                                ? GestureDetector(
                                    key: ValueKey('weekly-${monday.year}-${monday.month}-${monday.day}'),
                                    behavior: HitTestBehavior.opaque,
                                    onVerticalDragEnd: _handleVerticalDragExpand,
                                    child: WeeklyHeader(
                                      selectedDate: controller.selectedDate,
                                      onDateSelected: controller.setSelectedDate,
                                      isExpanded: false,
                                    ),
                                  )
                                : GestureDetector(
                                    key: ValueKey('monthly-${controller.selectedDate.year}-${controller.selectedDate.month}'),
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragEnd: _handleHorizontalDragEndExpanded,
                                    onVerticalDragEnd: _handleVerticalDragCollapse,
                                    child: WeeklyHeader(
                                      selectedDate: controller.selectedDate,
                                      onDateSelected: controller.setSelectedDate,
                                      isExpanded: true,
                                    ),
                                  ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleMonthView,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: AppTheme.surface(context).withValues(alpha: 0.05),
                  child: Icon(
                    _isMonthViewExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Expanded(
                child: controller.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : _buildTimelineContent(context, controller, isTodaySelected),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    CalendarSchedulerController controller,
    bool isTodaySelected,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final groups = _groupEvents(controller.events);
    final slots = _generateSlots(controller.events);
    final double totalTimelineHeight = slots.isEmpty
        ? 24 * _hourHeight
        : slots.last.topOffset + slots.last.height;

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Container(
        height: totalTimelineHeight + 30.0,
        padding: const EdgeInsets.only(top: 10, bottom: 20),
        child: Stack(
          children: [
            // Hourly grid background lines with collapsed hour ranges
            RepaintBoundary(
              child: TimelineGridBackground(hourHeight: _hourHeight, slots: slots),
            ),

            // Empty state overlay if no items scheduled
            if (controller.events.isEmpty)
              Positioned(
                top: 8.0 * _hourHeight,
                left: 68.0,
                right: 16.0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.borderColor(context),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 40,
                        color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.4),
                      ),
                      const VGapSm(),
                      Text(
                        'No Scheduled Tasks',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const VGapSm(),
                      Text(
                        'Scheduled activities or subtasks for this day will appear here on the timeline.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Render scheduled timeline events in vertical groups
            ...groups.map((group) {
              final double width = screenWidth - 68.0 - 16.0;
              final double topOffset = _getYOffsetForHour(group.startHour, slots) + 2.0;
              final double groupHeight = (_getYOffsetForHour(group.endHour, slots) - _getYOffsetForHour(group.startHour, slots)) - 4.0;

              return Positioned(
                top: topOffset,
                height: groupHeight.clamp(20.0, double.infinity),
                left: 68.0,
                width: width,
                child: Column(
                  children: List.generate(group.events.length, (index) {
                    final event = group.events[index];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: index == group.events.length - 1 ? 0 : 4.0,
                        ),
                        child: TimelineEventCard(
                          event: event,
                          onTap: () => _handleCardTap(context, controller, event),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),

            // Real-time current time indicator
            if (isTodaySelected)
              CurrentTimeLineIndicator(hourHeight: _hourHeight, slots: slots),
          ],
        ),
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -3.141592653589793 / 2; // top of circle
      final sweepAngle = 2 * 3.141592653589793 * progress.clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class WeeklyHeader extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final bool isExpanded;

  const WeeklyHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isExpanded,
  });

  static const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<CalendarSchedulerController>(context);
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final now = DateTime.now();

    final provider = CalendarAnimationProvider.of(context);
    final isVertical = provider != null && provider.transitionType == CalendarTransitionType.vertical;

    if (!isExpanded) {
      // Single Weekly Row
      final weeklyRowWidget = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = monday.add(Duration(days: index));
          return DateCell(
            date: date,
            selectedDate: selectedDate,
            now: now,
            isExpanded: false,
            completionFraction: controller.getCompletionFractionForDate(date),
            onDateSelected: onDateSelected,
          );
        }),
      );

      if (isVertical) {
        final weeklyCurve = CurvedAnimation(
          parent: provider.animation,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
        );
        final slideAnim = Tween<Offset>(
          begin: const Offset(0.0, 0.15),
          end: Offset.zero,
        ).animate(weeklyCurve);

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FadeTransition(
            opacity: weeklyCurve,
            child: SlideTransition(
              position: slideAnim,
              child: weeklyRowWidget,
            ),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: weeklyRowWidget,
        );
      }
    } else {
      // Multi-row Monthly Grid in the exact same style!
      final gridDates = _generateMonthGridDates(selectedDate);
      final List<Widget> rows = [];
      
      for (int i = 0; i < gridDates.length; i += 7) {
        final weekDates = gridDates.sublist(i, i + 7);
        final rowIndex = i ~/ 7;
        
        final rowWidget = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: weekDates.map((date) {
            final isCurrentMonth = date.month == selectedDate.month;
            return DateCell(
              date: date,
              selectedDate: selectedDate,
              now: now,
              isExpanded: true,
              isCurrentMonth: isCurrentMonth,
              completionFraction: controller.getCompletionFractionForDate(date),
              onDateSelected: onDateSelected,
            );
          }).toList(),
        );

        if (isVertical) {
          final double start = (0.5 + rowIndex * 0.05).clamp(0.5, 0.8);
          final double end = (start + 0.2).clamp(0.5, 1.0);
          final rowCurve = CurvedAnimation(
            parent: provider.animation,
            curve: Interval(start, end, curve: Curves.easeOutCubic),
          );
          final rowSlide = Tween<Offset>(
            begin: const Offset(0.0, -0.15),
            end: Offset.zero,
          ).animate(rowCurve);

          rows.add(
            FadeTransition(
              opacity: rowCurve,
              child: SlideTransition(
                position: rowSlide,
                child: rowWidget,
              ),
            ),
          );
        } else {
          rows.add(rowWidget);
        }

        if (i + 7 < gridDates.length) {
          rows.add(const SizedBox(height: 8));
        }
      }

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      );
    }
  }
}

class DateCell extends StatelessWidget {
  final DateTime date;
  final DateTime selectedDate;
  final DateTime now;
  final bool isExpanded;
  final bool isCurrentMonth;
  final double? completionFraction;
  final ValueChanged<DateTime> onDateSelected;

  const DateCell({
    super.key,
    required this.date,
    required this.selectedDate,
    required this.now,
    required this.isExpanded,
    this.isCurrentMonth = true,
    this.completionFraction,
    required this.onDateSelected,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _isSameDay(date, selectedDate);
    final isToday = _isSameDay(date, now);
    
    // Check if expanded and date falls outside allowed range [current month - 3, current month + 1]
    final isTapBlocked = isExpanded && () {
      final earliestMonth = DateTime(now.year, now.month - 3, 1);
      final latestMonth = DateTime(now.year, now.month + 1, 1);
      final dateMonthStart = DateTime(date.year, date.month, 1);
      return dateMonthStart.isBefore(earliestMonth) || dateMonthStart.isAfter(latestMonth);
    }();

    Widget innerCircle = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF43F5E) // Premium coral color
            : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(
                color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        date.day.toString(),
        style: GoogleFonts.outfit(
          color: isSelected
              ? Colors.white
              : (isToday ? AppTheme.primaryAccentColor(context) : AppTheme.textPrimaryColor(context)),
          fontSize: 13,
          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );

    Widget cellContent;
    if (completionFraction != null) {
      final Color progressColor = const Color(0xFFF43F5E); // Brand coral
      final Color trackColor = isSelected
          ? Colors.white.withValues(alpha: 0.3)
          : AppTheme.textSecondaryColor(context).withValues(alpha: 0.1);

      cellContent = CustomPaint(
        painter: CircularProgressPainter(
          progress: completionFraction!,
          color: progressColor,
          backgroundColor: trackColor,
          strokeWidth: 2.0,
        ),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: innerCircle,
          ),
        ),
      );
    } else {
      cellContent = SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: innerCircle,
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: isTapBlocked ? null : () => onDateSelected(date),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Opacity(
            opacity: (isCurrentMonth && !isTapBlocked) ? 1.0 : 0.25,
            child: cellContent,
          ),
        ),
      ),
    );
  }
}

class TimelineGridBackground extends StatelessWidget {
  final double hourHeight;
  final List<TimelineSlot> slots;

  const TimelineGridBackground({
    super.key,
    required this.hourHeight,
    required this.slots,
  });

  String _formatHour(double hour) {
    final int h = hour.floor();
    final int m = ((hour - h) * 60).round();
    
    final String amPm = h >= 12 ? 'PM' : 'AM';
    int displayHour = h % 12;
    if (displayHour == 0) displayHour = 12;
    
    final String minuteStr = m < 10 ? '0$m' : '$m';
    return '$displayHour:$minuteStr $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: slots.map((slot) {
        return SizedBox(
          height: slot.height,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        _formatHour(slot.startHour),
                        style: GoogleFonts.outfit(
                          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: AppTheme.borderColor(context).withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class CurrentTimeLineIndicator extends StatefulWidget {
  final double hourHeight;
  final List<TimelineSlot> slots;

  const CurrentTimeLineIndicator({
    super.key,
    required this.hourHeight,
    required this.slots,
  });

  @override
  State<CurrentTimeLineIndicator> createState() => _CurrentTimeLineIndicatorState();
}

class _CurrentTimeLineIndicatorState extends State<CurrentTimeLineIndicator> {
  Timer? _timer;
  late DateTime _now;
  static final DateFormat _timeFormat = DateFormat('h:mm');

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _getYOffsetForHour(double hour, List<TimelineSlot> slots) {
    for (var slot in slots) {
      if (hour >= slot.startHour && hour <= slot.endHour) {
        if (slot.isMerged) {
          final ratio = (hour - slot.startHour) / (slot.endHour - slot.startHour);
          return slot.topOffset + ratio * slot.height;
        } else {
          final ratio = hour - slot.startHour;
          return slot.topOffset + ratio * slot.height;
        }
      }
    }
    if (slots.isNotEmpty) {
      final lastSlot = slots.last;
      return lastSlot.topOffset + lastSlot.height;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final double currentHour = _now.hour + _now.minute / 60.0;
    final double topPosition = _getYOffsetForHour(currentHour, widget.slots);

    return Positioned(
      top: topPosition - 8,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: Row(
          children: [
            Container(
              width: 60,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                _timeFormat.format(_now),
                style: GoogleFonts.outfit(
                  color: AppTheme.errorColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Container(
                height: 1.5,
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
