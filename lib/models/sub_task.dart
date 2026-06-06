import 'package:cloud_firestore/cloud_firestore.dart';

class SubTask {
  final String id;
  final String activityId;
  final String subTaskName;
  final DateTime timestamp;
  final bool checked;

  SubTask({
    required this.id,
    required this.activityId,
    required this.subTaskName,
    required this.timestamp,
    required this.checked,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'subTaskName': subTaskName,
      'timestamp': Timestamp.fromDate(timestamp),
      'checked': checked,
    };
  }

  factory SubTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    return SubTask(
      id: doc.id,
      activityId: data['activityId'] as String? ?? '',
      subTaskName: data['subTaskName'] as String? ?? '',
      timestamp: dateTime,
      checked: data['checked'] as bool? ?? false,
    );
  }

  SubTask copyWith({
    String? id,
    String? activityId,
    String? subTaskName,
    DateTime? timestamp,
    bool? checked,
  }) {
    return SubTask(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      subTaskName: subTaskName ?? this.subTaskName,
      timestamp: timestamp ?? this.timestamp,
      checked: checked ?? this.checked,
    );
  }
}
