import 'package:cloud_firestore/cloud_firestore.dart';
import 'topic.dart';

/// An independent revision topic entity managed exclusively inside a Revision.
/// Allows full CRUD operations and completion toggling separate from course modules.
/// - [moduleId] is inherited from the parent [Revision]; not stored here.
/// - [title] is looked up from [Topic] via [topicId].
class RevisionTopic {
  final String id;
  final String revisionId;
  final String courseId;
  final String topicId;   // FK → Topic.id  (replaces stored title)
  final TopicStatus status;
  final int orderIndex;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RevisionTopic({
    required this.id,
    required this.revisionId,
    this.courseId = '',
    this.topicId = '',
    this.status = TopicStatus.notStarted,
    this.orderIndex = 0,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == TopicStatus.completed;

  RevisionTopic copyWith({
    String? id,
    String? revisionId,
    String? courseId,
    String? topicId,
    TopicStatus? status,
    int? orderIndex,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RevisionTopic(
      id: id ?? this.id,
      revisionId: revisionId ?? this.revisionId,
      courseId: courseId ?? this.courseId,
      topicId: topicId ?? this.topicId,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this [RevisionTopic] into a lightweight [Topic] so widgets like [TopicListItem]
  /// can consume it. The [topic] parameter supplies the title and icon looked up via [topicId].
  Topic toTopic({Topic? topic}) {
    return Topic(
      id: id,
      courseId: courseId,
      moduleId: topic?.moduleId ?? '',
      title: topic?.title ?? topicId,
      status: status,
      orderIndex: orderIndex,
      iconCodePoint: topic?.iconCodePoint,
      colorValue: topic?.colorValue,
      completedAt: completedAt,
    );
  }

  /// Creates a [RevisionTopic] from an existing base [Topic].
  factory RevisionTopic.fromTopic(
    Topic topic, {
    required String revisionId,
    String? newId,
  }) {
    final now = DateTime.now();
    return RevisionTopic(
      id: newId ?? (topic.id.isNotEmpty ? 'rev_${topic.id}' : 'rev_topic_${now.millisecondsSinceEpoch}'),
      revisionId: revisionId,
      courseId: topic.courseId,
      topicId: topic.id,
      status: TopicStatus.notStarted,
      orderIndex: topic.orderIndex,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'revisionId': revisionId,
      'courseId': courseId,
      'topicId': topicId,
      'status': status.name,
      'orderIndex': orderIndex,
      'completedAt': completedAt == null
          ? null
          : (forLocalJson
              ? completedAt!.toIso8601String()
              : Timestamp.fromDate(completedAt!)),
      'createdAt': forLocalJson
          ? createdAt.toIso8601String()
          : Timestamp.fromDate(createdAt),
      'updatedAt': forLocalJson
          ? updatedAt.toIso8601String()
          : Timestamp.fromDate(updatedAt),
    };
  }

  factory RevisionTopic.fromMap(Map<String, dynamic> map, {String? documentId}) {
    final now = DateTime.now();
    return RevisionTopic(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      revisionId: map['revisionId']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      topicId: map['topicId']?.toString() ?? '',
      status: Topic.parseStatus(map['status']),
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      completedAt: Topic.parseDateTime(map['completedAt']),
      createdAt: Topic.parseDateTime(map['createdAt']) ?? now,
      updatedAt: Topic.parseDateTime(map['updatedAt']) ?? now,
    );
  }
}
