enum StudyLogType {
  topicCompleted,
  revisionCompleted,
  studySession;

  String get value => name;

  static StudyLogType fromString(String? val) {
    if (val == null) return StudyLogType.studySession;
    switch (val.toLowerCase()) {
      case 'topiccompleted':
      case 'topic_completed':
      case 'topic':
        return StudyLogType.topicCompleted;
      case 'revisioncompleted':
      case 'revision_completed':
      case 'revision':
        return StudyLogType.revisionCompleted;
      case 'studysession':
      case 'study_session':
      case 'session':
      default:
        return StudyLogType.studySession;
    }
  }
}

/// Represents an immutable log entry of a study action (e.g. topic finished, revision completed).
class StudyLog {
  final String id;
  final StudyLogType type;
  final String courseId;
  final String courseTitle;
  final String moduleId;
  final String moduleTitle;
  final String? topicId;
  final String? topicTitle;
  final int? revisionLevel;
  final int? durationMinutes;
  final DateTime timestamp;
  final DateTime createdAt;

  const StudyLog({
    required this.id,
    required this.type,
    required this.courseId,
    required this.courseTitle,
    required this.moduleId,
    required this.moduleTitle,
    this.topicId,
    this.topicTitle,
    this.revisionLevel,
    this.durationMinutes,
    required this.timestamp,
    required this.createdAt,
  });

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'type': type.value,
      'courseId': courseId,
      'courseTitle': courseTitle,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      if (topicId != null) 'topicId': topicId,
      if (topicTitle != null) 'topicTitle': topicTitle,
      if (revisionLevel != null) 'revisionLevel': revisionLevel,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudyLog.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return StudyLog(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      type: StudyLogType.fromString(map['type']?.toString()),
      courseId: map['courseId']?.toString() ?? '',
      courseTitle: map['courseTitle']?.toString() ?? '',
      moduleId: map['moduleId']?.toString() ?? '',
      moduleTitle: map['moduleTitle']?.toString() ?? '',
      topicId: map['topicId']?.toString(),
      topicTitle: map['topicTitle']?.toString(),
      revisionLevel: map['revisionLevel'] is int
          ? map['revisionLevel'] as int
          : int.tryParse(map['revisionLevel']?.toString() ?? ''),
      durationMinutes: map['durationMinutes'] is int
          ? map['durationMinutes'] as int
          : int.tryParse(map['durationMinutes']?.toString() ?? ''),
      timestamp: _parseDateTime(map['timestamp']) ?? DateTime.now(),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  StudyLog copyWith({
    String? id,
    StudyLogType? type,
    String? courseId,
    String? courseTitle,
    String? moduleId,
    String? moduleTitle,
    String? topicId,
    String? topicTitle,
    int? revisionLevel,
    int? durationMinutes,
    DateTime? timestamp,
    DateTime? createdAt,
  }) {
    return StudyLog(
      id: id ?? this.id,
      type: type ?? this.type,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      moduleId: moduleId ?? this.moduleId,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      topicId: topicId ?? this.topicId,
      topicTitle: topicTitle ?? this.topicTitle,
      revisionLevel: revisionLevel ?? this.revisionLevel,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
