import 'dart:convert';
import 'package:flutter/material.dart';

/// Execution state of a Todo task.
enum TodoStatus {
  todo('TODO'),
  inProgress('IN_PROGRESS'),
  done('DONE'),
  archived('ARCHIVED');

  final String value;
  const TodoStatus(this.value);

  static TodoStatus fromString(String? val) {
    if (val == null) return TodoStatus.todo;
    final normalized = val.trim().toLowerCase();
    switch (normalized) {
      case 'in_progress':
      case 'inprogress':
        return TodoStatus.inProgress;
      case 'done':
      case 'completed':
        return TodoStatus.done;
      case 'archived':
      case 'archive':
        return TodoStatus.archived;
      case 'todo':
      default:
        return TodoStatus.todo;
    }
  }
}

/// Priority tier for triage and visual styling.
enum TodoPriority {
  low('LOW', 1),
  med('MED', 2),
  high('HIGH', 3);

  final String value;
  final int weight;
  const TodoPriority(this.value, this.weight);

  static TodoPriority fromString(String? val) {
    if (val == null) return TodoPriority.med;
    final normalized = val.trim().toLowerCase();
    switch (normalized) {
      case 'high':
        return TodoPriority.high;
      case 'low':
        return TodoPriority.low;
      case 'med':
      case 'medium':
      default:
        return TodoPriority.med;
    }
  }
}

/// Recurrence cadence pattern.
enum RecurrenceType {
  none,
  daily,
  weekly,
  weekdays, // Monday to Friday
  monthly,
  custom;

  static RecurrenceType fromString(String? val) {
    if (val == null) return RecurrenceType.none;
    switch (val.toLowerCase().trim()) {
      case 'daily':
        return RecurrenceType.daily;
      case 'weekly':
        return RecurrenceType.weekly;
      case 'weekdays':
        return RecurrenceType.weekdays;
      case 'monthly':
        return RecurrenceType.monthly;
      case 'custom':
        return RecurrenceType.custom;
      case 'none':
      default:
        return RecurrenceType.none;
    }
  }
}

/// Structured recurrence configuration for repeating tasks.
class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // e.g. every 1 day, every 2 weeks
  final List<int> daysOfWeek; // 1 = Monday .. 7 = Sunday
  final DateTime? untilDate;

  const RecurrenceRule({
    this.type = RecurrenceType.none,
    this.interval = 1,
    this.daysOfWeek = const [],
    this.untilDate,
  });

  bool get isRepeating => type != RecurrenceType.none;

  DateTime? calculateNextDueDate(DateTime fromDate) {
    if (!isRepeating) return null;
    DateTime candidate;
    switch (type) {
      case RecurrenceType.daily:
        candidate = fromDate.add(Duration(days: interval > 0 ? interval : 1));
        break;
      case RecurrenceType.weekdays:
        candidate = fromDate.add(const Duration(days: 1));
        while (candidate.weekday == DateTime.saturday || candidate.weekday == DateTime.sunday) {
          candidate = candidate.add(const Duration(days: 1));
        }
        break;
      case RecurrenceType.weekly:
        candidate = fromDate.add(Duration(days: 7 * (interval > 0 ? interval : 1)));
        break;
      case RecurrenceType.monthly:
        candidate = DateTime(
          fromDate.year,
          fromDate.month + (interval > 0 ? interval : 1),
          fromDate.day,
          fromDate.hour,
          fromDate.minute,
        );
        break;
      case RecurrenceType.custom:
        if (daysOfWeek.isNotEmpty) {
          candidate = fromDate.add(const Duration(days: 1));
          for (int i = 0; i < 14; i++) {
            if (daysOfWeek.contains(candidate.weekday)) break;
            candidate = candidate.add(const Duration(days: 1));
          }
        } else {
          candidate = fromDate.add(Duration(days: interval > 0 ? interval : 1));
        }
        break;
      case RecurrenceType.none:
        return null;
    }

    if (untilDate != null && candidate.isAfter(untilDate!)) {
      return null;
    }
    return candidate;
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'interval': interval,
      'daysOfWeek': daysOfWeek,
      if (untilDate != null) 'untilDate': untilDate!.toIso8601String(),
    };
  }

  factory RecurrenceRule.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const RecurrenceRule();
    return RecurrenceRule(
      type: RecurrenceType.fromString(map['type']?.toString()),
      interval: (map['interval'] is int)
          ? map['interval'] as int
          : (int.tryParse(map['interval']?.toString() ?? '') ?? 1),
      daysOfWeek: (map['daysOfWeek'] is List)
          ? (map['daysOfWeek'] as List).map((e) => int.tryParse(e.toString()) ?? 1).toList()
          : const [],
      untilDate: map['untilDate'] != null ? DateTime.tryParse(map['untilDate'].toString()) : null,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RecurrenceRule.fromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return const RecurrenceRule();
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return RecurrenceRule.fromMap(decoded);
      }
    } catch (_) {}
    return const RecurrenceRule();
  }
}

