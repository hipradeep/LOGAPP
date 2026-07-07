import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_services/core_services.dart' show JournalLogger;
import '../models/note_entity.dart';

class NoteService implements JournalLogger {
  final CollectionReference _logsCollection =
      FirebaseFirestore.instance.collection('notes');

  // ==================== LOGS OPERATIONS ====================

  Stream<List<NoteEntity>> getNotesStream({DateTime? oldestDate}) {
    var query = _logsCollection.orderBy('timestamp', descending: true);
    if (oldestDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: oldestDate);
    }
    return query
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => NoteEntity.fromFirestore(doc)).toList();
    });
  }

  Future<int> getNextDayNumber() async {
    final snapshot = await _logsCollection.get();
    final uniqueDates = <String>{};
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      if (ts != null) {
        final date = ts.toDate();
        final dateStr = '${date.year}-${date.month}-${date.day}';
        uniqueDates.add(dateStr);
      }
    }
    
    if (uniqueDates.contains(todayStr)) {
      return uniqueDates.length;
    } else {
      return uniqueDates.length + 1;
    }
  }

  Future<String> addEntry(
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    final newEntry = NoteEntity(
      id: '',
      title: title,
      content: content,
      timestamp: DateTime.now(),
      mood: mood,
      tags: tags,
      isPinned: isPinned,
    );
    final docRef = await _logsCollection.add(newEntry.toFirestore());
    return docRef.id;
  }

  /// JournalLogger interface implementation used by pomodoro_module.
  @override
  Future<void> createEntry({
    required String title,
    required String body,
    String? category,
    Map<String, dynamic>? metadata,
  }) async {
    final tags = (metadata?['tags'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    await addEntry(title, body, category ?? '🎯', tags);
  }

  Future<void> updateEntry(
    String id,
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    await _logsCollection.doc(id).update({
      'title': title,
      'content': content,
      'mood': mood,
      'tags': tags,
      'isPinned': isPinned,
    });
  }

  Future<void> togglePin(String id, bool isPinned) async {
    await _logsCollection.doc(id).update({'isPinned': isPinned});
  }

  Future<void> deleteEntry(String id) async {
    await _logsCollection.doc(id).delete();
  }
}
