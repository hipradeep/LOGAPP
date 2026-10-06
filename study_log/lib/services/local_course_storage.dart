import 'dart:async';
import '../models/course.dart';
import 'database_service.dart';

/// Local storage for Course entities backed by SQLite [DatabaseService].
class LocalCourseStorage {
  /// Loads courses from local SQLite storage.
  static Future<List<Course>> loadCourses() {
    return DatabaseService.instance.getCourses();
  }

  /// Saves the full list of courses to local SQLite storage.
  static Future<void> saveCourses(List<Course> courses) {
    return DatabaseService.instance.saveCourses(courses);
  }

  /// Clears all courses from local SQLite storage.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearCourses();
  }
}
