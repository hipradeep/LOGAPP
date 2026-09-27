import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course.dart';
import '../models/section.dart';
import '../models/subsection.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // === COURSES ===
  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      _firestore.collection('courses');

  Stream<List<Course>> streamCourses() {
    return _coursesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Course.fromMap(doc.data(), documentId: doc.id);
      }).toList();
    });
  }

  Future<void> addCourse(Course course) async {
    final docRef = course.id.isEmpty ? _coursesRef.doc() : _coursesRef.doc(course.id);
    final courseToSave = course.id.isEmpty ? course.copyWith(id: docRef.id) : course;
    await docRef.set(courseToSave.toMap());
  }

  Future<void> updateCourse(Course course) async {
    await _coursesRef.doc(course.id).update(course.toMap());
  }

  Future<void> deleteCourse(String courseId) async {
    await _coursesRef.doc(courseId).delete();
  }

  // === SECTIONS ===
  CollectionReference<Map<String, dynamic>> get _sectionsRef =>
      _firestore.collection('sections');

  Stream<List<Section>> streamSections({required String courseId}) {
    return _sectionsRef
        .where('courseId', isEqualTo: courseId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Section.fromMap(doc.data(), documentId: doc.id);
      }).toList();
    });
  }

  Future<void> addSection(Section section) async {
    final docRef = section.id.isEmpty ? _sectionsRef.doc() : _sectionsRef.doc(section.id);
    final sectionToSave = section.id.isEmpty ? section.copyWith(id: docRef.id) : section;
    await docRef.set(sectionToSave.toMap());
  }

  // === SUBSECTIONS ===
  CollectionReference<Map<String, dynamic>> get _subsectionsRef =>
      _firestore.collection('subsections');

  Stream<List<Subsection>> streamSubsections({required String sectionId}) {
    return _subsectionsRef
        .where('sectionId', isEqualTo: sectionId)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Subsection.fromMap(doc.data(), documentId: doc.id);
      }).toList();
    });
  }

  Future<void> addSubsection(Subsection subsection) async {
    final docRef = subsection.id.isEmpty ? _subsectionsRef.doc() : _subsectionsRef.doc(subsection.id);
    final subToSave = subsection.id.isEmpty ? subsection.copyWith(id: docRef.id) : subsection;
    await docRef.set(subToSave.toMap());
  }
}
