import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/revision_module.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'progress_controller.dart';

/// Manages the spaced repetition ladder for individual [Topic] entities.
///
/// Follows the R1 -> R5 schedule:
/// R1 -> +1 day, R2 -> +3 days, R3 -> +7 days, R4 -> +14 days, R5 -> +30 days.
///
/// Policy:
/// - Manual enrollment only: topics enter revision only when explicitly requested
///   by the user (no automatic enrollment upon topic completion).
/// - Advancing a level is explicit: user reviews the topic and taps "Revise"
///   or completes a study session for that topic.
class TopicRevisionController extends ChangeNotifier {
  final CoursesController _coursesController;
  final DatabaseService _dbService;

  StreamSubscription<List<TopicRevision>>? _subscription;
  List<TopicRevision> _topicRevisions = [];
  bool _isLoading = true;

  TopicRevisionController({
    CoursesController? coursesController,
    DatabaseService? databaseService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _dbService = databaseService ?? getIt<DatabaseService>() {
    _coursesController.addListener(_onCoursesChanged);
    _load();
  }

  bool _isCourseArchived(String courseId) {
    if (courseId.isEmpty) return false;
    final c = _coursesController.getCourseById(courseId);
    return c != null && c.isArchived;
  }

  List<TopicRevision> get _activeTopicRevisions =>
      _topicRevisions.where((tr) => !_isCourseArchived(tr.courseId)).toList();

  List<TopicRevision> get topicRevisions =>
      List.unmodifiable(_activeTopicRevisions);

  bool get isLoading => _isLoading;

  /// Topic revisions whose current level has unlocked, soonest first.
  List<TopicRevision> get dueTopics {
    final now = DateTime.now();
    final due = _activeTopicRevisions.where((tr) => tr.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return due;
  }

  /// Topic revisions still counting down to their next level.
  List<TopicRevision> get upcomingTopics {
    final now = DateTime.now();
    final upcoming = _activeTopicRevisions
        .where((tr) => !tr.isFinished && !tr.isDueAt(now))
        .toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return upcoming;
  }

  /// Topic revisions that have cleared R5.
  List<TopicRevision> get finishedTopics {
    final done = _activeTopicRevisions.where((tr) => tr.isFinished).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
    return done;
  }

  int get dueCount => dueTopics.length;

  /// Topics due on the current calendar day (or overdue) and not yet finished.
  List<TopicRevision> get topicsDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _activeTopicRevisions.where((tr) {
      if (tr.isFinished) return false;
      final dueDay = DateTime(
        tr.nextRevisionAt.year,
        tr.nextRevisionAt.month,
        tr.nextRevisionAt.day,
      );
      return dueDay.isAtSameMomentAs(today) || tr.isDueAt(now);
    }).toList();
  }

  /// Full scheduled list: active records by due date first, finished at the bottom.
  List<TopicRevision> get scheduledTopics =>
      _sorted(List<TopicRevision>.of(_activeTopicRevisions));

  /// Filtered by 1-based level (R1..R5), or all when [level] is null.
  List<TopicRevision> topicsAtLevel(int? level) {
    if (level == null) return scheduledTopics;
    return scheduledTopics.where((tr) => tr.currentLevel == level).toList();
  }

  /// Returns the revision record for [topicId], or null if not enrolled.
  TopicRevision? topicRevisionFor(String topicId) {
    if (topicId.isEmpty) return null;
    for (final tr in _topicRevisions) {
      if (tr.topicId == topicId) return tr;
    }
    return null;
  }

  /// Returns all active topic revisions for [moduleId].
  List<TopicRevision> revisionsForModule(String moduleId) {
    if (moduleId.isEmpty) return const [];
    return _activeTopicRevisions.where((tr) => tr.moduleId == moduleId).toList();
  }

  /// Fast boolean check if a topic is enrolled in revision.
  bool isTopicEnrolled(String topicId) => topicRevisionFor(topicId) != null;

  /// Manually enrolls a topic into spaced repetition (starts at R1, unlocking tomorrow).
  ///
  /// If the topic is already enrolled, returns the existing record without duplicating.
  Future<TopicRevision> enrollTopicInRevision({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String title,
    DateTime? anchorDate,
  }) async {
    final existing = topicRevisionFor(topicId);
    if (existing != null) {
      return existing;
    }

    final now = anchorDate ?? DateTime.now();
    final newRecord = TopicRevision(
      id: 'topic_rev_${topicId.isNotEmpty ? topicId : now.millisecondsSinceEpoch}_${now.millisecondsSinceEpoch}',
      courseId: courseId,
      moduleId: moduleId,
      topicId: topicId,
      title: title,
      currentLevel: 1,
      status: RevisionStatus.active,
      levelStatus: TopicStatus.notStarted,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      createdAt: now,
      updatedAt: now,
    );

    _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..add(newRecord));
    _isLoading = false;
    notifyListeners();

    try {
      await _dbService.addTopicRevision(newRecord);
    } catch (e) {
      debugPrint('Error enrolling topic in revision: $e');
    }

    return newRecord;
  }

  /// Advances the current level for the target topic revision.
  ///
  /// Writes a [StudyLogType.revisionCompleted] study log so activity feeds and streaks update.
  Future<bool> completeCurrentLevel(String id, {DateTime? at, int? durationMinutes}) async {
    final now = at ?? DateTime.now();
    final index = _topicRevisions.indexWhere((tr) => tr.id == id);
    if (index == -1) return false;

    final current = _topicRevisions[index];
    if (current.isFinished) return false;

    // STRICT INVARIANT: Under no circumstances can a topic advance to the next level before its due date.
    if (!current.isDueAt(now)) {
      if (durationMinutes != null && durationMinutes > 0) {
        final courseTitle = _coursesController.getCourseById(current.courseId)?.title ?? '';
        final log = StudyLog(
          id: 'rev_topic_${current.id}_${now.millisecondsSinceEpoch}',
          type: StudyLogType.revisionCompleted,
          courseId: current.courseId,
          courseTitle: courseTitle,
          moduleId: current.moduleId,
          moduleTitle: '',
          topicId: current.topicId,
          topicTitle: current.title,
          revisionLevel: current.currentLevel,
          durationMinutes: durationMinutes,
          timestamp: now,
          createdAt: now,
        );
        try {
          await DatabaseService.instance.addStudyLog(log);
          if (getIt.isRegistered<ProgressController>()) {
            unawaited(getIt<ProgressController>().refresh());
          }
        } catch (e) {
          debugPrint('Error logging early topic revision completion: $e');
        }
      }
      await setLevelStatus(id, TopicStatus.completed, at: now);
      return false;
    }

    final advanced = current.advance(now);
    _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = advanced);
    notifyListeners();

    // 1. Persist updated topic revision
    try {
      await _dbService.updateTopicRevision(advanced);
    } catch (e) {
      debugPrint('Error updating topic revision: $e');
    }

    // 2. Record revision study log
    final courseTitle = _coursesController.getCourseById(current.courseId)?.title ?? '';
    final log = StudyLog(
      id: 'rev_topic_${current.id}_${now.millisecondsSinceEpoch}',
      type: StudyLogType.revisionCompleted,
      courseId: current.courseId,
      courseTitle: courseTitle,
      moduleId: current.moduleId,
      moduleTitle: '',
      topicId: current.topicId,
      topicTitle: current.title,
      revisionLevel: current.currentLevel,
      durationMinutes: durationMinutes,
      timestamp: now,
      createdAt: now,
    );

    try {
      await DatabaseService.instance.addStudyLog(log);
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    } catch (e) {
      debugPrint('Error logging topic revision completion: $e');
    }

    return true;
  }

