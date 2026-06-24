import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../models/check_in.dart';

class ActivityService {
  final CollectionReference _activitiesCollection =
      FirebaseFirestore.instance.collection('activities');

  final CollectionReference _tasksCollection =
      FirebaseFirestore.instance.collection('tasks');

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

  Future<List<Activity>> getAllActivities() async {
    final snapshot = await _activitiesCollection.get();
    return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
  }

  Stream<Activity?> getActivityStream(String id) {
    return _activitiesCollection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Activity.fromFirestore(doc);
    });
  }

  Stream<List<Activity>> getActiveActivitiesStream() {
    return _activitiesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Future<void> deactivateFinishedActivities() async {
    try {
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);

      final snapshot = await _activitiesCollection
          .where('isActive', isEqualTo: true)
          .get();

      final writeBatch = FirebaseFirestore.instance.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        final activity = Activity.fromFirestore(doc);
        if (activity.endDate != null) {
          final endMidnight = DateTime(
            activity.endDate!.year,
            activity.endDate!.month,
            activity.endDate!.day,
          );
          if (todayMidnight.isAfter(endMidnight)) {
            writeBatch.update(doc.reference, {'isActive': false});
            count++;
          }
        }
      }

      if (count > 0) {
        await writeBatch.commit();
        debugPrint("Background task: Deactivated $count finished activities.");
      }
    } catch (e) {
      debugPrint("Error in deactivateFinishedActivities: $e");
    }
  }

  Future<String> createActivity(
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
    bool reminderEnabled = true,
    double weight = 1.0,
    int points = 10,
    int focusDuration = 25,
    bool isPomodoroFocusEnabled = false,
  }) async {
    final newActivity = Activity(
      id: '',
      name: name,
      isActive: true,
      timestamp: DateTime.now(),
      trackingType: trackingType,
      targetCount: targetCount,
      reminderEnabled: reminderEnabled,
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
      weight: weight,
      points: points,
      focusDuration: focusDuration,
      isPomodoroFocusEnabled: isPomodoroFocusEnabled,
    );
    final docRef = await _activitiesCollection.add(newActivity.toFirestore());

    if (trackingType == 'multiple' && subTaskTemplates.isNotEmpty) {
      final List<SubTask> initialSubTasks = subTaskTemplates.map((template) {
        final parts = template.split('|');
        final title = parts.first;
        final timeStr = parts.length > 1 ? parts.last : null;
        return SubTask(
          id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}-${subTaskTemplates.indexOf(template)}',
          title: title,
          checked: false,
          scheduledTime: timeStr,
        );
      }).toList();

      final newTask = Task(
        id: '',
        activityId: docRef.id,
        taskName: name,
        timestamp: DateTime.now(),
        checked: false,
        scheduledTime: null,
        subTasks: initialSubTasks,
      );
      await _tasksCollection.add(newTask.toFirestore());
    }

    return docRef.id;
  }

  Future<void> toggleActivity(String id, bool isActive) async {
    await _activitiesCollection.doc(id).update({
      'isActive': isActive,
    });
  }

  Future<void> toggleReminderEnabled(String id, bool enabled) async {
    await _activitiesCollection.doc(id).update({
      'reminderEnabled': enabled,
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
    bool? reminderEnabled,
    double? weight,
    int? points,
    int? focusDuration,
    bool? isPomodoroFocusEnabled,
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
    if (reminderEnabled != null) {
      updates['reminderEnabled'] = reminderEnabled;
    }
    if (description != null) {
      updates['description'] = description;
    }
    if (weight != null) {
      updates['weight'] = weight;
    }
    if (points != null) {
      updates['points'] = points;
    }
    if (focusDuration != null) {
      updates['focusDuration'] = focusDuration;
    }
    if (isPomodoroFocusEnabled != null) {
      updates['isPomodoroFocusEnabled'] = isPomodoroFocusEnabled;
    }
    await _activitiesCollection.doc(id).update(updates);

    if (trackingType == 'multiple' && subTaskTemplates.isNotEmpty) {
      final todayQuery = await _tasksCollection
          .where('activityId', isEqualTo: id)
          .get();
      
      final now = DateTime.now();
      bool isToday(DateTime date) =>
          date.day == now.day && date.month == now.month && date.year == now.year;
      
      DocumentSnapshot? todayDoc;
      for (var doc in todayQuery.docs) {
        final task = Task.fromFirestore(doc);
        if (isToday(task.timestamp) && task.subTasks.isNotEmpty) {
          todayDoc = doc;
          break;
        }
      }

      if (todayDoc == null) {
        final List<SubTask> initialSubTasks = subTaskTemplates.map((template) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          return SubTask(
            id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}-${subTaskTemplates.indexOf(template)}',
            title: title,
            checked: false,
            scheduledTime: timeStr,
          );
        }).toList();

        final newTask = Task(
          id: '',
          activityId: id,
          taskName: name,
          timestamp: DateTime.now(),
          checked: false,
          scheduledTime: null,
          subTasks: initialSubTasks,
        );
        await _tasksCollection.add(newTask.toFirestore());
      } else {
        final existingTask = Task.fromFirestore(todayDoc);
        final List<SubTask> updatedSubTasks = [];
        
        for (var template in subTaskTemplates) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          
          final existing = existingTask.subTasks.firstWhere(
            (st) => st.title == title,
            orElse: () => SubTask(id: '', title: '', checked: false),
          );
          
          if (existing.id.isNotEmpty) {
            updatedSubTasks.add(existing.copyWith(scheduledTime: timeStr));
          } else {
            updatedSubTasks.add(SubTask(
              id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}-${subTaskTemplates.indexOf(template)}',
              title: title,
              checked: false,
              scheduledTime: timeStr,
            ));
          }
        }
        
        final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
        final updatedTask = existingTask.copyWith(
          taskName: name,
          subTasks: updatedSubTasks,
          checked: allChecked,
        );
        await _tasksCollection.doc(todayDoc.id).set(updatedTask.toFirestore(), SetOptions(merge: true));
      }
    }
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

  // ==================== TASKS OPERATIONS ====================

  Stream<List<Task>> getTasksStreamForCurrentWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final cutoff = monday.subtract(const Duration(days: 1));

    return _tasksCollection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Task>> getTasksStream() {
    return _tasksCollection
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Task>> getTasksForActivityStream(String activityId) {
    return _tasksCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<Task>> getTasksForActivitiesStream(List<String> activityIds) {
    if (activityIds.isEmpty) {
      return Stream.value(const <Task>[]);
    }
    // Unique list to avoid duplicate query entries
    final uniqueIds = activityIds.toSet().toList();
    return _tasksCollection
        .where('activityId', whereIn: uniqueIds)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Task>> getCurrentAndRecentMilestoneTasksStream(
    Activity activity,
  ) {
    if (activity.trackingType != 'milestone' || !activity.isActive) {
      return Stream.value(const <Task>[]);
    }

    final cutoff = DateTime.now().subtract(const Duration(days: 3));

    List<Task> filterAndSort(Iterable<Task> source) {
      final sorted = source
          .where((s) => s.activityId == activity.id)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final currentTaskId = sorted.isNotEmpty ? sorted.first.id : null;
      final list = sorted
          .where((s) =>
              s.id == currentTaskId ||
              !s.checked ||
              !s.timestamp.isBefore(cutoff))
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    }

    return getTasksForActivityStream(activity.id).map(filterAndSort);
  }

  Future<Task> createTask(
    String activityId, 
    String taskName, 
    DateTime timestamp, 
    bool checked, {
    List<SubTask> subTasks = const [],
    String? symbolType,
    String? symbolValue,
    String? notes,
  }) async {
    final hasTime = taskName.contains('|');
    final cleanName = hasTime ? taskName.split('|').first : taskName;
    final timeStr = hasTime ? taskName.split('|').last : null;

    final newTask = Task(
      id: '',
      activityId: activityId,
      taskName: cleanName,
      timestamp: timestamp,
      checked: checked,
      scheduledTime: timeStr,
      subTasks: subTasks,
      symbolType: symbolType,
      symbolValue: symbolValue,
      notes: notes,
    );
    final docRef = await _tasksCollection.add(newTask.toFirestore());
    final savedTask = newTask.copyWith(id: docRef.id);
    
    // Auto-reactivate parent activity when adding a task to it
    await _activitiesCollection.doc(activityId).update({'isActive': true});
    if (checked) {
      final checkIn = CheckIn(
        id: '',
        activityId: activityId,
        timestamp: DateTime.now(),
        checked: true,
        subTaskName: cleanName,
      );
      await _checkinsCollection.add(checkIn.toFirestore());
      unawaited(_awardXPAndCoins(activityId));
    }
    return savedTask;
  }

  Future<Task?> getTaskById(String taskId) async {
    final doc = await _tasksCollection.doc(taskId).get();
    if (!doc.exists) return null;
    return Task.fromFirestore(doc);
  }

  Future<Task?> getActiveTaskForActivity(String activityId) async {
    final snapshot = await _tasksCollection
        .where('activityId', isEqualTo: activityId)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    // Sort descending by timestamp
    tasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // Find first unchecked task
    final unchecked = tasks.where((t) => !t.checked);
    if (unchecked.isNotEmpty) {
      return unchecked.first;
    }
    return tasks.first;
  }

  Future<Task?> getOrCreateTodayTaskForRoutine(Activity activity) async {
    final snapshot = await _tasksCollection
        .where('activityId', isEqualTo: activity.id)
        .get();
    
    final now = DateTime.now();
    bool isToday(DateTime date) =>
        date.day == now.day && date.month == now.month && date.year == now.year;
    
    for (var doc in snapshot.docs) {
      final task = Task.fromFirestore(doc);
      if (isToday(task.timestamp)) {
        return task;
      }
    }
    
    if (activity.subTaskTemplates.isNotEmpty) {
      final List<SubTask> initialSubTasks = activity.subTaskTemplates.map((template) {
        final parts = template.split('|');
        final title = parts.first;
        final timeStr = parts.length > 1 ? parts.last : null;
        return SubTask(
          id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}-${activity.subTaskTemplates.indexOf(template)}',
          title: title,
          checked: false,
          scheduledTime: timeStr,
        );
      }).toList();

      return await createTask(
        activity.id,
        activity.name,
        now,
        false,
        subTasks: initialSubTasks,
      );
    }
    
    return null;
  }


  Future<void> updateTask(Task task) async {
    await _tasksCollection.doc(task.id).set(task.toFirestore(), SetOptions(merge: true));

    if (task.checked) {
      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: task.activityId)
          .where('subTaskName', isEqualTo: task.taskName)
          .get();
      if (existingQuery.docs.isEmpty) {
        final checkIn = CheckIn(
          id: '',
          activityId: task.activityId,
          timestamp: DateTime.now(),
          checked: true,
          subTaskName: task.taskName,
        );
        await _checkinsCollection.add(checkIn.toFirestore());
        unawaited(_awardXPAndCoins(task.activityId));
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

  Future<void> toggleTask(String id, bool checked) async {
    final doc = await _tasksCollection.doc(id).get();
    if (doc.exists) {
      final task = Task.fromFirestore(doc);
      await _tasksCollection.doc(id).update({
        'checked': checked,
        'completionTime': checked ? Timestamp.fromDate(DateTime.now()) : null,
      });

      if (checked) {
        final existingQuery = await _checkinsCollection
            .where('activityId', isEqualTo: task.activityId)
            .where('subTaskName', isEqualTo: task.taskName)
            .get();
        if (existingQuery.docs.isEmpty) {
          final checkIn = CheckIn(
            id: '',
            activityId: task.activityId,
            timestamp: DateTime.now(),
            checked: true,
            subTaskName: task.taskName,
          );
          await _checkinsCollection.add(checkIn.toFirestore());
          unawaited(_awardXPAndCoins(task.activityId));
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
  }

  Future<void> deleteTask(String id) async {
    final doc = await _tasksCollection.doc(id).get();
    if (doc.exists) {
      final task = Task.fromFirestore(doc);
      await _tasksCollection.doc(id).delete();

      final existingQuery = await _checkinsCollection
          .where('activityId', isEqualTo: task.activityId)
          .where('subTaskName', isEqualTo: task.taskName)
          .get();
      for (var doc in existingQuery.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> _awardXPAndCoins(String activityId, {double scale = 1.0}) async {
    try {
      final doc = await _activitiesCollection.doc(activityId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final weight = (data['weight'] as num?)?.toDouble() ?? 1.0;
        final basePoints = (data['points'] as num?)?.toInt() ?? 10;

        final coins = weight * 5.0 * scale;
        final xp = (basePoints * scale).toInt();

        final profileDoc = FirebaseFirestore.instance.collection('profile').doc('default_user');
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(profileDoc);
          if (!snapshot.exists) {
            transaction.set(profileDoc, {
              'coins': coins,
              'xp': xp,
              'level': 1,
            });
          } else {
            final pData = snapshot.data() ?? {};
            final currentCoins = pData['coins'] as num? ?? 0.0;
            final currentXp = pData['xp'] as num? ?? 0;

            final newCoins = currentCoins + coins;
            final newXp = (currentXp + xp).toInt();
            final newLevel = (newXp / 100).floor() + 1;

            transaction.update(profileDoc, {
              'coins': newCoins,
              'xp': newXp,
              'level': newLevel,
            });
          }
        });
        debugPrint("Awarded $coins coins and $xp XP (scale: $scale) to profile.");
      }
    } catch (e) {
      debugPrint("Error awarding XP and coins: $e");
    }
  }

  Future<void> updateTaskSymbols(
    String id, {
    String? symbolType,
    String? symbolValue,
  }) async {
    final Map<String, dynamic> updates = {};
    if (symbolType != null) updates['symbolType'] = symbolType;
    if (symbolValue != null) updates['symbolValue'] = symbolValue;

    await _tasksCollection.doc(id).update(updates);
  }
}
