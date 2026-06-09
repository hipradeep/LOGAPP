import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/log_entry.dart';

class LogService {
  final CollectionReference _logsCollection =
      FirebaseFirestore.instance.collection('logs');

  // ==================== LOGS OPERATIONS ====================

  Stream<List<LogEntry>> getLogsStream() {
    return _logsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogEntry.fromFirestore(doc)).toList();
    });
  }

  Future<void> createEntry(String title, String content, String mood, List<String> tags) async {
    final newEntry = LogEntry(
      id: '',
      title: title,
      content: content,
      timestamp: DateTime.now(),
      mood: mood,
      tags: tags,
    );
    await _logsCollection.add(newEntry.toFirestore());
  }

  Future<void> updateEntry(
    String id,
    String title,
    String content,
    String mood,
    List<String> tags,
  ) async {
    await _logsCollection.doc(id).update({
      'title': title,
      'content': content,
      'mood': mood,
      'tags': tags,
    });
  }

  Future<void> deleteEntry(String id) async {
    await _logsCollection.doc(id).delete();
  }
}
