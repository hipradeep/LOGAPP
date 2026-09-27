import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap({bool forLocalJson = false}) {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'deadline': deadline != null
          ? (forLocalJson ? deadline!.toIso8601String() : Timestamp.fromDate(deadline!))
          : null,
      'createdAt': forLocalJson ? createdAt.toIso8601String() : Timestamp.fromDate(createdAt),
      'updatedAt': forLocalJson ? updatedAt.toIso8601String() : Timestamp.fromDate(updatedAt),
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.tryParse(value.toString());
  }
}
