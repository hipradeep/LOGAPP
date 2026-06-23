import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import '../services/service_locator.dart';

class PomodoroActivitiesController extends ChangeNotifier {
  final ActivityService _activityService;
  StreamSubscription<List<Activity>>? _subscription;

  List<Activity> _activities = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  PomodoroActivitiesController({ActivityService? activityService})
      : _activityService = activityService ?? getIt<ActivityService>() {
    _initStream();
  }

  void _initStream() {
    _isLoading = true;
    notifyListeners();

    _subscription = _activityService.getActivitiesStream().listen(
      (data) {
        final today = DateTime.now();
        // weekday: Mon=1, Tue=2, ... Sun=7 — matches Activity.repeatDays convention
        final todayWeekday = today.weekday;
        final todayDate = DateTime(today.year, today.month, today.day);

        _activities = data.where((activity) {
          if (!activity.isActive) return false;

          // Only activities with Pomodoro focus enabled
          if (!activity.isPomodoroFocusEnabled) return false;

          // Only single and milestone types (not multiple/checklist)
          if (activity.trackingType == 'multiple') return false;

          // Must be scheduled for today's weekday
          if (!activity.repeatDays.contains(todayWeekday)) return false;

          // Must be within startDate window (if set)
          if (activity.startDate != null) {
            final start = DateTime(
              activity.startDate!.year,
              activity.startDate!.month,
              activity.startDate!.day,
            );
            if (todayDate.isBefore(start)) return false;
          }

          // Must be within endDate window (if set)
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

        // Sort by timestamp descending
        _activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _isLoading = false;
        _errorMessage = err.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
