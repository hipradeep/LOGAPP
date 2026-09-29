import 'package:flutter/material.dart';

/// Configuration model representing user notification preferences.
class NotificationSettings {
  final bool enabled;
  final bool revisionDueEnabled;
  final int revisionIntervalHours;
  final TimeOfDay revisionDueTime;
  final bool courseDueEnabled;
  final TimeOfDay courseDueTime;
  final bool streakSaverEnabled;
  final TimeOfDay streakSaverTime;
  final bool deadlineEnabled;
  final int deadlineDaysBefore;

  const NotificationSettings({
    this.enabled = true,
    this.revisionDueEnabled = true,
    this.revisionIntervalHours = 2,
    this.revisionDueTime = const TimeOfDay(hour: 9, minute: 0),
    this.courseDueEnabled = true,
    this.courseDueTime = const TimeOfDay(hour: 11, minute: 0),
    this.streakSaverEnabled = true,
    this.streakSaverTime = const TimeOfDay(hour: 20, minute: 0),
    this.deadlineEnabled = true,
    this.deadlineDaysBefore = 3,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? revisionDueEnabled,
    int? revisionIntervalHours,
    TimeOfDay? revisionDueTime,
    bool? courseDueEnabled,
    TimeOfDay? courseDueTime,
    bool? streakSaverEnabled,
    TimeOfDay? streakSaverTime,
    bool? deadlineEnabled,
    int? deadlineDaysBefore,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      revisionDueEnabled: revisionDueEnabled ?? this.revisionDueEnabled,
      revisionIntervalHours: revisionIntervalHours ?? this.revisionIntervalHours,
      revisionDueTime: revisionDueTime ?? this.revisionDueTime,
      courseDueEnabled: courseDueEnabled ?? this.courseDueEnabled,
      courseDueTime: courseDueTime ?? this.courseDueTime,
      streakSaverEnabled: streakSaverEnabled ?? this.streakSaverEnabled,
      streakSaverTime: streakSaverTime ?? this.streakSaverTime,
      deadlineEnabled: deadlineEnabled ?? this.deadlineEnabled,
      deadlineDaysBefore: deadlineDaysBefore ?? this.deadlineDaysBefore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'revisionDueEnabled': revisionDueEnabled,
      'revisionIntervalHours': revisionIntervalHours,
      'revisionDueHour': revisionDueTime.hour,
      'revisionDueMinute': revisionDueTime.minute,
      'courseDueEnabled': courseDueEnabled,
      'courseDueHour': courseDueTime.hour,
      'courseDueMinute': courseDueTime.minute,
      'streakSaverEnabled': streakSaverEnabled,
      'streakSaverHour': streakSaverTime.hour,
      'streakSaverMinute': streakSaverTime.minute,
      'deadlineEnabled': deadlineEnabled,
      'deadlineDaysBefore': deadlineDaysBefore,
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? true,
      revisionDueEnabled: map['revisionDueEnabled'] as bool? ?? true,
      revisionIntervalHours: map['revisionIntervalHours'] as int? ?? 2,
      revisionDueTime: TimeOfDay(
        hour: map['revisionDueHour'] as int? ?? 9,
        minute: map['revisionDueMinute'] as int? ?? 0,
      ),
      courseDueEnabled: map['courseDueEnabled'] as bool? ?? true,
      courseDueTime: TimeOfDay(
        hour: map['courseDueHour'] as int? ?? 11,
        minute: map['courseDueMinute'] as int? ?? 0,
      ),
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
