import 'package:cloud_firestore/cloud_firestore.dart';
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

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory WaterLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
    final DateTime dateTime = firestoreTimestamp != null 
        ? firestoreTimestamp.toDate() 
        : DateTime.now();

    return WaterLogEntry(
      id: doc.id,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: dateTime,
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
  final double dailyGoal; // in ml, e.g. 2000.0
  final bool notificationsEnabled;
  final List<String> reminderTimes; // e.g. ["08:00 AM", "11:00 AM", ...]
  final int hourlyInterval; // 0 = custom, 1 = every hour, 2 = every 2 hours, 3 = every 3 hours

  WaterSettings({
    this.dailyGoal = 2000.0,
    this.notificationsEnabled = false,
    this.reminderTimes = const [],
    this.hourlyInterval = 0,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'dailyGoal': dailyGoal,
      'notificationsEnabled': notificationsEnabled,
      'reminderTimes': reminderTimes,
      'hourlyInterval': hourlyInterval,
    };
  }

  factory WaterSettings.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      return WaterSettings();
    }
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final List<dynamic>? rawTimes = data['reminderTimes'] as List<dynamic>?;
    List<String> timesList = rawTimes != null 
        ? List<String>.from(rawTimes) 
        : const [];

    // Legacy migration: If loaded times exactly match default or hourly generated slots, clear them.
    final List<String> oldDefaults = const ["08:00 AM", "11:00 AM", "02:00 PM", "05:00 PM", "08:00 PM"];
    final List<String> oldDefaultsAlt = const ["8:00 AM", "11:00 AM", "2:00 PM", "5:00 PM", "8:00 PM"];
    
    bool isDefault = (timesList.length == 5 && 
        (timesList.every((t) => oldDefaults.contains(t)) || timesList.every((t) => oldDefaultsAlt.contains(t))));
        
    bool isAllHourly = timesList.length == 13 && timesList.every((t) {
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
      dailyGoal: (data['dailyGoal'] as num?)?.toDouble() ?? 2000.0,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? false,
      reminderTimes: timesList,
      hourlyInterval: data['hourlyInterval'] as int? ?? 0,
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
