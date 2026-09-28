import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/course.dart';

/// Local disk cache for Course entities to guarantee persistent offline
/// availability and immediate loading upon app launch.
class LocalCourseStorage {
  static const String _fileName = 'study_courses_cache.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalCourseStorage getFile error: $e');
      return null;
    }
  }

  /// Serializes all disk writes into a FIFO queue.
  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<List<dynamic>> _readAndDecodeList(File file) async {
    if (!await file.exists()) return [];
    final jsonString = await file.readAsString();
    if (jsonString.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) return decoded;
      return [];
    } catch (e) {
      debugPrint('LocalCourseStorage JSON format error, attempting recovery: $e');
      List<dynamic>? recovered;

      if (e is FormatException && e.offset != null && e.offset! > 0) {
        try {
          final candidate = jsonString.substring(0, e.offset).trim();
          final decoded = jsonDecode(candidate);
          if (decoded is List) recovered = decoded;
        } catch (_) {}
      }

      if (recovered == null) {
        final lastBracket = jsonString.lastIndexOf(']');
        if (lastBracket != -1) {
          try {
            final candidate = jsonString.substring(0, lastBracket + 1);
            final decoded = jsonDecode(candidate);
            if (decoded is List) recovered = decoded;
          } catch (_) {}
        }
      }

      if (recovered != null) {
        debugPrint('LocalCourseStorage recovered ${recovered.length} courses. Repairing file on disk.');
        try {
          await file.writeAsString(jsonEncode(recovered), flush: true);
        } catch (_) {}
        return recovered;
      }

      debugPrint('LocalCourseStorage could not recover corrupted cache. Resetting file.');
      try {
        await file.writeAsString('[]', flush: true);
      } catch (_) {}
      return [];
    }
  }

  /// Loads cached courses from local disk.
  static Future<List<Course>> loadCourses() async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final jsonList = await _readAndDecodeList(file);
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
  static Future<void> saveCourses(List<Course> courses) {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;
        final jsonList = courses.map((c) => c.toMap(forLocalJson: true)).toList();
        await file.writeAsString(jsonEncode(jsonList), flush: true);
      } catch (e) {
        debugPrint('Error saving cached courses: $e');
      }
    });
  }

  /// Clears all locally cached courses from disk.
  static Future<void> clearAll() {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error clearing courses cache: $e');
      }
    });
  }
}
