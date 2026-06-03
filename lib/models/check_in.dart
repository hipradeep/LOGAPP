import 'package:cloud_firestore/cloud_firestore.dart';

class CheckIn {
  final String id;
  final String activityId;
  final DateTime timestamp;
  final bool checked;

  CheckIn({
    required this.id,
    required this.activityId,
    required this.timestamp,
    required this.checked,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'activityId': activityId,
      'timestamp': Timestamp.fromDate(timestamp),
      'checked': checked,
    };
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
    );
  }

  CheckIn copyWith({
    String? id,
    String? activityId,
    DateTime? timestamp,
    bool? checked,
  }) {
    return CheckIn(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      timestamp: timestamp ?? this.timestamp,
      checked: checked ?? this.checked,
    );
  }
}
