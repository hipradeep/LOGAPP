import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/section.dart';
import '../models/subsection.dart';

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

  // === COURSES ===
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
    await ref.doc(course.id).update(course.toMap());
  }

  Future<void> deleteCourse(String courseId) async {
    final ref = _coursesRef;
    if (ref == null) return;
    await ref.doc(courseId).delete();
  }

  // === SECTIONS ===
  CollectionReference<Map<String, dynamic>>? get _sectionsRef =>
      _firestore?.collection('sections');

  Stream<List<Section>> streamSections({required String courseId}) {
    final ref = _sectionsRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snapshot) {
      final list = <Section>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Section.fromMap(doc.data(), documentId: doc.id));
        } catch (e) {
          // Skip corrupt document safely
        }
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  Future<void> addSection(Section section) async {
    final ref = _sectionsRef;
    if (ref == null) return;
    final docRef = section.id.isEmpty ? ref.doc() : ref.doc(section.id);
    final sectionToSave = section.id.isEmpty ? section.copyWith(id: docRef.id) : section;
    await docRef.set(sectionToSave.toMap());
  }

  // === SUBSECTIONS ===
  CollectionReference<Map<String, dynamic>>? get _subsectionsRef =>
      _firestore?.collection('subsections');

  Stream<List<Subsection>> streamSubsections({required String sectionId}) {
    final ref = _subsectionsRef;
    if (ref == null) {
      return const Stream.empty();
    }
    return ref
        .where('sectionId', isEqualTo: sectionId)
        .snapshots()
        .map((snapshot) {
      final list = <Subsection>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Subsection.fromMap(doc.data(), documentId: doc.id));
        } catch (e) {
          // Skip corrupt document safely
        }
      }
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return list;
    });
  }

  Future<void> addSubsection(Subsection subsection) async {
    final ref = _subsectionsRef;
    if (ref == null) return;
    final docRef = subsection.id.isEmpty ? ref.doc() : ref.doc(subsection.id);
    final subToSave = subsection.id.isEmpty ? subsection.copyWith(id: docRef.id) : subsection;
    await docRef.set(subToSave.toMap());
  }
}
