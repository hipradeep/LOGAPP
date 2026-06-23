import 'package:cloud_firestore/cloud_firestore.dart';

class Activity {
  final String id;
  final String name;
  final bool isActive;
  final DateTime timestamp;
  final String trackingType; // 'single', 'multiple', or 'milestone'
  final int targetCount;
  final bool reminderEnabled;

  // Schedule fields
  final List<int> repeatDays; // 1=Mon, 2=Tue, ... 7=Sun
  final String? scheduledTime; // e.g. "06:30"
  final DateTime? startDate;
  final DateTime? endDate;

  // Sub-task templates
  final List<String> subTaskTemplates;

  // Description
  final String? description;

  final String? category;
  final String? symbolType;
  final String? symbolValue;
  final bool? _skippable;
  final double weight;
  final int points;

  // Pomodoro focus duration (in minutes, default 25)
  final int focusDuration;

  // Whether Pomodoro focus mode is enabled for this activity
  final bool isPomodoroFocusEnabled;

  /// Whether this activity type supports sub-tasks.
  /// Derived from trackingType: routine & goal have sub-tasks, habit does not.
  bool get hasSubTasks => trackingType == 'multiple' || trackingType == 'milestone';

  bool get skippable => _skippable ?? false;

  Activity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.timestamp,
    this.trackingType = 'single',
    this.targetCount = 1,
    this.reminderEnabled = true,
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.scheduledTime,
    this.startDate,
    this.endDate,
    this.subTaskTemplates = const [],
    this.description,
    this.category,
    this.symbolType,
    this.symbolValue,
    bool? skippable = false,
    this.weight = 1.0,
    this.points = 10,
    this.focusDuration = 25,
    this.isPomodoroFocusEnabled = false,
  }) : _skippable = skippable;

  // Convert to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'isActive': isActive,
      'timestamp': Timestamp.fromDate(timestamp),
      'trackingType': trackingType,
      'targetCount': targetCount,
      'reminderEnabled': reminderEnabled,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'subTaskTemplates': subTaskTemplates,
      'description': description,
      'category': category,
      'symbolType': symbolType,
      'symbolValue': symbolValue,
      'skippable': skippable,
      'weight': weight,
      'points': points,
      'focusDuration': focusDuration,
      'isPomodoroFocusEnabled': isPomodoroFocusEnabled,
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
      isActive: data['isActive'] as bool? ?? false,
      timestamp: dateTime,
      trackingType: rawType,
      targetCount: data['targetCount'] as int? ?? 1,
      reminderEnabled: data['reminderEnabled'] as bool? ?? true,
      repeatDays: parsedRepeatDays,
      scheduledTime: data['scheduledTime'] as String?,
      startDate: firestoreStartDate?.toDate(),
      endDate: firestoreEndDate?.toDate(),
      subTaskTemplates: parsedSubTaskTemplates,
      description: data['description'] as String?,
      category: data['category'] as String?,
      symbolType: data['symbolType'] as String?,
      symbolValue: data['symbolValue'] as String?,
      skippable: data['skippable'] as bool? ?? false,
      weight: (data['weight'] as num?)?.toDouble() ?? 1.0,
      points: (data['points'] as num?)?.toInt() ?? 10,
      focusDuration: (data['focusDuration'] as num?)?.toInt() ?? 25,
      isPomodoroFocusEnabled: data['isPomodoroFocusEnabled'] as bool? ?? false,
    );
  }

  // Helper method for updating state locally
  Activity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? timestamp,
    String? trackingType,
    int? targetCount,
    bool? reminderEnabled,
    List<int>? repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? subTaskTemplates,
    String? description,
    String? category,
    String? symbolType,
    String? symbolValue,
    bool? skippable,
    double? weight,
    int? points,
    int? focusDuration,
    bool? isPomodoroFocusEnabled,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      timestamp: timestamp ?? this.timestamp,
      trackingType: trackingType ?? this.trackingType,
      targetCount: targetCount ?? this.targetCount,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      subTaskTemplates: subTaskTemplates ?? this.subTaskTemplates,
      description: description ?? this.description,
      category: category ?? this.category,
      symbolType: symbolType ?? this.symbolType,
      symbolValue: symbolValue ?? this.symbolValue,
      skippable: skippable ?? this.skippable,
      weight: weight ?? this.weight,
      points: points ?? this.points,
      focusDuration: focusDuration ?? this.focusDuration,
      isPomodoroFocusEnabled: isPomodoroFocusEnabled ?? this.isPomodoroFocusEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'timestamp': timestamp.toIso8601String(),
      'trackingType': trackingType,
      'targetCount': targetCount,
      'reminderEnabled': reminderEnabled,
      'repeatDays': repeatDays,
      'scheduledTime': scheduledTime,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'subTaskTemplates': subTaskTemplates,
      'description': description,
      'category': category,
      'symbolType': symbolType,
      'symbolValue': symbolValue,
      'skippable': skippable,
      'weight': weight,
      'points': points,
      'focusDuration': focusDuration,
      'isPomodoroFocusEnabled': isPomodoroFocusEnabled,
    };
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      trackingType: json['trackingType'] as String? ?? 'single',
      targetCount: json['targetCount'] as int? ?? 1,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      repeatDays: (json['repeatDays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [1, 2, 3, 4, 5, 6, 7],
      scheduledTime: json['scheduledTime'] as String?,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      subTaskTemplates: (json['subTaskTemplates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      description: json['description'] as String?,
      category: json['category'] as String?,
      symbolType: json['symbolType'] as String?,
      symbolValue: json['symbolValue'] as String?,
      skippable: json['skippable'] as bool? ?? false,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      points: (json['points'] as num?)?.toInt() ?? 10,
      focusDuration: (json['focusDuration'] as num?)?.toInt() ?? 25,
      isPomodoroFocusEnabled: json['isPomodoroFocusEnabled'] as bool? ?? false,
    );
  }
}
