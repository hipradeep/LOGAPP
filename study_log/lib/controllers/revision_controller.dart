import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/revision.dart';
import '../models/module.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_course_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_topic_storage.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'ongoing_modules_controller.dart';
import 'progress_controller.dart';

/// Owns the R1 -> R5 spaced repetition ladder.
///
/// A revision is created the moment every topic in a Module is completed
/// (level R1, unlocking after 1 day). Each later level unlocks only after the
/// previous level is completed *and* its date has arrived:
///
///   R1 -> +1 day, R2 -> +3 days, R3 -> +7 days, R4 -> +14 days, R5 -> +30 days
///
/// Progression is automatic — there is no manual "mark done" step. Whenever a
/// due level's Module is still fully completed, [reconcile] advances the
/// record and schedules the next date from the completion moment. Finishing R5
/// flips the record to [RevisionStatus.finished].
class RevisionController extends ChangeNotifier {
  final CoursesController _coursesController;
  final OngoingModulesController _ongoingController;
  final DatabaseService _dbService;

  StreamSubscription<List<Revision>>? _revisionsSubscription;

  List<Revision> _revisions = [];
  bool _isLoading = true;
  bool _isReconciling = false;

  RevisionController({
    CoursesController? coursesController,
    OngoingModulesController? ongoingController,
    DatabaseService? databaseService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _ongoingController =
            ongoingController ?? getIt<OngoingModulesController>(),
        _dbService = databaseService ?? getIt<DatabaseService>() {
    _coursesController.addListener(_onCoursesChanged);
    // OngoingModulesController notifies on every course change and on every
    // topic toggle, add or delete, which is exactly when the ladder must be
    // re-evaluated.
    _ongoingController.addListener(_onOngoingChanged);
    _load();
  }

  bool _isCourseArchived(String courseId) {
    if (courseId.isEmpty) return false;
    final c = _coursesController.getCourseById(courseId);
    return c != null && c.isArchived;
  }

  List<Revision> get _activeRevisions =>
      _revisions.where((r) => !_isCourseArchived(r.courseId)).toList();

  List<Revision> get revisions => List.unmodifiable(_activeRevisions);
  bool get isLoading => _isLoading;

  /// Revisions whose current level has unlocked, soonest first.
  List<Revision> get dueRevisions {
    final now = DateTime.now();
    final due = _activeRevisions.where((r) => r.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return due;
  }

  /// Revisions still counting down to their next level.
  List<Revision> get upcomingRevisions {
    final now = DateTime.now();
    final upcoming = _activeRevisions.where((r) => !r.isFinished && !r.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return upcoming;
  }

  /// Revisions that have cleared R5.
  List<Revision> get finishedRevisions {
    final done = _activeRevisions.where((r) => r.isFinished).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
    return done;
  }

  int get dueCount => dueRevisions.length;

  /// Revisions due on the current calendar day (or already unlocked/overdue) and not yet finished.
  List<Revision> get revisionsDueToday {
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
  /// Finished records sink to the bottom because they have nothing left due.
  List<Revision> get scheduledRevisions => _sorted(List<Revision>.of(_activeRevisions));

  /// Records matching a level filter, or all of them when [level] is null.
  List<Revision> revisionsAtLevel(int? level) {
    if (level == null) return scheduledRevisions;
    return scheduledRevisions.where((r) => r.currentLevel == level).toList();
  }

  /// Marks the current level as revised and moves the ladder on.
  ///
  /// This is the only path that advances a level, so a record stays due — and
  /// keeps offering its "Start Rn" button — until the user acts. Returns true
  /// when something changed.
  Future<bool> completeCurrentLevel(String revisionId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final index = _revisions.indexWhere((r) => r.id == revisionId);
    if (index == -1) return false;

    final current = _revisions[index];
    if (current.isFinished) return false;

    final advanced = current.advance(now);
    _revisions = _sorted(List<Revision>.of(_revisions)..[index] = advanced);
    await LocalRevisionStorage.saveAll(_revisions);
    await LocalRevisionStorage.recordRevisionEvent(now);

    final courseTitle = _coursesController.getCourseById(current.courseId)?.title ?? '';
    final moduleTitle = _ongoingController.moduleTitleFor(current.moduleId);

    final log = StudyLog(
      id: 'rev_${current.id}_${now.millisecondsSinceEpoch}',
      type: StudyLogType.revisionModuleCompleted,
      courseId: current.courseId,
      courseTitle: courseTitle,
      moduleId: current.moduleId,
      moduleTitle: moduleTitle,
      revisionLevel: current.currentLevel,
      timestamp: now,
      createdAt: now,
    );
    await LocalStudyLogStorage.addLog(log);
    if (getIt.isRegistered<ProgressController>()) {
      unawaited(getIt<ProgressController>().refresh());
    }
    notifyListeners();
    await _pushToDatabase(advanced, isNew: false);
    return true;
  }

  /// Sends a record back to R1, re-anchored to [at] (defaults to now).
  Future<void> resetRevision(String revisionId, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final index = _revisions.indexWhere((r) => r.id == revisionId);
    if (index == -1) return;

    final reset = _revisions[index].copyWith(
      currentLevel: 1,
      status: RevisionStatus.active,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      clearCompletedAt: true,
      updatedAt: now,
    );
    _revisions = _sorted(List<Revision>.of(_revisions)..[index] = reset);
    await LocalRevisionStorage.saveAll(_revisions);
    notifyListeners();
    await _pushToDatabase(reset, isNew: false);
  }

  Revision? revisionForModule(String moduleId, {String? moduleTitle}) {
    for (final revision in _revisions) {
      if (moduleId.isNotEmpty && revision.moduleId == moduleId) return revision;
      if (moduleTitle != null && moduleTitle.trim().isNotEmpty) {
        final mod = _ongoingController.getModuleById(revision.moduleId);
        if (mod != null && mod.title.trim().toLowerCase() == moduleTitle.trim().toLowerCase()) {
          return revision;
        }
      }
    }
    return null;
  }

  void _onCoursesChanged() {
    unawaited(_load());
  }

  void _onOngoingChanged() {
    unawaited(reconcile());
  }

  Future<void> _load() async {
    final cached = await LocalRevisionStorage.loadAll();
    if (_revisions.isEmpty && cached.isNotEmpty) {
      _revisions = _sorted(cached);
      _isLoading = false;
      notifyListeners();
    }
    _listenToDatabase();
    await reconcile();
  }

  void _listenToDatabase() {
    _revisionsSubscription?.cancel();
    try {
      _revisionsSubscription = _dbService.streamRevisions().listen(
        (remote) {
          _mergeRemote(remote);
        },
        onError: (Object error) {
          debugPrint('Error streaming revisions: $error');
        },
      );
    } catch (e) {
      debugPrint('Revision stream unavailable: $e');
    }
  }

  void _mergeRemote(List<Revision> remote) {
    _revisions = _sorted(remote);
    _isLoading = false;
    notifyListeners();
  }

  /// Creates R1 for newly completed Modules and keeps a record's mirrored
  /// module description in sync.
  ///
  /// Progression is deliberately *not* done here. Levels only move forward when
  /// the user taps "Start Rn" on the revision detail screen, via
  /// [completeCurrentLevel]. Advancing automatically would consume the due
  /// window before the UI ever renders, so the button would never appear.
  bool _reconcileQueued = false;

  /// Creates R1 for newly completed Modules and keeps a record's mirrored
  /// module description in sync.
  Future<void> reconcile() async {
    if (_isReconciling) {
      _reconcileQueued = true;
      return;
    }
    _isReconciling = true;

    try {
      do {
        _reconcileQueued = false;
        await _performReconcile();
      } while (_reconcileQueued);
    } catch (e) {
      debugPrint('Error reconciling revisions: $e');
    } finally {
      _isReconciling = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates R1 for a specific completed module immediately and ensures it is persisted.
  /// Enforces that a module can only be added to revision ONE time (no duplicates).
  Future<Revision> createOrEnsureRevision({
    required String courseId,
    required String moduleId,
    String? courseTitle,
    String? moduleTitle,
    String? moduleDescription,
  }) async {
    final now = DateTime.now();

    // 1. Check in-memory list first by moduleId or title
    final existingIndex = _revisions.indexWhere(
      (r) => (moduleId.isNotEmpty && r.moduleId == moduleId) ||
          (moduleTitle != null && moduleTitle.trim().isNotEmpty &&
              r.moduleId.isNotEmpty &&
              _ongoingController.getModuleById(r.moduleId)?.title.trim().toLowerCase() == moduleTitle.trim().toLowerCase()),
    );

    if (existingIndex != -1) {
      return _revisions[existingIndex];
    }

    // 2. Check cached storage
    final cached = await LocalRevisionStorage.loadAll();
    final cachedIndex = cached.indexWhere(
      (r) => moduleId.isNotEmpty && r.moduleId == moduleId,
    );
    if (cachedIndex != -1) {
      final existingRev = cached[cachedIndex];
      if (!_revisions.any((r) => r.id == existingRev.id)) {
        _revisions = _sorted(List<Revision>.of(_revisions)..add(existingRev));
        notifyListeners();
      }
      return existingRev;
    }

    // 3. Check database
    try {
      final dbRevisions = await _dbService.getRevisions();
      final existingInDb = dbRevisions.where((r) => r.moduleId == moduleId).toList();
      if (existingInDb.isNotEmpty) {
        final existingRev = existingInDb.first;
        if (!_revisions.any((r) => r.id == existingRev.id)) {
          _revisions = _sorted(List<Revision>.of(_revisions)..add(existingRev));
          notifyListeners();
        }
        return existingRev;
      }
    } catch (_) {}

    // 4. Create revision ONLY once on explicit manual user request
    final newRevision = Revision(
      id: 'revision_${moduleId.isNotEmpty ? moduleId : 'module'}_${now.millisecondsSinceEpoch}',
      courseId: courseId,
      moduleId: moduleId,
      currentLevel: 1,
      status: RevisionStatus.active,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      createdAt: now,
      updatedAt: now,
    );

    _revisions = _sorted(List<Revision>.of(_revisions)..add(newRevision));
    _isLoading = false;
    notifyListeners();
    await _pushToDatabase(newRevision, isNew: true);
    unawaited(_ongoingController.refresh());
    return newRevision;
  }

  Future<void> _performReconcile() async {
    final working = List<Revision>.of(_revisions);
    var changed = false;

    // Only purge revisions belonging to archived courses
    final toRemove = <String>[];
    for (final revision in working) {
      if (_isCourseArchived(revision.courseId)) {
        toRemove.add(revision.id);
      }
    }

    if (toRemove.isNotEmpty) {
      working.removeWhere((r) => toRemove.contains(r.id));
      changed = true;
      for (final id in toRemove) {
        try {
          await _dbService.deleteRevision(id);
        } catch (_) {}
      }
    }

    if (changed) {
      _revisions = _sorted(working);
      notifyListeners();
      unawaited(_ongoingController.refresh());
    }
  }

  /// Deletes a single revision record entirely from memory and SQLite database.
  Future<void> deleteRevision(String revisionId) async {
    if (revisionId.isEmpty) return;

    // 1. Immediately remove from local list for surgical UI update
    _revisions = _revisions.where((r) => r.id != revisionId).toList();
    notifyListeners();

    // 2. Clean up revision topics belonging strictly to this revision
    try {
      await LocalRevisionTopicStorage.deleteTopicsForRevision(revisionId);
    } catch (e) {
      debugPrint('Error cleaning up revision topics: $e');
    }

    // 3. Delete ONLY the target revision row from SQLite
    try {
      await _dbService.deleteRevision(revisionId);
    } catch (e) {
      debugPrint('Error deleting revision from database: $e');
    }
  }

  /// Removes all existing revision records for a course.
  /// Used when a course is archived, and ensuring restored courses start
  /// fresh with a new revision ID when added to revision later.
  Future<void> removeRevisionsForCourse(String courseId) async {
    if (courseId.isEmpty) return;
    final toRemove = _revisions.where((r) => r.courseId == courseId).toList();
    if (toRemove.isEmpty) return;

    _revisions = _revisions.where((r) => r.courseId != courseId).toList();
    notifyListeners();
    unawaited(_ongoingController.refresh());

    for (final r in toRemove) {
      try {
        await _dbService.deleteRevision(r.id);
      } catch (e) {
        debugPrint('Error deleting revision for course $courseId: $e');
      }
    }
  }

  List<Course> _activeCourses() {
    return _coursesController.courses.where((course) {
      final status = course.status.toLowerCase();
      return status != 'archived';
    }).toList();
  }



  Future<void> _pushToDatabase(Revision revision, {required bool isNew}) async {
    try {
      if (isNew) {
        await _dbService.addRevision(revision);
      } else {
        await _dbService.updateRevision(revision);
      }
    } catch (e) {
      debugPrint('Database revision write error: $e');
    }
  }

  static List<Revision> _sorted(List<Revision> revisions) {
    revisions.sort((a, b) {
      if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
      return a.nextRevisionAt.compareTo(b.nextRevisionAt);
    });
    return revisions;
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesChanged);
    _ongoingController.removeListener(_onOngoingChanged);
    _revisionsSubscription?.cancel();
    super.dispose();
  }
}
