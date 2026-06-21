import 'dart:convert';
import '../utils/db_utils.dart';
import '../utils/id_utils.dart';

class SubTask {
  final String id;
  final String title;
  final bool checked;
  final int? durationMinutes;
  final String? scheduledTime;

  SubTask({
    required this.id,
    required this.title,
    required this.checked,
    this.durationMinutes,
    this.scheduledTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'checked': checked,
      'durationMinutes': durationMinutes,
      'scheduledTime': scheduledTime,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> data) {
    return SubTask(
      id: data['id'] as String? ?? IdUtils.generateId(),
      title: data['title'] as String? ?? '',
      checked: data['checked'] == true || data['checked'] == 1,
      durationMinutes: data['durationMinutes'] as int?,
      scheduledTime: data['scheduledTime'] as String?,
    );
  }

  SubTask copyWith({
    String? id,
    String? title,
    bool? checked,
    int? durationMinutes,
    String? scheduledTime,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      checked: checked ?? this.checked,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }
}

class Task {
  final String id;
  final String activityId;
  final String taskName;
  final DateTime timestamp;
  final bool checked;
  final String? symbolType;
  final String? symbolValue;
  final String? scheduledTime;
  final DateTime? completionTime;
  final List<SubTask> subTasks;

  Task({
    required this.id,
    required this.activityId,
    required this.taskName,
    required this.timestamp,
    required this.checked,
    this.symbolType,
    this.symbolValue,
    this.scheduledTime,
    this.completionTime,
    this.subTasks = const [],
  });

  // ─── SQLite serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'taskName': taskName,
      'timestamp': DbUtils.dateToMs(timestamp),
      'checked': checked ? 1 : 0,
      'symbolType': symbolType,
      'symbolValue': symbolValue,
      'scheduledTime': scheduledTime,
      'completionTime': completionTime != null ? DbUtils.dateToMs(completionTime!) : null,
      'subTasks': jsonEncode(subTasks.map((st) => st.toMap()).toList()),
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    // Parse subTasks — may be stored as JSON string or raw List
    List<SubTask> parsedSubTasks = [];
    final rawSubTasks = map['subTasks'];
    if (rawSubTasks is String && rawSubTasks.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSubTasks) as List;
        parsedSubTasks = decoded
            .map((item) => SubTask.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {}
    } else if (rawSubTasks is List) {
      parsedSubTasks = rawSubTasks
          .map((item) => SubTask.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    // Support both taskName and legacy subTaskName
    final String name = map['taskName'] as String? ?? map['subTaskName'] as String? ?? '';

    // Extract time suffix from legacy format "Title|10:30"
    final hasTime = name.contains('|');
    final nameWithoutTime = hasTime ? name.split('|').first : name;
    final parsedScheduledTime = hasTime ? name.split('|').last : null;
    final String? scheduledTime = map['scheduledTime'] as String? ?? parsedScheduledTime;

    // Clean legacy "::" format
    String cleanName = nameWithoutTime;
    if (nameWithoutTime.contains('::')) {
      cleanName = nameWithoutTime.split('::').first.trim();
      if (parsedSubTasks.isEmpty) {
        final parts = nameWithoutTime.split('::');
        final itemsPart = parts.length > 1 ? parts[1].trim() : '';
        if (itemsPart.isNotEmpty) {
          final itemsList = itemsPart.split(',');
          for (int i = 0; i < itemsList.length; i++) {
            final trimmed = itemsList[i].trim();
            if (trimmed.isEmpty) continue;
            final bool isChecked = trimmed.startsWith('[x]');
            final String itemTitle = isChecked
                ? trimmed.substring(3).trim()
                : (trimmed.startsWith('[ ]') ? trimmed.substring(3).trim() : trimmed);
            parsedSubTasks.add(SubTask(
              id: 'legacy-$i',
              title: itemTitle,
              checked: isChecked,
            ));
          }
        }
      }
    }

    return Task(
      id: id,
      activityId: map['activityId'] as String? ?? '',
      taskName: cleanName,
      timestamp: DbUtils.msToDate(map['timestamp'] as int?),
      checked: map['checked'] == 1 || map['checked'] == true,
      symbolType: map['symbolType'] as String?,
      symbolValue: map['symbolValue'] as String?,
      scheduledTime: scheduledTime,
      completionTime: DbUtils.msToDateNullable(map['completionTime'] as int?),
      subTasks: parsedSubTasks,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  Task copyWith({
    String? id,
    String? activityId,
    String? taskName,
    DateTime? timestamp,
    bool? checked,
    String? symbolType,
    String? symbolValue,
    String? scheduledTime,
    DateTime? completionTime,
    List<SubTask>? subTasks,
  }) {
    return Task(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      taskName: taskName ?? this.taskName,
      timestamp: timestamp ?? this.timestamp,
      checked: checked ?? this.checked,
      symbolType: symbolType ?? this.symbolType,
      symbolValue: symbolValue ?? this.symbolValue,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      completionTime: completionTime ?? this.completionTime,
      subTasks: subTasks ?? this.subTasks,
    );
  }
}
