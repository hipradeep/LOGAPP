import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/revision.dart';
import '../models/section.dart';
import '../services/firestore_service.dart';
import '../services/local_revision_storage.dart';
import '../services/local_section_storage.dart';
import '../services/local_subsection_storage.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';
import 'ongoing_sections_controller.dart';

/// Owns the R1 -> R5 spaced repetition ladder.
///
/// A revision is created the moment every topic in a Section is completed
/// (level R1, unlocking after 1 day). Each later level unlocks only after the
/// previous level is completed *and* its date has arrived:
///
///   R1 -> +1 day, R2 -> +3 days, R3 -> +7 days, R4 -> +14 days, R5 -> +30 days
///
/// Progression is automatic — there is no manual "mark done" step. Whenever a
/// due level's Section is still fully completed, [reconcile] advances the
/// record and schedules the next date from the completion moment. Finishing R5
/// flips the record to [RevisionStatus.finished].
class RevisionController extends ChangeNotifier {
  final CoursesController _coursesController;
  final OngoingSectionsController _ongoingController;
  final FirestoreService _firestoreService;

  StreamSubscription<List<Revision>>? _revisionsSubscription;

  List<Revision> _revisions = [];
  bool _isLoading = true;
  bool _isReconciling = false;

  RevisionController({
    CoursesController? coursesController,
    OngoingSectionsController? ongoingController,
    FirestoreService? firestoreService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _ongoingController =
            ongoingController ?? getIt<OngoingSectionsController>(),
        _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _coursesController.addListener(_onCoursesChanged);
    // OngoingSectionsController notifies on every course change and on every
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
  /// This is the explicit counterpart to the automatic pass in [reconcile];
  /// it lets a user finish a level the moment they want rather than waiting
  /// for the next reconciliation. Returns true when something changed.
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

  Revision? revisionForSection(String sectionId) {
    for (final revision in _revisions) {
      if (revision.sectionId == sectionId) return revision;
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

  /// Creates R1 for newly completed Sections and advances any level that is
  /// both unlocked and still fully completed.
  ///
  /// Safe to call repeatedly: a single pass always settles, because advancing
  /// always pushes [Revision.nextRevisionAt] into the future.
  Future<void> reconcile() async {
    if (_isReconciling) return;
    _isReconciling = true;

    try {
      final now = DateTime.now();
      final bySection = <String, Revision>{
        for (final revision in _revisions) revision.sectionId: revision,
      };
      final working = List<Revision>.of(_revisions);
      var changed = false;

      for (final course in _activeCourses()) {
        final sections = await LocalSectionStorage.loadSections(course.id);

        for (final section in sections) {
          final isComplete = await _isSectionComplete(section);
          if (!isComplete) continue;

          final existing = bySection[section.id];

          if (existing == null) {
            final created = _createRevision(course, section, now);
            working.add(created);
            bySection[section.id] = created;
            changed = true;
            await _pushToFirestore(created, isNew: true);
            continue;
          }

          if (existing.sectionDescription != section.description) {
            final index = working.indexWhere((r) => r.id == existing.id);
            if (index != -1) {
              final updated = existing.copyWith(
                sectionDescription: section.description,
                updatedAt: now,
              );
              working[index] = updated;
              bySection[section.id] = updated;
              changed = true;
              await _pushToFirestore(updated, isNew: false);
            }
            continue;
          }

          if (existing.isFinished || !existing.isDueAt(now)) continue;

          final index = working.indexWhere((r) => r.id == existing.id);
          if (index == -1) continue;

          final advanced = existing.advance(now);
          working[index] = advanced;
          bySection[section.id] = advanced;
          changed = true;
          await _pushToFirestore(advanced, isNew: false);
        }
      }

      if (changed) {
        _revisions = _sorted(working);
        await LocalRevisionStorage.saveAll(_revisions);
      }
    } catch (e) {
      debugPrint('Error reconciling revisions: $e');
    } finally {
      _isReconciling = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes a revision record entirely (used when its Section disappears).
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
      return status != 'completed' && status != 'archived';
    }).toList();
  }

  /// A module counts as complete only when it has at least one topic and every
  /// one of them is completed. Lookups are id-first so a renamed module (or two
  /// modules sharing a title) is still measured against its own topics.
  Future<bool> _isSectionComplete(Section section) async {
    if (section.id.isEmpty && section.title.isEmpty) return false;

    final topics = await LocalSubsectionStorage.loadSubsectionsForSection(
      sectionId: section.id,
      fallbackTitle: section.title,
    );
    if (topics.isEmpty) return false;
    return topics.every((topic) => topic.isCompleted);
  }

  Revision _createRevision(Course course, Section section, DateTime now) {
    return Revision(
      id: 'revision_${section.id}_${now.millisecondsSinceEpoch}',
      courseId: course.id,
      sectionId: section.id,
      courseTitle: course.title,
      sectionTitle: section.title,
      sectionDescription: section.description,
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
