import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';

class DashboardController extends ChangeNotifier {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<List<Task>>? _subTasksSub;

  List<Activity> _checkedActivities = [];
  List<CheckIn> _checkIns = [];
  List<Task> _subTasks = [];

  bool _isLoading = true;

  // Cached classified lists
  List<Activity> _pendingActivities = [];
  List<Activity> _completedActivities = [];
  List<Activity> _skippedActivities = [];
  List<CheckIn> _todayCheckIns = [];

  // Getters
  List<Activity> get checkedActivities => _checkedActivities;
  List<CheckIn> get checkIns => _checkIns;
  List<Task> get subTasks => _subTasks;
  bool get isLoading => _isLoading;

  List<Activity> get pendingActivities => _pendingActivities;
  List<Activity> get completedActivities => _completedActivities;
  List<Activity> get skippedActivities => _skippedActivities;
  List<CheckIn> get todayCheckIns => _todayCheckIns;

  DashboardController() {
    _initStreams();
  }

  void _initStreams() {
    _activitiesSub = _activityService.getCheckedActivitiesStream().listen((activities) {
      _checkedActivities = activities;
      _recomputeAndNotify();
    });

    _checkInsSub = _checkInService.getCheckInsStreamForCurrentWeek().listen((checkIns) {
      _checkIns = checkIns;
      _recomputeAndNotify();
    });

    _subTasksSub = _activityService.getSubTasksStreamForCurrentWeek().listen((subTasks) {
      _subTasks = subTasks;
      _recomputeAndNotify();
    });
  }

  bool _isToday(DateTime date, DateTime today) {
    return date.day == today.day && date.month == today.month && date.year == today.year;
  }

  void _recomputeAndNotify() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _todayCheckIns = _checkIns.where((c) => _isToday(c.timestamp, today) && c.checked).toList();

    final List<Activity> pending = [];
    final List<Activity> completed = [];
    final List<Activity> skipped = [];

    for (var activity in _checkedActivities) {
      if (activity.trackingType == 'milestone') {
        final hasTasksToday = _subTasks.any((t) => t.activityId == activity.id && _isToday(t.timestamp, today));
        if (!hasTasksToday) {
          continue;
        }
      }

      final bool isSkipped = _checkIns.any((c) =>
          _isToday(c.timestamp, today) &&
          c.activityId == activity.id &&
          c.skipped == true);

      if (isSkipped) {
        skipped.add(activity);
        continue;
      }

      final int todayCount;
      if (activity.trackingType == 'multiple') {
        final todayTask = _subTasks.firstWhere(
          (s) => s.activityId == activity.id && _isToday(s.timestamp, today) && s.subTasks.isNotEmpty,
          orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: today, checked: false),
        );
        todayCount = todayTask.subTasks.where((st) => st.checked).length;
      } else if (activity.trackingType == 'milestone') {
        todayCount = _subTasks.where((s) => s.activityId == activity.id && _isToday(s.timestamp, today) && s.checked).length;
      } else {
        todayCount = _todayCheckIns.where((c) => c.activityId == activity.id).length;
      }

      final bool isCompleted = todayCount >= activity.targetCount;
      if (isCompleted) {
        completed.add(activity);
      } else {
        pending.add(activity);
      }
    }

    String? getSortingTime(Activity activity) {
      if (activity.trackingType == 'multiple') {
        final todayTask = _subTasks.firstWhere(
          (s) => s.activityId == activity.id && _isToday(s.timestamp, today) && s.subTasks.isNotEmpty,
          orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: today, checked: false),
        );
        for (var template in activity.subTaskTemplates) {
          final parts = template.split('|');
          if (parts.length > 1) {
            final timeStr = parts.last;
            final isCheckedIn = todayTask.subTasks.any((st) => st.title == parts.first && st.checked);
            if (!isCheckedIn) {
              return timeStr;
            }
          }
        }
        for (var template in activity.subTaskTemplates) {
          final parts = template.split('|');
          if (parts.length > 1) {
            return parts.last;
          }
        }
      }
      return activity.scheduledTime;
    }

    int compareActivities(Activity a, Activity b) {
      final aTime = getSortingTime(a);
      final bTime = getSortingTime(b);
      if (aTime != null && bTime != null) {
        return aTime.compareTo(bTime);
      }
      if (aTime != null && bTime == null) {
        return -1;
      }
      if (aTime == null && bTime != null) {
        return 1;
      }
      return a.timestamp.compareTo(b.timestamp);
    }

    pending.sort(compareActivities);
    completed.sort(compareActivities);
    skipped.sort(compareActivities);

    _pendingActivities = pending;
    _completedActivities = completed;
    _skippedActivities = skipped;
    
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _checkInsSub?.cancel();
    _subTasksSub?.cancel();
    super.dispose();
  }
}
