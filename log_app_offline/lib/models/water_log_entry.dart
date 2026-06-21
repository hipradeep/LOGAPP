import '../utils/db_utils.dart';
import '../services/notification_service.dart';

class WaterLogEntry {
  final String id;
  final double amount; // in milliliters
  final DateTime timestamp;

  WaterLogEntry({
    required this.id,
    required this.amount,
    required this.timestamp,
  });

  // ─── Hive serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'timestamp': DbUtils.dateToMs(timestamp),
    };
  }

  factory WaterLogEntry.fromJson(String id, Map<String, dynamic> map) {
    return WaterLogEntry(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: DbUtils.msToDate(map['timestamp'] as int?),
    );
  }

  WaterLogEntry copyWith({
    String? id,
    double? amount,
    DateTime? timestamp,
  }) {
    return WaterLogEntry(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class WaterSettings {
  final double dailyGoal; // in ml
  final bool notificationsEnabled;
  final List<String> reminderTimes;
  final int hourlyInterval; // 0=custom, 1=hourly, 2=every 2h, 3=every 3h

  WaterSettings({
    this.dailyGoal = 2000.0,
    this.notificationsEnabled = false,
    this.reminderTimes = const [],
    this.hourlyInterval = 0,
  });

  // ─── Hive serialization ───────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'dailyGoal': dailyGoal,
      'notificationsEnabled': notificationsEnabled,
      'reminderTimes': reminderTimes,
      'hourlyInterval': hourlyInterval,
    };
  }

  factory WaterSettings.fromJson(Map<String, dynamic> map) {
    final rawTimes = map['reminderTimes'];
    List<String> timesList = rawTimes is List
        ? List<String>.from(rawTimes)
        : (rawTimes is String ? DbUtils.decodeStringList(rawTimes) : const []);

    // Legacy migration — clear pre-populated default slots
    final List<String> oldDefaults = const ["08:00 AM", "11:00 AM", "02:00 PM", "05:00 PM", "08:00 PM"];
    final List<String> oldDefaultsAlt = const ["8:00 AM", "11:00 AM", "2:00 PM", "5:00 PM", "8:00 PM"];
    final bool isDefault = timesList.length == 5 &&
        (timesList.every((t) => oldDefaults.contains(t)) ||
            timesList.every((t) => oldDefaultsAlt.contains(t)));

    final bool isAllHourly = timesList.length == 13 &&
        timesList.every((t) {
          final clean = t.trim().toLowerCase();
          return clean.endsWith(":00 am") || clean.endsWith(":00 pm");
        });

    final len = timesList.length;
    bool isPrepopulatedHourly = false;
    if (len == 13 || len == 7 || len == 5) {
      isPrepopulatedHourly = timesList.every((t) {
        try {
          final parsed = NotificationService.parseTimeString(t);
          return parsed.minute == 0 && parsed.hour >= 8 && parsed.hour <= 20;
        } catch (_) {
          return false;
        }
      });
    }

    if (isDefault || isAllHourly || isPrepopulatedHourly) {
      timesList = [];
    }

    return WaterSettings(
      dailyGoal: (map['dailyGoal'] as num?)?.toDouble() ?? 2000.0,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      reminderTimes: timesList,
      hourlyInterval: map['hourlyInterval'] as int? ?? 0,
    );
  }

  WaterSettings copyWith({
    double? dailyGoal,
    bool? notificationsEnabled,
    List<String>? reminderTimes,
    int? hourlyInterval,
  }) {
    return WaterSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      hourlyInterval: hourlyInterval ?? this.hourlyInterval,
    );
  }
}
