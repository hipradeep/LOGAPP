import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
class ActivityDetailsController extends ChangeNotifier {
  final String activityId;
  final ActivityService _activityService;
  final CheckInService _checkInService;

  StreamSubscription<Activity?>? _activitySub;
  StreamSubscription<List<CheckIn>>? _checkInsSub;
  StreamSubscription<List<Task>>? _tasksSub;

  Activity? _activity;
  List<CheckIn> _checkIns = [];
  List<Task> _tasks = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Getters
  Activity? get activity => _activity;
  List<CheckIn> get checkIns => _checkIns;
  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ActivityDetailsController({
    required this.activityId,
    ActivityService? activityService,
    CheckInService? checkInService,
  }) : _activityService = activityService ?? GetIt.instance<ActivityService>(),
       _checkInService = checkInService ?? GetIt.instance<CheckInService>() {
    _subscribeToStreams();
  }

  void _subscribeToStreams() {
    _isLoading = true;
    notifyListeners();

    _activitySub?.cancel();
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

    _activitySub = _activityService.getActivityStream(activityId).listen(
      (activityData) {
        _activity = activityData;
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

    _checkInsSub = _checkInService.getCheckInsStreamForActivity(activityId).listen(
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

    _tasksSub = _activityService.getTasksForActivityStream(activityId).listen(
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

  @override
  void dispose() {
    _activitySub?.cancel();
    _checkInsSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }
}
