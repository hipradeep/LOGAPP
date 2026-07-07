import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/activity.dart';
import '../models/task.dart';
import '../models/check_in.dart';
import '../services/database_service.dart';
import '../utils/id_utils.dart';
import '../utils/date_utils.dart';

class ActivityService {
  Future<DatabaseService> get _db async => DatabaseService.instance;

  // ─── Stream helper (periodic polling) ────────────────────────────────────

  Stream<T> _pollStream<T>(Future<T> Function() query, {Duration interval = const Duration(seconds: 3)}) {
    final controller = StreamController<T>.broadcast();
    Timer? timer;

    Future<void> emit() async {
      try {
        if (!controller.isClosed) controller.add(await query());
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () async {
      await emit();
      timer = Timer.periodic(interval, (_) => emit());
    };
    controller.onCancel = () => timer?.cancel();

    return controller.stream;
  }

  // ─── Activities — streams ─────────────────────────────────────────────────

  Stream<List<Activity>> getActivitiesStream() =>
      _pollStream(() => getAllActivities());

  Stream<Activity?> getActivityStream(String id) =>
      _pollStream(() => _getActivity(id));

  Stream<List<Activity>> getActiveActivitiesStream() =>
      _pollStream(() => _getActiveActivities());

  // ─── Activities — queries ─────────────────────────────────────────────────

  Future<List<Activity>> getAllActivities() async {
    final db = await (await _db).database;
    final rows = await db.query('activities', orderBy: 'createdAt DESC');
    return rows.map((r) => Activity.fromMap(r['id'] as String, r)).toList();
  }

  Future<Activity?> _getActivity(String id) async {
    final db = await (await _db).database;
    final rows = await db.query('activities', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Activity.fromMap(rows.first['id'] as String, rows.first);
  }

  Future<List<Activity>> _getActiveActivities() async {
    final db = await (await _db).database;
    final rows = await db.query('activities', where: 'isActive = 1', orderBy: 'createdAt DESC');
    return rows.map((r) => Activity.fromMap(r['id'] as String, r)).toList();
  }

  // ─── Activities — writes ──────────────────────────────────────────────────

  Future<void> deactivateFinishedActivities() async {
    try {
      final db = await (await _db).database;
      final today = AppDateUtils.startOfDay(DateTime.now());
      final rows = await db.query('activities', where: 'isActive = 1');

      final batch = db.batch();
      int count = 0;
      for (final row in rows) {
        final activity = Activity.fromMap(row['id'] as String, row);
        if (activity.endDate != null) {
          final endMidnight = AppDateUtils.startOfDay(activity.endDate!);
          if (today.isAfter(endMidnight)) {
            batch.update('activities', {'isActive': 0}, where: 'id = ?', whereArgs: [activity.id]);
            count++;
          }
        }
      }
      if (count > 0) {
        await batch.commit(noResult: true);
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
    int points = 10,
    double weight = 1.0,
    int focusDuration = 25,
    bool isPomodoroFocusEnabled = false,
  }) async {
    final db = await (await _db).database;
    final id = IdUtils.generateId();
    final now = DateTime.now();

    final newActivity = Activity(
      id: id,
      name: name,
      isActive: true,
      timestamp: now,
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
      points: points,
      weight: weight,
      focusDuration: focusDuration,
      isPomodoroFocusEnabled: isPomodoroFocusEnabled,
    );

    final map = newActivity.toMap();
    map['createdAt'] = now.millisecondsSinceEpoch;
    await db.insert('activities', map);

    // Seed today's task for multi-subtask activities
    if (trackingType == 'multiple' && subTaskTemplates.isNotEmpty) {
      await _seedTodayTask(db, id, name, subTaskTemplates, now);
    }

    return id;
  }

  Future<void> toggleActivity(String id, bool isActive) async {
    final db = await (await _db).database;
    await db.update('activities', {'isActive': isActive ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleReminderEnabled(String id, bool enabled) async {
    final db = await (await _db).database;
    await db.update('activities', {'reminderEnabled': enabled ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
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
    int? points,
    double? weight,
    int? focusDuration,
    bool? isPomodoroFocusEnabled,
  }) async {
    final db = await (await _db).database;
    final updates = <String, dynamic>{
      'name': name,
      'trackingType': trackingType,
      'targetCount': targetCount,
      'repeatDays': _encodeIntList(repeatDays),
      'scheduledTime': scheduledTime,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'subTaskTemplates': _encodeStringList(subTaskTemplates),
    };
    if (skippable != null) updates['skippable'] = skippable ? 1 : 0;
    if (reminderEnabled != null) updates['reminderEnabled'] = reminderEnabled ? 1 : 0;
    if (description != null) updates['description'] = description;
    if (points != null) updates['points'] = points;
    if (weight != null) updates['weight'] = weight;
    if (focusDuration != null) updates['focusDuration'] = focusDuration;
    if (isPomodoroFocusEnabled != null) updates['isPomodoroFocusEnabled'] = isPomodoroFocusEnabled ? 1 : 0;

    await db.update('activities', updates, where: 'id = ?', whereArgs: [id]);

    if (trackingType == 'multiple' && subTaskTemplates.isNotEmpty) {
      final now = DateTime.now();
      final todayStart = AppDateUtils.startOfDay(now);
      final tomorrowStart = todayStart.add(const Duration(days: 1));

      final rows = await db.query(
        'tasks',
        where: 'activityId = ? AND timestamp >= ? AND timestamp < ?',
        whereArgs: [id, todayStart.millisecondsSinceEpoch, tomorrowStart.millisecondsSinceEpoch],
        limit: 1,
      );

      if (rows.isEmpty) {
        await _seedTodayTask(db, id, name, subTaskTemplates, now);
      } else {
        // Merge existing subtask check states with updated templates
        final existingTask = Task.fromMap(rows.first['id'] as String, rows.first);
        final updatedSubTasks = subTaskTemplates.map((template) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          final existing = existingTask.subTasks.firstWhere(
            (st) => st.title == title,
            orElse: () => SubTask(id: '', title: '', checked: false),
          );
          return existing.id.isNotEmpty
              ? existing.copyWith(scheduledTime: timeStr)
              : SubTask(id: IdUtils.generateId(), title: title, checked: false, scheduledTime: timeStr);
        }).toList();

        final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
        final updatedTask = existingTask.copyWith(taskName: name, subTasks: updatedSubTasks, checked: allChecked);
        await db.update('tasks', updatedTask.toMap(), where: 'id = ?', whereArgs: [updatedTask.id]);
      }
    }
  }

  Future<Task?> getTaskById(String id) async {
    final db = await (await _db).database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first['id'] as String, rows.first);
  }

  Future<Task?> getOrCreateTodayTaskForRoutine(Activity activity) async {
    final db = await (await _db).database;
    final now = DateTime.now();
    final todayStart = AppDateUtils.startOfDay(now);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    // Query tasks for this activity today
    final rows = await db.query(
      'tasks',
      where: 'activityId = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [activity.id, todayStart.millisecondsSinceEpoch, tomorrowStart.millisecondsSinceEpoch],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return Task.fromMap(rows.first['id'] as String, rows.first);
    }

    if (activity.subTaskTemplates.isNotEmpty) {
      final subTasks = activity.subTaskTemplates.map((template) {
        final parts = template.split('|');
        return SubTask(
          id: IdUtils.generateId(),
          title: parts.first,
          checked: false,
          scheduledTime: parts.length > 1 ? parts.last : null,
        );
      }).toList();

      final id = IdUtils.generateId();
      final task = Task(
        id: id,
        activityId: activity.id,
        taskName: activity.name,
        timestamp: now,
        checked: false,
        subTasks: subTasks,
      );

      final map = task.toMap();
      map['createdAt'] = now.millisecondsSinceEpoch;
      await db.insert('tasks', map);

      // Auto-reactivate parent activity
      await db.update('activities', {'isActive': 1}, where: 'id = ?', whereArgs: [activity.id]);

      return task;
    }

    return null;
  }

  Future<void> deleteActivity(String id) async {
    final db = await (await _db).database;
    // Cascade handled by FK constraint in schema
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateActivitySymbols(
    String id, {
    String? symbolType,
    String? symbolValue,
    String? category,
  }) async {
    final db = await (await _db).database;
    final updates = <String, dynamic>{};
    if (symbolType != null) updates['symbolType'] = symbolType;
    if (symbolValue != null) updates['symbolValue'] = symbolValue;
    if (category != null) updates['category'] = category;
    if (updates.isEmpty) return;
    await db.update('activities', updates, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Tasks — streams ──────────────────────────────────────────────────────

  Stream<List<Task>> getTasksStreamForCurrentWeek() {
    final cutoff = AppDateUtils.startOfWeek(DateTime.now()).subtract(const Duration(days: 1));
    return _pollStream(() => _queryTasks(since: cutoff));
  }

  Stream<List<Task>> getTasksStream() =>
      _pollStream(() => _queryTasks());

  Stream<List<Task>> getTasksForActivityStream(String activityId) =>
      _pollStream(() => _queryTasksForActivity(activityId));

  Stream<List<Task>> getTasksForActivitiesStream(List<String> activityIds) {
    if (activityIds.isEmpty) return Stream.value(const <Task>[]);
    return _pollStream(() => _queryTasksForActivities(activityIds));
  }

  Stream<List<Task>> getCurrentAndRecentMilestoneTasksStream(Activity activity) {
    if (activity.trackingType != 'milestone' || !activity.isActive) {
      return Stream.value(const <Task>[]);
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    return _pollStream(() => _queryTasksForActivity(activity.id)).map((tasks) {
      final sorted = tasks.where((t) => t.activityId == activity.id).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final currentId = sorted.isNotEmpty ? sorted.first.id : null;
      return sorted
          .where((t) => t.id == currentId || !t.checked || !t.timestamp.isBefore(cutoff))
          .toList();
    });
  }

  // ─── Tasks — queries ──────────────────────────────────────────────────────

  Future<List<Task>> _queryTasks({DateTime? since}) async {
    final db = await (await _db).database;
    final rows = since != null
        ? await db.query('tasks', where: 'timestamp >= ?', whereArgs: [since.millisecondsSinceEpoch])
        : await db.query('tasks');
    return rows.map((r) => Task.fromMap(r['id'] as String, r)).toList();
  }

  Future<List<Task>> _queryTasksForActivity(String activityId) async {
    final db = await (await _db).database;
    final rows = await db.query('tasks', where: 'activityId = ?', whereArgs: [activityId], orderBy: 'timestamp DESC');
    return rows.map((r) => Task.fromMap(r['id'] as String, r)).toList();
  }

  Future<List<Task>> _queryTasksForActivities(List<String> activityIds) async {
    final db = await (await _db).database;
    final unique = activityIds.toSet().toList();
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await db.rawQuery('SELECT * FROM tasks WHERE activityId IN ($placeholders)', unique);
    return rows.map((r) => Task.fromMap(r['id'] as String, r)).toList();
  }

  // ─── Tasks — writes ───────────────────────────────────────────────────────

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
    final db = await (await _db).database;

    final hasTime = taskName.contains('|');
    final cleanName = hasTime ? taskName.split('|').first : taskName;
    final timeStr = hasTime ? taskName.split('|').last : null;

    final id = IdUtils.generateId();
    final newTask = Task(
      id: id,
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

    final map = newTask.toMap();
    map['createdAt'] = timestamp.millisecondsSinceEpoch;
    await db.insert('tasks', map);

    // Auto-reactivate parent activity
    await db.update('activities', {'isActive': 1}, where: 'id = ?', whereArgs: [activityId]);

    if (checked) {
      await _upsertCheckIn(db, activityId, cleanName, timestamp);
    }
    return newTask;
  }

  Future<void> updateTask(Task task) async {
    final db = await (await _db).database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);

    if (task.checked) {
      await _upsertCheckIn(db, task.activityId, task.taskName, DateTime.now());
    } else {
      await _deleteCheckInsForSubTask(db, task.activityId, task.taskName);
    }
  }

  Future<void> toggleTask(String id, bool checked) async {
    final db = await (await _db).database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final task = Task.fromMap(rows.first['id'] as String, rows.first);
    await db.update(
      'tasks',
      {'checked': checked ? 1 : 0, 'completionTime': checked ? DateTime.now().millisecondsSinceEpoch : null},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (checked) {
      await _upsertCheckIn(db, task.activityId, task.taskName, DateTime.now());
    } else {
      await _deleteCheckInsForSubTask(db, task.activityId, task.taskName);
    }
  }

  Future<void> deleteTask(String id) async {
    final db = await (await _db).database;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final task = Task.fromMap(rows.first['id'] as String, rows.first);
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await _deleteCheckInsForSubTask(db, task.activityId, task.taskName);
  }

  Future<void> updateTaskSymbols(String id, {String? symbolType, String? symbolValue}) async {
    final db = await (await _db).database;
    final updates = <String, dynamic>{};
    if (symbolType != null) updates['symbolType'] = symbolType;
    if (symbolValue != null) updates['symbolValue'] = symbolValue;
    if (updates.isEmpty) return;
    await db.update('tasks', updates, where: 'id = ?', whereArgs: [id]);
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _seedTodayTask(
    dynamic db,
    String activityId,
    String name,
    List<String> templates,
    DateTime now,
  ) async {
    final subTasks = templates.map((template) {
      final parts = template.split('|');
      return SubTask(
        id: IdUtils.generateId(),
        title: parts.first,
        checked: false,
        scheduledTime: parts.length > 1 ? parts.last : null,
      );
    }).toList();

    final id = IdUtils.generateId();
    final task = Task(
      id: id,
      activityId: activityId,
      taskName: name,
      timestamp: now,
      checked: false,
      subTasks: subTasks,
    );
    final map = task.toMap();
    map['createdAt'] = now.millisecondsSinceEpoch;
    await db.insert('tasks', map);
  }

  Future<void> _upsertCheckIn(dynamic db, String activityId, String subTaskName, DateTime ts) async {
    final existing = await db.query(
      'check_ins',
      where: 'activityId = ? AND subTaskName = ?',
      whereArgs: [activityId, subTaskName],
      limit: 1,
    );
    if (existing.isEmpty) {
      final checkIn = CheckIn(
        id: IdUtils.generateId(),
        activityId: activityId,
        timestamp: ts,
        checked: true,
        subTaskName: subTaskName,
      );
      await db.insert('check_ins', checkIn.toMap());
    }
  }

  Future<void> _deleteCheckInsForSubTask(dynamic db, String activityId, String subTaskName) async {
    await db.delete(
      'check_ins',
      where: 'activityId = ? AND subTaskName = ?',
      whereArgs: [activityId, subTaskName],
    );
  }

  // ─── Encoding helpers ─────────────────────────────────────────────────────

  String _encodeIntList(List<int> list) => jsonEncode(list);

  String _encodeStringList(List<String> list) => jsonEncode(list);

  Future<Task?> getActiveTaskForActivity(String activityId) async {
    final db = await (await _db).database;
    // Check if it's a task ID first
    final taskRows = await db.query('tasks', where: 'id = ?', whereArgs: [activityId], limit: 1);
    if (taskRows.isNotEmpty) {
      return Task.fromMap(taskRows.first['id'] as String, taskRows.first);
    }

    final rows = await db.query('tasks', where: 'activityId = ?', whereArgs: [activityId]);
    if (rows.isEmpty) return null;
    final tasks = rows.map((r) => Task.fromMap(r['id'] as String, r)).toList();
    // Sort descending by timestamp
    tasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // Find first unchecked task
    final unchecked = tasks.where((t) => !t.checked);
    if (unchecked.isNotEmpty) {
      return unchecked.first;
    }
    return tasks.first;
  }
}
