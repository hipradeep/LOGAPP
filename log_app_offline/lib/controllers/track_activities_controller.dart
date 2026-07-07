import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/service_locator.dart';

class TrackActivitiesController extends ChangeNotifier {
  final ActivityService _activityService;
  final CheckInService _checkInService;

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<List<Task>>? _tasksSub;

  List<Activity> _activities = [];
  List<CheckIn> _checkIns = [];
  List<Task> _tasks = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Getters
  List<Activity> get activities => _activities;
  List<CheckIn> get checkIns => _checkIns;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  TrackActivitiesController({
    ActivityService? activityService,
    CheckInService? checkInService,
  }) : _activityService = activityService ?? getIt<ActivityService>(),
       _checkInService = checkInService ?? getIt<CheckInService>() {
    _initStreams();
  }

  void _initStreams() {
    _isLoading = true;
    notifyListeners();

    _deactivateAndSubscribe();
  }

  void _deactivateAndSubscribe() async {
    try {
      await _activityService.deactivateFinishedActivities();
    } catch (e) {
      debugPrint("Error deactivating finished activities: $e");
    }

    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    _activitiesSub?.cancel();
    _checkInsSub?.cancel();
    _tasksSub?.cancel();

    int completedStreams = 0;
    void checkLoading() {
      completedStreams++;
      if (completedStreams >= 3) {
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      }
    }

    _activitiesSub = _activityService.getActivitiesStream().listen(
      (activitiesData) {
        _activities = activitiesData;
        if (_isLoading) {
          checkLoading();
        } else {
          notifyListeners();
        }
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    _checkInsSub = _checkInService.getActiveActivitiesCheckInsStream().listen(
      (checkInsData) {
        _checkIns = checkInsData;
        if (_isLoading) {
          checkLoading();
        } else {
          notifyListeners();
        }
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );

    _tasksSub = _activityService.getTasksStream().listen(
      (tasksData) {
        _tasks = tasksData;
        if (_isLoading) {
          checkLoading();
        } else {
          notifyListeners();
        }
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> createActivity(
    String name,
    String trackingType,
    int targetCount, {
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String? description,
    bool skippable = false,
    bool reminderEnabled = true,
    int points = 10,
    double weight = 1.0,
    int focusDuration = 25,
    bool isPomodoroFocusEnabled = false,
  }) async {
    try {
      await _activityService.createActivity(
        name,
        trackingType: trackingType,
        targetCount: targetCount,
        repeatDays: repeatDays,
        scheduledTime: scheduledTime,
        startDate: startDate,
        endDate: endDate,
        subTaskTemplates: subTaskTemplates,
        description: description ?? '',
        skippable: skippable,
        reminderEnabled: reminderEnabled,
        points: points,
        weight: weight,
        focusDuration: focusDuration,
        isPomodoroFocusEnabled: isPomodoroFocusEnabled,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _checkInsSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }
}
