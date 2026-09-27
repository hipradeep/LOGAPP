class Course {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.deadline,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'deadline': deadline?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Course.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Course(
      id: documentId ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      deadline: map['deadline'] != null
          ? DateTime.tryParse(map['deadline'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
