import 'dart:async';
import '../models/study_log.dart';
import 'database_service.dart';

/// Local storage for [StudyLog] entities backed by SQLite [DatabaseService].
class LocalStudyLogStorage {
  /// Loads all study logs from SQLite.
  static Future<List<StudyLog>> loadAll() {
    return DatabaseService.instance.getStudyLogs();
  }

  /// Loads study logs created on or after [cutoffDate].
  static Future<List<StudyLog>> loadLogsSince(DateTime cutoffDate) async {
    final all = await loadAll();
    final cutoffNormalized = DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);
    return all.where((log) {
      final logNorm = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      return !logNorm.isBefore(cutoffNormalized);
    }).toList();
  }

  /// Records a new study log entry in SQLite.
  static Future<void> addLog(StudyLog log) {
    return DatabaseService.instance.addStudyLog(log);
  }

  /// Overwrites SQLite cache with a full list of study logs.
  static Future<void> saveAll(List<StudyLog> logs) {
    return DatabaseService.instance.saveStudyLogs(logs);
  }

  /// Clears all study logs from SQLite.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearStudyLogs();
  }

  /// Deletes study log entries for a specific topic and log type.
  static Future<void> deleteLogForTopic({
    required String topicId,
    required String type,
  }) {
    return DatabaseService.instance.deleteStudyLogForTopic(
      topicId: topicId,
      type: type,
    );
  }

  /// Deletes study log entries for a specific module and log type.
  static Future<void> deleteLogForModule({
    required String moduleId,
    required String type,
  }) {
    return DatabaseService.instance.deleteStudyLogForModule(
      moduleId: moduleId,
      type: type,
    );
  }
}
