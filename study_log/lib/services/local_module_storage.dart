import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/module.dart';

/// Local disk cache for Module entities to guarantee persistent offline availability.
class LocalModuleStorage {
  static const String _fileName = 'study_modules_cache.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalModuleStorage getFile error: $e');
      return null;
    }
  }

  /// Serializes all disk writes into a FIFO queue to prevent race conditions and partial file corruptions.
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

  /// Reads and parses the JSON list from disk, with self-healing recovery if
  /// unexpected characters or corrupted trailing chunks are encountered.
  static Future<List<dynamic>> _readAndDecodeList(File file) async {
    if (!await file.exists()) return [];
    final jsonString = await file.readAsString();
    if (jsonString.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) return decoded;
      return [];
    } catch (e) {
      debugPrint('LocalModuleStorage JSON format error, attempting recovery: $e');
      List<dynamic>? recovered;

      // 1. If FormatException provides an offset, attempt slice up to offset
      if (e is FormatException && e.offset != null && e.offset! > 0) {
        try {
          final candidate = jsonString.substring(0, e.offset).trim();
          final decoded = jsonDecode(candidate);
          if (decoded is List) recovered = decoded;
        } catch (_) {}
      }

      // 2. Try looking for the nearest closing bracket ']' before trailing garbage
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
        debugPrint('LocalModuleStorage successfully recovered ${recovered.length} modules. Repairing cache on disk.');
        try {
          await file.writeAsString(jsonEncode(recovered), flush: true);
        } catch (_) {}
        return recovered;
      }

      // 3. Reset corrupted cache file to prevent repeated format exceptions
      debugPrint('LocalModuleStorage could not recover corrupted cache. Resetting file.');
      try {
        await file.writeAsString('[]', flush: true);
      } catch (_) {}
      return [];
    }
  }

  /// Loads all cached modules across all courses.
  static Future<List<Module>> loadAllModules() async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final jsonList = await _readAndDecodeList(file);
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
      if (file == null) return [];

      final jsonList = await _readAndDecodeList(file);
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
  /// Writes are serialized via [_synchronized] to avoid concurrent file collision.
  static Future<void> saveModulesForCourse(String courseId, List<Module> courseModules) {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;

        final allJson = await _readAndDecodeList(file);

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
    });
  }

  /// Overwrites all cached modules atomically.
  static Future<void> saveAllModules(List<Module> modules) {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;
        final jsonList = modules.map((m) => m.toMap(forLocalJson: true)).toList();
        await file.writeAsString(jsonEncode(jsonList), flush: true);
      } catch (e) {
        debugPrint('Error saving all cached modules: $e');
      }
    });
  }

  /// Clears all locally cached modules from disk.
  static Future<void> clearAll() {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error clearing modules cache: $e');
      }
    });
  }
}
