class Course {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? deadline;
  final int? iconCodePoint;
  final int? colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.deadline,
    this.iconCodePoint,
    this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => status.toLowerCase() == 'archived';
  bool get isActive => status.toLowerCase() == 'active';
  bool get isCompleted => status.toLowerCase() == 'completed';

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'deadline': deadline?.toIso8601String(),
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Course.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Course(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      title: map['title']?.toString() ?? 'Untitled Course',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      deadline: _parseDateTime(map['deadline']),
      iconCodePoint: (map['iconCodePoint'] as num?)?.toInt(),
      colorValue: (map['colorValue'] as num?)?.toInt(),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    DateTime? deadline,
    int? iconCodePoint,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}
