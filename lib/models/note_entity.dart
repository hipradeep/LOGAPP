import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'mood': mood,
      'tags': tags,
      'isPinned': isPinned,
    };
  }

  // Create from Firestore Document Snapshot
  factory NoteEntity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Handle Timestamp parsing
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    // Handle Tags parsing
    final List<dynamic>? rawTags = data['tags'] as List<dynamic>?;
    final List<String> tagsList = rawTags != null 
        ? List<String>.from(rawTags) 
        : [];

    return NoteEntity(
      id: doc.id,
      title: data['title'] as String? ?? '',
      content: data['content'] as String? ?? '',
      timestamp: dateTime,
      mood: data['mood'] as String? ?? '😊',
      tags: tagsList,
      isPinned: data['isPinned'] as bool? ?? false,
    );
  }

  // Copy with helper for modifications
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
