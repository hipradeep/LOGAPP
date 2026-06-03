import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/log_entry.dart';
import '../models/activity.dart';
import '../models/check_in.dart';

class FirebaseService {
  final CollectionReference _logsCollection =
      FirebaseFirestore.instance.collection('logs');

  final CollectionReference _activitiesCollection =
      FirebaseFirestore.instance.collection('activities');

  final CollectionReference _checkinsCollection =
      FirebaseFirestore.instance.collection('checkins');

  // ==================== REACTIVE OFFLINE STREAM CONTROLLERS ====================
  static final StreamController<List<Activity>> _mockActivitiesController = StreamController<List<Activity>>.broadcast();
  static final StreamController<List<CheckIn>> _mockCheckInsController = StreamController<List<CheckIn>>.broadcast();
  static final StreamController<List<LogEntry>> _mockLogsController = StreamController<List<LogEntry>>.broadcast();

  static void notifyActivitiesChanged() {
    _mockActivitiesController.add(List.from(mockActivities));
  }

  static void notifyCheckInsChanged() {
    _mockCheckInsController.add(List.from(mockCheckIns));
  }

  static void notifyLogsChanged() {
    _mockLogsController.add(List.from(mockEntries));
  }

  // ==================== STATIC MOCK STORAGE (OFFLINE SYNC) ====================
  
  static final List<LogEntry> mockEntries = [
    LogEntry(
      id: 'mock-1',
      title: '✨ Welcome to LOG!',
      content: 'This is your premium personal space to capture thoughts, ideas, and milestones. Tap the + button below to create your first entry!',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      mood: '🚀',
      tags: ['General', 'Welcome'],
    ),
    LogEntry(
      id: 'mock-2',
      title: 'Late night walk in the park',
      content: 'The air was crisp and clear tonight. Saw some fireflies near the lake. Felt very calm and present.',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      mood: '🌌',
      tags: ['Mindfulness', 'Life'],
    ),
    LogEntry(
      id: 'mock-3',
      title: 'Designing the LOG App UI',
      content: 'Working on a sleek glassmorphic theme with a neon violet primary color. Extremely pleased with how modern the layout feels.',
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      mood: '🎨',
      tags: ['Design', 'Work'],
    ),
  ];

