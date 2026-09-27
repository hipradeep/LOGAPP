import 'package:flutter/material.dart';

import '../theme/revision_level_palette.dart';

/// The view mode shown on the Calendar screen.
enum CalendarViewMode {
  month('Month'),
  week('Week'),
  agenda('Agenda');

  const CalendarViewMode(this.label);
  final String label;
}

/// Represents an event on the study calendar:
/// either a scheduled revision (R1..R5) or a completed study milestone.
class CalendarEvent {
  final String id;
  final String revisionId;
  final String topicTitle;
  final String courseTitle;
  final String moduleTitle;
  final String courseId;
  final String moduleId;
  final int level;
  final DateTime date;
  final String time;
  final bool isCompleted;
  final DateTime? completedAt;
  final String notes;

  const CalendarEvent({
    required this.id,
    required this.revisionId,
    required this.topicTitle,
    required this.courseTitle,
    required this.moduleTitle,
    this.courseId = '',
    this.moduleId = '',
    required this.level,
    required this.date,
    required this.time,
    this.isCompleted = false,
    this.completedAt,
    this.notes = '',
  });

  /// Level label, e.g. "R1"
  String get levelLabel => 'R$level';

  /// Breadcrumb format e.g. "DSA → Arrays"
  String get breadcrumb {
    if (courseTitle.isNotEmpty && moduleTitle.isNotEmpty) {
      return '$courseTitle → $moduleTitle';
    }
    if (courseTitle.isNotEmpty) return courseTitle;
    return moduleTitle;
  }

  /// Color associated with this revision level or completion
  Color color(BuildContext context) {
    if (isCompleted) return RevisionLevelPalette.completed(context).foreground;
    return RevisionLevelPalette.of(context, level).foreground;
  }

  /// Background tint for the level pill
  Color bgTint(BuildContext context) {
    if (isCompleted) return RevisionLevelPalette.completed(context).background;
    return RevisionLevelPalette.of(context, level).background;
  }

  /// Border tint for the level pill
  Color borderTint(BuildContext context) {
    if (isCompleted) return RevisionLevelPalette.completed(context).border;
    return RevisionLevelPalette.of(context, level).border;
  }

  CalendarEvent copyWith({
    String? id,
    String? revisionId,
    String? topicTitle,
    String? courseTitle,
    String? moduleTitle,
    String? courseId,
    String? moduleId,
    int? level,
    DateTime? date,
    String? time,
    bool? isCompleted,
    DateTime? completedAt,
    String? notes,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      revisionId: revisionId ?? this.revisionId,
      topicTitle: topicTitle ?? this.topicTitle,
      courseTitle: courseTitle ?? this.courseTitle,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      level: level ?? this.level,
      date: date ?? this.date,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}
