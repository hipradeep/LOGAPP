import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/log_entry.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
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

  // ==================== LOGS OPERATIONS ====================

  Stream<List<LogEntry>> getLogsStream() {
    return _logsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogEntry.fromFirestore(doc)).toList();
    });
  }

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

  Future<void> deleteEntry(String id) async {
    await _logsCollection.doc(id).delete();
  }

  // ==================== ACTIVITIES OPERATIONS ====================

  Stream<List<Activity>> getActivitiesStream() {
    return _activitiesCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Activity>> getCheckedActivitiesStream() {
    return _activitiesCollection
        .where('checked', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> createActivity(
    String name,
    bool checked,
    String trackingType,
    int targetCount, {
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String description = '',
    String? category,
    String? symbolType,
    String? symbolValue,
  }) async {
    final newActivity = Activity(
      id: '',
      name: name,
      checked: checked,
      timestamp: DateTime.now(),
      trackingType: trackingType,
      targetCount: targetCount,
      repeatDays: repeatDays,
      scheduledTime: scheduledTime,
      startDate: startDate,
      endDate: endDate,
      subTaskTemplates: subTaskTemplates,
      description: description,
      category: category,
      symbolType: symbolType,
      symbolValue: symbolValue,
    );
    await _activitiesCollection.add(newActivity.toFirestore());
  }

  Future<void> toggleActivity(String id, bool checked) async {
    await _activitiesCollection.doc(id).update({
      'checked': checked,
    });
  }

  Future<void> deleteActivity(String id) async {
    await _activitiesCollection.doc(id).delete();
  }

  Future<void> updateActivitySymbols(
    String id, {
    String? symbolType,
    String? symbolValue,
    String? category,
  }) async {
    final Map<String, dynamic> updates = {};
    if (symbolType != null) updates['symbolType'] = symbolType;
    if (symbolValue != null) updates['symbolValue'] = symbolValue;
    if (category != null) updates['category'] = category;

    await _activitiesCollection.doc(id).update(updates);
  }

  // ==================== CHECK-INS OPERATIONS ====================

  Stream<List<CheckIn>> getCheckedActivitiesCheckInsStream() {
    return _checkinsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  Future<void> createCheckIn(String activityId, DateTime timestamp, bool checked) async {
    final newCheckIn = CheckIn(
      id: '',
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
    );
    await _checkinsCollection.add(newCheckIn.toFirestore());
  }

  Future<void> toggleCheckIn(String id, bool checked) async {
    await _checkinsCollection.doc(id).update({
      'checked': checked,
    });
  }

  Future<void> deleteCheckIn(String id) async {
    await _checkinsCollection.doc(id).delete();
  }

  // ==================== SUB-TASKS OPERATIONS ====================

  Stream<List<Task>> getSubTasksStream() {
    return _subtasksCollection
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Task>> getSubTasksForActivityStream(String activityId) {
    return _subtasksCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<Task>> getCurrentAndRecentMilestoneSubTasksStream(
    Activity activity,
  ) {
    if (activity.trackingType != 'milestone' || !activity.checked) {
      return Stream.value(const <Task>[]);
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 3));

    List<Task> filterAndSort(Iterable<Task> source) {
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

  Future<void> createSubTask(
    String activityId, 
    String subTaskName, 
    DateTime timestamp, 
    bool checked,
  ) async {
    final hasTime = subTaskName.contains('|');
    final cleanName = hasTime ? subTaskName.split('|').first : subTaskName;
    final timeStr = hasTime ? subTaskName.split('|').last : null;

    final newSubTask = Task(
      id: '',
      activityId: activityId,
      taskName: cleanName,
      timestamp: timestamp,
      checked: checked,
      scheduledTime: timeStr,
      subTasks: const [],
    );
    await _subtasksCollection.add(newSubTask.toFirestore());
    if (checked) {
      final checkIn = CheckIn(
        id: '',
        activityId: activityId,
        timestamp: timestamp,
        checked: true,
        subTaskName: cleanName,
      );
      await _checkinsCollection.add(checkIn.toFirestore());
    }
  }

  Future<void> updateSubTask(Task task) async {
    await _subtasksCollection.doc(task.id).set(task.toFirestore(), SetOptions(merge: true));

    if (task.checked) {
      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: task.activityId)
          .where('subTaskName', isEqualTo: task.taskName)
          .get();
      if (existingQuery.docs.isEmpty) {
        final checkIn = CheckIn(
          id: '',
          activityId: task.activityId,
          timestamp: task.timestamp,
          checked: true,
          subTaskName: task.taskName,
        );
        await _checkinsCollection.add(checkIn.toFirestore());
      }
    } else {
      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: task.activityId)
          .where('subTaskName', isEqualTo: task.taskName)
          .get();
      for (var doc in existingQuery.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> toggleSubTask(String id, bool checked) async {
    final doc = await _subtasksCollection.doc(id).get();
    if (doc.exists) {
      final subTask = Task.fromFirestore(doc);
      await _subtasksCollection.doc(id).update({
        'checked': checked,
        'completionTime': checked ? Timestamp.fromDate(DateTime.now()) : null,
      });

      if (checked) {
        final existingQuery = await _checkinsCollection
            .where('activityId', isEqualTo: subTask.activityId)
            .where('subTaskName', isEqualTo: subTask.taskName)
            .get();
        if (existingQuery.docs.isEmpty) {
          final checkIn = CheckIn(
            id: '',
            activityId: subTask.activityId,
            timestamp: subTask.timestamp,
            checked: true,
            subTaskName: subTask.taskName,
          );
          await _checkinsCollection.add(checkIn.toFirestore());
        }
      } else {
        final existingQuery = await _checkinsCollection
            .where('activityId', isEqualTo: subTask.activityId)
            .where('subTaskName', isEqualTo: subTask.taskName)
            .get();
        for (var doc in existingQuery.docs) {
          await doc.reference.delete();
        }
      }
    }
  }

  Future<void> deleteSubTask(String id) async {
    final doc = await _subtasksCollection.doc(id).get();
    if (doc.exists) {
      final subTask = Task.fromFirestore(doc);
      await _subtasksCollection.doc(id).delete();

      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: subTask.activityId)
          .where('subTaskName', isEqualTo: subTask.taskName)
          .get();
      for (var doc in existingQuery.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> updateSubTaskSymbols(
    String id, {
    String? symbolType,
    String? symbolValue,
  }) async {
    final Map<String, dynamic> updates = {};
    if (symbolType != null) updates['symbolType'] = symbolType;
    if (symbolValue != null) updates['symbolValue'] = symbolValue;

    await _subtasksCollection.doc(id).update(updates);
  }

  // ==================== BUDGET OPERATIONS ====================

  Stream<double> getSalaryStream() {
    return _budgetSettingsDoc.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        return (data['monthlySalary'] as num?)?.toDouble() ?? 3000.0;
      }
      return 3000.0;
    });
  }

  Future<void> updateSalary(double salary) async {
    await _budgetSettingsDoc.set({'monthlySalary': salary}, SetOptions(merge: true));
  }

  Stream<List<BudgetItem>> getBudgetsStream() {
    return _budgetsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BudgetItem.fromFirestore(doc)).toList();
    });
  }

  Future<void> _deactivateOtherFirestoreBudgets(String activeBudgetId) async {
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
      id: '',
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
    await _budgetsCollection.doc(budgetId).update({'checked': checked});
    if (checked) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    await _budgetsCollection.doc(budgetId).delete();
  }

  Future<void> addExpenseToBudget(String budgetId, String tag, String description, double amount, {DateTime? timestamp}) async {
    final expenseTime = timestamp ?? DateTime.now();
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
