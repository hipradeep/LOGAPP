import '../utils/db_utils.dart';

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
  final int points;

  // Weight / priority
  final double weight;

  // Pomodoro focus duration (in minutes, default 25)
  final int focusDuration;

  // Whether Pomodoro focus mode is enabled for this activity
  final bool isPomodoroFocusEnabled;

  /// Whether this activity type supports sub-tasks.
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
    this.points = 10,
    this.weight = 1.0,
    this.focusDuration = 25,
    this.isPomodoroFocusEnabled = false,
  }) : _skippable = skippable;

  // ─── SQLite serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive ? 1 : 0,
      'timestamp': DbUtils.dateToMs(timestamp),
      'trackingType': trackingType,
      'targetCount': targetCount,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'repeatDays': DbUtils.encodeIntList(repeatDays),
      'scheduledTime': scheduledTime,
      'startDate': startDate != null ? DbUtils.dateToMs(startDate!) : null,
      'endDate': endDate != null ? DbUtils.dateToMs(endDate!) : null,
      'subTaskTemplates': DbUtils.encodeStringList(subTaskTemplates),
      'description': description,
      'category': category,
      'symbolType': symbolType,
      'symbolValue': symbolValue,
      'skippable': skippable ? 1 : 0,
      'points': points,
      'weight': weight,
      'focusDuration': focusDuration,
      'isPomodoroFocusEnabled': isPomodoroFocusEnabled ? 1 : 0,
    };
  }

  factory Activity.fromMap(String id, Map<String, dynamic> map) {
    // Migrate legacy trackingType values
    String rawType = map['trackingType'] as String? ?? 'single';
    if (rawType == 'daily' || rawType == 'habit') rawType = 'single';
    if (rawType == 'routine') rawType = 'multiple';
    if (rawType == 'goal') rawType = 'milestone';

    // repeatDays — may be stored as JSON string or raw List
    List<int> parsedRepeatDays;
    final rawDays = map['repeatDays'];
    if (rawDays is String) {
      parsedRepeatDays = DbUtils.decodeIntList(rawDays);
    } else if (rawDays is List) {
      parsedRepeatDays = rawDays.map((e) => (e as num).toInt()).toList();
    } else {
      parsedRepeatDays = const [1, 2, 3, 4, 5, 6, 7];
    }

    // subTaskTemplates — may be stored as JSON string or raw List
    List<String> parsedTemplates;
    final rawTemplates = map['subTaskTemplates'];
    if (rawTemplates is String) {
      parsedTemplates = DbUtils.decodeStringList(rawTemplates);
    } else if (rawTemplates is List) {
      parsedTemplates = List<String>.from(rawTemplates);
    } else {
      parsedTemplates = const [];
    }

    return Activity(
      id: id,
      name: map['name'] as String? ?? '',
      isActive: (map['isActive'] == 1 || map['isActive'] == true),
      timestamp: DbUtils.msToDate(map['timestamp'] as int?),
      trackingType: rawType,
      targetCount: map['targetCount'] as int? ?? 1,
      reminderEnabled: (map['reminderEnabled'] == 1 || map['reminderEnabled'] == true),
      repeatDays: parsedRepeatDays,
      scheduledTime: map['scheduledTime'] as String?,
      startDate: DbUtils.msToDateNullable(map['startDate'] as int?),
      endDate: DbUtils.msToDateNullable(map['endDate'] as int?),
      subTaskTemplates: parsedTemplates,
      description: map['description'] as String?,
      category: map['category'] as String?,
      symbolType: map['symbolType'] as String?,
      symbolValue: map['symbolValue'] as String?,
      skippable: (map['skippable'] == 1 || map['skippable'] == true),
      points: (map['points'] as int?) ?? 10,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      focusDuration: (map['focusDuration'] as num?)?.toInt() ?? 25,
      isPomodoroFocusEnabled: (map['isPomodoroFocusEnabled'] == 1 || map['isPomodoroFocusEnabled'] == true),
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

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
    int? points,
    double? weight,
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
      points: points ?? this.points,
      weight: weight ?? this.weight,
      focusDuration: focusDuration ?? this.focusDuration,
      isPomodoroFocusEnabled: isPomodoroFocusEnabled ?? this.isPomodoroFocusEnabled,
    );
  }

  // ─── JSON serialization ───────────────────────────────────────────────────

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
      'points': points,
      'weight': weight,
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
      points: (json['points'] as num?)?.toInt() ?? 10,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      focusDuration: (json['focusDuration'] as num?)?.toInt() ?? 25,
      isPomodoroFocusEnabled: json['isPomodoroFocusEnabled'] as bool? ?? false,
    );
  }
}
