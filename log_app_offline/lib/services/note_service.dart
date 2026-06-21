import 'dart:async';
import '../models/note_entity.dart';
import '../services/hive_service.dart';
import '../utils/id_utils.dart';
import '../utils/hive_utils.dart';

class NoteService {
  // ─── Reactive stream ──────────────────────────────────────────────────────

  /// Emits sorted list of all notes whenever Hive box changes.
  Stream<List<NoteEntity>> getNotesStream({DateTime? oldestDate}) {
    return HiveUtils.boxToStream<NoteEntity>(
      HiveService.notesBox,
      (id, map) => NoteEntity.fromJson(id, map),
    ).map((notes) {
      var result = notes;
      if (oldestDate != null) {
        result = result.where((n) => !n.timestamp.isBefore(oldestDate)).toList();
      }
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result;
    });
  }

  // ─── Queries ──────────────────────────────────────────────────────────────

  Future<int> getNextDayNumber() async {
    final notes = HiveUtils.readAll<NoteEntity>(
      HiveService.notesBox,
      (id, map) => NoteEntity.fromJson(id, map),
    );
    final uniqueDates = <String>{};
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    for (final note in notes) {
      final d = note.timestamp;
      uniqueDates.add('${d.year}-${d.month}-${d.day}');
    }

    return uniqueDates.contains(todayStr)
        ? uniqueDates.length
        : uniqueDates.length + 1;
  }

  // ─── Write operations ─────────────────────────────────────────────────────

  Future<String> createEntry(
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    final id = IdUtils.generateId();
    final entry = NoteEntity(
      id: id,
      title: title,
      content: content,
      timestamp: DateTime.now(),
      mood: mood,
      tags: tags,
      isPinned: isPinned,
    );
    await HiveService.notesBox.put(id, entry.toJson());
    return id;
  }

  Future<void> updateEntry(
    String id,
    String title,
    String content,
    String mood,
    List<String> tags, {
    bool isPinned = false,
  }) async {
    final existing = HiveUtils.safeGet(HiveService.notesBox, id);
    if (existing == null) return;

    final updated = NoteEntity.fromJson(id, existing).copyWith(
      title: title,
      content: content,
      mood: mood,
      tags: tags,
      isPinned: isPinned,
    );
    await HiveService.notesBox.put(id, updated.toJson());
  }

  Future<void> togglePin(String id, bool isPinned) async {
    final existing = HiveUtils.safeGet(HiveService.notesBox, id);
    if (existing == null) return;
    final updated = NoteEntity.fromJson(id, existing).copyWith(isPinned: isPinned);
    await HiveService.notesBox.put(id, updated.toJson());
  }

  Future<void> deleteEntry(String id) async {
    await HiveService.notesBox.delete(id);
  }
}
