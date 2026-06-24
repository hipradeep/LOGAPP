// Updated Task model with notes field
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'checked': checked,
      'durationMinutes': durationMinutes,
      'scheduledTime': scheduledTime,
    };
  }

  factory SubTask.fromFirestore(Map<String, dynamic> data) {
    return SubTask(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      checked: data['checked'] as bool? ?? false,
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
  final String? notes;

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
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'taskName': taskName,
      'timestamp': Timestamp.fromDate(timestamp),
      'checked': checked,
      'symbolType': symbolType,
      'symbolValue': symbolValue,
      'scheduledTime': scheduledTime,
      'completionTime': completionTime != null ? Timestamp.fromDate(completionTime!) : null,
      'subTasks': subTasks.map((st) => st.toFirestore()).toList(),
      'notes': notes,
    };
  }

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null
        ? firestoreTimestamp.toDate()
        : DateTime.now();

    final Timestamp? firestoreCompletionTime = data['completionTime'] as Timestamp?;

    final List<dynamic>? rawSubTasks = data['subTasks'] as List<dynamic>?;
    List<SubTask> parsedSubTasks = [];
    
    // Support either taskName or the legacy subTaskName
    final String name = data['taskName'] as String? ?? data['subTaskName'] as String? ?? '';

    // Extract time suffix from the name if it has one (legacy format e.g., "Title|10:30")
    final hasTime = name.contains('|');
    final nameWithoutTime = hasTime ? name.split('|').first : name;
    final parsedScheduledTime = hasTime ? name.split('|').last : null;

    final String? scheduledTime = data['scheduledTime'] as String? ?? parsedScheduledTime;

    if (rawSubTasks != null) {
      parsedSubTasks = rawSubTasks
          .map((item) => SubTask.fromFirestore(Map<String, dynamic>.from(item as Map)))
          .toList();
    } else if (nameWithoutTime.contains('::')) {
      // Legacy nested checklist parsing fallback
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

    // Clean name (without '::' and without '|10:30')
    String cleanName = nameWithoutTime;
    if (nameWithoutTime.contains('::')) {
      cleanName = nameWithoutTime.split('::').first.trim();
    }

    return Task(
      id: doc.id,
      activityId: data['activityId'] as String? ?? '',
      taskName: cleanName,
      timestamp: dateTime,
      checked: data['checked'] as bool? ?? false,
      symbolType: data['symbolType'] as String?,
      symbolValue: data['symbolValue'] as String?,
      scheduledTime: scheduledTime,
      completionTime: firestoreCompletionTime?.toDate(),
      subTasks: parsedSubTasks,
      notes: data['notes'] as String?,
    );
  }

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
    String? notes,
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
      notes: notes ?? this.notes,
    );
  }
}
