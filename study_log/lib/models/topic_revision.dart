import 'revision_module.dart';

/// A spaced repetition record for a single, individually tracked [Topic].
///
/// Follows the standard R1 -> R5 spaced repetition ladder:
/// R1 -> +1 day, R2 -> +3 days, R3 -> +7 days, R4 -> +14 days, R5 -> +30 days.
class TopicRevision {
  final String id;
  final String courseId;
  final String moduleId;
  final String topicId;
  final String title;

  /// 1-based level, R1 through R5.
  final int currentLevel;
  final RevisionStatus status;

  /// When [currentLevel] unlocks.
  final DateTime nextRevisionAt;

  /// Set when the ladder finishes (clears R5).
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TopicRevision({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    required this.title,
    required this.currentLevel,
    required this.status,
    required this.nextRevisionAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFinished => status == RevisionStatus.finished;

  String get levelLabel => 'R$currentLevel';

  int get levelsRemaining =>
      isFinished ? 0 : (RevisionSchedule.maxLevel - currentLevel + 1);

  /// Fraction of the ladder already cleared, 0.0 - 1.0.
  double get ladderProgress =>
      isFinished ? 1.0 : (currentLevel - 1) / RevisionSchedule.maxLevel;

  /// True when [currentLevel] has unlocked and is waiting to be revised.
  bool isDueAt(DateTime now) {
    if (isFinished) return false;
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      nextRevisionAt.year,
      nextRevisionAt.month,
      nextRevisionAt.day,
    );
    return !today.isBefore(dueDay);
  }

  /// Whole days until [currentLevel] unlocks. Negative once overdue.
  int daysUntilDue(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      nextRevisionAt.year,
      nextRevisionAt.month,
      nextRevisionAt.day,
    );
    return due.difference(today).inDays;
  }

  /// Human-friendly due status label.
  String dueStatusLabel(DateTime now) {
    if (isFinished) return 'Mastered';
    final days = daysUntilDue(now);
    if (days < 0) return 'Overdue (${-days}d)';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'In $days days';
  }

  /// Advances the record to the next level, scheduling [nextRevisionAt] from [now].
  ///
  /// If the current level is [RevisionSchedule.maxLevel], marks it [RevisionStatus.finished].
  TopicRevision advance(DateTime now) {
    if (currentLevel >= RevisionSchedule.maxLevel) {
      return copyWith(
        status: RevisionStatus.finished,
        completedAt: now,
        updatedAt: now,
      );
    }

    final nextLevel = currentLevel + 1;
    final delay = RevisionSchedule.intervalFor(currentLevel);
    return copyWith(
      currentLevel: nextLevel,
      nextRevisionAt: now.add(delay),
      updatedAt: now,
    );
  }

  TopicRevision copyWith({
    String? id,
    String? courseId,
    String? moduleId,
    String? topicId,
    String? title,
    int? currentLevel,
    RevisionStatus? status,
    DateTime? nextRevisionAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TopicRevision(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      topicId: topicId ?? this.topicId,
      title: title ?? this.title,
      currentLevel: currentLevel ?? this.currentLevel,
      status: status ?? this.status,
      nextRevisionAt: nextRevisionAt ?? this.nextRevisionAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'topicId': topicId,
      'title': title,
      'currentLevel': currentLevel,
      'status': status.name,
      'nextRevisionAt': nextRevisionAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TopicRevision.fromMap(Map<String, dynamic> map) {
    return TopicRevision(
      id: map['id'] as String,
      courseId: map['courseId'] as String? ?? '',
      moduleId: map['moduleId'] as String? ?? '',
      topicId: map['topicId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      currentLevel: map['currentLevel'] as int? ?? 1,
      status: map['status'] == 'finished'
          ? RevisionStatus.finished
          : RevisionStatus.active,
      nextRevisionAt: DateTime.parse(map['nextRevisionAt'] as String),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
