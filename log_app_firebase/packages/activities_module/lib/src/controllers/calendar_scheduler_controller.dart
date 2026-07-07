import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
class TimelineEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isCompleted;
  final String trackingType; // 'single', 'multiple', 'milestone'
  final String? category;
  final String activityId;
  final String? taskId;
  final String? subTaskId;
  final bool isSubTask;

  TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isCompleted,
    required this.trackingType,
    this.category,
    required this.activityId,
    this.taskId,
    this.subTaskId,
    this.isSubTask = false,
  });

  double get startHour => startTime.hour + startTime.minute / 60.0;
  double get endHour => endTime.hour + endTime.minute / 60.0;
  double get durationHours => endHour - startHour;
}

class CalendarSchedulerController extends ChangeNotifier {
  final ActivityService _activityService;
  final CheckInService _checkInService;

  DateTime _selectedDate;
  DateTime? _currentSubscribedMonth;

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<QuerySnapshot>? _tasksSub;
  StreamSubscription<QuerySnapshot>? _checkInsSub;

  List<Activity> _activities = [];
  List<Task> _tasks = [];
  List<CheckIn> _checkIns = [];

  bool _isLoading = true;
  bool _activitiesLoaded = false;
  bool _tasksLoaded = false;
  bool _checkInsLoaded = false;
  String? _errorMessage;

  List<TimelineEvent> _events = [];

  // Getters
  DateTime get selectedDate => _selectedDate;
  List<TimelineEvent> get events => _events;
  List<Activity> get activities => _activities;
  List<CheckIn> get checkIns => _checkIns;
  bool get isLoading => _isLoading && !(_activitiesLoaded && _tasksLoaded && _checkInsLoaded);
  String? get errorMessage => _errorMessage;

  CalendarSchedulerController({
    ActivityService? activityService,
    CheckInService? checkInService,
    DateTime? initialDate,
  })  : _activityService = activityService ?? GetIt.instance<ActivityService>(),
        _checkInService = checkInService ?? GetIt.instance<CheckInService>(),
        _selectedDate = initialDate ?? DateTime.now() {
    _initActivitiesStream();
    _updateSubscriptions(_selectedDate);
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    _updateSubscriptions(date);
    _recomputeEvents();
    notifyListeners();
  }

  void _handleStreamError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  void _initActivitiesStream() {
    _activitiesSub = _activityService.getActiveActivitiesStream().listen(
      (activities) {
        _activities = activities;
        _activitiesLoaded = true;
        _recomputeEvents();
      },
      onError: _handleStreamError,
    );
  }


