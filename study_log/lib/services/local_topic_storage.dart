import 'dart:async';
import '../models/topic.dart';
import 'database_service.dart';

/// Local storage for Topic entities backed by SQLite [DatabaseService].
class LocalTopicStorage {
  /// Loads topics for a specific module by key (either [moduleId] or [fallbackTitle]).
  static Future<List<Topic>> loadTopics(String moduleKey) {
    return DatabaseService.instance.getTopics(moduleId: moduleKey);
  }

  /// Loads all topics grouped into a map keyed by moduleId.
  static Future<Map<String, List<Topic>>> loadAllBuckets() async {
    final all = await DatabaseService.instance.getAllTopics();
    final buckets = <String, List<Topic>>{};
    for (final t in all) {
      final key = t.moduleId.isNotEmpty ? t.moduleId : t.courseId;
      buckets.putIfAbsent(key, () => []).add(t);
    }
    return buckets;
  }

  /// Loads topics for a module and returns them keyed by topic id for fast lookup.
  static Future<Map<String, Topic>> loadTopicsMapForModule(String moduleId) async {
    if (moduleId.isEmpty) return {};
    final topics = await loadTopicsForModule(moduleId: moduleId);
    return {for (final t in topics) t.id: t};
  }

  /// Fast query for progress analytics: loads completion timestamps for completed
  /// topics on or after [cutoffDate].
  static Future<List<DateTime>> loadCompletedTopicDatesSince(DateTime cutoffDate) {
    return DatabaseService.instance.loadCompletedTopicDatesSince(cutoffDate);
  }

  /// Loads the topics belonging to a specific Module.
  static Future<List<Topic>> loadTopicsForModule({
    required String moduleId,
    String? fallbackTitle,
  }) async {
    if (moduleId.isNotEmpty) {
      final topics = await DatabaseService.instance.getTopics(moduleId: moduleId);
      if (topics.isNotEmpty) return topics;
    }
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      final all = await DatabaseService.instance.getAllTopics();
      final matched = all.where((t) => t.moduleId == fallbackTitle).toList();
      if (matched.isNotEmpty) return matched;
    }
    return [];
  }

  /// Synchronous variant of [loadTopicsForModule] when caller already has the buckets.
  static List<Topic> resolveForModule(
    Map<String, List<Topic>> buckets, {
    required String moduleId,
    String? fallbackTitle,
  }) {
    if (moduleId.isNotEmpty && buckets.containsKey(moduleId)) {
      return buckets[moduleId]!;
    }
    if (fallbackTitle != null && buckets.containsKey(fallbackTitle)) {
      return buckets[fallbackTitle]!;
    }
    return [];
  }

  /// Saves topics for a specific moduleId in SQLite.
  static Future<void> saveTopics(String moduleKey, List<Topic> items) {
    return DatabaseService.instance.saveTopics(moduleKey, items);
  }

  /// Clears all topics from SQLite.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearTopics();
  }
}
