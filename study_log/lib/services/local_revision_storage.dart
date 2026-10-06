import 'dart:async';
import '../models/revision.dart';
import 'database_service.dart';

/// Local storage for Revision entities backed by SQLite [DatabaseService].
class LocalRevisionStorage {
  /// Loads all cached revisions from SQLite.
  static Future<List<RevisionModule>> loadRevisions() {
    return DatabaseService.instance.getRevisions();
  }

  /// Alias for backward compatibility.
  static Future<List<RevisionModule>> loadAll() => loadRevisions();

  /// Saves the full list of revisions to SQLite.
  static Future<void> saveRevisions(List<RevisionModule> revisions) {
    return DatabaseService.instance.saveRevisions(revisions);
  }

  /// Alias for backward compatibility.
  static Future<void> saveAll(List<RevisionModule> revisions) =>
      saveRevisions(revisions);

  /// Looks up a single revision by id.
  static Future<RevisionModule?> loadRevision(String id) async {
    final list = await loadRevisions();
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Loads timestamps of all completed revision sessions.
  static Future<List<DateTime>> loadRevisionEvents() {
    return DatabaseService.instance
        .loadRevisionEventsSince(DateTime.fromMillisecondsSinceEpoch(0));
  }

  /// Fast query for progress analytics: loads revision events on or after [cutoffDate].
  static Future<List<DateTime>> loadRevisionEventsSince(DateTime cutoffDate) {
    return DatabaseService.instance.loadRevisionEventsSince(cutoffDate);
  }

  /// Records a timestamp when a revision is completed.
  static Future<void> recordRevisionEvent(DateTime at) async {
    // Stored in study_logs via StudyLogType.revisionCompleted
  }

  /// Clears all revisions from SQLite.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearRevisions();
  }

  /// Loads suppressed module IDs that the user manually removed.
  static Future<Set<String>> loadSuppressedModuleIds() {
    return DatabaseService.instance.loadSuppressedModuleIds();
  }

  /// Saves suppressed module IDs.
  static Future<void> saveSuppressedModuleIds(Set<String> ids) {
    return DatabaseService.instance.saveSuppressedModuleIds(ids);
  }
}
