import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/revision_topic.dart';

/// Local disk cache for [RevisionTopic] entities ensuring fast, offline access.
class LocalRevisionTopicStorage {
  static const String _fileName = 'study_revision_topics_cache.json';
  static Future<void> _writeQueue = Future.value();

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/$_fileName');
    } catch (e) {
      debugPrint('LocalRevisionTopicStorage getFile error: $e');
      return null;
    }
  }

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

  static Future<Map<String, dynamic>> _readMap(File file) async {
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    if (content.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('LocalRevisionTopicStorage JSON decode error: $e');
    }
    return {};
  }

  /// Loads all revision topics for a specific revision.
  static Future<List<RevisionTopic>> loadTopicsForRevision(String revisionId) async {
    if (revisionId.isEmpty) return [];
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) return [];

      final map = await _readMap(file);
      final rawList = map[revisionId];
      if (rawList is List) {
        return rawList
            .whereType<Map>()
            .map((item) => RevisionTopic.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (e) {
      debugPrint('LocalRevisionTopicStorage load error: $e');
    }
    return [];
  }

  /// Saves a list of revision topics for a specific revision.
  static Future<void> saveTopics(
    String revisionId,
    List<RevisionTopic> topics,
  ) async {
    if (revisionId.isEmpty) return;
    await _synchronized(() async {
      try {
        final file = await _getFile();
        if (file == null) return;

        final map = await _readMap(file);
        map[revisionId] = topics.map((t) => t.toMap(forLocalJson: true)).toList();
        await file.writeAsString(jsonEncode(map), flush: true);
      } catch (e) {
        debugPrint('LocalRevisionTopicStorage save error: $e');
      }
    });
  }

  /// Adds a single revision topic.
  static Future<void> addTopic(String revisionId, RevisionTopic topic) async {
    final list = await loadTopicsForRevision(revisionId);
    list.add(topic);
    await saveTopics(revisionId, list);
  }

  /// Updates a single revision topic.
  static Future<void> updateTopic(String revisionId, RevisionTopic topic) async {
    final list = await loadTopicsForRevision(revisionId);
    final idx = list.indexWhere((t) => t.id == topic.id);
    if (idx != -1) {
      list[idx] = topic;
    } else {
      list.add(topic);
    }
    await saveTopics(revisionId, list);
  }

  /// Deletes a revision topic by ID.
  static Future<void> deleteTopic(String revisionId, String topicId) async {
    final list = await loadTopicsForRevision(revisionId);
    list.removeWhere((t) => t.id == topicId);
    await saveTopics(revisionId, list);
  }
}
