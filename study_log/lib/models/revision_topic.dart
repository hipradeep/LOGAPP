import 'package:cloud_firestore/cloud_firestore.dart';
import 'topic.dart';

/// An independent revision topic entity managed exclusively inside a Revision.
/// Allows full CRUD operations and completion toggling separate from course modules.
class RevisionTopic {
  final String id;
  final String revisionId;
  final String courseId;
  final String moduleId;
  final String title;
  final TopicStatus status;
  final int orderIndex;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RevisionTopic({
    required this.id,
    required this.revisionId,
    this.courseId = '',
    this.moduleId = '',
    required this.title,
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
    String? moduleId,
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
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      status: status ?? this.status,
      orderIndex: orderIndex ?? this.orderIndex,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this [RevisionTopic] into a lightweight [Topic] so widgets like [TopicListItem]
  /// can consume it with 100% interoperability.
  Topic toTopic() {
    return Topic(
      id: id,
      courseId: courseId,
      moduleId: moduleId,
      title: title,
      status: status,
      orderIndex: orderIndex,
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
      id: newId ?? (topic.id.isNotEmpty ? topic.id : 'rev_topic_${now.millisecondsSinceEpoch}'),
      revisionId: revisionId,
      courseId: topic.courseId,
      moduleId: topic.moduleId,
      title: topic.title,
      status: topic.status,
      orderIndex: topic.orderIndex,
      completedAt: topic.completedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'revisionId': revisionId,
      'courseId': courseId,
      'moduleId': moduleId,
      'title': title,
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
      moduleId: map['moduleId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      status: Topic.parseStatus(map['status']),
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      completedAt: Topic.parseDateTime(map['completedAt']),
      createdAt: Topic.parseDateTime(map['createdAt']) ?? now,
      updatedAt: Topic.parseDateTime(map['updatedAt']) ?? now,
    );
  }
}
