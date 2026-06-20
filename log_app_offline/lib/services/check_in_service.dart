import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/check_in.dart';

class CheckInService {
  final CollectionReference _checkinsCollection =
      FirebaseFirestore.instance.collection('checkins');

  // ==================== CHECK-INS OPERATIONS ====================

  Stream<List<CheckIn>> getCheckInsStream(String activityId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final cutoff = todayStart.subtract(const Duration(days: 2));

    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<CheckIn>> getCheckInsStreamForLast7Days(String activityId) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final cutoff = todayStart.subtract(const Duration(days: 6)); // last 7 calendar days including today

    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<CheckIn>> getCheckInsStreamForActivity(String activityId) {
    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }


  Stream<List<CheckIn>> getCheckInsStreamForCurrentWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final cutoff = monday.subtract(const Duration(days: 1));

    return _checkinsCollection
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  Stream<List<CheckIn>> getActiveActivitiesCheckInsStream() {
    return _checkinsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  Future<List<CheckIn>> getCheckInsForActivity(String activityId) async {
    final snapshot = await _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .get();
    return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
  }

  Future<void> createCheckIn(String activityId, DateTime timestamp, bool checked, {bool skipped = false, String? subTaskName}) async {
    if (checked) {
      try {
        final query = await _checkinsCollection
            .where('activityId', isEqualTo: activityId)
            .get(const GetOptions(source: Source.cache));
        for (var doc in query.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
          if (firestoreTimestamp != null) {
            final dateTime = firestoreTimestamp.toDate();
            final isToday = dateTime.year == timestamp.year &&
                dateTime.month == timestamp.month &&
                dateTime.day == timestamp.day;
            final isSkippedDoc = data['skipped'] as bool? ?? false;
            if (isToday && isSkippedDoc) {
              await doc.reference.delete();
            }
          }
        }
      } catch (e) {
        debugPrint("Error deleting skipped checkin: $e");
      }
    }

    final newCheckIn = CheckIn(
      id: '',
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
      skipped: skipped,
      subTaskName: subTaskName,
    );
    await _checkinsCollection.add(newCheckIn.toFirestore());
  }

  Future<void> toggleCheckIn(String id, bool checked) async {
    await _checkinsCollection.doc(id).update({
      'checked': checked,
    });
  }

  Future<void> deleteCheckIn(String id) async {
    await _checkinsCollection.doc(id).delete();
  }

  Future<void> deleteSkippedCheckInForToday(String activityId) async {
    final now = DateTime.now();
    try {
      final query = await _checkinsCollection
          .where('activityId', isEqualTo: activityId)
          .get(const GetOptions(source: Source.cache));
      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final Timestamp? firestoreTimestamp = data['timestamp'] as Timestamp?;
        if (firestoreTimestamp != null) {
          final dateTime = firestoreTimestamp.toDate();
          final isToday = dateTime.year == now.year &&
              dateTime.month == now.month &&
              dateTime.day == now.day;
          final isSkippedDoc = data['skipped'] as bool? ?? false;
          if (isToday && isSkippedDoc) {
            await doc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Error deleting skipped checkin for today: $e");
    }
  }
}