  /// Toggles the levelStatus for a topic revision when the leading checkmark is tapped.
  ///
  /// Transition flow:
  /// - `TopicStatus.notStarted` -> `TopicStatus.inProgress`
  /// - `TopicStatus.inProgress` -> `TopicStatus.completed`:
  ///    - If on/after due date (`isDueAt(now)`), completing advances to the next revision level
  ///      (where its levelStatus resets fresh to notStarted).
  ///    - If before due date, marks as completed for the current cycle without advancing level.
  /// - `TopicStatus.completed` -> `TopicStatus.notStarted`: unchecks/resets back to not started.
  Future<bool> toggleLevelStatus(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final index = _topicRevisions.indexWhere((tr) => tr.id == id);
    if (index == -1) return false;

    final current = _topicRevisions[index];
    if (current.isFinished) return false;

    switch (current.levelStatus) {
      case TopicStatus.notStarted:
        // First tap: move from notStarted to inProgress
        final updated = current.copyWith(
          levelStatus: TopicStatus.inProgress,
          updatedAt: now,
        );
        _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = updated);
        notifyListeners();

        try {
          await _dbService.updateTopicRevision(updated);
        } catch (e) {
          debugPrint('Error updating topic revision status: $e');
        }
        return true;

      case TopicStatus.inProgress:
        // Second tap: move from inProgress to completed
        if (current.isDueAt(now)) {
          // If due date has arrived/passed, completing advances to next level
          return completeCurrentLevel(id, at: now);
        } else {
          // If before due date, mark completed for this level without advancing
          final updated = current.copyWith(
            levelStatus: TopicStatus.completed,
            updatedAt: now,
          );
          _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = updated);
          notifyListeners();

          try {
            await _dbService.updateTopicRevision(updated);
          } catch (e) {
            debugPrint('Error updating topic revision status: $e');
          }
          return true;
        }

