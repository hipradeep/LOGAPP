import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/course.dart';

/// Local disk cache for Course entities to guarantee persistent offline
/// availability and immediate loading upon app launch.
class LocalCourseStorage {
  static const String _fileName = 'study_courses_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalCourseStorage getFile error: $e');
      return null;
    }
  }

  /// Loads cached courses from local disk.
  static Future<List<Course>> loadCourses() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Course> courses = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            courses.add(Course.fromMap(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Error parsing cached course: $e');
          }
        }
      }
      // Keep sorted by creation date
      courses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return courses;
    } catch (e) {
      debugPrint('Error loading cached courses: $e');
      return [];
    }
  }

  /// Saves the full list of courses to local disk.
  static Future<void> saveCourses(List<Course> courses) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      final jsonList = courses.map((c) => c.toMap(forLocalJson: true)).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('Error saving cached courses: $e');
    }
  }
}