  void _updateSubscriptions(DateTime date) {
    if (_currentSubscribedMonth != null) {
      return;
    }
    _currentSubscribedMonth = date;

    _tasksSub?.cancel();
    _checkInsSub?.cancel();

    _tasksSub = FirebaseFirestore.instance
        .collection('tasks')
        .snapshots()
        .listen(
      (snapshot) {
        _tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
        _tasksLoaded = true;
        _recomputeEvents();
      },
      onError: _handleStreamError,
    );

    _checkInsSub = FirebaseFirestore.instance
        .collection('checkins')
        .snapshots()
        .listen(
      (snapshot) {
        _checkIns = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
        _checkInsLoaded = true;
        _recomputeEvents();
      },
      onError: _handleStreamError,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isDateInRange(DateTime date, DateTime? start, DateTime? end) {
    final d = DateTime(date.year, date.month, date.day);
    if (start != null) {
      final s = DateTime(start.year, start.month, start.day);
      if (d.isBefore(s)) return false;
    }
    if (end != null) {
      final e = DateTime(end.year, end.month, end.day);
      if (d.isAfter(e)) return false;
    }
    return true;
  }

  List<TimelineEvent> _computeEventsForDate(DateTime date) {
    final dayOfWeek = date.weekday;
    final List<TimelineEvent> computedEvents = [];

    final activeOnDay = _activities.where((activity) {
      // Verify active, schedules, and start/end date bounds
      final repeatMatch = activity.repeatDays.contains(dayOfWeek);
      final rangeMatch = _isDateInRange(date, activity.startDate, activity.endDate);
      return repeatMatch && rangeMatch;
    }).toList();

    for (var activity in activeOnDay) {
      // Find Firestore Task document for this activity on date
      final Task? todayTaskDoc = _tasks.where((t) => t.activityId == activity.id && _isSameDay(t.timestamp, date)).firstOrNull;

      if (activity.trackingType == 'single') {
        // Habits: single daily check-ins
        if (activity.scheduledTime != null) {
          final isCompleted = _checkIns.any((c) =>
              c.activityId == activity.id &&
              _isSameDay(c.timestamp, date) &&
              c.checked &&
              c.skipped != true);

          final parsed = TimeParser.parseTimeRange(activity.scheduledTime!);
          computedEvents.add(TimelineEvent(
            id: 'single-${activity.id}',
            title: activity.name,
            description: activity.description ?? 'Daily Habit',
            startTime: DateTime(date.year, date.month, date.day, parsed.start.hour, parsed.start.minute),
            endTime: DateTime(date.year, date.month, date.day, parsed.end.hour, parsed.end.minute),
            isCompleted: isCompleted,
            trackingType: 'single',
            category: activity.category,
            activityId: activity.id,
          ));
        }
      } else if (activity.trackingType == 'multiple') {
        // Routines: list of subtasks
        // If today's Task document exists, use its subtasks. Otherwise, fallback to the template subtasks.
        final List<SubTask> subTasksToProcess = [];
        if (todayTaskDoc != null && todayTaskDoc.subTasks.isNotEmpty) {
          subTasksToProcess.addAll(todayTaskDoc.subTasks);
        } else {
          // Pre-populate from templates for display
          for (int i = 0; i < activity.subTaskTemplates.length; i++) {
            final template = activity.subTaskTemplates[i];
            final parts = template.split('|');
            final title = parts.first;
            final timeStr = parts.length > 1 ? parts.last : null;
            subTasksToProcess.add(SubTask(
              id: 'temp-$i-${template.hashCode}',
              title: title,
              checked: false,
              scheduledTime: timeStr,
            ));
          }
        }

        for (var subtask in subTasksToProcess) {
          if (subtask.scheduledTime != null) {
            final parsed = TimeParser.parseTimeRange(subtask.scheduledTime!);
            computedEvents.add(TimelineEvent(
              id: 'subtask-${activity.id}-${subtask.id}',
              title: subtask.title,
              description: activity.name,
              startTime: DateTime(date.year, date.month, date.day, parsed.start.hour, parsed.start.minute),
              endTime: DateTime(date.year, date.month, date.day, parsed.end.hour, parsed.end.minute),
              isCompleted: subtask.checked,
              trackingType: 'multiple',
              category: activity.category,
              activityId: activity.id,
              taskId: todayTaskDoc?.id,
              subTaskId: subtask.id,
              isSubTask: true,
            ));
          }
        }
      } else if (activity.trackingType == 'milestone') {
        // Milestones: separate Task documents linked to the milestone activity
        final milestoneTasks = _tasks.where((t) => t.activityId == activity.id && _isSameDay(t.timestamp, date));
        for (var task in milestoneTasks) {
          if (task.scheduledTime != null) {
            final parsed = TimeParser.parseTimeRange(task.scheduledTime!);
            computedEvents.add(TimelineEvent(
              id: 'milestone-${task.id}',
              title: task.taskName,
              description: activity.name,
              startTime: DateTime(date.year, date.month, date.day, parsed.start.hour, parsed.start.minute),
              endTime: DateTime(date.year, date.month, date.day, parsed.end.hour, parsed.end.minute),
              isCompleted: task.checked,
              trackingType: 'milestone',
              category: activity.category,
              activityId: activity.id,
              taskId: task.id,
            ));
          }
        }
      }
    }

    // Sort events by start time
    computedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    return computedEvents;
  }

  void _recomputeEvents() {
    _events = _computeEventsForDate(_selectedDate);
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  double? getCompletionFractionForDate(DateTime date) {
    final dateEvents = _computeEventsForDate(date);
    if (dateEvents.isEmpty) return null;
    final completedCount = dateEvents.where((e) => e.isCompleted).length;
    return completedCount / dateEvents.length;
  }

  double getStarsForDate(DateTime date) {
    final dateEvents = _computeEventsForDate(date);
    if (dateEvents.isEmpty) return 0.0;

    double dayStars = 0.0;

    final Map<String, List<TimelineEvent>> eventsByActivity = {};
    for (var event in dateEvents) {
      eventsByActivity.putIfAbsent(event.activityId, () => []).add(event);
    }

    for (var entry in eventsByActivity.entries) {
      final activityId = entry.key;
      final activityEvents = entry.value;

      final activity = _activities.firstWhere(
        (a) => a.id == activityId,
        orElse: () => Activity(
          id: '',
          name: '',
          isActive: false,
          timestamp: DateTime.now(),
        ),
      );
      if (activity.id.isEmpty) continue;

      final completedEvents = activityEvents.where((e) => e.isCompleted).length;
      final double activityProgress = activityEvents.isNotEmpty ? completedEvents / activityEvents.length : 0.0;

      dayStars += (activityProgress * activity.points);
    }

    return dayStars;
  }

  double getMaxStarsForDate(DateTime date) {
    final dateEvents = _computeEventsForDate(date);
    if (dateEvents.isEmpty) return 0.0;

    double dayMaxStars = 0.0;

    final Map<String, List<TimelineEvent>> eventsByActivity = {};
    for (var event in dateEvents) {
      eventsByActivity.putIfAbsent(event.activityId, () => []).add(event);
    }

    for (var entry in eventsByActivity.entries) {
      final activityId = entry.key;

      final activity = _activities.firstWhere(
        (a) => a.id == activityId,
        orElse: () => Activity(
          id: '',
          name: '',
          isActive: false,
          timestamp: DateTime.now(),
        ),
      );
      if (activity.id.isEmpty) continue;

      dayMaxStars += activity.points;
    }

    return dayMaxStars;
  }

  int getTotalDiamondsForHistory() {
    final Set<String> uniqueDateStrings = {};

    for (var task in _tasks) {
      final date = task.timestamp;
      final dateStr = "${date.year}-${date.month}-${date.day}";
      uniqueDateStrings.add(dateStr);
    }

    for (var checkIn in _checkIns) {
      final date = checkIn.timestamp;
      final dateStr = "${date.year}-${date.month}-${date.day}";
      uniqueDateStrings.add(dateStr);
    }

    int count = 0;
    for (var dateStr in uniqueDateStrings) {
      final parts = dateStr.split('-');
      final day = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final fraction = getCompletionFractionForDate(day);
      if (fraction != null && fraction >= 1.0) {
        count++;
      }
    }
    return count;
  }

  DateTime _addMonths(DateTime date, int months) {
    int newYear = date.year;
    int newMonth = date.month + months;
    while (newMonth > 12) {
      newMonth -= 12;
      newYear += 1;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear -= 1;
    }

    final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day.clamp(1, daysInNewMonth);

    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  void addMonths(int months, {bool enforceLimit = false}) {
    final targetDate = _addMonths(_selectedDate, months);
    if (enforceLimit) {
      final now = DateTime.now();
      final earliestMonth = DateTime(now.year, now.month - 3, 1);
      final latestMonth = DateTime(now.year, now.month + 1, 1);
      final targetMonthStart = DateTime(targetDate.year, targetDate.month, 1);
      if (targetMonthStart.isBefore(earliestMonth) || targetMonthStart.isAfter(latestMonth)) {
        return;
      }
    }
    setSelectedDate(targetDate);
  }

  Future<void> toggleEventCompletion(TimelineEvent event) async {
    try {
      if (event.trackingType == 'single') {
        if (event.isCompleted) {
          // Find the check-in and delete it
          final checkInToDelete = _checkIns.firstWhere(
            (c) => c.activityId == event.activityId && _isSameDay(c.timestamp, _selectedDate) && c.checked && c.skipped != true,
          );
          await _checkInService.deleteCheckIn(checkInToDelete.id);
        } else {
          // Log a check-in
          await _checkInService.createCheckIn(event.activityId, _selectedDate, true);
        }
      } else if (event.trackingType == 'multiple') {
        // Find parent activity to reconstruct checklist templates
        final activity = _activities.firstWhere((a) => a.id == event.activityId);

        // If today's Task document doesn't exist yet, we create it first
        Task taskDoc;
        if (event.taskId == null || event.taskId!.isEmpty) {
          final List<SubTask> initialSubTasks = activity.subTaskTemplates.map((template) {
            final parts = template.split('|');
            final title = parts.first;
            final timeStr = parts.length > 1 ? parts.last : null;
            return SubTask(
              id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}-${activity.subTaskTemplates.indexOf(template)}',
              title: title,
              checked: false,
              scheduledTime: timeStr,
            );
          }).toList();

          final newTask = Task(
            id: '',
            activityId: activity.id,
            taskName: activity.name,
            timestamp: _selectedDate,
            checked: false,
            scheduledTime: null,
            subTasks: initialSubTasks,
          );

          // Add to firestore and get doc
          final docRef = await FirebaseFirestore.instance.collection('tasks').add(newTask.toFirestore());
          taskDoc = newTask.copyWith(id: docRef.id);
        } else {
          taskDoc = _tasks.firstWhere((t) => t.id == event.taskId);
        }

        // Toggle the subtask's checked status
        final updatedSubTasks = taskDoc.subTasks.map((st) {
          // Match by title/ID
          final match = (event.subTaskId != null && !event.subTaskId!.startsWith('temp') && st.id == event.subTaskId) ||
              (st.title == event.title);
          if (match) {
            return st.copyWith(checked: !event.isCompleted);
          }
          return st;
        }).toList();

        final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
        final updatedTask = taskDoc.copyWith(
          subTasks: updatedSubTasks,
          checked: allChecked,
        );

        await _activityService.updateTask(updatedTask);
      } else if (event.trackingType == 'milestone') {
        if (event.taskId != null && event.taskId!.isNotEmpty) {
          await _activityService.toggleTask(event.taskId!, !event.isCompleted);
        }
      }
    } catch (e) {
      debugPrint("Error toggling timeline event completion: $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    _checkInsSub?.cancel();
    super.dispose();
  }
}

class TimeParser {
  static final Map<String, ({TimeOfDay start, TimeOfDay end})> _cache = {};

  static ({TimeOfDay start, TimeOfDay end}) parseTimeRange(String timeStr) {
    final cached = _cache[timeStr];
    if (cached != null) return cached;

    final cleaned = timeStr.trim().toLowerCase();
    ({TimeOfDay start, TimeOfDay end}) result;

    if (cleaned.contains('-') || cleaned.contains('to')) {
      final parts = cleaned.split(RegExp(r'[-–]|to'));
      final startPart = parts[0].trim();
      final endPart = parts[1].trim();

      final start = parseSingleTime(startPart);
      final end = parseSingleTime(endPart);
      result = (start: start, end: end);
    } else {
      final start = parseSingleTime(cleaned);
      int endHour = (start.hour + 1) % 24;
      final end = TimeOfDay(hour: endHour, minute: start.minute);
      result = (start: start, end: end);
    }

    _cache[timeStr] = result;
    return result;
  }

  static TimeOfDay parseSingleTime(String timeStr) {
    final cleaned = timeStr.trim().toLowerCase();

    bool isPm = cleaned.contains('pm');
    bool isAm = cleaned.contains('am');

    final numberPart = cleaned.replaceAll(RegExp(r'[ap]m'), '').trim();

    int hour = 9;
    int minute = 0;

    if (numberPart.contains(':')) {
      final parts = numberPart.split(':');
      hour = int.tryParse(parts[0]) ?? 9;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(numberPart) ?? 9;
    }

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) {
      hour = 0;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}
