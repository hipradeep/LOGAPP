import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String name;
  final bool checked;
  final DateTime timestamp;
  final String trackingType; // 'daily' or 'multiple'
  final int targetCount;

  Activity({
    required this.id,
    required this.name,
    required this.checked,
    required this.timestamp,
    this.trackingType = 'daily',
    this.targetCount = 1,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'checked': checked,
      'timestamp': Timestamp.fromDate(timestamp),
      'trackingType': trackingType,
      'targetCount': targetCount,
    };
  }

  // Create from Firestore Document Snapshot
  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    return Activity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      checked: data['checked'] as bool? ?? false,
      timestamp: dateTime,
      trackingType: data['trackingType'] as String? ?? 'daily',
      targetCount: data['targetCount'] as int? ?? 1,
    );
  }

  // Helper method for updating state locally
  Activity copyWith({
    String? id,
    String? name,
    bool? checked,
    DateTime? timestamp,
    String? trackingType,
    int? targetCount,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      checked: checked ?? this.checked,
      timestamp: timestamp ?? this.timestamp,
      trackingType: trackingType ?? this.trackingType,
      targetCount: targetCount ?? this.targetCount,
    );
  }
}
