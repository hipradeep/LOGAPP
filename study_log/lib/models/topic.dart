import 'package:cloud_firestore/cloud_firestore.dart';

/// Study status of a single topic inside a Module.
enum TopicStatus {
  completed,
  inProgress,
  notStarted,
}

/// A topic belonging to a Module — the leaf of the Course → Module → Topic tree.
///
/// [moduleId] is the stable identity used to resolve topics for a module;
/// the local cache buckets are keyed by module title, so a title rename would
/// otherwise orphan the topics.
class Topic {
  final String id;
  final String courseId;
  final String moduleId;
  final String title;
  final TopicStatus status;
  final String description;
  final int orderIndex;
  final int? iconCodePoint;
  final int? colorValue;
  final DateTime? completedAt;

  const Topic({
    required this.id,
    this.courseId = '',
    this.moduleId = '',
    required this.title,
    required this.status,
    this.description = '',
    this.orderIndex = 0,
    this.iconCodePoint,
    this.colorValue,
    this.completedAt,
  });

  bool get isCompleted => status == TopicStatus.completed;

  Topic copyWith({
    String? id,
    String? courseId,
    String? moduleId,
    String? title,
    TopicStatus? status,
    String? description,
    int? orderIndex,
    int? iconCodePoint,
    int? colorValue,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Topic(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      status: status ?? this.status,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  /// Serialises for either backend.
  ///
  /// [forLocalJson] writes ISO-8601 dates for the on-disk cache; otherwise dates
  /// become Firestore [Timestamp]s.
  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'courseId': courseId,
      'moduleId': moduleId,
      'title': title,
      'status': status.name,
      'description': description,
      'orderIndex': orderIndex,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'completedAt': completedAt == null
          ? null
          : (forLocalJson
              ? completedAt!.toIso8601String()
              : Timestamp.fromDate(completedAt!)),
    };
  }

  /// Reads a record from the on-disk cache or from Firestore.
  ///
  /// [documentId] wins over the stored `id` so a Firestore document whose id
  /// field is missing or stale still resolves to its real document key.
  factory Topic.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Topic(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      courseId: map['courseId']?.toString() ?? '',
      moduleId: map['moduleId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      status: parseStatus(map['status']),
      description: map['description']?.toString() ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt(),
      colorValue: (map['colorValue'] as num?)?.toInt(),
      completedAt: parseDateTime(map['completedAt']),
    );
  }

  /// Lenient status parsing: an unrecognised value degrades to [TopicStatus.notStarted]
  /// rather than throwing, so one bad row cannot break a whole bucket.
  static TopicStatus parseStatus(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'completed':
        return TopicStatus.completed;
      case 'inprogress':
      case 'in_progress':
        return TopicStatus.inProgress;
      default:
        return TopicStatus.notStarted;
    }
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}
