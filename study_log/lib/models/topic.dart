/// Study status of a single topic inside a Section.
enum SubsectionStatus {
  completed,
  inProgress,
  notStarted,
}

/// A topic (subsection) belonging to a Section.
///
/// [sectionId] is the stable identity used to resolve topics for a module;
/// the local cache buckets are keyed by section title, so a title rename would
/// otherwise orphan the topics.
class SubsectionItem {
  final String id;
  final String courseId;
  final String sectionId;
  final String title;
  final SubsectionStatus status;
  final String description;
  final int orderIndex;
  final int? iconCodePoint;
  final int? colorValue;
  final DateTime? completedAt;

  const SubsectionItem({
    required this.id,
    this.courseId = '',
    this.sectionId = '',
    required this.title,
    required this.status,
    this.description = '',
    this.orderIndex = 0,
    this.iconCodePoint,
    this.colorValue,
    this.completedAt,
  });

  bool get isCompleted => status == SubsectionStatus.completed;

  SubsectionItem copyWith({
    String? id,
    String? courseId,
    String? sectionId,
    String? title,
    SubsectionStatus? status,
    String? description,
    int? orderIndex,
    int? iconCodePoint,
    int? colorValue,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SubsectionItem(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      status: status ?? this.status,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'sectionId': sectionId,
      'title': title,
      'status': status.name,
      'description': description,
      'orderIndex': orderIndex,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SubsectionItem.fromMap(Map<String, dynamic> map) {
    SubsectionStatus parsedStatus = SubsectionStatus.notStarted;
    final statusStr = map['status'] as String?;
    if (statusStr == 'completed') {
      parsedStatus = SubsectionStatus.completed;
    } else if (statusStr == 'inProgress') {
      parsedStatus = SubsectionStatus.inProgress;
    }
    final completedRaw = map['completedAt'];
    return SubsectionItem(
      id: map['id'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      sectionId: map['sectionId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      status: parsedStatus,
      description: map['description'] as String? ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt(),
      colorValue: (map['colorValue'] as num?)?.toInt(),
      completedAt: completedRaw == null
          ? null
          : DateTime.tryParse(completedRaw.toString()),
    );
  }
}
