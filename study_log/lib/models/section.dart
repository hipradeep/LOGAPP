class Section {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int orderIndex;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Section({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
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

  factory Section.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Section(
      id: documentId ?? map['id'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'active',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Section copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? orderIndex,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Section(
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
}
