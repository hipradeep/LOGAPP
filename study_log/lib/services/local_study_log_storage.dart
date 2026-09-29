import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/study_log.dart';

/// Local disk cache for [StudyLog] entities ensuring high-speed queries for streaks & progress.
class LocalStudyLogStorage {
  static const String _fileName = 'study_logs_cache.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalStudyLogStorage getFile error: $e');
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
      debugPrint('LocalStudyLogStorage JSON format error, attempting recovery: $e');
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
        debugPrint('LocalStudyLogStorage recovered ${recovered.length} logs. Repairing file on disk.');
        try {
          await file.writeAsString(jsonEncode(recovered), flush: true);
        } catch (_) {}
        return recovered;
      }

      debugPrint('LocalStudyLogStorage could not recover corrupted cache. Resetting file.');
      try {
        await file.writeAsString('[]', flush: true);
      } catch (_) {}
      return [];
    }
  }

  /// Loads all cached study logs from disk.
  static Future<List<StudyLog>> loadAll() async {
    try {
      final file = await _getFile();
      if (file == null) return [];

      final jsonList = await _readAndDecodeList(file);
      final logs = <StudyLog>[];
      for (final item in jsonList) {
        if (item is Map) {
          try {
            logs.add(StudyLog.fromMap(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      return logs;
    } catch (e) {
      debugPrint('LocalStudyLogStorage loadAll error: $e');
      return [];
    }
  }

  /// Fast-path query: loads study logs on or after [cutoffDate].
  static Future<List<StudyLog>> loadSince(DateTime cutoffDate) async {
    final all = await loadAll();
    final cutoffNormalized = DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
    return all.where((log) {
      final logNorm = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      return !logNorm.isBefore(cutoffNormalized);
    }).toList();
  }

  /// Records a new study log entry and appends it to disk.
  static Future<void> addLog(StudyLog log) async {
    await _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;

        final current = await loadAll();
        // Prevent duplicate logs with same ID
        final updated = current.where((e) => e.id != log.id).toList()..add(log);

        await file.writeAsString(
          jsonEncode(updated.map((e) => e.toMap(forLocalJson: true)).toList()),
          flush: true,
        );
      } catch (e) {
        debugPrint('LocalStudyLogStorage addLog error: $e');
      }
    });
  }

  /// Overwrites disk cache with a full list of study logs.
  static Future<void> saveAll(List<StudyLog> logs) async {
    await _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;

        await file.writeAsString(
          jsonEncode(logs.map((e) => e.toMap(forLocalJson: true)).toList()),
          flush: true,
        );
      } catch (e) {
        debugPrint('LocalStudyLogStorage saveAll error: $e');
      }
    });
  }

  /// Clears all study logs from disk.
  static Future<void> clearAll() async {
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('LocalStudyLogStorage clearAll error: $e');
    }
  }
}
