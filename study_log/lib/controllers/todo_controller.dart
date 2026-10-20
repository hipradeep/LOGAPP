import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/todo_item.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../services/notification_service.dart';

/// Central state controller managing Todos, Subtasks, Pomodoro sessions,
/// and categorized collapsible task groups.
///
/// Follows zero-dependency ChangeNotifier architecture conforming to
/// [aa-rules.md] and [optimize_data.md].
class TodoController extends ChangeNotifier {
  final DatabaseService _dbService;

  StreamSubscription<List<TodoItem>>? _subscription;
  List<TodoItem> _rawTodos = [];
  Map<String, TodoItem> _todosById = {};

  // Pre-computed cached category lists (Rule 1 of optimize_data.md)
  List<TodoItem> _cachedDueTodayTodos = [];
  List<TodoItem> _cachedUpcomingTodos = [];
  List<TodoItem> _cachedFinishedTodos = [];
  List<TodoItem> _cachedArchivedTodos = [];

  bool _isLoading = true;

  /// Collapsed groups tracker for zero-jank leaf rebuilds.
  /// Keys: 'due_today', 'upcoming', 'finished', 'archive'.
  final ValueNotifier<Set<String>> collapsedGroupsNotifier =
      ValueNotifier<Set<String>>({'finished', 'archive'});

  TodoController({DatabaseService? databaseService})
      : _dbService = databaseService ?? getIt<DatabaseService>() {
    _init();
  }

