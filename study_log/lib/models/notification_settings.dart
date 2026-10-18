import 'package:flutter/material.dart';

/// Represents a single user-configured study reminder slot with custom title and time.
class StudyReminderSlot {
  final String id;
  final String title;
  final TimeOfDay time;
  final bool isEnabled;

  const StudyReminderSlot({
    required this.id,
    required this.title,
    required this.time,
    this.isEnabled = true,
  });

  StudyReminderSlot copyWith({
    String? id,
    String? title,
    TimeOfDay? time,
    bool? isEnabled,
  }) {
    return StudyReminderSlot(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'hour': time.hour,
      'minute': time.minute,
      'isEnabled': isEnabled,
    };
  }

  factory StudyReminderSlot.fromMap(Map<String, dynamic> map) {
    return StudyReminderSlot(
      id: map['id'] as String? ?? 'slot_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? 'Study Reminder',
      time: TimeOfDay(
        hour: (map['hour'] as num?)?.toInt() ?? 9,
        minute: (map['minute'] as num?)?.toInt() ?? 0,
      ),
      isEnabled: map['isEnabled'] as bool? ?? true,
    );
  }
}

/// Configuration model representing user notification preferences.
class NotificationSettings {
  final bool enabled;
  final int repeatIntervalHours;

  // Morning Briefing (Tier 1)
  final bool morningBriefingEnabled;
  final TimeOfDay morningBriefingTime;

  // Revision Due (Tier 2)
  final bool revisionDueEnabled;
  final TimeOfDay revisionDueTime;

  // Course / Daily Study Reminders (Configurable slots)
  final bool courseDueEnabled;
  final TimeOfDay courseDueTime;
  final List<StudyReminderSlot> studyReminderSlots;

  // Streak Saver (Tier 3 & 4)
  final bool streakSaverEnabled;
  final TimeOfDay streakSaverTime;

  // Course Deadlines
  final bool deadlineEnabled;
  final int deadlineDaysBefore;

  const NotificationSettings({
    this.enabled = true,
    this.repeatIntervalHours = 2,
    this.morningBriefingEnabled = true,
    this.morningBriefingTime = const TimeOfDay(hour: 8, minute: 0),
    this.revisionDueEnabled = true,
    this.revisionDueTime = const TimeOfDay(hour: 4, minute: 0),
    this.courseDueEnabled = true,
    this.courseDueTime = const TimeOfDay(hour: 11, minute: 0),
    this.studyReminderSlots = const [
      StudyReminderSlot(
        id: 'default_study_slot',
        title: 'Morning Deep Work',
        time: TimeOfDay(hour: 9, minute: 0),
        isEnabled: true,
      ),
    ],
    this.streakSaverEnabled = true,
    this.streakSaverTime = const TimeOfDay(hour: 20, minute: 0),
    this.deadlineEnabled = true,
    this.deadlineDaysBefore = 3,
  });

  /// Alias for backward compatibility with revision interval settings.
  int get revisionIntervalHours => repeatIntervalHours;

