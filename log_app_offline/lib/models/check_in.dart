import '../utils/db_utils.dart';

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

  // ─── SQLite serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activityId': activityId,
      'timestamp': DbUtils.dateToMs(timestamp),
      'checked': checked ? 1 : 0,
      'skipped': skipped ? 1 : 0,
      'subTaskName': subTaskName,
    };
  }

  factory CheckIn.fromMap(String id, Map<String, dynamic> map) {
    return CheckIn(
      id: id,
      activityId: map['activityId'] as String? ?? '',
      timestamp: DbUtils.msToDate(map['timestamp'] as int?),
      checked: map['checked'] == 1 || map['checked'] == true,
      skipped: map['skipped'] == 1 || map['skipped'] == true,
      subTaskName: map['subTaskName'] as String?,
    );
  }

  // ─── copyWith ─────────────────────────────────────────────────────────────

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
