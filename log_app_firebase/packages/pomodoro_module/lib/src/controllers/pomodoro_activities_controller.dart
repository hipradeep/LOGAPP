import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:core_services/core_services.dart';

final _getIt = GetIt.instance;

class PomodoroActivitiesController extends ChangeNotifier {
  final ActivityService _activityService;
  StreamSubscription<List<Activity>>? _activitySubscription;
  StreamSubscription<List<Task>>? _tasksSubscription;

  List<Activity> _rawActivities = [];
  List<Task> _rawTasks = [];

  List<Activity> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PomodoroActivitiesController({ActivityService? activityService})
      : _activityService = activityService ?? _getIt<ActivityService>() {
    _initStreams();
  }

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    _activitySubscription = _activityService.getActivitiesStream().listen(
      (data) {
        _rawActivities = data;
        _combineAndNotify();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );

    _tasksSubscription = _activityService.getTasksStream().listen(
      (data) {
        _rawTasks = data;
        _combineAndNotify();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  void _combineAndNotify() {
    final today = DateTime.now();
    final todayWeekday = today.weekday;
    final todayDate = DateTime(today.year, today.month, today.day);

    final filteredActivities = _rawActivities.where((activity) {
      if (!activity.isActive) return false;
      if (!activity.isPomodoroFocusEnabled) return false;
      if (activity.trackingType == 'multiple') return false;
      if (!activity.repeatDays.contains(todayWeekday)) return false;

      if (activity.startDate != null) {
        final start = DateTime(
          activity.startDate!.year,
          activity.startDate!.month,
          activity.startDate!.day,
        );
        if (todayDate.isBefore(start)) return false;
      }

      if (activity.endDate != null) {
        final end = DateTime(
          activity.endDate!.year,
          activity.endDate!.month,
          activity.endDate!.day,
        );
        if (todayDate.isAfter(end)) return false;
      }

      return true;
    }).toList();

    filteredActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final List<Activity> sortedCombined = [];
    for (var activity in filteredActivities) {
      if (activity.trackingType == 'milestone') {
        final milestoneTasks = _rawTasks.where((t) => t.activityId == activity.id).toList();
        milestoneTasks.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (milestoneTasks.isEmpty) {
          sortedCombined.add(activity);
        } else {
          for (var task in milestoneTasks) {
            final virtualActivity = activity.copyWith(
              id: task.id,
              name: task.taskName,
              isActive: !task.checked,
              symbolValue: task.symbolValue ?? activity.symbolValue,
              category: activity.name,
            );
            sortedCombined.add(virtualActivity);
          }
        }
      } else {
        sortedCombined.add(activity);
      }
    }

    _activities = sortedCombined;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _tasksSubscription?.cancel();
    super.dispose();
  }
}
