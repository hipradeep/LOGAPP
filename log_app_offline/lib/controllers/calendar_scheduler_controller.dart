import 'dart:async';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/service_locator.dart';
import '../utils/date_utils.dart';
import '../utils/id_utils.dart';

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
  StreamSubscription<List<Task>>? _tasksSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;

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
  })  : _activityService = activityService ?? getIt<ActivityService>(),
        _checkInService = checkInService ?? getIt<CheckInService>(),
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
    final startOfCurrentMonth = DateTime(date.year, date.month, 1);
    if (_currentSubscribedMonth != null &&
        _currentSubscribedMonth!.year == startOfCurrentMonth.year &&
        _currentSubscribedMonth!.month == startOfCurrentMonth.month) {
      return;
    }
    _currentSubscribedMonth = startOfCurrentMonth;

    _tasksSub?.cancel();
    _checkInsSub?.cancel();

    // Start 7 days before the beginning of the month to cover trailing week
    final cutoff = startOfCurrentMonth.subtract(const Duration(days: 7));

    _tasksSub = _activityService.getTasksStreamForCurrentWeek().listen(
      (tasks) {
        // Filter to cutoff locally (stream returns current-week tasks)
        _tasks = tasks.where((t) => !t.timestamp.isBefore(cutoff)).toList();
        _tasksLoaded = true;
        _recomputeEvents();
      },
      onError: _handleStreamError,
    );

    _checkInsSub = _checkInService.getCheckInsStreamForCurrentWeek().listen(
      (checkIns) {
        _checkIns = checkIns.where((c) => !c.timestamp.isBefore(cutoff)).toList();
        _checkInsLoaded = true;
        _recomputeEvents();
      },
      onError: _handleStreamError,
    );
  }

  List<TimelineEvent> _computeEventsForDate(DateTime date) {
    final dayOfWeek = date.weekday;
    final List<TimelineEvent> computedEvents = [];

    final activeOnDay = _activities.where((activity) {
      final repeatMatch = activity.repeatDays.contains(dayOfWeek);
      final rangeMatch = AppDateUtils.isDateInRange(date, activity.startDate, activity.endDate);
      return repeatMatch && rangeMatch;
    }).toList();

    for (var activity in activeOnDay) {
      final Task? todayTaskDoc = _tasks
          .where((t) => t.activityId == activity.id && AppDateUtils.isSameDay(t.timestamp, date))
          .firstOrNull;

      if (activity.trackingType == 'single') {
        if (activity.scheduledTime != null) {
          final isCompleted = _checkIns.any((c) =>
              c.activityId == activity.id &&
              AppDateUtils.isSameDay(c.timestamp, date) &&
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
        final List<SubTask> subTasksToProcess = [];
        if (todayTaskDoc != null && todayTaskDoc.subTasks.isNotEmpty) {
          subTasksToProcess.addAll(todayTaskDoc.subTasks);
        } else {
          for (int i = 0; i < activity.subTaskTemplates.length; i++) {
            final template = activity.subTaskTemplates[i];
            final parts = template.split('|');
            subTasksToProcess.add(SubTask(
              id: 'temp-$i-${template.hashCode}',
              title: parts.first,
              checked: false,
              scheduledTime: parts.length > 1 ? parts.last : null,
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
        final milestoneTasks = _tasks.where(
            (t) => t.activityId == activity.id && AppDateUtils.isSameDay(t.timestamp, date));
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
    return dateEvents.where((e) => e.isCompleted).length / dateEvents.length;
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
    return DateTime(newYear, newMonth, date.day.clamp(1, daysInNewMonth), date.hour, date.minute, date.second);
  }

  void addMonths(int months, {bool enforceLimit = false}) {
    final targetDate = _addMonths(_selectedDate, months);
    if (enforceLimit) {
      final now = DateTime.now();
      final earliestMonth = DateTime(now.year, now.month - 3, 1);
      final latestMonth = DateTime(now.year, now.month + 1, 1);
      final targetMonthStart = DateTime(targetDate.year, targetDate.month, 1);
      if (targetMonthStart.isBefore(earliestMonth) || targetMonthStart.isAfter(latestMonth)) return;
    }
    setSelectedDate(targetDate);
  }

  Future<void> toggleEventCompletion(TimelineEvent event) async {
    try {
      if (event.trackingType == 'single') {
        if (event.isCompleted) {
          final checkInToDelete = _checkIns.firstWhere(
            (c) => c.activityId == event.activityId &&
                AppDateUtils.isSameDay(c.timestamp, _selectedDate) &&
                c.checked &&
                c.skipped != true,
          );
          await _checkInService.deleteCheckIn(checkInToDelete.id);
        } else {
          await _checkInService.createCheckIn(event.activityId, _selectedDate, true);
        }
      } else if (event.trackingType == 'multiple') {
        final activity = _activities.firstWhere((a) => a.id == event.activityId);

        Task taskDoc;
        if (event.taskId == null || event.taskId!.isEmpty) {
          // Create task locally then persist via ActivityService
          final initialSubTasks = activity.subTaskTemplates.map((template) {
            final parts = template.split('|');
            return SubTask(
              id: IdUtils.generateId(),
              title: parts.first,
              checked: false,
              scheduledTime: parts.length > 1 ? parts.last : null,
            );
          }).toList();

          final newTaskId = IdUtils.generateId();
          final newTask = Task(
            id: newTaskId,
            activityId: activity.id,
            taskName: activity.name,
            timestamp: _selectedDate,
            checked: false,
            subTasks: initialSubTasks,
          );
          await _activityService.createTask(
            activity.id,
            activity.name,
            _selectedDate,
            false,
            subTasks: initialSubTasks,
          );
          taskDoc = newTask;
        } else {
          taskDoc = _tasks.firstWhere((t) => t.id == event.taskId);
        }

        final updatedSubTasks = taskDoc.subTasks.map((st) {
          final match = (event.subTaskId != null &&
                  !event.subTaskId!.startsWith('temp') &&
                  st.id == event.subTaskId) ||
              (st.title == event.title);
          return match ? st.copyWith(checked: !event.isCompleted) : st;
        }).toList();

        final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
        final updatedTask = taskDoc.copyWith(subTasks: updatedSubTasks, checked: allChecked);
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
      result = (start: parseSingleTime(parts[0].trim()), end: parseSingleTime(parts[1].trim()));
    } else {
      final start = parseSingleTime(cleaned);
      result = (start: start, end: TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute));
    }

    _cache[timeStr] = result;
    return result;
  }

  static TimeOfDay parseSingleTime(String timeStr) {
    final cleaned = timeStr.trim().toLowerCase();
    final bool isPm = cleaned.contains('pm');
    final bool isAm = cleaned.contains('am');
    final numberPart = cleaned.replaceAll(RegExp(r'[ap]m'), '').trim();

    int hour = 9, minute = 0;
    if (numberPart.contains(':')) {
      final parts = numberPart.split(':');
      hour = int.tryParse(parts[0]) ?? 9;
      minute = int.tryParse(parts[1]) ?? 0;
    } else {
      hour = int.tryParse(numberPart) ?? 9;
    }

    if (isPm && hour < 12) {
      hour += 12;
    } else if (isAm && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }
}
