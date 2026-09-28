import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/topic.dart';

/// Local disk cache for Topic entities to guarantee persistent offline availability.
class LocalTopicStorage {
  static const String _fileName = 'study_topics_cache.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalTopicStorage getFile error: $e');
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

  /// Reads and parses the JSON map from disk, with self-healing recovery if
  /// unexpected characters or corrupted trailing chunks are encountered.
  static Future<Map<String, dynamic>> _readAndDecodeMap(File file) async {
    if (!await file.exists()) return {};
    final jsonString = await file.readAsString();
    if (jsonString.trim().isEmpty) return {};

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {};
    } catch (e) {
      debugPrint('LocalTopicStorage JSON format error, attempting recovery: $e');
      Map<String, dynamic>? recovered;

      // 1. If FormatException provides an offset, attempt slice up to offset
      if (e is FormatException && e.offset != null && e.offset! > 0) {
        try {
          final candidate = jsonString.substring(0, e.offset).trim();
          final decoded = jsonDecode(candidate);
          if (decoded is Map) recovered = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }

      // 2. Try looking for the nearest closing brace '}' before trailing garbage
      if (recovered == null) {
        final lastBrace = jsonString.lastIndexOf('}');
        if (lastBrace != -1) {
          try {
            final candidate = jsonString.substring(0, lastBrace + 1);
            final decoded = jsonDecode(candidate);
            if (decoded is Map) recovered = Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
      }

      if (recovered != null) {
        debugPrint('LocalTopicStorage successfully recovered ${recovered.length} buckets. Repairing cache on disk.');
        try {
          await file.writeAsString(jsonEncode(recovered), flush: true);
        } catch (_) {}
        return recovered;
      }

      // 3. Reset corrupted cache file to prevent repeated format exceptions
      debugPrint('LocalTopicStorage could not recover corrupted cache. Resetting file.');
      try {
        await file.writeAsString('{}', flush: true);
      } catch (_) {}
      return {};
    }
  }

  /// Loads cached topics for a specific module title or module key.
  static Future<List<Topic>> loadTopics(String moduleKey) async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final data = await _readAndDecodeMap(file);
      final List<dynamic>? rawList = data[moduleKey] as List<dynamic>?;
      if (rawList == null || rawList.isEmpty) return [];

      return rawList
          .map((item) => Topic.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading cached topics: $e');
      return [];
    }
  }

  /// Reads every bucket from disk in a single pass.
  static Future<Map<String, List<Topic>>> loadAllBuckets() async {
    try {
      final file = await _getFile();
      if (file == null) return {};

      final decoded = await _readAndDecodeMap(file);

      final buckets = <String, List<Topic>>{};
      decoded.forEach((key, value) {
        if (value is! List) return;
        final items = <Topic>[];
        for (final entry in value) {
          if (entry is Map) {
            try {
              items.add(Topic.fromMap(Map<String, dynamic>.from(entry)));
            } catch (e) {
              debugPrint('Error parsing cached topic: $e');
            }
          }
        }
        buckets[key.toString()] = items;
      });
      return buckets;
    } catch (e) {
      debugPrint('Error loading cached topic buckets: $e');
      return {};
    }
  }

  /// Fast query for progress analytics: loads completion timestamps for completed
  /// topics within the specified date window directly from raw JSON, avoiding
  /// the allocation of full Topic model objects for incomplete or historical items.
  static Future<List<DateTime>> loadCompletedTopicDatesSince(DateTime cutoffDate) async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final data = await _readAndDecodeMap(file);
      final completedDates = <DateTime>[];

      for (final value in data.values) {
        if (value is! List) continue;
        for (final entry in value) {
          if (entry is Map) {
            final statusStr = entry['status']?.toString();
            if (statusStr == 'completed') {
              final dt = Topic.parseDateTime(entry['completedAt']);
              if (dt != null && !dt.isBefore(cutoffDate)) {
                completedDates.add(dt);
              }
            }
          }
        }
      }
      return completedDates;
    } catch (e) {
      debugPrint('Error loading completed topic dates: $e');
      return [];
    }
  }

  /// Loads the topics belonging to a specific Module.
  ///
  /// Prefers records tagged with [moduleId], which stays correct when a
  /// module is renamed or two modules share a title. Falls back to the bucket
  /// keyed by [fallbackTitle] for records written before ids were stored.
  static Future<List<Topic>> loadTopicsForModule({
    required String moduleId,
    String? fallbackTitle,
  }) async {
    if (moduleId.isEmpty) {
      return fallbackTitle == null
          ? <Topic>[]
          : loadTopics(fallbackTitle);
    }
    return resolveForModule(
      await loadAllBuckets(),
      moduleId: moduleId,
      fallbackTitle: fallbackTitle,
    );
  }

  /// Synchronous variant of [loadTopicsForModule] for callers that
  /// already hold the buckets and must not re-read the file per module.
  static List<Topic> resolveForModule(
    Map<String, List<Topic>> buckets, {
    required String moduleId,
    String? fallbackTitle,
  }) {
    if (moduleId.isEmpty) {
      if (fallbackTitle == null) return <Topic>[];
      if (buckets.containsKey(fallbackTitle)) return buckets[fallbackTitle]!;
      for (final entry in buckets.entries) {
        if (entry.key.toLowerCase() == fallbackTitle.toLowerCase()) {
          return entry.value;
        }
      }
      return <Topic>[];
    }

    // 1. Direct key lookup by moduleId
    if (buckets.containsKey(moduleId) && buckets[moduleId]!.isNotEmpty) {
      return buckets[moduleId]!;
    }

    // 2. Case-insensitive key lookup for moduleId
    for (final entry in buckets.entries) {
      if (entry.key.toLowerCase() == moduleId.toLowerCase() && entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    // 3. Match by item.moduleId across all buckets (with deduplication)
    final byId = <Topic>[];
    final seen = <String>{};
    for (final items in buckets.values) {
      for (final item in items) {
        if (item.moduleId == moduleId) {
          final idKey = item.id.isNotEmpty ? item.id : item.title;
          if (seen.add(idKey)) {
            byId.add(item);
          }
        }
      }
    }
    if (byId.isNotEmpty) return byId;

    // 4. Fallback title lookup
    if (fallbackTitle != null) {
      if (buckets.containsKey(fallbackTitle)) {
        return buckets[fallbackTitle]!;
      }
      for (final entry in buckets.entries) {
        if (entry.key.toLowerCase() == fallbackTitle.toLowerCase()) {
          return entry.value;
        }
      }
    }
    return <Topic>[];
  }

  /// Saves topics for a specific moduleKey to local disk.
  static Future<void> saveTopics(
    String moduleKey,
    List<Topic> items,
  ) {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;

        final data = await _readAndDecodeMap(file);
        data[moduleKey] = items.map((i) => i.toMap(forLocalJson: true)).toList();

        // Buckets are keyed by module title, so a renamed module would leave the
        // previous title's bucket behind holding the same records. Drop any bucket
        // that duplicates the module id we just wrote, otherwise id-based reads
        // would count those topics twice.
        if (items.isNotEmpty && items.first.moduleId.isNotEmpty) {
          final moduleId = items.first.moduleId;
          data.removeWhere((key, value) {
            if (key == moduleKey || value is! List) return false;
            for (final entry in value) {
              if (entry is Map && entry['moduleId'] == moduleId) return true;
            }
            return false;
          });
        }

        await file.writeAsString(jsonEncode(data), flush: true);
      } catch (e) {
        debugPrint('Error saving cached topics: $e');
      }
    });
  }

  /// Clears all locally cached topics from disk.
  static Future<void> clearAll() {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file != null && await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error clearing topics cache: $e');
      }
    });
  }
}
