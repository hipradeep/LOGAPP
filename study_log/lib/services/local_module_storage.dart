import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/module.dart';

/// Local disk cache for Module entities to guarantee persistent offline availability.
class LocalModuleStorage {
  static const String _fileName = 'study_modules_cache.json';

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalModuleStorage getFile error: $e');
      return null;
    }
  }

  /// Loads all cached modules across all courses.
  static Future<List<Module>> loadAllModules() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Module> modules = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            modules.add(Module.fromMap(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Error parsing cached module: $e');
          }
        }
      }
      modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return modules;
    } catch (e) {
      debugPrint('Error loading all cached modules: $e');
      return [];
    }
  }

  /// Loads cached modules for a specific courseId.
  static Future<List<Module>> loadModules(String courseId) async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return [];
      }
      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<Module> modules = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            final module = Module.fromMap(Map<String, dynamic>.from(item));
            if (module.courseId == courseId) {
              modules.add(module);
            }
          } catch (e) {
            debugPrint('Error parsing cached module: $e');
          }
        }
      }
      modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return modules;
    } catch (e) {
      debugPrint('Error loading cached modules: $e');
      return [];
    }
  }

  /// Saves or updates modules for a specific courseId while preserving others.
  static Future<void> saveModulesForCourse(String courseId, List<Module> courseModules) async {
    try {
      final file = await _getFile();
      if (file == null) return;

      List<dynamic> allJson = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          try {
            allJson = jsonDecode(content) as List<dynamic>;
          } catch (_) {
            allJson = [];
          }
        }
      }

      // Filter out existing modules for this courseId
      final remaining = allJson.where((item) {
        if (item is Map) {
          return item['courseId'] != courseId;
        }
        return false;
      }).toList();

      // Add new course modules
      remaining.addAll(courseModules.map((s) => s.toMap(forLocalJson: true)));

      await file.writeAsString(jsonEncode(remaining), flush: true);
    } catch (e) {
      debugPrint('Error saving cached modules: $e');
    }
  }
}
