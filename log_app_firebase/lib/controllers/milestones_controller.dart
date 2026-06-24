import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../services/activity_service.dart';

class MilestonesController extends ChangeNotifier {
  final ActivityService _activityService = ActivityService();

  StreamSubscription<List<Activity>>? _activitiesSub;
  StreamSubscription<List<Task>>? _tasksSub;

  List<Activity> _milestoneActivities = [];
  List<Task> _allTasks = [];
  List<String> _lastActiveIds = [];

  bool _isLoadingActivities = true;
  bool _isLoadingTasks = true;

  String _selectedCategory = 'All';
  Activity? _selectedMilestoneActivity;
  bool _shouldSelectDefaultMilestone = true;
  String? _errorMessage;

  // Cached classified lists
  List<Task> _todayTasks = [];
  List<Task> _futureTasks = [];
  List<Task> _completedTasks = [];

  // Getters
  List<Activity> get milestoneActivities => _milestoneActivities.where((a) => a.isActive).toList();
  List<Activity> get allMilestoneActivities => _milestoneActivities;
  Activity? get selectedMilestoneActivity => _selectedMilestoneActivity;
  List<Task> get allTasks => _allTasks;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoadingActivities || _isLoadingTasks;
  String? get errorMessage => _errorMessage;

  List<Task> get todayTasks => _todayTasks;
  List<Task> get futureTasks => _futureTasks;
  List<Task> get completedTasks => _completedTasks;

  MilestonesController() {
    _initStreams();
  }

  Future<void> refresh() async {
    _initStreams();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _initStreams() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    _tasksSub = null;
    _isLoadingActivities = true;
    _isLoadingTasks = true;

    _activitiesSub = _activityService.getActivitiesStream().listen((activities) {
      _milestoneActivities = activities.where((a) => a.trackingType == 'milestone').toList();
      _isLoadingActivities = false;
      _errorMessage = null;

      final activeIds = _milestoneActivities
          .where((a) => a.isActive)
          .map((a) => a.id)
          .toList();

      if (_tasksSub == null || !_listEquals(activeIds, _lastActiveIds)) {
        _lastActiveIds = activeIds;
        _tasksSub?.cancel();

        if (activeIds.isEmpty) {
          _allTasks = [];
          _isLoadingTasks = false;
          _recomputeAndNotify();
        } else {
          _isLoadingTasks = true;
          // Notify listeners so UI updates its loading state for subtasks if active activity list changed
          notifyListeners();
          
          _tasksSub = _activityService.getTasksForActivitiesStream(activeIds).listen((tasks) {
            _allTasks = tasks;
            _isLoadingTasks = false;
            _recomputeAndNotify();
          }, onError: (error) {
            _isLoadingTasks = false;
            _errorMessage = error.toString();
            notifyListeners();
          });
        }
      } else {
        _isLoadingTasks = false;
        _recomputeAndNotify();
      }
    }, onError: (error) {
      _isLoadingActivities = false;
      _isLoadingTasks = false;
      _errorMessage = error.toString();
      notifyListeners();
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

  void resetDefaultSelection() {
    _shouldSelectDefaultMilestone = true;
    _recomputeAndNotify();
  }


  void _recomputeAndNotify() {
    final activeMilestones = _milestoneActivities.where((a) => a.isActive).toList();

    // 1. Update selected activity based on active milestones
    if (_shouldSelectDefaultMilestone && activeMilestones.isNotEmpty) {
      _selectedMilestoneActivity = activeMilestones.first;
      // Keep category as 'All' — this is the initial default state
    } else if (_selectedMilestoneActivity != null) {
      final stillActive = activeMilestones.any((a) => a.id == _selectedMilestoneActivity!.id);
      if (!stillActive) {
        _selectedMilestoneActivity = activeMilestones.isNotEmpty ? activeMilestones.first : null;
      }
    } else {
      _selectedMilestoneActivity = activeMilestones.isNotEmpty ? activeMilestones.first : null;
    }

    // 2. Filter tasks based on the selected category
    final List<Task> filteredTasks = _allTasks.where((st) {
      final parent = _milestoneActivities.firstWhere(
        (a) => a.id == st.activityId,
        orElse: () => Activity(
          id: '',
          name: '',
          isActive: false,
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

    for (var st in filteredTasks) {
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

  Future<Task> createTask(
    Activity activity, 
    String taskName, 
    DateTime timestamp, {
    List<SubTask> subTasks = const [],
    String? symbolType,
    String? symbolValue,
    String? notes,
  }) async {
    final task = await _activityService.createTask(
      activity.id,
      taskName,
      timestamp,
      false,
      subTasks: subTasks,
      symbolType: symbolType,
      symbolValue: symbolValue,
      notes: notes,
    );
    return task;
  }

  Future<void> toggleTask(Task task, bool checked) async {
    List<SubTask> updatedSubTasks = task.subTasks;
    if (checked != task.checked) {
      updatedSubTasks = task.subTasks
          .map((subTask) => subTask.copyWith(checked: checked))
          .toList();
    }
    final updated = task.copyWith(
      checked: checked,
      completionTime: checked ? DateTime.now() : null,
      subTasks: updatedSubTasks,
    );
    await _activityService.updateTask(updated);
  }

  Future<void> toggleActivity(Activity activity, bool isActive) async {
    await _activityService.toggleActivity(activity.id, isActive);
  }

  Future<void> updateActivitySymbols(
    Activity activity, {
    String? symbolType,
    String? symbolValue,
    String? category,
  }) async {
    await _activityService.updateActivitySymbols(
      activity.id,
      symbolType: symbolType,
      symbolValue: symbolValue,
      category: category,
    );
  }

  Future<void> deleteTask(Task task) async {
    await _activityService.deleteTask(task.id);
  }

  Future<void> updateTask(Task task) async {
    await _activityService.updateTask(task);
  }

  Future<void> updateTaskSymbols(
    Task task, {
    String? symbolType,
    String? symbolValue,
  }) async {
    await _activityService.updateTaskSymbols(
      task.id,
      symbolType: symbolType,
      symbolValue: symbolValue,
    );
  }

  @override
  void dispose() {
    _activitiesSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }
}
