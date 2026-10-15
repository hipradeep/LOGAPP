import 'dart:async';
import '../models/topic_revision.dart';
import 'database_service.dart';

/// Local storage for [TopicRevision] entities backed by SQLite [DatabaseService].
class LocalTopicRevisionStorage {
  /// Loads all cached topic revisions from SQLite.
  static Future<List<TopicRevision>> loadTopicRevisions({
    String? courseId,
    String? moduleId,
  }) {
    return DatabaseService.instance.getTopicRevisions(
      courseId: courseId,
      moduleId: moduleId,
    );
  }

  /// Alias for loading all topic revisions.
  static Future<List<TopicRevision>> loadAll() => loadTopicRevisions();

  /// Saves the full list of topic revisions to SQLite.
  static Future<void> saveTopicRevisions(List<TopicRevision> topicRevisions) {
    return DatabaseService.instance.saveTopicRevisions(topicRevisions);
  }

  /// Alias for saving all topic revisions.
  static Future<void> saveAll(List<TopicRevision> topicRevisions) =>
      saveTopicRevisions(topicRevisions);

  /// Looks up a single topic revision by its record id.
  static Future<TopicRevision?> loadTopicRevision(String id) async {
    final list = await loadAll();
    for (final tr in list) {
      if (tr.id == id) return tr;
    }
    return null;
  }

  /// Looks up an active topic revision by the base [topicId].
  static Future<TopicRevision?> loadByTopicId(String topicId) {
    return DatabaseService.instance.getTopicRevisionByTopicId(topicId);
  }

  /// Adds a new topic revision record.
  static Future<void> addTopicRevision(TopicRevision topicRevision) {
    return DatabaseService.instance.addTopicRevision(topicRevision);
  }

  /// Updates an existing topic revision record.
  static Future<void> updateTopicRevision(TopicRevision topicRevision) {
    return DatabaseService.instance.updateTopicRevision(topicRevision);
  }

  /// Deletes a topic revision record by id.
  static Future<void> deleteTopicRevision(String id) {
    return DatabaseService.instance.deleteTopicRevision(id);
  }

  /// Deletes a topic revision record by its underlying [topicId].
  static Future<void> deleteByTopicId(String topicId) {
    return DatabaseService.instance.deleteTopicRevisionByTopicId(topicId);
  }

  /// Clears all topic revisions from SQLite.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearTopicRevisions();
  }
}
