import 'package:flutter/material.dart';

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
  Color get color {
    if (isCompleted) return const Color(0xFF10B981);
    switch (level) {
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF0284C7);
      case 4:
        return const Color(0xFF8B5CF6);
      case 5:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF5B4DFB);
    }
  }

  /// Background tint for the level pill
  Color get bgTint {
    if (isCompleted) return const Color(0xFFECFDF5);
    switch (level) {
      case 1:
        return const Color(0xFFFEF2F2);
      case 2:
        return const Color(0xFFFFFBEB);
      case 3:
        return const Color(0xFFF0F9FF);
      case 4:
        return const Color(0xFFFAF5FF);
      case 5:
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFEEF2FF);
    }
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
