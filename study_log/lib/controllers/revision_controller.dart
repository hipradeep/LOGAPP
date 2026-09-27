import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/revision.dart';
import '../models/module.dart';
import '../services/firestore_service.dart';
import '../services/local_revision_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_course_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'ongoing_modules_controller.dart';

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

  List<Revision> get revisions => List.unmodifiable(_revisions);
  bool get isLoading => _isLoading;

  /// Revisions whose current level has unlocked, soonest first.
  List<Revision> get dueRevisions {
    final now = DateTime.now();
    final due = _revisions.where((r) => r.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return due;
  }

  /// Revisions still counting down to their next level.
  List<Revision> get upcomingRevisions {
    final now = DateTime.now();
    final upcoming = _revisions.where((r) => !r.isFinished && !r.isDueAt(now)).toList()
      ..sort((a, b) => a.nextRevisionAt.compareTo(b.nextRevisionAt));
    return upcoming;
  }

  /// Revisions that have cleared R5.
  List<Revision> get finishedRevisions {
    final done = _revisions.where((r) => r.isFinished).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));
    return done;
  }

  int get dueCount => dueRevisions.length;

  /// Every record in one continuous list, most urgent due date first.
  /// Finished records sink to the bottom because they have nothing left due.
  List<Revision> get scheduledRevisions => _sorted(List<Revision>.of(_revisions));

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

  Revision? revisionForModule(String moduleId) {
    for (final revision in _revisions) {
      if (revision.moduleId == moduleId) return revision;
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
    _listenToFirestore();
    await reconcile();
  }

  void _listenToFirestore() {
    if (!_firestoreService.isAvailable) return;
    _revisionsSubscription?.cancel();
    try {
      _revisionsSubscription = _firestoreService.streamRevisions().listen(
        (remote) {
          if (remote.isEmpty) return;
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
    final merged = <String, Revision>{
      for (final revision in _revisions) revision.id: revision,
    };
    for (final revision in remote) {
      final local = merged[revision.id];
      // Local records win while they are ahead of the remote copy.
      if (local != null && !local.updatedAt.isBefore(revision.updatedAt)) {
        merged[revision.id] = local;
      } else {
        merged[revision.id] = revision;
      }
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
    return newRevision;
  }

  Future<void> _performReconcile() async {
    final now = DateTime.now();
    final byModuleId = <String, Revision>{
      for (final revision in _revisions)
        if (revision.moduleId.isNotEmpty) revision.moduleId: revision,
    };
    final byModuleTitle = <String, Revision>{
      for (final revision in _revisions)
        if (revision.moduleTitle.isNotEmpty)
          revision.moduleTitle.trim().toLowerCase(): revision,
    };
    final working = List<Revision>.of(_revisions);
    var changed = false;

    // Build course map for fast lookup and fallback to local disk if needed
    final coursesMap = <String, Course>{};
    for (final c in _coursesController.courses) {
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
          courseModules = await _firestoreService
              .streamModules(courseId: course.id)
              .first
              .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
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

      final isComplete = await _isModuleComplete(module);
      if (!isComplete) continue;

      final existing = byModuleId[module.id] ??
          byModuleTitle[module.title.trim().toLowerCase()];

      if (existing == null) {
        final created = _createRevision(course, module, now);
        working.add(created);
        if (created.moduleId.isNotEmpty) byModuleId[created.moduleId] = created;
        if (created.moduleTitle.isNotEmpty) {
          byModuleTitle[created.moduleTitle.trim().toLowerCase()] = created;
        }
        changed = true;
        await _pushToFirestore(created, isNew: true);
        continue;
      }

      if (existing.moduleDescription != module.description ||
          existing.courseTitle.isEmpty && course.title.isNotEmpty) {
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
        continue;
      }
    }

    if (changed) {
      _revisions = _sorted(working);
      await LocalRevisionStorage.saveAll(_revisions);
      notifyListeners();
    }
  }

  /// Deletes a revision record entirely (used when its Module disappears).
  Future<void> deleteRevision(String revisionId) async {
    _revisions = _revisions.where((r) => r.id != revisionId).toList();
    await LocalRevisionStorage.saveAll(_revisions);
    notifyListeners();

    if (_firestoreService.isAvailable) {
      try {
        await _firestoreService.deleteRevision(revisionId);
      } catch (e) {
        debugPrint('Error deleting revision from firestore: $e');
      }
    }
  }

  List<Course> _activeCourses() {
    return _coursesController.courses.where((course) {
      final status = course.status.toLowerCase();
      return status != 'archived';
    }).toList();
  }

  /// A module counts as complete when its status is 'completed', when OngoingModulesController
  /// reports it complete, or when every one of its topics is completed.
  Future<bool> _isModuleComplete(Module module) async {
    if (module.id.isEmpty && module.title.isEmpty) return false;
    if (module.status.toLowerCase() == 'completed') return true;

    // Check with in-memory OngoingModulesController
    if (module.id.isNotEmpty && _ongoingController.isModuleComplete(module.id)) {
      return true;
    }
    if (module.id.isNotEmpty) {
      final total = _ongoingController.topicCountForModule(module.id);
      final done = _ongoingController.completedTopicCountForModule(module.id);
      if (total > 0 && done >= total) return true;
    }

    var topics = await LocalTopicStorage.loadTopicsForModule(
      moduleId: module.id,
      fallbackTitle: module.title,
    );
    if (topics.isEmpty && _firestoreService.isAvailable && module.id.isNotEmpty) {
      try {
        topics = await _firestoreService
            .streamTopics(moduleId: module.id)
            .first
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
        if (topics.isNotEmpty) {
          final key = module.id.isNotEmpty ? module.id : module.title;
          await LocalTopicStorage.saveTopics(key, topics);
        }
      } catch (_) {}
    }
    if (topics.isEmpty) return false;
    return topics.every((topic) => topic.isCompleted);
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