  NotificationSettings copyWith({
    bool? enabled,
    int? repeatIntervalHours,
    bool? morningBriefingEnabled,
    TimeOfDay? morningBriefingTime,
    bool? revisionDueEnabled,
    int? revisionIntervalHours,
    TimeOfDay? revisionDueTime,
    bool? courseDueEnabled,
    TimeOfDay? courseDueTime,
    List<StudyReminderSlot>? studyReminderSlots,
    bool? streakSaverEnabled,
    TimeOfDay? streakSaverTime,
    bool? deadlineEnabled,
    int? deadlineDaysBefore,
  }) {
    final effectiveRepeatHours = repeatIntervalHours ?? revisionIntervalHours ?? this.repeatIntervalHours;
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      repeatIntervalHours: effectiveRepeatHours,
      morningBriefingEnabled: morningBriefingEnabled ?? this.morningBriefingEnabled,
      morningBriefingTime: morningBriefingTime ?? this.morningBriefingTime,
      revisionDueEnabled: revisionDueEnabled ?? this.revisionDueEnabled,
      revisionDueTime: revisionDueTime ?? this.revisionDueTime,
      courseDueEnabled: courseDueEnabled ?? this.courseDueEnabled,
      courseDueTime: courseDueTime ?? this.courseDueTime,
      studyReminderSlots: studyReminderSlots ?? this.studyReminderSlots,
      streakSaverEnabled: streakSaverEnabled ?? this.streakSaverEnabled,
      streakSaverTime: streakSaverTime ?? this.streakSaverTime,
      deadlineEnabled: deadlineEnabled ?? this.deadlineEnabled,
      deadlineDaysBefore: deadlineDaysBefore ?? this.deadlineDaysBefore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'repeatIntervalHours': repeatIntervalHours,
      'revisionIntervalHours': repeatIntervalHours,
      'morningBriefingEnabled': morningBriefingEnabled,
      'morningBriefingHour': morningBriefingTime.hour,
      'morningBriefingMinute': morningBriefingTime.minute,
      'revisionDueEnabled': revisionDueEnabled,
      'revisionDueHour': revisionDueTime.hour,
      'revisionDueMinute': revisionDueTime.minute,
      'courseDueEnabled': courseDueEnabled,
      'courseDueHour': courseDueTime.hour,
      'courseDueMinute': courseDueTime.minute,
      'studyReminderSlots': studyReminderSlots.map((s) => s.toMap()).toList(),
      'streakSaverEnabled': streakSaverEnabled,
      'streakSaverHour': streakSaverTime.hour,
      'streakSaverMinute': streakSaverTime.minute,
      'deadlineEnabled': deadlineEnabled,
      'deadlineDaysBefore': deadlineDaysBefore,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    final parsedRepeatHours = (map['repeatIntervalHours'] as num?)?.toInt() ??
        (map['revisionIntervalHours'] as num?)?.toInt() ??
        2;

    List<StudyReminderSlot> parsedSlots = const [];
    if (map['studyReminderSlots'] is List) {
      parsedSlots = (map['studyReminderSlots'] as List)
          .map((item) => StudyReminderSlot.fromMap(item as Map<String, dynamic>))
          .toList();
    }
    if (parsedSlots.isEmpty) {
      final legacyHour = map['courseDueHour'] as int? ?? 9;
      final legacyMinute = map['courseDueMinute'] as int? ?? 0;
      parsedSlots = [
        StudyReminderSlot(
          id: 'default_slot_1',
          title: 'Daily Study Session',
          time: TimeOfDay(hour: legacyHour, minute: legacyMinute),
          isEnabled: map['courseDueEnabled'] as bool? ?? true,
        ),
      ];
    }

    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? true,
      repeatIntervalHours: parsedRepeatHours,
      morningBriefingEnabled: map['morningBriefingEnabled'] as bool? ?? true,
      morningBriefingTime: TimeOfDay(
        hour: map['morningBriefingHour'] as int? ?? 8,
        minute: map['morningBriefingMinute'] as int? ?? 0,
      ),
      revisionDueEnabled: map['revisionDueEnabled'] as bool? ?? true,
      revisionDueTime: TimeOfDay(
        hour: map['revisionDueHour'] as int? ?? 4,
        minute: map['revisionDueMinute'] as int? ?? 0,
      ),
      courseDueEnabled: map['courseDueEnabled'] as bool? ?? true,
      courseDueTime: TimeOfDay(
        hour: map['courseDueHour'] as int? ?? 11,
        minute: map['courseDueMinute'] as int? ?? 0,
      ),
      studyReminderSlots: parsedSlots,
      streakSaverEnabled: map['streakSaverEnabled'] as bool? ?? true,
      streakSaverTime: TimeOfDay(
        hour: map['streakSaverHour'] as int? ?? 20,
        minute: map['streakSaverMinute'] as int? ?? 0,
      ),
      deadlineEnabled: map['deadlineEnabled'] as bool? ?? true,
      deadlineDaysBefore: map['deadlineDaysBefore'] as int? ?? 3,
    );
  }
}
