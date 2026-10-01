import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/revision.dart';
import '../models/module.dart';
import '../models/study_log.dart';
import '../services/firestore_service.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_course_storage.dart';
import '../services/local_topic_storage.dart';
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
  final FirestoreService _firestoreService;

  StreamSubscription<List<Revision>>? _revisionsSubscription;

  List<Revision> _revisions = [];
  bool _isLoading = true;
  bool _isReconciling = false;

  /// ModuleIds whose revisions were manually removed by the user.
  /// Reconcile skips these so a still-complete module is not re-added.
  final Set<String> _suppressedModuleIds = {};

  RevisionController({
    CoursesController? coursesController,
    OngoingModulesController? ongoingController,
    FirestoreService? firestoreService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _ongoingController =
            ongoingController ?? getIt<OngoingModulesController>(),
        _firestoreService = firestoreService ?? getIt<FirestoreService>() {
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

    final log = StudyLog(
      id: 'rev_${current.id}_${now.millisecondsSinceEpoch}',
      type: StudyLogType.revisionCompleted,
      courseId: current.courseId,
      courseTitle: current.courseTitle,
      moduleId: current.moduleId,
      moduleTitle: current.moduleTitle,
      revisionLevel: current.currentLevel,
      timestamp: now,
      createdAt: now,
    );
    await LocalStudyLogStorage.addLog(log);
    if (getIt.isRegistered<FirestoreService>()) {
      final firestore = getIt<FirestoreService>();
      if (firestore.isAvailable) {
        unawaited(firestore.addStudyLog(log));
      }
    }

    if (getIt.isRegistered<OngoingModulesController>()) {
      unawaited(getIt<OngoingModulesController>().refresh());
    }
    if (getIt.isRegistered<ProgressController>()) {
      unawaited(getIt<ProgressController>().refresh());
    }
    notifyListeners();
    await _pushToFirestore(advanced, isNew: false);
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
    await _pushToFirestore(reset, isNew: false);
  }

  Revision? revisionForModule(String moduleId, {String moduleTitle = ''}) {
    for (final revision in _revisions) {
      if (moduleId.isNotEmpty && revision.moduleId == moduleId) return revision;
      if (moduleTitle.isNotEmpty &&
          revision.moduleTitle.trim().toLowerCase() ==
              moduleTitle.trim().toLowerCase()) {
        return revision;
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
    // Load suppress list before first reconcile so no deleted module is re-created.
    final suppressed = await LocalRevisionStorage.loadSuppressedModuleIds();
    _suppressedModuleIds.addAll(suppressed);

    final cached = await LocalRevisionStorage.loadAll();
    if (_revisions.isEmpty && cached.isNotEmpty) {
      _revisions = _sorted(cached);
      _isLoading = false;
      notifyListeners();
    }
    _listenToFirestore();
    await reconcile();
  }

  void _listenToFirestore() {
    if (!_firestoreService.isAvailable) return;
    _revisionsSubscription?.cancel();
    try {
      _revisionsSubscription = _firestoreService.streamRevisions().listen(
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
    // Build a lookup of what Firestore currently has.
    final remoteById = <String, Revision>{
      for (final r in remote) r.id: r,
    };

    final merged = <String, Revision>{};

    // For every local record:
    //  - If Firestore still has it, pick whichever copy is newer.
    //  - If Firestore no longer has it (was deleted remotely), drop it.
    for (final local in _revisions) {
      final remoteVersion = remoteById[local.id];
      if (remoteVersion == null) {
        // Record was deleted on Firestore (or never pushed) — keep local only
        // if it is strictly newer than any remote update we can find, i.e. it
        // was created or modified offline after the remote delete.  We cannot
        // distinguish an offline-new record from a remotely-deleted one, so we
        // keep it — reconcile will re-push it if the module is still complete.
        merged[local.id] = local;
      } else if (!local.updatedAt.isBefore(remoteVersion.updatedAt)) {
        merged[local.id] = local; // local is newer, keep it
      } else {
        merged[local.id] = remoteVersion; // remote is newer
      }
    }

    // Add any records that exist only on Firestore (synced from another device).
    for (final r in remote) {
      merged.putIfAbsent(r.id, () => r);
    }

    _revisions = _sorted(merged.values.toList());
    unawaited(LocalRevisionStorage.saveAll(_revisions));
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
  Future<Revision> createOrEnsureRevision({
    required String courseId,
    required String moduleId,
    required String courseTitle,
    required String moduleTitle,
    String moduleDescription = '',
  }) async {
    final now = DateTime.now();

    // Un-suppress so manual add takes effect immediately
    final key1 = moduleId;
    final key2 = moduleTitle.trim().toLowerCase();
    if (_suppressedModuleIds.remove(key1) || _suppressedModuleIds.remove(key2)) {
      unawaited(LocalRevisionStorage.saveSuppressedModuleIds(_suppressedModuleIds));
    }

    final existingIndex = _revisions.indexWhere(
      (r) =>
          (moduleId.isNotEmpty && r.moduleId == moduleId) ||
          (moduleTitle.isNotEmpty &&
              r.moduleTitle.toLowerCase() == moduleTitle.toLowerCase()),
    );

    if (existingIndex != -1) {
      final existing = _revisions[existingIndex];
      if (existing.courseTitle != courseTitle ||
          existing.moduleTitle != moduleTitle ||
          existing.moduleDescription != moduleDescription) {
        final updated = existing.copyWith(
          courseTitle:
              courseTitle.isNotEmpty ? courseTitle : existing.courseTitle,
          moduleTitle:
              moduleTitle.isNotEmpty ? moduleTitle : existing.moduleTitle,
          moduleDescription: moduleDescription.isNotEmpty
              ? moduleDescription
              : existing.moduleDescription,
          updatedAt: now,
        );
        _revisions =
            _sorted(List<Revision>.of(_revisions)..[existingIndex] = updated);
        await LocalRevisionStorage.saveAll(_revisions);
        notifyListeners();
        await _pushToFirestore(updated, isNew: false);
        return updated;
      }
      return existing;
    }

    final newRevision = Revision(
      id: 'revision_${moduleId.isNotEmpty ? moduleId : moduleTitle.toLowerCase().replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}',
      courseId: courseId,
      moduleId: moduleId,
      courseTitle: courseTitle,
      moduleTitle: moduleTitle,
      moduleDescription: moduleDescription,
      currentLevel: 1,
      status: RevisionStatus.active,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      createdAt: now,
      updatedAt: now,
    );

    _revisions = _sorted(List<Revision>.of(_revisions)..add(newRevision));
    _isLoading = false;
    await LocalRevisionStorage.saveAll(_revisions);
    notifyListeners();
    await _pushToFirestore(newRevision, isNew: true);
    unawaited(_ongoingController.refresh());
    return newRevision;
  }

  Future<void> _performReconcile() async {
    final now = DateTime.now();
    final working = List<Revision>.of(_revisions);
    var changed = false;

    // 1. Purge any revisions whose module is NOT complete!
    // Revision list should ONLY contain completed modules.
    final toRemove = <String>[];
    for (final revision in working) {
      final isComplete = await _isRevisionComplete(revision);
      if (!isComplete) {
        toRemove.add(revision.id);
      }
    }

    if (toRemove.isNotEmpty) {
      working.removeWhere((r) => toRemove.contains(r.id));
      changed = true;
      for (final id in toRemove) {
        if (_firestoreService.isAvailable) {
          try {
            await _firestoreService.deleteRevision(id);
          } catch (_) {}
        }
      }
    }

    final byModuleId = <String, Revision>{
      for (final revision in working)
        if (revision.moduleId.isNotEmpty) revision.moduleId: revision,
    };
    final byModuleTitle = <String, Revision>{
      for (final revision in working)
        if (revision.moduleTitle.isNotEmpty)
          revision.moduleTitle.trim().toLowerCase(): revision,
    };

    // Build course map for fast lookup and fallback to local disk if needed
    final coursesMap = <String, Course>{};
    for (final c in _coursesController.allCourses) {
      coursesMap[c.id] = c;
    }
    if (coursesMap.isEmpty) {
      final cachedCourses = await LocalCourseStorage.loadCourses();
      for (final c in cachedCourses) {
        coursesMap[c.id] = c;
      }
    }

    // Collect all modules from both local disk and all active courses
    final allModules = <Module>[];
    final seenModuleKeys = <String>{};

    void addModuleCandidate(Module m) {
      final key = m.id.isNotEmpty ? m.id : m.title.trim().toLowerCase();
      if (key.isNotEmpty && seenModuleKeys.add(key)) {
        allModules.add(m);
      }
    }

    final cachedAll = await LocalModuleStorage.loadAllModules();
    for (final m in cachedAll) {
      addModuleCandidate(m);
    }

    for (final course in coursesMap.values) {
      if (course.status.toLowerCase() == 'archived') continue;
      var courseModules = await LocalModuleStorage.loadModules(course.id);
      if (courseModules.isEmpty && _firestoreService.isAvailable) {
        try {
          courseModules = await _firestoreService.getModules(courseId: course.id);
          if (courseModules.isNotEmpty) {
            await LocalModuleStorage.saveModulesForCourse(course.id, courseModules);
          }
        } catch (_) {}
      }
      for (final m in courseModules) {
        addModuleCandidate(m);
      }
    }

    for (final module in allModules) {
      if (module.id.isEmpty && module.title.isEmpty) continue;

      final course = coursesMap[module.courseId] ??
          Course(
            id: module.courseId,
            title: module.courseId.isNotEmpty ? module.courseId : 'Course',
            description: '',
            status: 'active',
            createdAt: now,
            updatedAt: now,
          );

      if (course.status.toLowerCase() == 'archived') continue;

      final existing = byModuleId[module.id] ??
          byModuleTitle[module.title.trim().toLowerCase()];

      if (existing != null) {
        if (existing.moduleDescription != module.description ||
            (existing.courseTitle.isEmpty && course.title.isNotEmpty)) {
          final index = working.indexWhere((r) => r.id == existing.id);
          if (index != -1) {
            final updated = existing.copyWith(
              moduleDescription: module.description,
              courseTitle: course.title.isNotEmpty ? course.title : existing.courseTitle,
              updatedAt: now,
            );
            working[index] = updated;
            if (updated.moduleId.isNotEmpty) byModuleId[updated.moduleId] = updated;
            if (updated.moduleTitle.isNotEmpty) {
              byModuleTitle[updated.moduleTitle.trim().toLowerCase()] = updated;
            }
            changed = true;
            await _pushToFirestore(updated, isNew: false);
          }
        }
      }
    }

    if (changed) {
      _revisions = _sorted(working);
      await LocalRevisionStorage.saveAll(_revisions);
      notifyListeners();
      unawaited(_ongoingController.refresh());
    }
  }

  /// Deletes a revision record entirely and suppresses re-creation for that
  /// module so reconcile does not immediately add it back.
  Future<void> deleteRevision(String revisionId) async {
    // Find the revision first so we can record its moduleId.
    final toDelete = _revisions.firstWhere(
      (r) => r.id == revisionId,
      orElse: () => Revision(
        id: '', courseId: '', moduleId: '', courseTitle: '', moduleTitle: '',
        moduleDescription: '', currentLevel: 1, status: RevisionStatus.active,
        nextRevisionAt: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ),
    );

    _revisions = _revisions.where((r) => r.id != revisionId).toList();
    await LocalRevisionStorage.saveAll(_revisions);

    // Suppress by both moduleId and moduleTitle key so reconcile skips it.
    if (toDelete.moduleId.isNotEmpty) {
      _suppressedModuleIds.add(toDelete.moduleId);
    }
    if (toDelete.moduleTitle.isNotEmpty) {
      _suppressedModuleIds.add(toDelete.moduleTitle.trim().toLowerCase());
    }
    await LocalRevisionStorage.saveSuppressedModuleIds(_suppressedModuleIds);

    notifyListeners();
    unawaited(_ongoingController.refresh());

    if (_firestoreService.isAvailable) {
      try {
        await _firestoreService.deleteRevision(revisionId);
      } catch (e) {
        debugPrint('Error deleting revision from firestore: $e');
      }
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
    await LocalRevisionStorage.saveAll(_revisions);

    for (final r in toRemove) {
      if (r.moduleId.isNotEmpty) {
        _suppressedModuleIds.remove(r.moduleId);
      }
      if (r.moduleTitle.isNotEmpty) {
        _suppressedModuleIds.remove(r.moduleTitle.trim().toLowerCase());
      }
    }
    await LocalRevisionStorage.saveSuppressedModuleIds(_suppressedModuleIds);

    notifyListeners();
    unawaited(_ongoingController.refresh());

    if (_firestoreService.isAvailable) {
      for (final r in toRemove) {
        try {
          await _firestoreService.deleteRevision(r.id);
        } catch (e) {
          debugPrint('Error deleting revision for course $courseId: $e');
        }
      }
    }
  }

  List<Course> _activeCourses() {
    return _coursesController.courses.where((course) {
      final status = course.status.toLowerCase();
      return status != 'archived';
    }).toList();
  }

  /// Checks if a revision's module has completed all its topics.
  Future<bool> _isRevisionComplete(Revision revision) async {
    final moduleId = revision.moduleId;
    final moduleTitle = revision.moduleTitle;

    // 1. Check OngoingModulesController in-memory first
    if (moduleId.isNotEmpty) {
      final total = _ongoingController.topicCountForModule(moduleId);
      final done = _ongoingController.completedTopicCountForModule(moduleId);
      if (total > 0) {
        return done >= total;
      }
    }

    // 2. Load topics from local disk cache
    var topics = await LocalTopicStorage.loadTopicsForModule(
      moduleId: moduleId,
      fallbackTitle: moduleTitle,
    );

    // 3. Fallback to Firestore if local topics empty
    if (topics.isEmpty && _firestoreService.isAvailable && moduleId.isNotEmpty) {
      try {
        topics = await _firestoreService.getTopics(moduleId: moduleId);
        if (topics.isNotEmpty) {
          final key = moduleId.isNotEmpty ? moduleId : moduleTitle;
          await LocalTopicStorage.saveTopics(key, topics);
        }
      } catch (_) {}
    }

    // If topics exist, ALL must be completed!
    if (topics.isNotEmpty) {
      return topics.every((t) => t.isCompleted);
    }

    // 4. If no topics found, check module record itself
    if (revision.courseId.isNotEmpty) {
      final modules = await LocalModuleStorage.loadModules(revision.courseId);
      final match = modules.firstWhere(
        (m) =>
            (moduleId.isNotEmpty && m.id == moduleId) ||
            (moduleTitle.isNotEmpty &&
                m.title.toLowerCase() == moduleTitle.toLowerCase()),
        orElse: () => Module(
          id: '',
          courseId: '',
          title: '',
          description: '',
          orderIndex: 0,
          status: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (match.id.isNotEmpty) {
        return match.status.toLowerCase() == 'completed';
      }
    }

    return false;
  }

  /// A module counts as complete when all its topics are completed.
  Future<bool> _isModuleComplete(Module module) async {
    if (module.id.isEmpty && module.title.isEmpty) return false;

    // Check with in-memory OngoingModulesController
    if (module.id.isNotEmpty) {
      final total = _ongoingController.topicCountForModule(module.id);
      final done = _ongoingController.completedTopicCountForModule(module.id);
      if (total > 0) return done >= total;
    }

    var topics = await LocalTopicStorage.loadTopicsForModule(
      moduleId: module.id,
      fallbackTitle: module.title,
    );
    if (topics.isEmpty && _firestoreService.isAvailable && module.id.isNotEmpty) {
      try {
        topics = await _firestoreService.getTopics(moduleId: module.id);
        if (topics.isNotEmpty) {
          final key = module.id.isNotEmpty ? module.id : module.title;
          await LocalTopicStorage.saveTopics(key, topics);
        }
      } catch (_) {}
    }

    if (topics.isNotEmpty) {
      return topics.every((topic) => topic.isCompleted);
    }

    return module.status.toLowerCase() == 'completed';
  }

  Revision _createRevision(Course course, Module module, DateTime now) {
    return Revision(
      id: 'revision_${module.id}_${now.millisecondsSinceEpoch}',
      courseId: course.id,
      moduleId: module.id,
      courseTitle: course.title,
      moduleTitle: module.title,
      moduleDescription: module.description,
      currentLevel: 1,
      status: RevisionStatus.active,
      nextRevisionAt: now.add(RevisionSchedule.intervalFor(1)),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _pushToFirestore(Revision revision, {required bool isNew}) async {
    if (!_firestoreService.isAvailable) return;
    try {
      if (isNew) {
        await _firestoreService
            .addRevision(revision)
            .timeout(const Duration(seconds: 4));
      } else {
        await _firestoreService
            .updateRevision(revision)
            .timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('Firestore revision write error: $e');
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
