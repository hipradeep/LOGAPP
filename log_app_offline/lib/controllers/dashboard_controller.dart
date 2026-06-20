import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/milestone_service.dart';
import '../services/service_locator.dart';

class DashboardController extends ChangeNotifier {
  final ActivityService _activityService;
  final CheckInService _checkInService;
  final MilestoneService _milestoneService;

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<List<Task>>? _tasksSub;

  List<Activity> _activeActivities = [];
  List<CheckIn> _checkIns = [];
  List<Task> _tasks = [];

  bool _isLoading = true;
  bool _activitiesLoaded = false;
  bool _checkInsLoaded = false;
  bool _tasksLoaded = false;
  String? _errorMessage;

  // Cached classified lists
  List<Activity> _pendingActivities = [];
  List<Activity> _completedActivities = [];
  List<Activity> _skippedActivities = [];
  List<CheckIn> _todayCheckIns = [];

  // Getters
  List<Activity> get activeActivities => _activeActivities;
  List<CheckIn> get checkIns => _checkIns;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Activity> get pendingActivities => _pendingActivities;
  List<Activity> get completedActivities => _completedActivities;
  List<Activity> get skippedActivities => _skippedActivities;
  List<CheckIn> get todayCheckIns => _todayCheckIns;
  List<Activity> get todayActivities => [..._pendingActivities, ..._completedActivities, ..._skippedActivities];

  DashboardController({
    ActivityService? activityService,
    CheckInService? checkInService,
    MilestoneService? milestoneService,
  }) : _activityService = activityService ?? getIt<ActivityService>(),
       _checkInService = checkInService ?? getIt<CheckInService>(),
       _milestoneService = milestoneService ?? getIt<MilestoneService>() {
    _deactivateAndInit();
  }

  void _deactivateAndInit() {
    _initStreams();
    _activityService.deactivateFinishedActivities().catchError((e) {
      debugPrint("Error deactivating finished activities in DashboardController: $e");
    });
  }

  void _handleStreamError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  void _initStreams() {
    _activitiesSub = _activityService.getActiveActivitiesStream().listen(
      (activities) {
        _activeActivities = activities;
        _activitiesLoaded = true;
        _recomputeAndNotify();
      },
      onError: _handleStreamError,
    );

    _checkInsSub = _checkInService.getCheckInsStreamForCurrentWeek().listen(
      (checkIns) {
        _checkIns = checkIns;
        _checkInsLoaded = true;
        _recomputeAndNotify();
      },
      onError: _handleStreamError,
    );

    _tasksSub = _activityService.getTasksStreamForCurrentWeek().listen(
      (tasks) {
        _tasks = tasks;
        _tasksLoaded = true;
        _recomputeAndNotify();
      },
      onError: _handleStreamError,
    );
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

    for (var activity in _activeActivities) {
      if (!activity.repeatDays.contains(today.weekday)) {
        continue;
      }

      if (activity.trackingType == 'milestone') {
        final hasTasksToday = _tasks.any((t) => t.activityId == activity.id && _isToday(t.timestamp, today));
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

      final bool isCompleted;
      if (activity.trackingType == 'milestone') {
        isCompleted = _milestoneService.isMilestoneCompletedToday(activity, _tasks);
      } else {
        final int todayCount;
        if (activity.trackingType == 'multiple') {
          final todayTask = _tasks.firstWhere(
            (s) => s.activityId == activity.id && _isToday(s.timestamp, today) && s.subTasks.isNotEmpty,
            orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: today, checked: false),
          );
          todayCount = todayTask.subTasks.where((st) => st.checked).length;
        } else {
          todayCount = _todayCheckIns.where((c) => c.activityId == activity.id).length;
        }
        isCompleted = todayCount >= activity.targetCount;
      }

      if (isCompleted) {
        completed.add(activity);
      } else {
        pending.add(activity);
      }
    }

    String? getSortingTime(Activity activity) {
      if (activity.trackingType == 'multiple') {
        final todayTask = _tasks.firstWhere(
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
    
    if (_activitiesLoaded && _checkInsLoaded && _tasksLoaded) {
      _isLoading = false;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logWater() async {
    final activities = await _activityService.getAllActivities();
    Activity? waterActivity;
    for (var activity in activities) {
      final nameLower = activity.name.toLowerCase();
      if (nameLower == 'water' ||
          nameLower == 'drink water' ||
          nameLower == 'hydration' ||
          nameLower.contains('water') ||
          nameLower.contains('hydration')) {
        waterActivity = activity;
        break;
      }
    }

    String waterActivityId;
    if (waterActivity != null) {
      waterActivityId = waterActivity.id;
      if (!waterActivity.isActive) {
        await _activityService.toggleActivity(waterActivity.id, true);
      }
    } else {
      waterActivityId = await _activityService.createActivity(
        'Water',
        trackingType: 'single',
        targetCount: 8,
        description: 'Track daily water intake',
        category: 'Health',
        symbolType: 'emoji',
        symbolValue: '💧',
      );
    }

    await _checkInService.createCheckIn(
      waterActivityId,
      DateTime.now(),
      true,
    );
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _checkInsSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }
}
