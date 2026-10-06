class Module {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int orderIndex;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Module({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'orderIndex': orderIndex,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Module.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Module(
      id: (documentId != null && documentId.isNotEmpty)
          ? documentId
          : (map['id']?.toString() ?? ''),
      courseId: map['courseId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled Module',
      description: map['description']?.toString() ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      status: map['status']?.toString() ?? 'active',
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Module copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? orderIndex,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Module(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
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