  static final List<Activity> mockActivities = [
    Activity(id: 'act-1', name: 'Meditate 10m', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 10)), trackingType: 'daily', targetCount: 1),
    Activity(id: 'act-2', name: 'Drink 3L Water', checked: false, timestamp: DateTime.now().subtract(const Duration(minutes: 9)), trackingType: 'multiple', targetCount: 3),
    Activity(id: 'act-3', name: 'Read a Book', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 8)), trackingType: 'daily', targetCount: 1),
    Activity(id: 'act-4', name: 'Gym Session', checked: false, timestamp: DateTime.now().subtract(const Duration(minutes: 7)), trackingType: 'daily', targetCount: 1),
    Activity(id: 'act-5', name: 'Code Flutter', checked: false, timestamp: DateTime.now().subtract(const Duration(minutes: 6)), trackingType: 'multiple', targetCount: 2),
    Activity(id: 'act-6', name: 'Sleep 8 Hours', checked: true, timestamp: DateTime.now().subtract(const Duration(minutes: 5)), trackingType: 'daily', targetCount: 1),
  ];

  static final List<CheckIn> mockCheckIns = [
    CheckIn(id: 'c-1', activityId: 'act-1', timestamp: DateTime.now().subtract(const Duration(days: 1)), checked: true),
    CheckIn(id: 'c-2', activityId: 'act-1', timestamp: DateTime.now().subtract(const Duration(days: 2)), checked: true),
    CheckIn(id: 'c-3', activityId: 'act-3', timestamp: DateTime.now().subtract(const Duration(hours: 4)), checked: true),
  ];

  // ==================== LOGS OPERATIONS ====================

  // Stream of log entries ordered by timestamp descending
  Stream<List<LogEntry>> getLogsStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<LogEntry>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<LogEntry>>(
        onListen: () {
          final sorted = List<LogEntry>.from(mockEntries);
          sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(sorted);
          sub = _mockLogsController.stream.listen((data) {
            final s = List<LogEntry>.from(data);
            s.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(s);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _logsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LogEntry.fromFirestore(doc)).toList();
    });
  }

  // Create new log entry
  Future<void> createEntry(String title, String content, String mood, List<String> tags) async {
    final newEntry = LogEntry(
      id: '',
      title: title,
      content: content,
      timestamp: DateTime.now(),
      mood: mood,
      tags: tags,
    );
    await _logsCollection.add(newEntry.toFirestore());
  }

  // Update existing log entry
  Future<void> updateEntry(String id, String title, String content, String mood, List<String> tags) async {
    await _logsCollection.doc(id).update({
      'title': title,
      'content': content,
      'mood': mood,
      'tags': tags,
    });
  }

  // Delete a log entry
  Future<void> deleteEntry(String id) async {
    await _logsCollection.doc(id).delete();
  }

  // ==================== ACTIVITIES OPERATIONS ====================

  // Stream of all activities ordered by timestamp ascending
  Stream<List<Activity>> getActivitiesStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<Activity>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<Activity>>(
        onListen: () {
          controller.add(List.from(mockActivities));
          sub = _mockActivitiesController.stream.listen((data) {
            controller.add(data);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _activitiesCollection
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
    });
  }

  // Stream of checked activities only
  Stream<List<Activity>> getCheckedActivitiesStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<Activity>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<Activity>>(
        onListen: () {
          controller.add(mockActivities.where((a) => a.checked).toList());
          sub = _mockActivitiesController.stream.listen((data) {
            controller.add(data.where((a) => a.checked).toList());
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _activitiesCollection
        .where('checked', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Activity.fromFirestore(doc)).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  // Create new activity
  Future<void> createActivity(String name, {String trackingType = 'daily', int targetCount = 1}) async {
    final newActivity = Activity(
      id: '',
      name: name,
      checked: false,
      timestamp: DateTime.now(),
      trackingType: trackingType,
      targetCount: targetCount,
    );
    await _activitiesCollection.add(newActivity.toFirestore());
  }

  // Toggle activity checkbox
  Future<void> toggleActivity(String id, bool checked) async {
    await _activitiesCollection.doc(id).update({
      'checked': checked,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update activity details
  Future<void> updateActivity(String id, String name, String trackingType, int targetCount) async {
    await _activitiesCollection.doc(id).update({
      'name': name,
      'trackingType': trackingType,
      'targetCount': targetCount,
    });
  }

  // Delete an activity
  Future<void> deleteActivity(String id) async {
    await _activitiesCollection.doc(id).delete();
  }

  // ==================== CHECK-INS OPERATIONS ====================

  // Stream of check-ins for a specific activity ordered by timestamp descending
  Stream<List<CheckIn>> getCheckInsStream(String activityId) {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<CheckIn>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<CheckIn>>(
        onListen: () {
          final filtered = mockCheckIns.where((c) => c.activityId == activityId).toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(filtered);
          sub = _mockCheckInsController.stream.listen((data) {
            final f = data.where((c) => c.activityId == activityId).toList();
            f.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(f);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // Stream of checked (selected) activities only
  Stream<List<CheckIn>> getCheckedActivitiesCheckInsStream() {
    if (Firebase.apps.isEmpty) {
      late StreamController<List<CheckIn>> controller;
      StreamSubscription? sub;
      controller = StreamController<List<CheckIn>>(
        onListen: () {
          final sorted = List<CheckIn>.from(mockCheckIns);
          sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(sorted);
          sub = _mockCheckInsController.stream.listen((data) {
            final s = List<CheckIn>.from(data);
            s.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            controller.add(s);
          });
        },
        onCancel: () {
          sub?.cancel();
          controller.close();
        },
      );
      return controller.stream;
    }
    return _checkinsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  // Create new check-in
  Future<void> createCheckIn(String activityId, DateTime timestamp, bool checked) async {
    final newCheckIn = CheckIn(
      id: '',
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
    );
    await _checkinsCollection.add(newCheckIn.toFirestore());
  }

  // Toggle check-in status
  Future<void> toggleCheckIn(String id, bool checked) async {
    await _checkinsCollection.doc(id).update({
      'checked': checked,
    });
  }

  // Delete a check-in
  Future<void> deleteCheckIn(String id) async {
    await _checkinsCollection.doc(id).delete();
  }
}
