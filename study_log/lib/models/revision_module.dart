import 'topic_revision.dart';

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

/// A spaced repetition roll-up view for a completed Module.
///
/// Under the Hybrid Roll-Up Architecture, `TopicRevision` is the single
/// source of truth for spaced repetition intervals. `RevisionModule` acts as an
/// aggregator/computed view reflecting the collective status of its topics.
class RevisionModule {
  final String id;
  final String courseId;
  final String moduleId;

  /// 1-based level, R1 through R5. Derived from the lowest active topic level.
  final int currentLevel;
  final RevisionStatus status;

  /// When [currentLevel] unlocks (earliest due date among active topics).
  final DateTime nextRevisionAt;

  /// Set when all topics have cleared the ladder.
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Roll-up statistics computed from the module's topics
  final int totalTopicsCount;
  final int dueTopicsCount;
  final int masteredTopicsCount;

  const RevisionModule({
    required this.id,
    required this.courseId,
    required this.moduleId,
    required this.currentLevel,
    required this.status,
    required this.nextRevisionAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.totalTopicsCount = 0,
    this.dueTopicsCount = 0,
    this.masteredTopicsCount = 0,
  });

  bool get isFinished => status == RevisionStatus.finished;

  String get levelLabel => 'R$currentLevel';

  /// When this module was last revised, or null if it has not undergone any revision yet.
  DateTime? get lastRevisionAt => currentLevel > 1 ? (completedAt ?? updatedAt) : null;

  int get levelsRemaining =>
      isFinished ? 0 : (RevisionSchedule.maxLevel - currentLevel + 1);

  /// Fraction of the ladder already cleared, 0.0 - 1.0.
  double get ladderProgress =>
      isFinished ? 1.0 : (currentLevel - 1) / RevisionSchedule.maxLevel;

  /// Mastery percentage: proportion of topics in this module that reached R5 (0.0 - 1.0).
  double get masteryPercentage =>
      totalTopicsCount > 0 ? (masteredTopicsCount / totalTopicsCount) : 0.0;

  /// True if any topic in this module is currently due for revision.
  bool get hasDueTopics => dueTopicsCount > 0;

  /// True when [currentLevel] has unlocked and is waiting to be revised.
  bool isDueAt(DateTime now) {
    if (isFinished) return false;
    if (dueTopicsCount > 0) return true;
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

  /// Creates a roll-up [RevisionModule] dynamically derived from a list of [TopicRevision]s.
  factory RevisionModule.fromTopicRevisions({
    required String courseId,
    required String moduleId,
    required List<TopicRevision> topics,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final total = topics.length;
    final mastered = topics.where((t) => t.isFinished).length;
    final dueCount = topics.where((t) => t.isDueAt(currentTime)).length;
    final isAllFinished = topics.isNotEmpty && topics.every((t) => t.isFinished);
    final activeTopics = topics.where((t) => !t.isFinished).toList();

    int level = 1;
    if (isAllFinished) {
      level = RevisionSchedule.maxLevel;
    } else if (activeTopics.isNotEmpty) {
      level = activeTopics
          .map((t) => t.currentLevel)
          .reduce((a, b) => a < b ? a : b)
          .clamp(1, RevisionSchedule.maxLevel);
    }

    DateTime nextRev;
    if (activeTopics.isNotEmpty) {
      activeTopics.sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
      nextRev = activeTopics.first.nextRevisionAt;
    } else if (topics.isNotEmpty) {
      nextRev = topics.map((t) => t.nextRevisionAt).reduce((a, b) => a.isAfter(b) ? a : b);
    } else {
      nextRev = currentTime.add(RevisionSchedule.intervalFor(1));
    }

    DateTime created = currentTime;
    DateTime updated = currentTime;
    DateTime? completed;

    if (topics.isNotEmpty) {
      created = topics.map((t) => t.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
      updated = topics.map((t) => t.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
      if (isAllFinished) {
        final finishedDates = topics.map((t) => t.completedAt ?? t.updatedAt).toList();
        completed = finishedDates.reduce((a, b) => a.isAfter(b) ? a : b);
      }
    }

    return RevisionModule(
      id: 'mod_rev_$moduleId',
      courseId: courseId,
      moduleId: moduleId,
      currentLevel: level,
      status: isAllFinished ? RevisionStatus.finished : RevisionStatus.active,
      nextRevisionAt: nextRev,
      completedAt: completed,
      createdAt: created,
      updatedAt: updated,
      totalTopicsCount: total,
      dueTopicsCount: dueCount,
      masteredTopicsCount: mastered,
    );
  }

  /// Advances the ladder as of [at].
  RevisionModule advance(DateTime at) {
    if (isFinished) return this;
    if (currentLevel >= RevisionSchedule.maxLevel) {
      return copyWith(
        status: RevisionStatus.finished,
        completedAt: at,
        updatedAt: at,
      );
    }
    final nextLevel = currentLevel + 1;
    final interval = RevisionSchedule.intervalFor(nextLevel);
    final anchored = createdAt.add(interval);
    return copyWith(
      currentLevel: nextLevel,
      nextRevisionAt: anchored.isAfter(at) ? anchored : at.add(interval),
      updatedAt: at,
    );
  }

  RevisionModule copyWith({
    String? id,
    String? courseId,
    String? moduleId,
    int? currentLevel,
    RevisionStatus? status,
    DateTime? nextRevisionAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTopicsCount,
    int? dueTopicsCount,
    int? masteredTopicsCount,
  }) {
    return RevisionModule(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      currentLevel: currentLevel ?? this.currentLevel,
      status: status ?? this.status,
      nextRevisionAt: nextRevisionAt ?? this.nextRevisionAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTopicsCount: totalTopicsCount ?? this.totalTopicsCount,
      dueTopicsCount: dueTopicsCount ?? this.dueTopicsCount,
      masteredTopicsCount: masteredTopicsCount ?? this.masteredTopicsCount,
    );
  }

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'currentLevel': currentLevel,
      'status': status.name,
      'nextRevisionAt': nextRevisionAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalTopicsCount': totalTopicsCount,
      'dueTopicsCount': dueTopicsCount,
      'masteredTopicsCount': masteredTopicsCount,
    };
  }

  factory RevisionModule.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return RevisionModule(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      courseId: map['courseId']?.toString() ?? '',
      moduleId: map['moduleId']?.toString() ?? '',
      currentLevel: ((map['currentLevel'] as num?)?.toInt() ?? 1)
          .clamp(1, RevisionSchedule.maxLevel),
      status: map['status']?.toString() == RevisionStatus.finished.name
          ? RevisionStatus.finished
          : RevisionStatus.active,
      nextRevisionAt: _parseDateTime(map['nextRevisionAt']) ?? DateTime.now(),
      completedAt: _parseDateTime(map['completedAt']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      totalTopicsCount: (map['totalTopicsCount'] as num?)?.toInt() ?? 0,
      dueTopicsCount: (map['dueTopicsCount'] as num?)?.toInt() ?? 0,
      masteredTopicsCount: (map['masteredTopicsCount'] as num?)?.toInt() ?? 0,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}

/// Backwards compatibility alias
typedef Revision = RevisionModule;

