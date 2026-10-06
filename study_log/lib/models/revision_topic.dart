import 'topic.dart';

/// An independent revision topic entity managed exclusively inside a Revision.
/// Allows full CRUD operations and completion toggling separate from course modules.
/// - [moduleId] is inherited from the parent [Revision]; not stored here.
/// - [topicId] references the base [Topic.id].
/// - [title] caches the topic name for immediate offline availability.
class RevisionTopic {
  final String id;
  final String revisionId;
  final String courseId;
  final String topicId;   // FK → Topic.id
  final String title;     // Cached topic title for fast display & offline availability
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
    this.title = '',
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
    String? title,
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
      title: title ?? this.title,
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
    final resolvedTitle = (topic != null && topic.title.isNotEmpty)
        ? topic.title
        : (title.isNotEmpty ? title : (topicId.isNotEmpty ? topicId : 'Topic'));
    return Topic(
      id: id,
      courseId: courseId,
      moduleId: topic?.moduleId ?? '',
      title: resolvedTitle,
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
      title: topic.title,
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
      'title': title,
      'status': status.name,
      'orderIndex': orderIndex,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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
      title: map['title']?.toString() ?? '',
      status: Topic.parseStatus(map['status']),
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      completedAt: Topic.parseDateTime(map['completedAt']),
      createdAt: Topic.parseDateTime(map['createdAt']) ?? now,
      updatedAt: Topic.parseDateTime(map['updatedAt']) ?? now,
    );
  }
}
