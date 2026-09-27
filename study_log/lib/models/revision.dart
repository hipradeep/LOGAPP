import 'package:cloud_firestore/cloud_firestore.dart';

/// The R1 -> R5 spaced repetition ladder.
///
/// R1 -> +1 day, R2 -> +3 days, R3 -> +7 days, R4 -> +14 days, R5 -> +30 days.
class RevisionSchedule {
  const RevisionSchedule._();

  static const int maxLevel = 5;
  static const List<int> intervalDays = <int>[1, 3, 7, 14, 30];

  /// Delay applied *after* the given level is completed, before the next
  /// level unlocks. Level 5 is terminal, so its interval is never used.
  static Duration intervalFor(int level) {
    final index = (level - 1).clamp(0, intervalDays.length - 1);
    return Duration(days: intervalDays[index]);
  }

  /// Human readable delay, e.g. "in 3 days".
  static String intervalLabel(int level) {
    final days = intervalDays[(level - 1).clamp(0, intervalDays.length - 1)];
    return days == 1 ? '1 day' : '$days days';
  }
}

enum RevisionStatus {
  /// Still progressing through the ladder.
  active,

  /// R5 completed, nothing left to revise.
  finished,
}

/// A spaced repetition record for a single completed Section.
///
/// Firestore shape:
/// ```
/// revisions/{revisionId}
///   id, courseId, sectionId, currentLevel, status,
///   nextRevisionAt, completedAt, createdAt, updatedAt
/// ```
class Revision {
  final String id;
  final String courseId;
  final String sectionId;

  /// Denormalised for display only; the ids above stay authoritative.
  final String courseTitle;
  final String sectionTitle;

  /// Short blurb shown under [sectionTitle] on the Revision list.
  final String sectionDescription;

  /// 1-based level, R1 through R5.
  final int currentLevel;
  final RevisionStatus status;

  /// When [currentLevel] unlocks.
  final DateTime nextRevisionAt;

  /// Set when the ladder finishes.
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Revision({
    required this.id,
    required this.courseId,
    required this.sectionId,
    this.courseTitle = '',
    this.sectionTitle = '',
    this.sectionDescription = '',
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
  bool isDueAt(DateTime now) => !isFinished && !now.isBefore(nextRevisionAt);

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

  /// Advances the ladder as of [at].
  ///
  /// Finishing R5 marks the revision finished; otherwise the level moves on
  /// and the next date is calculated from [at] using the new level's interval.
  Revision advance(DateTime at) {
    if (isFinished) return this;
    if (currentLevel >= RevisionSchedule.maxLevel) {
      return copyWith(
        status: RevisionStatus.finished,
        completedAt: at,
        updatedAt: at,
      );
    }
    final nextLevel = currentLevel + 1;
    return copyWith(
      currentLevel: nextLevel,
      nextRevisionAt: at.add(RevisionSchedule.intervalFor(nextLevel)),
      updatedAt: at,
    );
  }

  Revision copyWith({
    String? id,
    String? courseId,
    String? sectionId,
    String? courseTitle,
    String? sectionTitle,
    String? sectionDescription,
    int? currentLevel,
    RevisionStatus? status,
    DateTime? nextRevisionAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Revision(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sectionId: sectionId ?? this.sectionId,
      courseTitle: courseTitle ?? this.courseTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      sectionDescription: sectionDescription ?? this.sectionDescription,
      currentLevel: currentLevel ?? this.currentLevel,
      status: status ?? this.status,
      nextRevisionAt: nextRevisionAt ?? this.nextRevisionAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'courseId': courseId,
      'sectionId': sectionId,
      'courseTitle': courseTitle,
      'sectionTitle': sectionTitle,
      'sectionDescription': sectionDescription,
      'currentLevel': currentLevel,
      'status': status.name,
      'nextRevisionAt': forLocalJson
          ? nextRevisionAt.toIso8601String()
          : Timestamp.fromDate(nextRevisionAt),
      'completedAt': completedAt == null
          ? null
          : (forLocalJson
              ? completedAt!.toIso8601String()
              : Timestamp.fromDate(completedAt!)),
      'createdAt': forLocalJson
          ? createdAt.toIso8601String()
          : Timestamp.fromDate(createdAt),
      'updatedAt': forLocalJson
          ? updatedAt.toIso8601String()
          : Timestamp.fromDate(updatedAt),
    };
  }

  factory Revision.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Revision(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      courseId: map['courseId']?.toString() ?? '',
      sectionId: map['sectionId']?.toString() ?? '',
      courseTitle: map['courseTitle']?.toString() ?? '',
      sectionTitle: map['sectionTitle']?.toString() ?? '',
      sectionDescription: map['sectionDescription']?.toString() ?? '',
      currentLevel: ((map['currentLevel'] as num?)?.toInt() ?? 1)
          .clamp(1, RevisionSchedule.maxLevel),
      status: map['status']?.toString() == RevisionStatus.finished.name
          ? RevisionStatus.finished
          : RevisionStatus.active,
      nextRevisionAt: _parseDateTime(map['nextRevisionAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(map['completedAt']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}
