import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../services/activity_service.dart';

class MilestonesController extends ChangeNotifier {
  final ActivityService _activityService = ActivityService();

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<Task>>? _subTasksSub;

  List<Activity> _milestoneActivities = [];
  List<Task> _allSubTasks = [];
  List<String> _lastActiveIds = [];

  bool _isLoadingActivities = true;
  bool _isLoadingSubTasks = true;

  String _selectedCategory = 'All';
  Activity? _selectedMilestoneActivity;
  bool _shouldSelectDefaultMilestone = true;

  // Cached classified lists
  List<Task> _todayTasks = [];
  List<Task> _futureTasks = [];
  List<Task> _completedTasks = [];

  // Getters
  List<Activity> get milestoneActivities => _milestoneActivities;
  Activity? get selectedMilestoneActivity => _selectedMilestoneActivity;
  List<Task> get allSubTasks => _allSubTasks;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoadingActivities || _isLoadingSubTasks;

  List<Task> get todayTasks => _todayTasks;
  List<Task> get futureTasks => _futureTasks;
  List<Task> get completedTasks => _completedTasks;

  MilestonesController() {
    _initStreams();
  }

  void _initStreams() {
    _activitiesSub = _activityService.getActivitiesStream().listen((activities) {
      _milestoneActivities = activities.where((a) => a.trackingType == 'milestone').toList();
      _isLoadingActivities = false;

      final activeIds = _milestoneActivities
          .where((a) => a.checked)
          .map((a) => a.id)
          .toList();

      if (!_listEquals(activeIds, _lastActiveIds)) {
        _lastActiveIds = activeIds;
        _subTasksSub?.cancel();

        if (activeIds.isEmpty) {
          _allSubTasks = [];
          _isLoadingSubTasks = false;
          _recomputeAndNotify();
        } else {
          _isLoadingSubTasks = true;
          // Notify listeners so UI updates its loading state for subtasks if active activity list changed
          notifyListeners();
          
          _subTasksSub = _activityService.getSubTasksForActivitiesStream(activeIds).listen((tasks) {
            _allSubTasks = tasks;
            _isLoadingSubTasks = false;
            _recomputeAndNotify();
          });
        }
      } else {
        _recomputeAndNotify();
      }
    });
  }

  void selectActivity(Activity? activity) {
    _selectedMilestoneActivity = activity;
    _shouldSelectDefaultMilestone = false;
    if (activity != null) {
      _selectedCategory = activity.name;
    } else {
      _selectedCategory = 'All';
    }
    _recomputeAndNotify();
  }

  void _recomputeAndNotify() {
    final activeMilestones = _milestoneActivities.where((a) => a.checked).toList();

    // 1. Update selected activity based on active milestones
    if (_shouldSelectDefaultMilestone && activeMilestones.isNotEmpty) {
      _selectedMilestoneActivity = activeMilestones.first;
    } else if (_selectedMilestoneActivity != null) {
      final stillActive = activeMilestones.any((a) => a.id == _selectedMilestoneActivity!.id);
      if (!stillActive) {
        _selectedMilestoneActivity = activeMilestones.isNotEmpty ? activeMilestones.first : null;
      }
    } else {
      _selectedMilestoneActivity = activeMilestones.isNotEmpty ? activeMilestones.first : null;
    }

    // 2. Filter tasks based on the selected category
    final List<Task> filteredSubTasks = _allSubTasks.where((st) {
      final parent = _milestoneActivities.firstWhere(
        (a) => a.id == st.activityId,
        orElse: () => Activity(
          id: '',
          name: '',
          checked: false,
          timestamp: DateTime.now(),
        ),
      );
      if (parent.id.isEmpty) return false;
      if (_selectedCategory == 'All') return true;
      return parent.name == _selectedCategory;
    }).toList();

    // 3. Classify into today, future, completed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<Task> todayList = [];
    final List<Task> futureList = [];
    final List<Task> completedList = [];

    for (var st in filteredSubTasks) {
      if (_isToday(st.timestamp, today)) {
        todayList.add(st);
      } else if (st.checked) {
        completedList.add(st);
      } else {
        futureList.add(st);
      }
    }

    // 4. Sort each section
    todayList.sort((a, b) {
      if (a.checked && !b.checked) return -1;
      if (!a.checked && b.checked) return 1;
      return a.timestamp.compareTo(b.timestamp);
    });

    futureList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    completedList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _todayTasks = todayList;
    _futureTasks = futureList;
    _completedTasks = completedList;

    notifyListeners();
  }

  bool _isToday(DateTime date, DateTime today) {
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _subTasksSub?.cancel();
    super.dispose();
  }
}
