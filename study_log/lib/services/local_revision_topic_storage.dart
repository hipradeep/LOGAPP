import 'dart:async';
import '../models/revision_topic.dart';
import 'database_service.dart';

/// Local storage for [RevisionTopic] entities backed by SQLite [DatabaseService].
class LocalRevisionTopicStorage {
  /// Loads all revision topics for a specific revision from SQLite.
  static Future<List<RevisionTopic>> loadTopicsForRevision(String revisionId) {
    return DatabaseService.instance.getRevisionTopics(revisionId: revisionId);
  }

  /// Alias for compatibility.
  static Future<List<RevisionTopic>> loadTopics(String revisionId) {
    return loadTopicsForRevision(revisionId);
  }

  /// Saves a list of revision topics for a specific revision in SQLite.
  static Future<void> saveTopics(
    String revisionId,
    List<RevisionTopic> topics,
  ) {
    return DatabaseService.instance.saveRevisionTopics(revisionId, topics);
  }

  /// Adds a single revision topic.
  static Future<void> addTopic(String revisionId, RevisionTopic topic) {
    return DatabaseService.instance.addRevisionTopic(topic);
  }

  /// Updates a single revision topic.
  static Future<void> updateTopic(String revisionId, RevisionTopic topic) {
    return DatabaseService.instance.updateRevisionTopic(topic);
  }

  /// Deletes a revision topic by ID.
  static Future<void> deleteTopic(String revisionId, String topicId) {
    return DatabaseService.instance.deleteRevisionTopic(topicId);
  }

  /// Deletes all revision topics for a specific revision.
  static Future<void> deleteTopicsForRevision(String revisionId) {
    return DatabaseService.instance.saveRevisionTopics(revisionId, []);
  }

  /// Clears all revision topics.
  static Future<void> clearAll() {
    return DatabaseService.instance.clearRevisionTopics();
  }
}
