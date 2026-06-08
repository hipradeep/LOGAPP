import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/log_entry.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/sub_task.dart';
import '../models/budget_item.dart';

class FirebaseService {
  final CollectionReference _logsCollection =
      FirebaseFirestore.instance.collection('logs');

  final CollectionReference _activitiesCollection =
      FirebaseFirestore.instance.collection('activities');

  final CollectionReference _checkinsCollection =
      FirebaseFirestore.instance.collection('checkins');

  final CollectionReference _subtasksCollection =
      FirebaseFirestore.instance.collection('subtasks');

  final CollectionReference _budgetsCollection =
      FirebaseFirestore.instance.collection('budgets');

  final DocumentReference _budgetSettingsDoc =
      FirebaseFirestore.instance.collection('metadata').doc('budget_settings');

  // ==================== REACTIVE OFFLINE STREAM CONTROLLERS ====================
  static final StreamController<List<Activity>> _mockActivitiesController = StreamController<List<Activity>>.broadcast();
  static final StreamController<List<CheckIn>> _mockCheckInsController = StreamController<List<CheckIn>>.broadcast();
  static final StreamController<List<SubTask>> _mockSubTasksController = StreamController<List<SubTask>>.broadcast();
  static final StreamController<List<LogEntry>> _mockLogsController = StreamController<List<LogEntry>>.broadcast();
  static final StreamController<double> _mockSalaryController = StreamController<double>.broadcast();
  static final StreamController<List<BudgetItem>> _mockBudgetsController = StreamController<List<BudgetItem>>.broadcast();

  static void notifySalaryChanged() {
    _mockSalaryController.add(mockMonthlySalary);
  }

  static void notifyBudgetsChanged() {
    _mockBudgetsController.add(List.from(mockBudgets));
  }

  static void notifyActivitiesChanged() {
    _mockActivitiesController.add(List.from(mockActivities));
  }

  static void notifyCheckInsChanged() {
    _mockCheckInsController.add(List.from(mockCheckIns));
  }

  static void notifySubTasksChanged() {
    _mockSubTasksController.add(List.from(mockSubTasks));
  }

  static void notifyLogsChanged() {
    _mockLogsController.add(List.from(mockEntries));
  }

  // ==================== STATIC MOCK STORAGE (OFFLINE SYNC) ====================
  static double mockMonthlySalary = 3000.0;

  static final List<BudgetItem> mockBudgets = [
    BudgetItem(
      id: 'b-1',
      category: 'Food & Groceries',
      limit: 200,
      period: 'monthly',
      expenses: [
        BudgetExpense(id: 'e-1', tag: 'Grocery', description: 'Supermarket', amount: 45.0, timestamp: DateTime.now().subtract(const Duration(days: 2))),
        BudgetExpense(id: 'e-2', tag: 'Dinner', description: 'Restaurant', amount: 100.0, timestamp: DateTime.now().subtract(const Duration(days: 1))),
      ],
      checked: true,
    ),
    BudgetItem(
      id: 'b-2',
      category: 'Transport',
      limit: 80,
      period: 'weekly',
      expenses: [
        BudgetExpense(id: 'e-3', tag: 'Fuel', description: 'Gas station', amount: 40.0, timestamp: DateTime.now()),
      ],
      checked: false,
    ),
    BudgetItem(
      id: 'b-3',
      category: 'Entertainment',
      limit: 100,
      period: 'monthly',
      expenses: [
        BudgetExpense(id: 'e-4', tag: 'Other', description: 'Movie night', amount: 110.0, timestamp: DateTime.now().subtract(const Duration(days: 5))),
      ],
      checked: false,
    ),
  ];
  
  static final List<LogEntry> mockEntries = [
    LogEntry(
      id: 'mock-1',
      title: '✨ Welcome to LOG!',
      content: 'This is your premium personal space to capture thoughts, ideas, and milestones. Tap the + button below to create your first entry!',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      mood: '🚀',
      tags: ['General', 'Welcome'],
    ),
    LogEntry(
      id: 'mock-2',
      title: 'Late night walk in the park',
      content: 'The air was crisp and clear tonight. Saw some fireflies near the lake. Felt very calm and present.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      mood: '🌌',
      tags: ['Mindfulness', 'Life'],
    ),
    LogEntry(
      id: 'mock-3',
      title: 'Designing the LOG App UI',
      content: 'Working on a sleek glassmorphic theme with a neon violet primary color. Extremely pleased with how modern the layout feels.',
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      mood: '🎨',
      tags: ['Design', 'Work'],
    ),
  ];

