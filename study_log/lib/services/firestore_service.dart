import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../models/revision.dart';
import '../models/revision_topic.dart';
import '../models/study_log.dart';
import '../models/user_profile.dart';
import 'local_study_log_storage.dart';
import 'local_topic_storage.dart';
import 'local_revision_storage.dart';
import 'local_user_profile_storage.dart';

/// Highly optimized Firebase Firestore Service with graceful fallbacks.
/// 
/// Key optimizations:
/// - Offline persistence and unlimited local disk cache enabled.
/// - Direct one-shot `get` methods with [Source.serverAndCache] to eliminate
///   stream-spinup and teardown overhead (`.snapshots().first`).
/// - Atomic [WriteBatch] support for bulk operations (e.g. JSON imports),
///   reducing dozens of round-trip network requests to a single batch commit.
/// - Cascading deletions for courses and modules to prevent orphaned documents.
/// - Duplicate write event suppression via `includeMetadataChanges: false`.
class FirestoreService {
  final FirebaseFirestore? _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _getSafeInstance();

  static FirebaseFirestore? _getSafeInstance() {
    try {
      final instance = FirebaseFirestore.instance;
      instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      return instance;
    } catch (e) {
      debugPrint('Firestore instance not available on current platform: $e');
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  // ===========================================================================
  // Courses
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _coursesRef =>
      _firestore?.collection('courses');

  /// Real-time stream of courses with local metadata change suppression.
  Stream<List<Course>> streamCourses() {
    final ref = _coursesRef;
    if (ref == null) return const Stream.empty();

    return ref.snapshots(includeMetadataChanges: false).map((snapshot) {
      final list = <Course>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Course.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// High-speed one-shot fetch avoiding stream listener overhead.
  Future<List<Course>> getCourses({
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _coursesRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => ref.get(const GetOptions(source: Source.cache)),
      );
      final list = <Course>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Course.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('Error getting courses from firestore: $e');
      return [];
    }
  }

  Future<void> addCourse(Course course) async {
    final ref = _coursesRef;
    if (ref == null) return;
    final docRef = course.id.isEmpty ? ref.doc() : ref.doc(course.id);
    final courseToSave = course.id.isEmpty ? course.copyWith(id: docRef.id) : course;
    await docRef.set(courseToSave.toMap());
  }

  Future<void> updateCourse(Course course) async {
    final ref = _coursesRef;
    if (ref == null) return;
    final docRef = course.id.isEmpty ? ref.doc() : ref.doc(course.id);
    final courseToSave = course.id.isEmpty ? course.copyWith(id: docRef.id) : course;
    await docRef.set(courseToSave.toMap(), SetOptions(merge: true));
  }

  /// Deletes a course along with all associated modules and child topics in a single batch.
  Future<void> deleteCourse(String courseId) async {
    final ref = _coursesRef;
    if (ref == null || courseId.isEmpty) return;

    final batch = _firestore?.batch();
    if (batch != null) {
      batch.delete(ref.doc(courseId));

      final modulesRef = _modulesRef;
      final topicsRef = _topicsRef;

      if (modulesRef != null) {
        try {
          final moduleDocs = await modulesRef.where('courseId', isEqualTo: courseId).get();
          for (final mDoc in moduleDocs.docs) {
            batch.delete(mDoc.reference);
            if (topicsRef != null) {
              final topicDocs = await topicsRef.where('moduleId', isEqualTo: mDoc.id).get();
              for (final tDoc in topicDocs.docs) {
                batch.delete(tDoc.reference);
              }
            }
          }
        } catch (_) {}
      }
      await batch.commit();
    } else {
      await ref.doc(courseId).delete();
    }
  }

  // ===========================================================================
  // Modules
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _modulesRef =>
      _firestore?.collection('modules');

  /// Real-time stream of modules for a course.
  Stream<List<Module>> streamModules({required String courseId}) {
    final ref = _modulesRef;
    if (ref == null) return const Stream.empty();

    return ref
        .where('courseId', isEqualTo: courseId)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      final list = <Module>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Module.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  /// High-speed one-shot module query avoiding stream listener setup/teardown.
  Future<List<Module>> getModules({
    required String courseId,
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _modulesRef;
    if (ref == null || courseId.isEmpty) return [];

    try {
      final query = ref.where('courseId', isEqualTo: courseId);
      final snapshot = await query.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
      final list = <Module>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Module.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    } catch (e) {
      debugPrint('Error getting modules for course $courseId: $e');
      return [];
    }
  }

  Future<void> addModule(Module module) async {
    final ref = _modulesRef;
    if (ref == null) return;
    final docRef = module.id.isEmpty ? ref.doc() : ref.doc(module.id);
    final moduleToSave = module.id.isEmpty ? module.copyWith(id: docRef.id) : module;
    await docRef.set(moduleToSave.toMap());
  }

  Future<void> updateModule(Module module) async {
    final ref = _modulesRef;
    if (ref == null) return;
    final docRef = module.id.isEmpty ? ref.doc() : ref.doc(module.id);
    final moduleToSave = module.id.isEmpty ? module.copyWith(id: docRef.id) : module;
    await docRef.set(moduleToSave.toMap(), SetOptions(merge: true));
  }

  /// Deletes a module and cascades deletion to all child topics.
  Future<void> deleteModule(String moduleId) async {
    final ref = _modulesRef;
    if (ref == null || moduleId.isEmpty) return;

    final batch = _firestore?.batch();
    if (batch != null) {
      batch.delete(ref.doc(moduleId));

      final topicsRef = _topicsRef;
      if (topicsRef != null) {
        try {
          final topicDocs = await topicsRef.where('moduleId', isEqualTo: moduleId).get();
          for (final tDoc in topicDocs.docs) {
            batch.delete(tDoc.reference);
          }
        } catch (_) {}
      }
      await batch.commit();
    } else {
      await ref.doc(moduleId).delete();
    }
  }

  // ===========================================================================
  // Topics
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _topicsRef =>
      _firestore?.collection('topics');

  /// Real-time stream of topics for a module.
  Stream<List<Topic>> streamTopics({required String moduleId}) {
    final ref = _topicsRef;
    if (ref == null) return const Stream.empty();

    return ref
        .where('moduleId', isEqualTo: moduleId)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      final list = <Topic>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Topic.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  /// High-speed one-shot topics query without listener thrashing.
  Future<List<Topic>> getTopics({
    required String moduleId,
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _topicsRef;
    if (ref == null || moduleId.isEmpty) return [];

    try {
      final query = ref.where('moduleId', isEqualTo: moduleId);
      final snapshot = await query.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
      final list = <Topic>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Topic.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    } catch (e) {
      debugPrint('Error getting topics for module $moduleId: $e');
      return [];
    }
  }

  Future<void> addTopic(Topic topic) async {
    final ref = _topicsRef;
    if (ref == null) return;
    final docRef = topic.id.isEmpty ? ref.doc() : ref.doc(topic.id);
    final subToSave = topic.id.isEmpty ? topic.copyWith(id: docRef.id) : topic;
    await docRef.set(subToSave.toMap());
  }

  Future<void> updateTopic(Topic topic) async {
    final ref = _topicsRef;
    if (ref == null) return;
    final docRef = topic.id.isEmpty ? ref.doc() : ref.doc(topic.id);
    final subToSave = topic.id.isEmpty ? topic.copyWith(id: docRef.id) : topic;
    await docRef.set(subToSave.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTopic(String topicId) async {
    final ref = _topicsRef;
    if (ref == null || topicId.isEmpty) return;
    await ref.doc(topicId).delete();
  }

  // ===========================================================================
  // Revisions
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _revisionsRef =>
      _firestore?.collection('revisions');

  Stream<List<Revision>> streamRevisions() {
    final ref = _revisionsRef;
    if (ref == null) return const Stream.empty();

    return ref.snapshots(includeMetadataChanges: false).map((snapshot) {
      final list = <Revision>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Revision.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      return list;
    });
  }

  Future<List<Revision>> getRevisions({
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _revisionsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => ref.get(const GetOptions(source: Source.cache)),
      );
      final list = <Revision>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Revision.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      return list;
    } catch (e) {
      debugPrint('Error getting revisions: $e');
      return [];
    }
  }

  Future<void> addRevision(Revision revision) async {
    final ref = _revisionsRef;
    if (ref == null) return;
    final docRef = revision.id.isEmpty ? ref.doc() : ref.doc(revision.id);
    final toSave = revision.id.isEmpty ? revision.copyWith(id: docRef.id) : revision;
    await docRef.set(toSave.toMap());
  }

  Future<void> updateRevision(Revision revision) async {
    final ref = _revisionsRef;
    if (ref == null) return;
    final docRef = revision.id.isEmpty ? ref.doc() : ref.doc(revision.id);
    final toSave = revision.id.isEmpty ? revision.copyWith(id: docRef.id) : revision;
    await docRef.set(toSave.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRevision(String revisionId) async {
    final ref = _revisionsRef;
    if (ref == null || revisionId.isEmpty) return;
    await ref.doc(revisionId).delete();
  }

  // ===========================================================================
  // Revision Topics
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _revisionTopicsRef =>
      _firestore?.collection('revision_topics');

  /// Real-time stream of revision topics for a revision.
  Stream<List<RevisionTopic>> streamRevisionTopics({required String revisionId}) {
    final ref = _revisionTopicsRef;
    if (ref == null || revisionId.isEmpty) return const Stream.empty();

    return ref
        .where('revisionId', isEqualTo: revisionId)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      final list = <RevisionTopic>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(RevisionTopic.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  /// High-speed one-shot query for revision topics.
  Future<List<RevisionTopic>> getRevisionTopics({
    required String revisionId,
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _revisionTopicsRef;
    if (ref == null || revisionId.isEmpty) return [];

    try {
      final query = ref.where('revisionId', isEqualTo: revisionId);
      final snapshot = await query.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
      final list = <RevisionTopic>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(RevisionTopic.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    } catch (e) {
      debugPrint('Error getting revision topics for revision $revisionId: $e');
      return [];
    }
  }

  Future<void> addRevisionTopic(RevisionTopic topic) async {
    final ref = _revisionTopicsRef;
    if (ref == null) return;
    final docRef = topic.id.isEmpty ? ref.doc() : ref.doc(topic.id);
    final toSave = topic.id.isEmpty ? topic.copyWith(id: docRef.id) : topic;
    await docRef.set(toSave.toMap(), SetOptions(merge: true));
  }

  Future<void> updateRevisionTopic(RevisionTopic topic) async {
    final ref = _revisionTopicsRef;
    if (ref == null || topic.id.isEmpty) return;
    await ref.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRevisionTopic(String topicId) async {
    final ref = _revisionTopicsRef;
    if (ref == null || topicId.isEmpty) return;
    await ref.doc(topicId).delete();
  }

  // ===========================================================================
  // High-Performance Batch Writes (Chunked into <= 450 items)
  // ===========================================================================
  /// Batches multiple courses, modules, topics, and revisions into atomic commits.
  /// Automatically chunks writes into blocks of 400 to respect Firestore's 500-op limit.
  Future<void> batchSave({
    List<Course>? courses,
    List<Module>? modules,
    List<Topic>? topics,
    List<Revision>? revisions,
    List<StudyLog>? studyLogs,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final List<void Function(WriteBatch)> writeOperations = [];

    if (courses != null && _coursesRef != null) {
      for (final c in courses) {
        final docRef = c.id.isEmpty ? _coursesRef!.doc() : _coursesRef!.doc(c.id);
        final item = c.id.isEmpty ? c.copyWith(id: docRef.id) : c;
        writeOperations.add((batch) => batch.set(docRef, item.toMap(), SetOptions(merge: true)));
      }
    }

    if (modules != null && _modulesRef != null) {
      for (final m in modules) {
        final docRef = m.id.isEmpty ? _modulesRef!.doc() : _modulesRef!.doc(m.id);
        final item = m.id.isEmpty ? m.copyWith(id: docRef.id) : m;
        writeOperations.add((batch) => batch.set(docRef, item.toMap(), SetOptions(merge: true)));
      }
    }

    if (topics != null && _topicsRef != null) {
      for (final t in topics) {
        final docRef = t.id.isEmpty ? _topicsRef!.doc() : _topicsRef!.doc(t.id);
        final item = t.id.isEmpty ? t.copyWith(id: docRef.id) : t;
        writeOperations.add((batch) => batch.set(docRef, item.toMap(), SetOptions(merge: true)));
      }
    }

    if (revisions != null && _revisionsRef != null) {
      for (final r in revisions) {
        final docRef = r.id.isEmpty ? _revisionsRef!.doc() : _revisionsRef!.doc(r.id);
        final item = r.id.isEmpty ? r.copyWith(id: docRef.id) : r;
        writeOperations.add((batch) => batch.set(docRef, item.toMap(), SetOptions(merge: true)));
      }
    }

    if (studyLogs != null && _studyLogsRef != null) {
      for (final log in studyLogs) {
        final docRef = log.id.isEmpty ? _studyLogsRef!.doc() : _studyLogsRef!.doc(log.id);
        final item = log.id.isEmpty ? log.copyWith(id: docRef.id) : log;
        writeOperations.add((batch) => batch.set(docRef, item.toMap(), SetOptions(merge: true)));
      }
    }

    // Execute in batches of 400
    const int batchSize = 400;
    for (int i = 0; i < writeOperations.length; i += batchSize) {
      final end = (i + batchSize < writeOperations.length) ? i + batchSize : writeOperations.length;
      final currentChunk = writeOperations.sublist(i, end);

      final batch = firestore.batch();
      for (final op in currentChunk) {
        op(batch);
      }
      await batch.commit();
    }
  }

  // ===========================================================================
  // Study Logs
  // ===========================================================================
  CollectionReference<Map<String, dynamic>>? get _studyLogsRef =>
      _firestore?.collection('study_logs');

  /// Adds a new study log entry to Firestore with offline safety.
  Future<void> addStudyLog(StudyLog log) async {
    final ref = _studyLogsRef;
    if (ref == null) return;

    try {
      final docRef = log.id.isEmpty ? ref.doc() : ref.doc(log.id);
      final toSave = log.id.isEmpty ? log.copyWith(id: docRef.id) : log;
      await docRef.set(toSave.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error adding study log to firestore: $e');
    }
  }

  /// Adds multiple study logs to Firestore atomically in batches.
  Future<void> addStudyLogs(List<StudyLog> logs) async {
    if (logs.isEmpty) return;
    await batchSave(studyLogs: logs);
  }

  /// Ensures all completed topics and revisions across local caches have matching
  /// StudyLog entries and syncs them to Firestore's 'study_logs' collection.
  Future<void> syncAllLocalStudyLogsToFirestore() async {
    final ref = _studyLogsRef;
    if (ref == null) return;

    try {
      final existingLogs = await LocalStudyLogStorage.loadAll();
      final existingIds = existingLogs.map((e) => e.id).toSet();
      final existingTopicIds = existingLogs
          .where((e) => e.type == StudyLogType.topicCompleted && e.topicId != null)
          .map((e) => e.topicId!)
          .toSet();

      final List<StudyLog> missingLogs = [];

      // 1. Scan completed topics
      final topicBuckets = await LocalTopicStorage.loadAllBuckets();
      for (final topics in topicBuckets.values) {
        for (final topic in topics) {
          if (topic.isCompleted && !existingTopicIds.contains(topic.id)) {
            final completedTime = topic.completedAt ?? DateTime.now();
            final log = StudyLog(
              id: '${topic.id}_${completedTime.millisecondsSinceEpoch}',
              type: StudyLogType.topicCompleted,
              courseId: topic.courseId,
              courseTitle: '',
              moduleId: topic.moduleId,
              moduleTitle: '',
              topicId: topic.id,
              topicTitle: topic.title,
              timestamp: completedTime,
              createdAt: completedTime,
            );
            if (!existingIds.contains(log.id)) {
              missingLogs.add(log);
              existingIds.add(log.id);
            }
          }
        }
      }

      // 2. Scan completed/advanced revisions
      final revisions = await LocalRevisionStorage.loadAll();
      final existingRevisionIds = existingLogs
          .where((e) => e.type == StudyLogType.revisionCompleted)
          .map((e) => e.moduleId)
          .toSet();

      for (final rev in revisions) {
        if ((rev.currentLevel > 1 || rev.isFinished) && !existingRevisionIds.contains(rev.moduleId)) {
          final revTime = rev.lastRevisionAt ?? rev.updatedAt;
          final log = StudyLog(
            id: 'rev_${rev.id}_${revTime.millisecondsSinceEpoch}',
            type: StudyLogType.revisionCompleted,
            courseId: rev.courseId,
            courseTitle: '',
            moduleId: rev.moduleId,
            moduleTitle: '',
            revisionLevel: rev.currentLevel,
            timestamp: revTime,
            createdAt: revTime,
          );
          if (!existingIds.contains(log.id)) {
            missingLogs.add(log);
            existingIds.add(log.id);
          }
        }
      }

      // 3. Save any missing logs to local disk cache
      if (missingLogs.isNotEmpty) {
        await LocalStudyLogStorage.saveAll([...existingLogs, ...missingLogs]);
      }

      // 4. Batch push all study logs to Firestore
      final allLogs = [...existingLogs, ...missingLogs];
      if (allLogs.isNotEmpty) {
        await batchSave(studyLogs: allLogs);
      }
    } catch (e) {
      debugPrint('Error syncing all study logs to Firestore: $e');
    }
  }

  /// Streams recent study logs ordered by timestamp descending.
  Stream<List<StudyLog>> streamStudyLogs({int limit = 100}) {
    final ref = _studyLogsRef;
    if (ref == null) return const Stream.empty();

    return ref
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      final list = <StudyLog>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(StudyLog.fromMap(doc.data(), documentId: doc.id));
        } catch (_) {}
      }
      return list;
    });
  }

  /// One-shot fetch for study logs.
  Future<List<StudyLog>> getStudyLogs({int limit = 200}) async {
    final ref = _studyLogsRef;
    if (ref == null) return [];

    try {
      final snapshot = await ref
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));
      return snapshot.docs
          .map((d) => StudyLog.fromMap(d.data(), documentId: d.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting study logs: $e');
      return [];
    }
  }

  // ===========================================================================
  // User Profile Document (Profile Details, Streaks & Total Session Hours)
  // ===========================================================================
  DocumentReference<Map<String, dynamic>>? get _userProfileDoc =>
      _firestore?.collection('user_profile').doc('profile');

  /// Fetches the user profile document from Firestore with offline cache fallback.
  Future<UserProfile?> getUserProfile({
    Source source = Source.serverAndCache,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final ref = _userProfileDoc;
    if (ref == null) return null;

    try {
      final snapshot = await ref.get(GetOptions(source: source)).timeout(
        timeout,
        onTimeout: () => ref.get(const GetOptions(source: Source.cache)),
      );
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromMap(snapshot.data()!, documentId: snapshot.id);
    } catch (e) {
      debugPrint('Error getting user profile from firestore: $e');
      return null;
    }
  }

  /// Real-time stream of the user profile document.
  Stream<UserProfile?> streamUserProfile() {
    final ref = _userProfileDoc;
    if (ref == null) return const Stream.empty();

    return ref.snapshots(includeMetadataChanges: false).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      try {
        return UserProfile.fromMap(snapshot.data()!, documentId: snapshot.id);
      } catch (e) {
        debugPrint('Error parsing streamUserProfile: $e');
        return null;
      }
    });
  }

  /// Saves or updates the user profile document in Firestore and mirrors to local cache.
  Future<void> saveUserProfile(UserProfile profile) async {
    final ref = _userProfileDoc;
    if (ref == null) return;

    try {
      await ref.set(profile.toMap(), SetOptions(merge: true));
      await LocalUserProfileStorage.saveProfile(profile);
    } catch (e) {
      debugPrint('Error saving user profile to firestore: $e');
    }
  }
}