      case TopicStatus.completed:
        // Third tap: uncheck/cycle back to notStarted
        final updated = current.copyWith(
          levelStatus: TopicStatus.notStarted,
          updatedAt: now,
        );
        _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = updated);
        notifyListeners();

        try {
          await _dbService.updateTopicRevision(updated);
        } catch (e) {
          debugPrint('Error updating topic revision status: $e');
        }
        return true;
    }
  }

  /// Explicitly sets the [levelStatus] for a topic revision.
  Future<bool> setLevelStatus(String id, TopicStatus status, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final index = _topicRevisions.indexWhere((tr) => tr.id == id);
    if (index == -1) return false;

    final current = _topicRevisions[index];
    if (current.isFinished) return false;

    if (status == TopicStatus.completed && current.isDueAt(now)) {
      return completeCurrentLevel(id, at: now);
    }

    final updated = current.copyWith(
      levelStatus: status,
      updatedAt: now,
    );

    _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = updated);
    notifyListeners();

    try {
      await _dbService.updateTopicRevision(updated);
    } catch (e) {
      debugPrint('Error updating topic revision levelStatus: $e');
    }
    return true;
  }

  /// Sends a topic revision back to R1, unlocking tomorrow.
  Future<void> resetTopicRevision(String id, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final index = _topicRevisions.indexWhere((tr) => tr.id == id);
    if (index == -1) return;

    final reset = _topicRevisions[index].copyWith(
      currentLevel: 1,
      status: RevisionStatus.active,
      levelStatus: TopicStatus.notStarted,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      clearCompletedAt: true,
      updatedAt: now,
    );

    _topicRevisions = _sorted(List<TopicRevision>.of(_topicRevisions)..[index] = reset);
    notifyListeners();

    try {
      await _dbService.updateTopicRevision(reset);
    } catch (e) {
      debugPrint('Error resetting topic revision: $e');
    }
  }

  /// Deletes a topic revision record.
  Future<void> deleteTopicRevision(String id) async {
    if (id.isEmpty) return;
    _topicRevisions = _topicRevisions.where((tr) => tr.id != id).toList();
    notifyListeners();

    try {
      await _dbService.deleteTopicRevision(id);
    } catch (e) {
      debugPrint('Error deleting topic revision: $e');
    }
  }

  /// Deletes a topic revision by its [topicId].
  Future<void> deleteByTopicId(String topicId) async {
    if (topicId.isEmpty) return;
    _topicRevisions = _topicRevisions.where((tr) => tr.topicId != topicId).toList();
    notifyListeners();

    try {
      await _dbService.deleteTopicRevisionByTopicId(topicId);
    } catch (e) {
      debugPrint('Error deleting topic revision by topicId: $e');
    }
  }

  /// Removes all topic revisions belonging to [courseId].
  Future<void> removeRevisionsForCourse(String courseId) async {
    if (courseId.isEmpty) return;
    final toRemove = _topicRevisions.where((tr) => tr.courseId == courseId).toList();
    if (toRemove.isEmpty) return;

    _topicRevisions = _topicRevisions.where((tr) => tr.courseId != courseId).toList();
    notifyListeners();

    for (final tr in toRemove) {
      try {
        await _dbService.deleteTopicRevision(tr.id);
      } catch (_) {}
    }
  }

  /// Removes all topic revisions belonging to [moduleId].
  Future<void> removeRevisionsForModule(String moduleId) async {
    if (moduleId.isEmpty) return;
    final toRemove = _topicRevisions.where((tr) => tr.moduleId == moduleId).toList();
    if (toRemove.isEmpty) return;

    _topicRevisions = _topicRevisions.where((tr) => tr.moduleId != moduleId).toList();
    notifyListeners();

    for (final tr in toRemove) {
      try {
        await _dbService.deleteTopicRevision(tr.id);
      } catch (_) {}
    }
  }

  Future<void> refresh() => _load();

  /// Loads topic revisions from SQLite cache and subscribes to streams.
  Future<void> loadRevisions() => _load();

  Future<void> _load() async {
    final cached = await _dbService.getTopicRevisions();
    if (cached.isNotEmpty) {
      _topicRevisions = _sorted(cached);
      _isLoading = false;
      notifyListeners();
      unawaited(_reconcileDueEarlyCompletions(cached));
    }
    _listenToDatabase();
  }

  void _listenToDatabase() {
    _subscription?.cancel();
    try {
      _subscription = _dbService.streamTopicRevisions().listen(
        (remote) {
          _topicRevisions = _sorted(remote);
          _isLoading = false;
          notifyListeners();
          unawaited(_reconcileDueEarlyCompletions(remote));
        },
        onError: (Object error) {
          debugPrint('Error streaming topic revisions: $error');
        },
      );
    } catch (e) {
      debugPrint('Topic revision stream unavailable: $e');
    }
  }

  /// Automatically advances early-completed revisions once their scheduled due date has arrived.
  Future<void> _reconcileDueEarlyCompletions(List<TopicRevision> records) async {
    final now = DateTime.now();
    for (final tr in records) {
      if (!tr.isFinished && tr.levelStatus == TopicStatus.completed && tr.isDueAt(now)) {
        await completeCurrentLevel(tr.id, at: now);
      }
    }
  }

  void _onCoursesChanged() {
    unawaited(_load());
  }

  static List<TopicRevision> _sorted(List<TopicRevision> list) {
    list.sort((a, b) {
      if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
      return a.nextRevisionAt.compareTo(b.nextRevisionAt);
    });
    return list;
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesChanged);
    _subscription?.cancel();
    super.dispose();
  }
}