  static final List<Activity> mockActivities = [
    Activity(id: 'act-1', name: 'Meditate 10m', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 10)), trackingType: 'single', targetCount: 1, repeatDays: [1, 2, 3, 4, 5, 6, 7], scheduledTime: '06:30', startDate: DateTime.now().subtract(const Duration(days: 30))),
    Activity(id: 'act-2', name: 'Skincare', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 9)), trackingType: 'multiple', targetCount: 1, repeatDays: [1, 2, 3, 4, 5, 6, 7], scheduledTime: '07:00', startDate: DateTime.now().subtract(const Duration(days: 14)), subTaskTemplates: ['Morning Skincare', 'Evening Skincare']),
    Activity(id: 'act-3', name: 'Study DSA', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 8)), trackingType: 'milestone', targetCount: 1, repeatDays: [1, 2, 3, 4, 5], scheduledTime: '21:00'),
    Activity(id: 'act-4', name: 'Gym Session', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 7)), trackingType: 'single', targetCount: 1, repeatDays: [1, 3, 5], scheduledTime: '07:00', startDate: DateTime.now().subtract(const Duration(days: 7)), endDate: DateTime.now().add(const Duration(days: 90))),
    Activity(id: 'act-5', name: 'Drink Water', checked: false, timestamp: DateTime.now().subtract(const Duration(minutes: 6)), trackingType: 'single', targetCount: 1, repeatDays: [1, 2, 3, 4, 5, 6, 7], scheduledTime: '10:00'),
    Activity(id: 'act-6', name: 'Sleep 8 Hours', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 5)), trackingType: 'single', targetCount: 1, repeatDays: [1, 2, 3, 4, 5, 6, 7], scheduledTime: '22:00'),
  ];

  static final List<CheckIn> mockCheckIns = [
    CheckIn(id: 'c-1', activityId: 'act-1', timestamp: DateTime.now().subtract(const Duration(days: 1)), checked: true),
    CheckIn(id: 'c-2', activityId: 'act-1', timestamp: DateTime.now().subtract(const Duration(days: 2)), checked: true),
  ];

  static final List<SubTask> mockSubTasks = [
    SubTask(id: 'sub-1', activityId: 'act-2', timestamp: DateTime.now().subtract(const Duration(hours: 2)), checked: true, subTaskName: 'Morning Skincare'),
    SubTask(id: 'sub-2', activityId: 'act-3', timestamp: DateTime.now().subtract(const Duration(hours: 4)), checked: true, subTaskName: 'Linked list'),
    SubTask(id: 'sub-3', activityId: 'act-3', timestamp: DateTime.now().subtract(const Duration(hours: 3)), checked: false, subTaskName: 'Stack'),
  ];

  // ==================== LOGS OPERATIONS ====================

  // Expose mock streams explicitly for offline reactive rendering
  Stream<List<LogEntry>> getMockLogsStream() {
    late StreamController<List<LogEntry>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<LogEntry>>(
      onListen: () {
        final sorted = List<LogEntry>.from(mockEntries);
        sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        controller.add(sorted);
        sub = _mockLogsController.stream.listen((data) {
          final s = List<LogEntry>.from(data);
          s.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(s);
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  // Stream of log entries ordered by timestamp descending
  Stream<List<LogEntry>> getLogsStream() {
    if (Firebase.apps.isEmpty) {
      return getMockLogsStream();
    }
    return _logsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogEntry.fromFirestore(doc)).toList();
    });
  }

  // Create new log entry
  Future<void> createEntry(String title, String content, String mood, List<String> tags) async {
    final newEntry = LogEntry(
      id: '',
      title: title,
      content: content,
      timestamp: DateTime.now(),
      mood: mood,
      tags: tags,
    );
    await _logsCollection.add(newEntry.toFirestore());
  }

  // Update existing log entry
  Future<void> updateEntry(String id, String title, String content, String mood, List<String> tags) async {
    await _logsCollection.doc(id).update({
      'title': title,
      'content': content,
      'mood': mood,
      'tags': tags,
    });
  }

  // Delete a log entry
  Future<void> deleteEntry(String id) async {
    await _logsCollection.doc(id).delete();
  }

  // ==================== ACTIVITIES OPERATIONS ====================

  // Expose mock streams explicitly for offline reactive rendering
  Stream<List<Activity>> getMockActivitiesStream() {
    late StreamController<List<Activity>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<Activity>>(
      onListen: () {
        controller.add(List.from(mockActivities));
        sub = _mockActivitiesController.stream.listen((data) {
          controller.add(data);
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  // Stream of all activities ordered by timestamp ascending
  Stream<List<Activity>> getActivitiesStream() {
    if (Firebase.apps.isEmpty) {
      return getMockActivitiesStream();
    }
    return _activitiesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  // Stream of checked activities only
  Stream<List<Activity>> getCheckedActivitiesStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<Activity>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<Activity>>(
        onListen: () {
          controller.add(mockActivities.where((a) => a.checked).toList());
          sub = _mockActivitiesController.stream.listen((data) {
            controller.add(data.where((a) => a.checked).toList());
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _activitiesCollection
        .where('checked', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  // Create new activity
  Future<void> createActivity(
    String name, {
    String trackingType = 'single',
    int targetCount = 1,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String? description,
  }) async {
    final newActivity = Activity(
      id: '',
      name: name,
      checked: true,
      timestamp: DateTime.now(),
      trackingType: trackingType,
      targetCount: targetCount,
      repeatDays: repeatDays,
      scheduledTime: scheduledTime,
      startDate: startDate,
      endDate: endDate,
      subTaskTemplates: subTaskTemplates,
      description: description,
    );
    await _activitiesCollection.add(newActivity.toFirestore());
  }

  // Toggle activity checkbox
  Future<void> toggleActivity(String id, bool checked) async {
    await _activitiesCollection.doc(id).update({
      'checked': checked,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update activity details
  Future<void> updateActivity(
    String id,
    String name,
    String trackingType,
    int targetCount, {
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String? description,
  }) async {
    await _activitiesCollection.doc(id).update({
      'name': name,
      'trackingType': trackingType,
      'targetCount': targetCount,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'subTaskTemplates': subTaskTemplates,
      'description': description,
    });
  }

  // Delete an activity
  Future<void> deleteActivity(String id) async {
    await _activitiesCollection.doc(id).delete();
  }

  // ==================== CHECK-INS OPERATIONS ====================

  // Stream of check-ins for a specific activity ordered by timestamp descending
  Stream<List<CheckIn>> getCheckInsStream(String activityId) {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<CheckIn>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<CheckIn>>(
        onListen: () {
          final filtered = mockCheckIns.where((c) => c.activityId == activityId).toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(filtered);
          sub = _mockCheckInsController.stream.listen((data) {
            final f = data.where((c) => c.activityId == activityId).toList();
            f.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(f);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // Expose mock streams explicitly for offline reactive rendering
  Stream<List<CheckIn>> getMockCheckInsStream() {
    late StreamController<List<CheckIn>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<CheckIn>>(
      onListen: () {
        final sorted = List<CheckIn>.from(mockCheckIns);
        sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        controller.add(sorted);
        sub = _mockCheckInsController.stream.listen((data) {
          final s = List<CheckIn>.from(data);
          s.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(s);
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  // Stream of checked (selected) activities only
  Stream<List<CheckIn>> getCheckedActivitiesCheckInsStream() {
    if (Firebase.apps.isEmpty) {
      return getMockCheckInsStream();
    }
    return _checkinsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  // Create new check-in
  Future<void> createCheckIn(String activityId, DateTime timestamp, bool checked) async {
    final newCheckIn = CheckIn(
      id: '',
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
    );
    await _checkinsCollection.add(newCheckIn.toFirestore());
  }

  // Toggle check-in status
  Future<void> toggleCheckIn(String id, bool checked) async {
    await _checkinsCollection.doc(id).update({
      'checked': checked,
    });
  }

  // Delete a check-in
  Future<void> deleteCheckIn(String id) async {
    await _checkinsCollection.doc(id).delete();
  }

  // ==================== SUB-TASKS OPERATIONS ====================

  // Stream of all sub-tasks
  Stream<List<SubTask>> getSubTasksStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<SubTask>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<SubTask>>(
        onListen: () {
          controller.add(List.from(mockSubTasks));
          sub = _mockSubTasksController.stream.listen((data) {
            controller.add(data);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _subtasksCollection
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SubTask.fromFirestore(doc)).toList();
    });
  }

  // Stream of sub-tasks for a specific activity ordered by timestamp descending
  Stream<List<SubTask>> getSubTasksForActivityStream(String activityId) {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<SubTask>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<SubTask>>(
        onListen: () {
          final filtered = mockSubTasks.where((s) => s.activityId == activityId).toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(filtered);
          sub = _mockSubTasksController.stream.listen((data) {
            final f = data.where((s) => s.activityId == activityId).toList();
            f.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(f);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _subtasksCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => SubTask.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // Stream the current milestone sub-task plus sub-tasks added in the last 3 days.
  // "Current" is the newest sub-task document; unfinished older work stays visible too.
  Stream<List<SubTask>> getCurrentAndRecentMilestoneSubTasksStream(
    Activity activity,
  ) {
    if (activity.trackingType != 'milestone' || !activity.checked) {
      return Stream.value(const <SubTask>[]);
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 3));

    List<SubTask> filterAndSort(Iterable<SubTask> source) {
      final sorted = source
          .where((s) => s.activityId == activity.id)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final currentSubTaskId = sorted.isNotEmpty ? sorted.first.id : null;
      final list = sorted
          .where((s) =>
              s.id == currentSubTaskId ||
              !s.checked ||
              !s.timestamp.isBefore(cutoff))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }

    return getSubTasksForActivityStream(activity.id).map(filterAndSort);
  }

  // Create new sub-task check-in
  // Create new sub-task check-in
  Future<void> createSubTask(String activityId, String subTaskName, DateTime timestamp, bool checked) async {
    final newSubTask = SubTask(
      id: Firebase.apps.isEmpty ? 'sub-${DateTime.now().millisecondsSinceEpoch}' : '',
      activityId: activityId,
      subTaskName: subTaskName,
      timestamp: timestamp,
      checked: checked,
    );
    if (Firebase.apps.isEmpty) {
      mockSubTasks.add(newSubTask);
      notifySubTasksChanged();
      if (checked) {
        final exists = mockCheckIns.any((c) => c.activityId == activityId && c.subTaskName == subTaskName);
        if (!exists) {
          mockCheckIns.add(CheckIn(
            id: 'c-sub-${DateTime.now().millisecondsSinceEpoch}',
            activityId: activityId,
            timestamp: timestamp,
            checked: true,
            subTaskName: subTaskName,
          ));
          notifyCheckInsChanged();
        }
      }
      return;
    }
    await _subtasksCollection.add(newSubTask.toFirestore());
    if (checked) {
      final checkIn = CheckIn(
        id: '',
        activityId: activityId,
        timestamp: timestamp,
        checked: true,
        subTaskName: subTaskName,
      );
      await _checkinsCollection.add(checkIn.toFirestore());
    }
  }

  // Toggle sub-task check-in status
  Future<void> toggleSubTask(String id, bool checked) async {
    if (Firebase.apps.isEmpty) {
      final idx = mockSubTasks.indexWhere((s) => s.id == id);
      if (idx != -1) {
        final subTask = mockSubTasks[idx];
        mockSubTasks[idx] = mockSubTasks[idx].copyWith(checked: checked);
        notifySubTasksChanged();

        if (checked) {
          final exists = mockCheckIns.any((c) =>
              c.activityId == subTask.activityId &&
              c.subTaskName == subTask.subTaskName);
          if (!exists) {
            mockCheckIns.add(CheckIn(
              id: 'c-sub-${DateTime.now().millisecondsSinceEpoch}',
              activityId: subTask.activityId,
              timestamp: subTask.timestamp,
              checked: true,
              subTaskName: subTask.subTaskName,
            ));
            notifyCheckInsChanged();
          }
        } else {
          mockCheckIns.removeWhere((c) =>
              c.activityId == subTask.activityId &&
              c.subTaskName == subTask.subTaskName);
          notifyCheckInsChanged();
        }
      }
      return;
    }

    final doc = await _subtasksCollection.doc(id).get();
    if (doc.exists) {
      final subTask = SubTask.fromFirestore(doc);
      await _subtasksCollection.doc(id).update({
        'checked': checked,
      });

      if (checked) {
        final existingQuery = await _checkinsCollection
            .where('activityId', isEqualTo: subTask.activityId)
            .where('subTaskName', isEqualTo: subTask.subTaskName)
            .get();
        if (existingQuery.docs.isEmpty) {
          final checkIn = CheckIn(
            id: '',
            activityId: subTask.activityId,
            timestamp: subTask.timestamp,
            checked: true,
            subTaskName: subTask.subTaskName,
          );
          await _checkinsCollection.add(checkIn.toFirestore());
        }
      } else {
        final existingQuery = await _checkinsCollection
            .where('activityId', isEqualTo: subTask.activityId)
            .where('subTaskName', isEqualTo: subTask.subTaskName)
            .get();
        for (var doc in existingQuery.docs) {
          await doc.reference.delete();
        }
      }
    }
  }

  // Delete a sub-task check-in
  Future<void> deleteSubTask(String id) async {
    if (Firebase.apps.isEmpty) {
      final idx = mockSubTasks.indexWhere((s) => s.id == id);
      if (idx != -1) {
        final subTask = mockSubTasks[idx];
        mockSubTasks.removeAt(idx);
        notifySubTasksChanged();

        mockCheckIns.removeWhere((c) =>
            c.activityId == subTask.activityId &&
            c.subTaskName == subTask.subTaskName);
        notifyCheckInsChanged();
      }
      return;
    }

    final doc = await _subtasksCollection.doc(id).get();
    if (doc.exists) {
      final subTask = SubTask.fromFirestore(doc);
      await _subtasksCollection.doc(id).delete();

      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: subTask.activityId)
          .where('subTaskName', isEqualTo: subTask.subTaskName)
          .get();
      for (var doc in existingQuery.docs) {
        await doc.reference.delete();
      }
    }
  }

  // ==================== BUDGET OPERATIONS ====================

  Stream<double> getMockSalaryStream() {
    late StreamController<double> controller;
    StreamSubscription? sub;
    controller = StreamController<double>(
      onListen: () {
        controller.add(mockMonthlySalary);
        sub = _mockSalaryController.stream.listen((data) {
          controller.add(data);
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<double> getSalaryStream() {
    if (Firebase.apps.isEmpty) {
      return getMockSalaryStream();
    }
    return _budgetSettingsDoc.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        return (data['monthlySalary'] as num?)?.toDouble() ?? 3000.0;
      }
      return 3000.0;
    });
  }

  Future<void> updateSalary(double salary) async {
    if (Firebase.apps.isEmpty) {
      mockMonthlySalary = salary;
      notifySalaryChanged();
      return;
    }
    await _budgetSettingsDoc.set({'monthlySalary': salary}, SetOptions(merge: true));
  }

  Stream<List<BudgetItem>> getMockBudgetsStream() {
    late StreamController<List<BudgetItem>> controller;
    StreamSubscription? sub;
    controller = StreamController<List<BudgetItem>>(
      onListen: () {
        controller.add(List.from(mockBudgets));
        sub = _mockBudgetsController.stream.listen((data) {
          controller.add(data);
        });
      },
      onCancel: () {
        sub?.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  Stream<List<BudgetItem>> getBudgetsStream() {
    if (Firebase.apps.isEmpty) {
      return getMockBudgetsStream();
    }
    return _budgetsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BudgetItem.fromFirestore(doc)).toList();
    });
  }  Future<void> _deactivateOtherFirestoreBudgets(String activeBudgetId) async {
    final query = await _budgetsCollection.where('checked', isEqualTo: true).get();
    for (var doc in query.docs) {
      if (doc.id != activeBudgetId) {
        await doc.reference.update({'checked': false});
      }
    }
  }

  Future<void> createBudget(
    String category,
    double limit,
    String period, {
    String description = '',
    DateTime? startDate,
    DateTime? endDate,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    bool repeat = true,
    bool checked = true,
  }) async {
    final newItem = BudgetItem(
      id: Firebase.apps.isEmpty ? 'b-${DateTime.now().millisecondsSinceEpoch}' : '',
      category: category,
      limit: limit,
      period: period,
      expenses: const [],
      description: description,
      startDate: startDate,
      endDate: endDate,
      repeatDays: repeatDays,
      scheduledTime: scheduledTime,
      repeat: repeat,
      checked: checked,
    );
    if (Firebase.apps.isEmpty) {
      if (checked) {
        for (int i = 0; i < mockBudgets.length; i++) {
          mockBudgets[i] = mockBudgets[i].copyWith(checked: false);
        }
      }
      mockBudgets.add(newItem);
      notifyBudgetsChanged();
      return;
    }
    final docRef = await _budgetsCollection.add(newItem.toFirestore());
    if (checked) {
      await _deactivateOtherFirestoreBudgets(docRef.id);
    }
  }

  Future<void> updateBudget(
    String budgetId, {
    double? limit,
    String? period,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? repeatDays,
    String? scheduledTime,
    bool? repeat,
    bool? checked,
  }) async {
    if (Firebase.apps.isEmpty) {
      final idx = mockBudgets.indexWhere((b) => b.id == budgetId);
      if (idx != -1) {
        mockBudgets[idx] = mockBudgets[idx].copyWith(
          limit: limit,
          period: period,
          description: description,
          startDate: startDate,
          endDate: endDate,
          repeatDays: repeatDays,
          scheduledTime: scheduledTime,
          repeat: repeat,
          checked: checked,
        );
        if (checked == true) {
          for (int i = 0; i < mockBudgets.length; i++) {
            if (mockBudgets[i].id != budgetId) {
              mockBudgets[i] = mockBudgets[i].copyWith(checked: false);
            }
          }
        }
        notifyBudgetsChanged();
      }
      return;
    }
    final Map<String, dynamic> updates = {};
    if (limit != null) updates['limit'] = limit;
    if (period != null) updates['period'] = period;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
    if (repeatDays != null) updates['repeatDays'] = repeatDays;
    if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
    if (repeat != null) updates['repeat'] = repeat;
    if (checked != null) updates['checked'] = checked;
    await _budgetsCollection.doc(budgetId).update(updates);
    if (checked == true) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> toggleBudget(String budgetId, bool checked) async {
    if (Firebase.apps.isEmpty) {
      final idx = mockBudgets.indexWhere((b) => b.id == budgetId);
      if (idx != -1) {
        mockBudgets[idx] = mockBudgets[idx].copyWith(checked: checked);
        if (checked) {
          for (int i = 0; i < mockBudgets.length; i++) {
            if (mockBudgets[i].id != budgetId) {
              mockBudgets[i] = mockBudgets[i].copyWith(checked: false);
            }
          }
        }
        notifyBudgetsChanged();
      }
      return;
    }
    await _budgetsCollection.doc(budgetId).update({'checked': checked});
    if (checked) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    if (Firebase.apps.isEmpty) {
      mockBudgets.removeWhere((b) => b.id == budgetId);
      notifyBudgetsChanged();
      return;
    }
    await _budgetsCollection.doc(budgetId).delete();
  }

  Future<void> addExpenseToBudget(String budgetId, String tag, String description, double amount, {DateTime? timestamp}) async {
    final expenseTime = timestamp ?? DateTime.now();
    if (Firebase.apps.isEmpty) {
      final idx = mockBudgets.indexWhere((b) => b.id == budgetId);
      if (idx != -1) {
        final list = List<BudgetExpense>.from(mockBudgets[idx].expenses);
        list.add(BudgetExpense(
          id: 'e-${DateTime.now().millisecondsSinceEpoch}',
          tag: tag,
          description: description,
          amount: amount,
          timestamp: expenseTime,
        ));
        mockBudgets[idx] = mockBudgets[idx].copyWith(expenses: list);
        notifyBudgetsChanged();
      }
      return;
    }
    final doc = await _budgetsCollection.doc(budgetId).get();
    if (doc.exists) {
      final budget = BudgetItem.fromFirestore(doc);
      final list = List<BudgetExpense>.from(budget.expenses);
      list.add(BudgetExpense(
        id: 'e-${DateTime.now().millisecondsSinceEpoch}',
        tag: tag,
        description: description,
        amount: amount,
        timestamp: expenseTime,
      ));
      await _budgetsCollection.doc(budgetId).update({
        'expenses': list.map((e) => e.toMap()).toList(),
      });
    }
  }

  Future<void> deleteExpenseFromBudget(String budgetId, String expenseId) async {
    if (Firebase.apps.isEmpty) {
      final idx = mockBudgets.indexWhere((b) => b.id == budgetId);
      if (idx != -1) {
        final list = List<BudgetExpense>.from(mockBudgets[idx].expenses);
        list.removeWhere((e) => e.id == expenseId);
        mockBudgets[idx] = mockBudgets[idx].copyWith(expenses: list);
        notifyBudgetsChanged();
      }
      return;
    }
    final doc = await _budgetsCollection.doc(budgetId).get();
    if (doc.exists) {
      final budget = BudgetItem.fromFirestore(doc);
      final list = List<BudgetExpense>.from(budget.expenses);
      list.removeWhere((e) => e.id == expenseId);
      await _budgetsCollection.doc(budgetId).update({
        'expenses': list.map((e) => e.toMap()).toList(),
      });
    }
  }
}
