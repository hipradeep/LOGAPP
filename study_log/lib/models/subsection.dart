import 'package:cloud_firestore/cloud_firestore.dart';

class Subsection {
  final String id;
  final String courseId;
  final String sectionId;
  final String title;
  final String description;
  final int orderIndex;
  final String status;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Subsection({
    required this.id,
    required this.courseId,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.status,
    this.scheduledStart,
    this.scheduledEnd,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'sectionId': sectionId,
      'title': title,
      'description': description,
      'orderIndex': orderIndex,
      'status': status,
      'scheduledStart': scheduledStart != null ? Timestamp.fromDate(scheduledStart!) : null,
      'scheduledEnd': scheduledEnd != null ? Timestamp.fromDate(scheduledEnd!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Subsection.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Subsection(
      id: documentId ?? map['id'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      sectionId: map['sectionId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      orderIndex: (map['orderIndex'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'active',
      scheduledStart: _parseDateTime(map['scheduledStart']),
      scheduledEnd: _parseDateTime(map['scheduledEnd']),
      completedAt: _parseDateTime(map['completedAt']),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  Subsection copyWith({
    String? id,
    String? courseId,
    String? sectionId,
    String? title,
    String? description,
    int? orderIndex,
    String? status,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subsection(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      status: status ?? this.status,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}
