import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/database_service.dart';
import '../services/local_course_storage.dart';
import '../services/service_locator.dart';
import 'revision_controller.dart';

class CoursesController extends ChangeNotifier {
  final DatabaseService _dbService;
  StreamSubscription<List<Course>>? _coursesSubscription;

  List<Course> _courses = [];
  bool _isLoading = true;
  String? _errorMessage;

  CoursesController({DatabaseService? databaseService})
      : _dbService = databaseService ?? getIt<DatabaseService>() {
    _init();
  }

  /// Active and completed courses (non-archived).
  List<Course> get courses =>
      List.unmodifiable(_courses.where((c) => !c.isArchived));

  /// Alias for non-archived courses.
  List<Course> get activeCourses => courses;

  /// Courses moved to archive.
  List<Course> get archivedCourses =>
      List.unmodifiable(_courses.where((c) => c.isArchived));

  /// All courses including archived.
  List<Course> get allCourses => List.unmodifiable(_courses);

  /// Look up any course by id (active or archived).
  Course? getCourseById(String id) {
    if (id.isEmpty) return null;
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    // 1. Immediately hydrate from local SQLite storage
    try {
      final cached = await _dbService.getCourses();
      if (cached.isNotEmpty) {
        _courses = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local courses hydration error: $e');
    }

    // 2. Start reactive SQLite stream
    _initStream();
  }

  void _initStream() {
    _coursesSubscription?.cancel();
    _errorMessage = null;

    try {
      _coursesSubscription = _dbService.streamCourses().listen(
        (coursesList) {
          _isLoading = false;
          _errorMessage = null;
          _courses = coursesList;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Error streaming courses from database: $error');
          _isLoading = false;
          if (_courses.isEmpty) {
            _errorMessage = error.toString();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      if (_courses.isEmpty) {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  Future<void> addCourse({
    required String title,
    required String description,
    DateTime? deadline,
    int? iconCodePoint,
    int? colorValue,
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final newId = 'course_${now.millisecondsSinceEpoch}';
    final newCourse = Course(
      id: newId,
      title: title,
      description: description,
      status: status,
      deadline: deadline,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistic local update
    _courses.removeWhere((c) => c.id == newId);
    _courses.insert(0, newCourse);
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();

    // Persist to SQLite
    try {
      await _dbService.addCourse(newCourse);
    } catch (e) {
      debugPrint('Database addCourse error: $e');
    }
  }

  Future<void> updateCourse(Course updatedCourse) async {
    final courseToSave = updatedCourse.copyWith(updatedAt: DateTime.now());
    final index = _courses.indexWhere((c) => c.id == courseToSave.id);
    if (index != -1) {
      _courses[index] = courseToSave;
      notifyListeners();
    }

    try {
      await _dbService.updateCourse(courseToSave);
    } catch (e) {
      debugPrint('Database updateCourse error: $e');
    }
  }

  /// Archives a course without deleting its study logs or streak history.
  Future<void> archiveCourse(String courseId) async {
    final course = getCourseById(courseId);
    if (course == null) return;
    await updateCourse(course.copyWith(status: 'archived'));
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().removeRevisionsForCourse(courseId);
    }
  }

  /// Restores an archived course back to active.
  Future<void> unarchiveCourse(String courseId) async {
    final course = getCourseById(courseId);
    if (course == null) return;
    await updateCourse(course.copyWith(status: 'active'));
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().removeRevisionsForCourse(courseId);
    }
  }

  Future<void> deleteCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
    notifyListeners();

    try {
      await _dbService.deleteCourse(courseId);
    } catch (e) {
      debugPrint('Database deleteCourse error: $e');
    }
  }

  /// Reloads courses from local SQLite storage.
  Future<void> loadCourses() async {
    try {
      final list = await _dbService.getCourses();
      _courses = list;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reloading courses: $e');
    }
  }

  /// Clears in-memory state and re-fetches from SQLite.
  void refresh() {
    loadCourses();
  }

  /// Immediately clears in-memory courses list.
  void clear() {
    _courses = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _coursesSubscription?.cancel();
    super.dispose();
  }
}
