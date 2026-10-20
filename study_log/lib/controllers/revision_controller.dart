import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/revision.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'ongoing_modules_controller.dart';
import 'progress_controller.dart';
import 'topic_revision_controller.dart';

/// Aggregates and presents module-level spaced repetition views derived
/// from [TopicRevisionController] as the single source of truth.
///
/// Under the Hybrid Roll-Up Architecture:
/// - Individual topics track true R1..R5 spaced repetition intervals in `topic_revisions`.
/// - [RevisionController] computes dynamic roll-up views ([RevisionModule]) for each module:
///   • `currentLevel`: Minimum active level among unfinished topics (or R5 if all cleared).
///   • `nextRevisionAt`: Earliest scheduled date among active topics.
///   • `dueCount`: Count of topics in this module currently due.
///   • `masteryPercentage`: Fraction of topics at R5.
/// - Batch action: Completing a module revision advances all currently due topics in that module.
class RevisionController extends ChangeNotifier {
  final CoursesController _coursesController;
  final OngoingModulesController _ongoingController;
  final DatabaseService _dbService;
  final TopicRevisionController _topicRevisionController;

  List<RevisionModule> _revisions = [];
  bool _isLoading = true;
  bool _isReconciling = false;
  bool _reconcileQueued = false;

  RevisionController({
    CoursesController? coursesController,
    OngoingModulesController? ongoingController,
    DatabaseService? databaseService,
    TopicRevisionController? topicRevisionController,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _ongoingController =
            ongoingController ?? getIt<OngoingModulesController>(),
        _dbService = databaseService ?? getIt<DatabaseService>(),
        _topicRevisionController =
            topicRevisionController ?? getIt<TopicRevisionController>() {
    _coursesController.addListener(_onCoursesChanged);
    _ongoingController.addListener(_onOngoingChanged);
    _topicRevisionController.addListener(_onTopicRevisionsChanged);
    _load();
  }

  bool _isCourseArchived(String courseId) {
    if (courseId.isEmpty) return false;
    final c = _coursesController.getCourseById(courseId);
    return c != null && c.isArchived;
  }

  List<RevisionModule> get _activeRevisions =>
      _revisions.where((r) => !_isCourseArchived(r.courseId)).toList();

  List<RevisionModule> get revisions => List.unmodifiable(_activeRevisions);
  bool get isLoading => _isLoading;

  /// Modules with topics whose current level has unlocked, soonest first.
  List<RevisionModule> get dueRevisions {
    final now = DateTime.now();
    final due = _activeRevisions.where((r) => r.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return due;
  }

  /// Modules still counting down to their next level.
  List<RevisionModule> get upcomingRevisions {
    final now = DateTime.now();
    final upcoming = _activeRevisions
        .where((r) => !r.isFinished && !r.isDueAt(now))
        .toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return upcoming;
  }

  /// Modules where 100% of enrolled topics have cleared R5.
  List<RevisionModule> get finishedRevisions {
    final done = _activeRevisions.where((r) => r.isFinished).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
    return done;
  }

  int get dueCount => dueRevisions.length;

  /// Modules due on the current calendar day (or overdue) and not yet finished.
  List<RevisionModule> get revisionsDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _activeRevisions.where((r) {
      if (r.isFinished) return false;
      final dueDay = DateTime(
        r.nextRevisionAt.year,
        r.nextRevisionAt.month,
        r.nextRevisionAt.day,
      );
      return dueDay.isAtSameMomentAs(today) || r.isDueAt(now);
    }).toList();
  }

  /// Titles of modules currently due for revision today.
  List<String> get moduleTitlesDueToday {
    final titles = <String>[];
    for (final r in revisionsDueToday) {
      final module = _ongoingController.getModuleById(r.moduleId);
      if (module != null && module.title.isNotEmpty) {
        titles.add(module.title);
      }
    }
    return titles;
  }

  /// Every record in one continuous list, most urgent due date first.
  List<RevisionModule> get scheduledRevisions =>
      _sorted(List<RevisionModule>.of(_activeRevisions));

  /// Records matching a level filter, or all when [level] is null.
  List<RevisionModule> revisionsAtLevel(int? level) {
    if (level == null) return scheduledRevisions;
    return scheduledRevisions.where((r) => r.currentLevel == level).toList();
  }

  /// Returns the computed roll-up revision for [moduleId], or by [moduleTitle].
  RevisionModule? revisionForModule(String moduleId, {String? moduleTitle}) {
    for (final revision in _revisions) {
      if (moduleId.isNotEmpty && revision.moduleId == moduleId) return revision;
      if (moduleTitle != null && moduleTitle.trim().isNotEmpty) {
        final mod = _ongoingController.getModuleById(revision.moduleId);
        if (mod != null &&
            mod.title.trim().toLowerCase() == moduleTitle.trim().toLowerCase()) {
          return revision;
        }
      }
    }
    return null;
  }

  /// Completes the currently due revision level for the module by batch-advancing
  /// all due topics in that module through [TopicRevisionController].
  Future<bool> completeCurrentLevel(String revisionId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final modId = revisionId.startsWith('mod_rev_')
        ? revisionId.substring('mod_rev_'.length)
        : revisionId;

    final targetIndex = _revisions.indexWhere(
      (r) => r.id == revisionId || r.moduleId == modId || r.moduleId == revisionId,
    );
    if (targetIndex == -1) return false;

    final currentModRev = _revisions[targetIndex];
    if (currentModRev.isFinished) return false;

    final targetModuleId = currentModRev.moduleId;
    final topics = _topicRevisionController.topicRevisions
        .where((tr) => tr.moduleId == targetModuleId)
        .toList();

    // Advance topics that are due, or topics sitting at the current module level
    final dueTopics = topics.where((tr) => tr.isDueAt(now) && !tr.isFinished).toList();
    final toAdvance = dueTopics.isNotEmpty
        ? dueTopics
        : topics.where((tr) => tr.currentLevel == currentModRev.currentLevel && !tr.isFinished).toList();

    if (toAdvance.isEmpty) return false;

    for (final tr in toAdvance) {
      await _topicRevisionController.completeCurrentLevel(tr.id, at: now);
    }

    final courseTitle =
        _coursesController.getCourseById(currentModRev.courseId)?.title ?? '';
    final moduleTitle = _ongoingController.moduleTitleFor(currentModRev.moduleId);

    final log = StudyLog(
      id: 'rev_${currentModRev.id}_${now.millisecondsSinceEpoch}',
      type: StudyLogType.revisionModuleCompleted,
      courseId: currentModRev.courseId,
      courseTitle: courseTitle,
      moduleId: currentModRev.moduleId,
      moduleTitle: moduleTitle,
      revisionLevel: currentModRev.currentLevel,
      timestamp: now,
      createdAt: now,
    );
    await DatabaseService.instance.addStudyLog(log);
    if (getIt.isRegistered<ProgressController>()) {
      unawaited(getIt<ProgressController>().refresh());
    }

    _recomputeRollups();
    return true;
  }

  /// Sends all topics in this module back to R1 in [TopicRevisionController].
  Future<void> resetRevision(String revisionId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final modId = revisionId.startsWith('mod_rev_')
        ? revisionId.substring('mod_rev_'.length)
        : revisionId;

    final topics = _topicRevisionController.topicRevisions
        .where((tr) => tr.moduleId == modId || tr.id == revisionId)
        .toList();

    for (final tr in topics) {
      await _topicRevisionController.resetTopicRevision(tr.id, at: now);
    }
    _recomputeRollups();
  }

  /// Removes all topic revisions for this module and cleans up legacy storage.
  Future<void> deleteRevision(String revisionId) async {
    if (revisionId.isEmpty) return;

    final modId = revisionId.startsWith('mod_rev_')
        ? revisionId.substring('mod_rev_'.length)
        : revisionId;

    final topics = _topicRevisionController.topicRevisions
        .where((tr) => tr.moduleId == modId || tr.id == revisionId)
        .toList();

    for (final tr in topics) {
      await _topicRevisionController.deleteTopicRevision(tr.id);
    }

    try {
      await _dbService.deleteRevision(revisionId);
      if (modId != revisionId) {
        await _dbService.deleteRevision(modId);
      }
      await _dbService.saveRevisionTopics(revisionId, []);
    } catch (e) {
      debugPrint('Error cleaning up legacy revision records: $e');
    }

    _recomputeRollups();
  }

  /// Enrolls all completed topics (or all topics if none completed) of [moduleId]
  /// into [TopicRevisionController] spaced repetition.
  Future<RevisionModule> createOrEnsureRevision({
    required String courseId,
    required String moduleId,
    String? courseTitle,
    String? moduleTitle,
    String? moduleDescription,
  }) async {
    final existing = revisionForModule(moduleId, moduleTitle: moduleTitle);
    if (existing != null) {
      return existing;
    }

    final baseTopics = await _dbService.getTopics(moduleId: moduleId);
    var toEnroll = baseTopics.where((t) => t.isCompleted).toList();
    if (toEnroll.isEmpty) {
      toEnroll = baseTopics;
    }

    final now = DateTime.now();
    for (final topic in toEnroll) {
      await _topicRevisionController.enrollTopicInRevision(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topic.id,
        title: topic.title,
        anchorDate: now,
      );
    }

    _recomputeRollups();
    unawaited(_ongoingController.refresh());
    return revisionForModule(moduleId, moduleTitle: moduleTitle) ??
        RevisionModule(
          id: 'mod_rev_$moduleId',
          courseId: courseId,
          moduleId: moduleId,
          currentLevel: 1,
          status: RevisionStatus.active,
          nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
          createdAt: now,
          updatedAt: now,
          totalTopicsCount: toEnroll.length,
          dueTopicsCount: 0,
        );
  }

  /// Removes all topic revisions belonging to [courseId].
  Future<void> removeRevisionsForCourse(String courseId) async {
    if (courseId.isEmpty) return;
    await _topicRevisionController.removeRevisionsForCourse(courseId);
    try {
      final dbRevisions = await _dbService.getRevisions();
      for (final r in dbRevisions.where((r) => r.courseId == courseId)) {
        await _dbService.deleteRevision(r.id);
      }
    } catch (_) {}
    _recomputeRollups();
  }

  void _onCoursesChanged() {
    unawaited(_load());
  }

  void _onOngoingChanged() {
    unawaited(reconcile());
  }

  void _onTopicRevisionsChanged() {
    _recomputeRollups();
  }

  Future<void> _load() async {
    await reconcile();
  }

  /// Reconciles state:
  /// 1. Migrates any legacy records from `revisions` SQLite table to `topic_revisions`.
  /// 2. Purges records belonging to archived courses.
  /// 3. Computes active module roll-up views.
  Future<void> reconcile() async {
    if (_isReconciling) {
      _reconcileQueued = true;
      return;
    }
    _isReconciling = true;

    try {
      do {
        _reconcileQueued = false;
        await _performMigrationAndReconcile();
      } while (_reconcileQueued);
    } catch (e) {
      debugPrint('Error reconciling revisions: $e');
    } finally {
      _isReconciling = false;
      _isLoading = false;
      _recomputeRollups();
    }
  }

  Future<void> _performMigrationAndReconcile() async {
    try {
      final legacyRevisions = await _dbService.getRevisions();
      if (legacyRevisions.isNotEmpty) {
        final existingTopicRevisions = _topicRevisionController.topicRevisions;
        final enrolledModuleIds =
            existingTopicRevisions.map((tr) => tr.moduleId).toSet();

        for (final legacy in legacyRevisions) {
          if (_isCourseArchived(legacy.courseId)) {
            await _dbService.deleteRevision(legacy.id);
            continue;
          }

          if (!enrolledModuleIds.contains(legacy.moduleId)) {
            final baseTopics =
                await _dbService.getTopics(moduleId: legacy.moduleId);
            var toEnroll = baseTopics.where((t) => t.isCompleted).toList();
            if (toEnroll.isEmpty) {
              toEnroll = baseTopics;
            }

            for (final t in toEnroll) {
              final newTr = await _topicRevisionController.enrollTopicInRevision(
                courseId: legacy.courseId,
                moduleId: legacy.moduleId,
                topicId: t.id,
                title: t.title,
                anchorDate: legacy.createdAt,
              );

              if (legacy.currentLevel > 1 || legacy.isFinished) {
                final updatedTr = newTr.copyWith(
                  currentLevel: legacy.currentLevel,
                  status: legacy.status,
                  nextRevisionAt: legacy.nextRevisionAt,
                  completedAt: legacy.completedAt,
                );
                try {
                  await _dbService.updateTopicRevision(updatedTr);
                } catch (_) {}
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error migrating legacy module revisions: $e');
    }
  }

  void _recomputeRollups() {
    final Map<String, List<TopicRevision>> byModule = {};
    for (final tr in _topicRevisionController.topicRevisions) {
      if (_isCourseArchived(tr.courseId)) continue;
      byModule.putIfAbsent(tr.moduleId, () => []).add(tr);
    }

    final rollups = <RevisionModule>[];
    for (final entry in byModule.entries) {
      final moduleId = entry.key;
      final topics = entry.value;
      if (topics.isEmpty) continue;
      final courseId = topics.first.courseId;
      rollups.add(RevisionModule.fromTopicRevisions(
        courseId: courseId,
        moduleId: moduleId,
        topics: topics,
      ));
    }

    _revisions = _sorted(rollups);
    _isLoading = false;
    notifyListeners();
  }

  static List<RevisionModule> _sorted(List<RevisionModule> list) {
    list.sort((a, b) {
      if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
      return a.nextRevisionAt.compareTo(b.nextRevisionAt);
    });
    return list;
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesChanged);
    _ongoingController.removeListener(_onOngoingChanged);
    _topicRevisionController.removeListener(_onTopicRevisionsChanged);
    super.dispose();
  }
}
