import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/firestore_service.dart';
import '../services/local_course_storage.dart';
import '../services/service_locator.dart';

class CoursesController extends ChangeNotifier {
  final FirestoreService _firestoreService;
  StreamSubscription<List<Course>>? _coursesSubscription;
  Timer? _loadingFallbackTimer;

  List<Course> _courses = [];
  final Set<String> _deletedCourseIds = {};
  bool _isLoading = true;
  String? _errorMessage;

  CoursesController({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _init();
  }

  List<Course> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _init() async {
    // 1. Immediately hydrate from local storage so UI is populated instantly
    try {
      final cached = await LocalCourseStorage.loadCourses();
      if (cached.isNotEmpty) {
        _courses = cached;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Local courses hydration error: $e');
    }

    // 2. Start Firestore realtime stream
    _initStream();
  }

  void _initStream() {
    _coursesSubscription?.cancel();
    _loadingFallbackTimer?.cancel();
    _errorMessage = null;

    if (_courses.isEmpty) {
      _isLoading = true;
    }

    // Safety fallback: Never leave the user stuck on an infinite loader
    _loadingFallbackTimer = Timer(const Duration(seconds: 2), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });

    try {
      _coursesSubscription = _firestoreService.streamCourses().listen(
        (remoteCourses) {
          _loadingFallbackTimer?.cancel();
          _isLoading = false;
          _errorMessage = null;
          _mergeCourses(remoteCourses);
        },
        onError: (error) {
          _loadingFallbackTimer?.cancel();
          debugPrint('Error streaming courses from Firebase: $error');
          _isLoading = false;
          // Only show error if we have no courses to display
          if (_courses.isEmpty) {
            _errorMessage = error.toString();
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _loadingFallbackTimer?.cancel();
      _isLoading = false;
      if (_courses.isEmpty) {
        _errorMessage = e.toString();
      }
      notifyListeners();
    }
  }

  void _mergeCourses(List<Course> remoteCourses) {
    final Map<String, Course> merged = {};

    // 1. Add valid remote courses (ignoring recently deleted ones)
    for (final course in remoteCourses) {
      if (!_deletedCourseIds.contains(course.id)) {
        merged[course.id] = course;
      }
    }

    // 2. Retain local courses that might not yet have reached Firestore
    for (final local in _courses) {
      if (!_deletedCourseIds.contains(local.id)) {
        if (!merged.containsKey(local.id)) {
          merged[local.id] = local;
        }
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _courses = result;
    LocalCourseStorage.saveCourses(_courses);
    notifyListeners();
  }

  Future<void> addCourse({
    required String title,
    required String description,
    DateTime? deadline,
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
      createdAt: now,
      updatedAt: now,
    );

    // 1. Optimistic update and instant local disk persistence
    _deletedCourseIds.remove(newId);
    _courses.removeWhere((c) => c.id == newId);
    _courses.insert(0, newCourse);
    _isLoading = false;
    _errorMessage = null; // Clear any previous error!
    await LocalCourseStorage.saveCourses(_courses);
    notifyListeners();

    // 2. Persist to Firestore with timeout fallback
    try {
      await _firestoreService.addCourse(newCourse).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore write timed out, course safely persisted in local storage.');
        },
      );
    } catch (e) {
      debugPrint('Firestore addCourse error (saved locally): $e');
    }
  }

  Future<void> updateCourse(Course updatedCourse) async {
    final courseToSave = updatedCourse.copyWith(updatedAt: DateTime.now());
    final index = _courses.indexWhere((c) => c.id == courseToSave.id);
    if (index != -1) {
      _courses[index] = courseToSave;
      await LocalCourseStorage.saveCourses(_courses);
      notifyListeners();
    }

    try {
      await _firestoreService.updateCourse(courseToSave).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore update timed out, kept local state.');
        },
      );
    } catch (e) {
      debugPrint('Firestore update error (saved locally): $e');
    }
  }

  Future<void> deleteCourse(String courseId) async {
    _deletedCourseIds.add(courseId);
    _courses.removeWhere((c) => c.id == courseId);
    await LocalCourseStorage.saveCourses(_courses);
    notifyListeners();

    try {
      await _firestoreService.deleteCourse(courseId).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Firestore delete timed out, kept local deletion.');
        },
      );
    } catch (e) {
      debugPrint('Firestore delete error (saved locally): $e');
    }
  }

  /// Reloads courses from local disk storage and syncs with Firestore stream.
  Future<void> loadCourses() async {
    _deletedCourseIds.clear();
    try {
      final cached = await LocalCourseStorage.loadCourses();
      _courses = cached;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error reloading courses: $e');
    }
    _initStream();
  }

  /// Clears in-memory state and re-fetches from local cache & Firestore.
  void refresh() {
    loadCourses();
  }

  @override
  void dispose() {
    _loadingFallbackTimer?.cancel();
    _coursesSubscription?.cancel();
    super.dispose();
  }
}
