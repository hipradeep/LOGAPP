import 'package:cloud_firestore/cloud_firestore.dart';

class CheckIn {
  final String id;
  final String activityId;
  final DateTime timestamp;
  final bool checked;
  final String? subTaskName;
  final bool? _skipped;

  CheckIn({
    required this.id,
    required this.activityId,
    required this.timestamp,
    required this.checked,
    this.subTaskName,
    bool? skipped = false,
  }) : _skipped = skipped;

  bool get skipped => _skipped ?? false;

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'activityId': activityId,
      'timestamp': Timestamp.fromDate(timestamp),
      'checked': checked,
      'skipped': skipped,
    };
    if (subTaskName != null) {
      data['subTaskName'] = subTaskName;
    }
    return data;
  }

  // Create from Firestore Document Snapshot
  factory CheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    return CheckIn(
      id: doc.id,
      activityId: data['activityId'] as String? ?? '',
      timestamp: dateTime,
      checked: data['checked'] as bool? ?? false,
      subTaskName: data['subTaskName'] as String?,
      skipped: data['skipped'] as bool? ?? false,
    );
  }

  CheckIn copyWith({
    String? id,
    String? activityId,
    DateTime? timestamp,
    bool? checked,
    String? subTaskName,
    bool? skipped,
  }) {
    return CheckIn(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      timestamp: timestamp ?? this.timestamp,
      checked: checked ?? this.checked,
      subTaskName: subTaskName ?? this.subTaskName,
      skipped: skipped ?? this.skipped,
    );
  }
}
