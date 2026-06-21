import '../utils/db_utils.dart';

class NoteEntity {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final String mood;
  final List<String> tags;
  final bool isPinned;

  NoteEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.mood,
    required this.tags,
    this.isPinned = false,
  });

  // ─── Hive serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'timestamp': DbUtils.dateToMs(timestamp),
      'mood': mood,
      'tags': tags,
      'isPinned': isPinned,
    };
  }

  factory NoteEntity.fromJson(String id, Map<String, dynamic> map) {
    final rawTags = map['tags'];
    final List<String> tagsList = rawTags is List
        ? List<String>.from(rawTags)
        : DbUtils.decodeStringList(rawTags as String?);

    return NoteEntity(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      timestamp: DbUtils.msToDate(map['timestamp'] as int?),
      mood: map['mood'] as String? ?? '😊',
      tags: tagsList,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

  NoteEntity copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
    String? mood,
    List<String>? tags,
    bool? isPinned,
  }) {
    return NoteEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      mood: mood ?? this.mood,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
