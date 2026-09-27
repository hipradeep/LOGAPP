import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../models/revision.dart';

/// Firebase Firestore Service with graceful fallbacks.
/// If Firebase is unavailable or uninitialized on the current platform,
/// it safely returns empty streams and logs warnings without crashing.
class FirestoreService {
  final FirebaseFirestore? _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? _getSafeInstance();

  static FirebaseFirestore? _getSafeInstance() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firestore instance not available on current platform: $e');
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  CollectionReference<Map<String, dynamic>>? get _coursesRef =>
      _firestore?.collection('courses');

  Stream<List<Course>> streamCourses() {
    final ref = _coursesRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref.snapshots().map((snapshot) {
      final list = <Course>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          list.add(Course.fromMap(data, documentId: doc.id));
        } catch (e) {
          // Ignore individual parsing failures safely
        }
      }
      // Sort in-memory to prevent missing-index errors and support offline documents
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
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
    await ref.doc(course.id).set(course.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteCourse(String courseId) async {
    final ref = _coursesRef;
    if (ref == null) return;
    await ref.doc(courseId).delete();
  }

  CollectionReference<Map<String, dynamic>>? get _modulesRef =>
      _firestore?.collection('modules');

  Stream<List<Module>> streamModules({required String courseId}) {
    final ref = _modulesRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
      final list = <Module>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Module.fromMap(doc.data(), documentId: doc.id));
        } catch (e) {
          // Skip corrupt document safely
        }
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
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
    if (ref == null || module.id.isEmpty) return;
    await ref.doc(module.id).set(module.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteModule(String moduleId) async {
    final ref = _modulesRef;
    if (ref == null) return;
    await ref.doc(moduleId).delete();
  }

  CollectionReference<Map<String, dynamic>>? get _topicsRef =>
      _firestore?.collection('topics');

  Stream<List<Topic>> streamTopics({required String moduleId}) {
    final ref = _topicsRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref
        .where('moduleId', isEqualTo: moduleId)
        .snapshots()
        .map((snapshot) {
      final list = <Topic>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Topic.fromMap(doc.data(), documentId: doc.id));
        } catch (e) {
          // Skip corrupt document safely
        }
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
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
    if (ref == null || topic.id.isEmpty) return;
    await ref.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteTopic(String topicId) async {
    final ref = _topicsRef;
    if (ref == null || topicId.isEmpty) return;
    await ref.doc(topicId).delete();
  }

  CollectionReference<Map<String, dynamic>>? get _revisionsRef =>
      _firestore?.collection('revisions');

  Stream<List<Revision>> streamRevisions() {
    final ref = _revisionsRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref.snapshots().map((snapshot) {
      final list = <Revision>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Revision.fromMap(doc.data(), documentId: doc.id));
        } catch (e) {
          // Skip corrupt document safely
        }
      }
      return list;
    });
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
    if (ref == null || revision.id.isEmpty) return;
    await ref.doc(revision.id).set(revision.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteRevision(String revisionId) async {
    final ref = _revisionsRef;
    if (ref == null) return;
    await ref.doc(revisionId).delete();
  }
}
