import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String name;
  final bool checked;
  final DateTime timestamp;
  final String trackingType; // 'single', 'multiple', or 'milestone'
  final int targetCount;

  // Schedule fields
  final List<int> repeatDays; // 1=Mon, 2=Tue, ... 7=Sun
  final String? scheduledTime; // e.g. "06:30"
  final DateTime? startDate;
  final DateTime? endDate;

  // Sub-task templates
  final List<String> subTaskTemplates;

  /// Whether this activity type supports sub-tasks.
  /// Derived from trackingType: routine & goal have sub-tasks, habit does not.
  bool get hasSubTasks => trackingType == 'multiple' || trackingType == 'milestone';

  Activity({
    required this.id,
    required this.name,
    required this.checked,
    required this.timestamp,
    this.trackingType = 'single',
    this.targetCount = 1,
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduledTime,
    this.startDate,
    this.endDate,
    this.subTaskTemplates = const [],
  });

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'checked': checked,
      'timestamp': Timestamp.fromDate(timestamp),
      'trackingType': trackingType,
      'targetCount': targetCount,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'subTaskTemplates': subTaskTemplates,
    };
  }

  // Create from Firestore Document Snapshot
  factory Activity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    final Timestamp? firestoreStartDate = data['startDate'] as Timestamp?;
    final Timestamp? firestoreEndDate = data['endDate'] as Timestamp?;

    final rawRepeatDays = data['repeatDays'];
    final List<int> parsedRepeatDays = rawRepeatDays is List
        ? rawRepeatDays.map((e) => (e as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];

    final rawSubTaskTemplates = data['subTaskTemplates'];
    final List<String> parsedSubTaskTemplates = rawSubTaskTemplates is List
        ? List<String>.from(rawSubTaskTemplates)
        : const [];

    // Migrate old values: 'daily'/'habit' → 'single', 'routine' → 'multiple', 'goal' → 'milestone'
    String rawType = data['trackingType'] as String? ?? 'single';
    if (rawType == 'daily' || rawType == 'habit') rawType = 'single';
    if (rawType == 'routine') rawType = 'multiple';
    if (rawType == 'goal') rawType = 'milestone';

    return Activity(
      id: doc.id,
      name: data['name'] as String? ?? '',
      checked: data['checked'] as bool? ?? false,
      timestamp: dateTime,
      trackingType: rawType,
      targetCount: data['targetCount'] as int? ?? 1,
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: firestoreStartDate?.toDate(),
      endDate: firestoreEndDate?.toDate(),
      subTaskTemplates: parsedSubTaskTemplates,
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
    List<int>? repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? subTaskTemplates,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      checked: checked ?? this.checked,
      timestamp: timestamp ?? this.timestamp,
      trackingType: trackingType ?? this.trackingType,
      targetCount: targetCount ?? this.targetCount,
      repeatDays: repeatDays ?? this.repeatDays,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      subTaskTemplates: subTaskTemplates ?? this.subTaskTemplates,
    );
  }
}