/// Represents an individual subtask belonging to a [TodoItem].
class TodoSubtask {
  final String id;
  final String todoId;
  final String title;
  final bool isCompleted;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TodoSubtask({
    required this.id,
    required this.todoId,
    required this.title,
    this.isCompleted = false,
    this.orderIndex = 0,
    required this.createdAt,
    this.completedAt,
  });

  TodoSubtask copyWith({
    String? id,
    String? todoId,
    String? title,
    bool? isCompleted,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return TodoSubtask(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'todoId': todoId,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    };
  }

  factory TodoSubtask.fromMap(Map<String, dynamic> map) {
    return TodoSubtask(
      id: map['id']?.toString() ?? '',
      todoId: map['todoId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      orderIndex: (map['orderIndex'] is int)
          ? map['orderIndex'] as int
          : (int.tryParse(map['orderIndex']?.toString() ?? '') ?? 0),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      completedAt: map['completedAt'] != null
          ? DateTime.tryParse(map['completedAt'].toString())
          : null,
    );
  }
}

/// Represents an immutable Todo task item.
class TodoItem {
  final String id;
  final String title;
  final String description;
  final TodoStatus status;
  final TodoPriority priority;
  final DateTime? deadline;
  final DateTime? reminderTime;
  final bool isRecurring;
  final RecurrenceRule recurrenceRule;
  final String? courseId;
  final String? moduleId;
  final String? topicId;
  final int estimatedPomodoros;
  final int completedPomodoros;
  final int totalMinutesSpent;
  final int orderIndex;
  final List<TodoSubtask> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const TodoItem({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TodoStatus.todo,
    this.priority = TodoPriority.med,
    this.deadline,
    this.reminderTime,
    this.isRecurring = false,
    this.recurrenceRule = const RecurrenceRule(),
    this.courseId,
    this.moduleId,
    this.topicId,
    this.estimatedPomodoros = 1,
    this.completedPomodoros = 0,
    this.totalMinutesSpent = 0,
    this.orderIndex = 0,
    this.subtasks = const [],
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  /// True if the task has been marked finished.
  bool get isCompleted => status == TodoStatus.done;

  /// True if the task is archived.
  bool get isArchived => status == TodoStatus.archived;

  /// True if the task is active and actionable (TODO or IN_PROGRESS).
  bool get isActive => status == TodoStatus.todo || status == TodoStatus.inProgress;

  /// True if task has subtasks.
  bool get hasSubtasks => subtasks.isNotEmpty;

  /// Number of completed subtasks.
  int get completedSubtaskCount => subtasks.where((s) => s.isCompleted).length;

  /// Completion ratio from 0.0 to 1.0.
  double get progressRatio {
    if (subtasks.isEmpty) {
      return status == TodoStatus.done ? 1.0 : (status == TodoStatus.inProgress ? 0.5 : 0.0);
    }
    return completedSubtaskCount / subtasks.length;
  }

  /// True if the task is past its due date and not done.
  bool get isOverdue {
    if (deadline == null || status == TodoStatus.done || status == TodoStatus.archived) {
      return false;
    }
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return deadline!.isBefore(todayEnd) && !DateUtils.isSameDay(deadline!, now);
  }

  /// True if the deadline is today (or overdue).
  bool get isDueTodayOrOverdue {
    if (deadline == null) return false;
    final now = DateTime.now();
    if (DateUtils.isSameDay(deadline!, now)) return true;
    return isOverdue;
  }

  /// True if the deadline is in the future (strictly after today).
  bool get isUpcoming {
    if (deadline == null) return true; // Tasks without deadline appear under upcoming by default
    final now = DateTime.now();
    return deadline!.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
  }

  TodoItem copyWith({
    String? id,
    String? title,
    String? description,
    TodoStatus? status,
    TodoPriority? priority,
    DateTime? deadline,
    bool clearDeadline = false,
    DateTime? reminderTime,
    bool clearReminderTime = false,
    bool? isRecurring,
    RecurrenceRule? recurrenceRule,
    String? courseId,
    String? moduleId,
    String? topicId,
    int? estimatedPomodoros,
    int? completedPomodoros,
    int? totalMinutesSpent,
    int? orderIndex,
    List<TodoSubtask>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      reminderTime: clearReminderTime ? null : (reminderTime ?? this.reminderTime),
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      topicId: topicId ?? this.topicId,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      totalMinutesSpent: totalMinutesSpent ?? this.totalMinutesSpent,
      orderIndex: orderIndex ?? this.orderIndex,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'deadline': deadline?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'isRecurring': isRecurring ? 1 : 0,
      'recurrenceRule': recurrenceRule.isRepeating ? recurrenceRule.toJson() : null,
      'courseId': courseId,
      'moduleId': moduleId,
      'topicId': topicId,
      'estimatedPomodoros': estimatedPomodoros,
      'completedPomodoros': completedPomodoros,
      'totalMinutesSpent': totalMinutesSpent,
      'orderIndex': orderIndex,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map, {List<TodoSubtask> subtasks = const []}) {
    return TodoItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: TodoStatus.fromString(map['status']?.toString()),
      priority: TodoPriority.fromString(map['priority']?.toString()),
      deadline: map['deadline'] != null ? DateTime.tryParse(map['deadline'].toString()) : null,
      reminderTime:
          map['reminderTime'] != null ? DateTime.tryParse(map['reminderTime'].toString()) : null,
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
      recurrenceRule: RecurrenceRule.fromJson(map['recurrenceRule']?.toString()),
      courseId: map['courseId']?.toString(),
      moduleId: map['moduleId']?.toString(),
      topicId: map['topicId']?.toString(),
      estimatedPomodoros: (map['estimatedPomodoros'] is int)
          ? map['estimatedPomodoros'] as int
          : (int.tryParse(map['estimatedPomodoros']?.toString() ?? '') ?? 1),
      completedPomodoros: (map['completedPomodoros'] is int)
          ? map['completedPomodoros'] as int
          : (int.tryParse(map['completedPomodoros']?.toString() ?? '') ?? 0),
      totalMinutesSpent: (map['totalMinutesSpent'] is int)
          ? map['totalMinutesSpent'] as int
          : (int.tryParse(map['totalMinutesSpent']?.toString() ?? '') ?? 0),
      orderIndex: (map['orderIndex'] is int)
          ? map['orderIndex'] as int
          : (int.tryParse(map['orderIndex']?.toString() ?? '') ?? 0),
      subtasks: subtasks,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
      completedAt:
          map['completedAt'] != null ? DateTime.tryParse(map['completedAt'].toString()) : null,
    );
  }
}
