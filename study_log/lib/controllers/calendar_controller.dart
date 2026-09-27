import 'dart:async';
import 'package:flutter/material.dart';
import '../models/calendar_event.dart';
import '../models/revision.dart';
import '../services/service_locator.dart';
import 'revision_controller.dart';
import 'courses_controller.dart';

/// Controller powering the StudyLog Calendar and all its views:
/// - Month View, Week View, Agenda View
/// - Date selection & navigation
/// - Filter by revision levels (R1..R5), completions, and courses
/// - Event mapping from the R1->R5 spaced repetition ladder
class CalendarController extends ChangeNotifier {
  final RevisionController _revisionController;
  final CoursesController _coursesController;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  CalendarViewMode _viewMode = CalendarViewMode.month;

  Set<int> _enabledLevels = {1, 2, 3, 4, 5};
  bool _showCompletions = true;
  String? _selectedCourseId;

  CalendarController({
    RevisionController? revisionController,
    CoursesController? coursesController,
  })  : _revisionController = revisionController ?? getIt<RevisionController>(),
        _coursesController = coursesController ?? getIt<CoursesController>() {
    _revisionController.addListener(_onRevisionsChanged);
    _coursesController.addListener(_onCoursesChanged);
  }

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;
  CalendarViewMode get viewMode => _viewMode;
  Set<int> get enabledLevels => Set.unmodifiable(_enabledLevels);
  bool get showCompletions => _showCompletions;
  String? get selectedCourseId => _selectedCourseId;

  void _onRevisionsChanged() {
    notifyListeners();
  }

  void _onCoursesChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _revisionController.removeListener(_onRevisionsChanged);
    _coursesController.removeListener(_onCoursesChanged);
    super.dispose();
  }

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    if (_focusedMonth.year != date.year || _focusedMonth.month != date.month) {
      _focusedMonth = DateTime(date.year, date.month, 1);
    }
    notifyListeners();
  }

  void setFocusedMonth(DateTime month) {
    _focusedMonth = DateTime(month.year, month.month, 1);
    notifyListeners();
  }

  void previousMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    notifyListeners();
  }

  void previousWeek() {
    _selectedDate = _selectedDate.subtract(const Duration(days: 7));
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    notifyListeners();
  }

  void nextWeek() {
    _selectedDate = _selectedDate.add(const Duration(days: 7));
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    notifyListeners();
  }

  void jumpToToday() {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
    notifyListeners();
  }

  void setViewMode(CalendarViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  void applyFilters({
    required Set<int> levels,
    required bool showCompletions,
    String? courseId,
  }) {
    _enabledLevels = Set.from(levels);
    _showCompletions = showCompletions;
    _selectedCourseId = courseId;
    notifyListeners();
  }

  void resetFilters() {
    _enabledLevels = {1, 2, 3, 4, 5};
    _showCompletions = true;
    _selectedCourseId = null;
    notifyListeners();
  }

  /// Marks a revision as completed and auto-progresses the ladder.
  Future<bool> markRevisionCompleted(String revisionId) async {
    final success = await _revisionController.completeCurrentLevel(revisionId);
    if (success) {
      notifyListeners();
    }
    return success;
  }

  /// All calendar events derived from the live revisions ladder.
  List<CalendarEvent> get allEvents {
    final revisions = _revisionController.revisions;
    final List<CalendarEvent> events = [];

    final timeSlots = [
      '09:00 AM',
      '10:30 AM',
      '02:00 PM',
      '04:00 PM',
      '06:00 PM',
      '08:00 PM',
    ];

    for (var i = 0; i < revisions.length; i++) {
      final r = revisions[i];

      // Check course filter
      if (_selectedCourseId != null && _selectedCourseId!.isNotEmpty) {
        if (r.courseId != _selectedCourseId) continue;
      }

      final time = timeSlots[i % timeSlots.length];

      // 1. Scheduled / Due Level
      if (!r.isFinished && _enabledLevels.contains(r.currentLevel)) {
        final d = r.nextRevisionAt;
        final scheduledDate = DateTime(d.year, d.month, d.day);
        events.add(
          CalendarEvent(
            id: '${r.id}_scheduled',
            revisionId: r.id,
            topicTitle: r.moduleTitle,
            courseTitle: r.courseTitle,
            moduleTitle: r.moduleDescription.isNotEmpty ? r.moduleDescription : r.moduleTitle,
            courseId: r.courseId,
            moduleId: r.moduleId,
            level: r.currentLevel,
            date: scheduledDate,
            time: time,
            isCompleted: false,
            notes: 'Revise key concepts and problem sets for R${r.currentLevel}.',
          ),
        );
      }

      // 2. Completed Milestones (if enabled)
      if (_showCompletions && r.completedAt != null) {
        final c = r.completedAt!;
        events.add(
          CalendarEvent(
            id: '${r.id}_completed',
            revisionId: r.id,
            topicTitle: r.moduleTitle,
            courseTitle: r.courseTitle,
            moduleTitle: r.moduleDescription.isNotEmpty ? r.moduleDescription : r.moduleTitle,
            courseId: r.courseId,
            moduleId: r.moduleId,
            level: r.currentLevel,
            date: DateTime(c.year, c.month, c.day),
            time: time,
            isCompleted: true,
            completedAt: c,
            notes: 'Completed milestone revision.',
          ),
        );
      }
    }

    return events;
  }

  /// Filtered events for a specific single day.
  List<CalendarEvent> eventsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return allEvents.where((e) => e.date == target).toList();
  }

  /// Distinct indicator dot colors for a given day in the Month grid.
  List<Color> dotsForDate(DateTime date) {
    final events = eventsForDate(date);
    if (events.isEmpty) return const [];

    final dots = <Color>[];
    for (final e in events) {
      final c = e.color;
      if (!dots.contains(c)) {
        dots.add(c);
      }
      if (dots.length >= 5) break;
    }
    return dots;
  }

  /// Level counts for a date, e.g. R1: 3, R2: 1, R4: 1.
  Map<int, int> levelCountsForDate(DateTime date) {
    final events = eventsForDate(date).where((e) => !e.isCompleted).toList();
    final map = <int, int>{};
    for (final e in events) {
      map[e.level] = (map[e.level] ?? 0) + 1;
    }
    return map;
  }

  /// Weekly schedule: returns map from Monday to Sunday for the week of [centerDate].
  Map<DateTime, List<CalendarEvent>> eventsForWeekOf(DateTime centerDate) {
    final clean = DateTime(centerDate.year, centerDate.month, centerDate.day);
    // Find Monday of this week (DateTime weekday: Mon=1, Sun=7)
    final monday = clean.subtract(Duration(days: clean.weekday - 1));

    final map = <DateTime, List<CalendarEvent>>{};
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      map[day] = eventsForDate(day);
    }
    return map;
  }

  /// Agenda grouping: chronological list of upcoming days with scheduled items.
  Map<DateTime, List<CalendarEvent>> agendaGroupedEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: 60));

    final upcoming = allEvents.where((e) {
      return !e.date.isBefore(today) && !e.date.isAfter(end);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final map = <DateTime, List<CalendarEvent>>{};
    for (final event in upcoming) {
      map.putIfAbsent(event.date, () => []).add(event);
    }
    return map;
  }
}