  void _init() {
    _subscription = _dbService.watchTodos().listen(_onTodosChanged);
    refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    try {
      final list = await _dbService.getTodos(includeArchived: true);
      _processTodos(list);
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onTodosChanged(List<TodoItem> todos) {
    _processTodos(todos);
    notifyListeners();
  }

  void _processTodos(List<TodoItem> todos) {
    _rawTodos = todos;
    _todosById = {for (final t in todos) t.id: t};

    final dueToday = <TodoItem>[];
    final upcoming = <TodoItem>[];
    final finished = <TodoItem>[];
    final archived = <TodoItem>[];

    for (final item in todos) {
      if (item.status == TodoStatus.archived) {
        archived.add(item);
      } else if (item.status == TodoStatus.done) {
        finished.add(item);
      } else if (item.isDueTodayOrOverdue) {
        dueToday.add(item);
      } else {
        upcoming.add(item);
      }
    }

    // Sort Due Today: Overdue tasks first, then by deadline
    dueToday.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
      return a.orderIndex.compareTo(b.orderIndex);
    });

    // Sort Upcoming: Soonest deadline first, unassigned deadlines at the end
    upcoming.sort((a, b) {
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
      if (a.deadline != null && b.deadline == null) return -1;
      if (a.deadline == null && b.deadline != null) return 1;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    // Sort Finished: Most recently completed first
    finished.sort((a, b) {
      final aTime = a.completedAt ?? a.updatedAt;
      final bTime = b.completedAt ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });

    // Sort Archived: Most recently updated first
    archived.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    _cachedDueTodayTodos = dueToday;
    _cachedUpcomingTodos = upcoming;
    _cachedFinishedTodos = finished;
    _cachedArchivedTodos = archived;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  List<TodoItem> get allTodos => List.unmodifiable(_rawTodos);
  List<TodoItem> get dueTodayTodos => List.unmodifiable(_cachedDueTodayTodos);
  List<TodoItem> get upcomingTodos => List.unmodifiable(_cachedUpcomingTodos);
  List<TodoItem> get finishedTodos => List.unmodifiable(_cachedFinishedTodos);
  List<TodoItem> get archivedTodos => List.unmodifiable(_cachedArchivedTodos);

  int get totalActiveCount => _cachedDueTodayTodos.length + _cachedUpcomingTodos.length;
  int get dueTodayCount => _cachedDueTodayTodos.length;
  int get finishedTodayCount {
    final now = DateTime.now();
    return _cachedFinishedTodos.where((t) {
      final c = t.completedAt;
      return c != null && c.year == now.year && c.month == now.month && c.day == now.day;
    }).length;
  }

  TodoItem? getTodoById(String id) => _todosById[id];

  // ─────────────────────────────────────────────────────────────────────────
  // Collapse State Management
  // ─────────────────────────────────────────────────────────────────────────

  bool isGroupCollapsed(String groupKey) {
    return collapsedGroupsNotifier.value.contains(groupKey);
  }

  void toggleGroupCollapse(String groupKey) {
    final current = Set<String>.from(collapsedGroupsNotifier.value);
    if (current.contains(groupKey)) {
      current.remove(groupKey);
    } else {
      current.add(groupKey);
    }
    collapsedGroupsNotifier.value = current;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mutations & Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addTodo(TodoItem item, {List<TodoSubtask>? initialSubtasks}) async {
    await _dbService.insertTodo(item, initialSubtasks: initialSubtasks);
    if (item.reminderTime != null && getIt.isRegistered<NotificationService>()) {
      getIt<NotificationService>().scheduleTodoReminder(
        todoId: item.id,
        title: item.title,
        reminderTime: item.reminderTime!,
      );
    }
  }

  Future<void> updateTodo(TodoItem item) async {
    final updated = item.copyWith(updatedAt: DateTime.now());
    await _dbService.updateTodo(updated);
    if (getIt.isRegistered<NotificationService>()) {
      if (updated.reminderTime != null && !updated.isCompleted && !updated.isArchived) {
        getIt<NotificationService>().scheduleTodoReminder(
          todoId: updated.id,
          title: updated.title,
          reminderTime: updated.reminderTime!,
        );
      } else {
        getIt<NotificationService>().cancelTodoReminder(updated.id);
      }
    }
  }

  Future<void> toggleTodoStatus(String id) async {
    final item = _todosById[id];
    if (item == null) return;

    if (item.status == TodoStatus.done) {
      // Re-open
      await updateStatus(id, TodoStatus.todo);
    } else {
      // Complete
      await updateStatus(id, TodoStatus.done);
    }
  }

  Future<void> updateStatus(String id, TodoStatus status) async {
    final item = _todosById[id];
    if (item == null) return;

    final now = DateTime.now();
    await _dbService.updateTodoStatus(id, status, completedAt: status == TodoStatus.done ? now : null);

    if (status == TodoStatus.done) {
      // 1. Record study log entry
      try {
        final log = StudyLog(
          id: 'log_todo_${item.id}_${now.millisecondsSinceEpoch}',
          type: StudyLogType.todoCompleted,
          courseId: item.courseId ?? '',
          courseTitle: item.title,
          moduleId: item.moduleId ?? '',
          moduleTitle: '',
          topicId: item.id,
          topicTitle: item.title,
          durationMinutes: item.totalMinutesSpent > 0 ? item.totalMinutesSpent : 5,
          timestamp: now,
          createdAt: now,
        );
        await _dbService.addStudyLog(log);
      } catch (_) {}

      // 2. Spawn next recurrence if repeating
      if (item.isRecurring && item.recurrenceRule.isRepeating) {
        final nextDue = item.recurrenceRule.calculateNextDueDate(item.deadline ?? now);
        if (nextDue != null) {
          final nextId = 'todo_${DateTime.now().millisecondsSinceEpoch}';
          final newSubtasks = item.subtasks.map((s) {
            return s.copyWith(
              id: 'subtask_${DateTime.now().microsecondsSinceEpoch}_${s.orderIndex}',
              todoId: nextId,
              isCompleted: false,
              createdAt: now,
              completedAt: null,
            );
          }).toList();

          final nextItem = item.copyWith(
            id: nextId,
            status: TodoStatus.todo,
            deadline: nextDue,
            completedPomodoros: 0,
            totalMinutesSpent: 0,
            subtasks: newSubtasks,
            createdAt: now,
            updatedAt: now,
            completedAt: null,
          );

          await _dbService.insertTodo(nextItem, initialSubtasks: newSubtasks);
        }
      }
    }
  }

  Future<void> archiveTodo(String id) async {
    await updateStatus(id, TodoStatus.archived);
  }

  Future<void> unarchiveTodo(String id) async {
    await updateStatus(id, TodoStatus.todo);
  }

  Future<void> deleteTodo(String id) async {
    if (getIt.isRegistered<NotificationService>()) {
      getIt<NotificationService>().cancelTodoReminder(id);
    }
    await _dbService.deleteTodo(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Subtasks Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addSubtask(String todoId, String title) async {
    if (title.trim().isEmpty) return;
    final item = _todosById[todoId];
    final order = item != null ? item.subtasks.length : 0;
    final subtask = TodoSubtask(
      id: 'subtask_${DateTime.now().millisecondsSinceEpoch}',
      todoId: todoId,
      title: title.trim(),
      isCompleted: false,
      orderIndex: order,
      createdAt: DateTime.now(),
    );
    await _dbService.insertSubtask(subtask);
  }

  Future<void> toggleSubtask(String todoId, String subtaskId) async {
    final item = _todosById[todoId];
    if (item == null) return;
    final subtaskIndex = item.subtasks.indexWhere((s) => s.id == subtaskId);
    if (subtaskIndex == -1) return;
    final subtask = item.subtasks[subtaskIndex];

    final willComplete = !subtask.isCompleted;
    await _dbService.toggleSubtaskCompletion(subtaskId, willComplete);

    // If all subtasks completed, auto-advance task status
    final remaining = item.subtasks.where((s) => s.id != subtaskId && !s.isCompleted).length;
    if (willComplete && remaining == 0 && item.status != TodoStatus.done) {
      await updateStatus(todoId, TodoStatus.done);
    } else if (!willComplete && item.status == TodoStatus.done) {
      await updateStatus(todoId, TodoStatus.inProgress);
    }
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await _dbService.deleteSubtask(subtaskId);
  }

  Future<void> reorderSubtasks(String todoId, int oldIndex, int newIndex) async {
    final item = _todosById[todoId];
    if (item == null) return;

    final subtasks = List<TodoSubtask>.from(item.subtasks);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final moved = subtasks.removeAt(oldIndex);
    subtasks.insert(newIndex, moved);

    // Optimistic local update
    final orderedIds = subtasks.map((s) => s.id).toList();
    _todosById[todoId] = item.copyWith(
      subtasks: [
        for (int i = 0; i < subtasks.length; i++) subtasks[i].copyWith(orderIndex: i)
      ],
    );
    notifyListeners();

    await _dbService.updateSubtaskOrder(todoId, orderedIds);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pomodoro Focus Session Operations
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordPomodoroCompleted(String todoId, int sessionMinutes) async {
    final item = _todosById[todoId];
    if (item == null) return;

    final now = DateTime.now();
    final updated = item.copyWith(
      completedPomodoros: item.completedPomodoros + 1,
      totalMinutesSpent: item.totalMinutesSpent + sessionMinutes,
      status: item.status == TodoStatus.todo ? TodoStatus.inProgress : item.status,
      updatedAt: now,
    );

    await _dbService.updateTodo(updated);

    // Record study session log to advance streaks and activity feed
    try {
      final log = StudyLog(
        id: 'log_pomodoro_${todoId}_${now.millisecondsSinceEpoch}',
        type: StudyLogType.todoSession,
        courseId: item.courseId ?? '',
        courseTitle: item.title,
        moduleId: item.moduleId ?? '',
        moduleTitle: '',
        topicId: item.id,
        topicTitle: item.title,
        durationMinutes: sessionMinutes,
        timestamp: now,
        createdAt: now,
      );
      await _dbService.addStudyLog(log);
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.cancel();
    collapsedGroupsNotifier.dispose();
    super.dispose();
  }
}
