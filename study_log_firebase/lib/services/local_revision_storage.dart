import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/revision.dart';

/// Local disk cache for Revision entities to guarantee persistent offline availability.
class LocalRevisionStorage {
  static const String _fileName = 'study_revisions_cache.json';
  static const String _suppressedFileName = 'study_revisions_suppressed.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalRevisionStorage getFile error: $e');
      return null;
    }
  }

  static Future<File?> _getSuppressedFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_suppressedFileName');
    } catch (e) {
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
      debugPrint('LocalRevisionStorage JSON format error, attempting recovery: $e');
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
        debugPrint('LocalRevisionStorage recovered ${recovered.length} revisions. Repairing file on disk.');
        try {
          await file.writeAsString(jsonEncode(recovered), flush: true);
        } catch (_) {}
        return recovered;
      }

      debugPrint('LocalRevisionStorage could not recover corrupted cache. Resetting file.');
      try {
        await file.writeAsString('[]', flush: true);
      } catch (_) {}
      return [];
    }
  }

  static Future<List<Revision>> loadAll() async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final jsonList = await _readAndDecodeList(file);
      final List<Revision> revisions = [];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            revisions.add(Revision.fromMap(Map<String, dynamic>.from(item)));
          } catch (e) {
            debugPrint('Error parsing cached revision: $e');
          }
        }
      }
      return revisions;
    } catch (e) {
      debugPrint('Error loading cached revisions: $e');
      return [];
    }
  }

  static Future<void> saveAll(List<Revision> revisions) {
    return _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;
        await file.writeAsString(
          jsonEncode(revisions.map((r) => r.toMap(forLocalJson: true)).toList()),
          flush: true,
        );
      } catch (e) {
        debugPrint('Error saving cached revisions: $e');
      }
    });
  }

  static const String _revisionEventsFileName = 'study_revision_events.json';

  static Future<File?> _getRevisionEventsFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_revisionEventsFileName');
    } catch (e) {
      return null;
    }
  }

  /// Loads timestamps of all completed revision sessions.
  static Future<List<DateTime>> loadRevisionEvents() async {
    try {
      final file = await _getRevisionEventsFile();
      if (file == null || !await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => DateTime.parse(e.toString())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fast query for progress analytics: loads revision events on or after [cutoffDate].
  static Future<List<DateTime>> loadRevisionEventsSince(DateTime cutoffDate) async {
    try {
      final file = await _getRevisionEventsFile();
      if (file == null || !await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final result = <DateTime>[];
      for (final item in list) {
        try {
          final dt = DateTime.parse(item.toString());
          if (!dt.isBefore(cutoffDate)) {
            result.add(dt);
          }
        } catch (_) {}
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  /// Records a timestamp when a revision is completed.
  static Future<void> recordRevisionEvent(DateTime at) async {
    try {
      final file = await _getRevisionEventsFile();
      if (file == null) return;
      final events = await loadRevisionEvents();
      events.add(at);
      await file.writeAsString(
        jsonEncode(events.map((e) => e.toIso8601String()).toList()),
        flush: true,
      );
    } catch (e) {
      debugPrint('Error recording revision event: $e');
    }
  }

  /// Clears all locally cached revisions from disk.
  static Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
      final eventsFile = await _getRevisionEventsFile();
      if (eventsFile != null && await eventsFile.exists()) {
        await eventsFile.delete();
      }
    } catch (e) {
      debugPrint('Error clearing revisions cache: $e');
    }
  }

  /// Loads the set of moduleIds whose revisions were manually deleted by the
  /// user. Reconcile skips these so they are not immediately re-created.
  static Future<Set<String>> loadSuppressedModuleIds() async {
    try {
      final file = await _getSuppressedFile();
      if (file == null || !await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (e) {
      debugPrint('Error loading suppressed module IDs: $e');
      return {};
    }
  }

  static Future<void> saveSuppressedModuleIds(Set<String> ids) async {
    try {
      final file = await _getSuppressedFile();
      if (file == null) return;
      await file.writeAsString(jsonEncode(ids.toList()), flush: true);
    } catch (e) {
      debugPrint('Error saving suppressed module IDs: $e');
    }
  }
}
