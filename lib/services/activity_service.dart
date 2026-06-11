import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../models/check_in.dart';

class ActivityService {
  final CollectionReference _activitiesCollection =
      FirebaseFirestore.instance.collection('activities');

  final CollectionReference _subtasksCollection =
      FirebaseFirestore.instance.collection('subtasks');

  final CollectionReference _checkinsCollection =
      FirebaseFirestore.instance.collection('checkins');

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
    String name, {
    required String trackingType,
    required int targetCount,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String description = '',
    String? category,
    String? symbolType,
    String? symbolValue,
    bool skippable = false,
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
      category: category,
      symbolType: symbolType,
      symbolValue: symbolValue,
      skippable: skippable,
    );
    await _activitiesCollection.add(newActivity.toFirestore());
  }

  Future<void> toggleActivity(String id, bool checked) async {
    await _activitiesCollection.doc(id).update({
      'checked': checked,
    });
  }

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
    bool? skippable,
  }) async {
    final Map<String, dynamic> updates = {
      'name': name,
      'trackingType': trackingType,
      'targetCount': targetCount,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate) : null,
      'subTaskTemplates': subTaskTemplates,
    };
    if (skippable != null) {
      updates['skippable'] = skippable;
    }
    if (description != null) {
      updates['description'] = description;
    }
    await _activitiesCollection.doc(id).update(updates);
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
}
