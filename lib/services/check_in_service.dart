import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/check_in.dart';

class CheckInService {
  final CollectionReference _checkinsCollection =
      FirebaseFirestore.instance.collection('checkins');

  // ==================== CHECK-INS OPERATIONS ====================

  Stream<List<CheckIn>> getCheckInsStream(String activityId) {
    return _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  Stream<List<CheckIn>> getCheckedActivitiesCheckInsStream() {
    return _checkinsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CheckIn.fromFirestore(doc)).toList();
    });
  }

  Future<void> createCheckIn(String activityId, DateTime timestamp, bool checked, {bool skipped = false}) async {
    if (checked) {
      final todayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      try {
        final skippedQuery = await _checkinsCollection
            .where('activityId', isEqualTo: activityId)
            .where('skipped', isEqualTo: true)
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
            .get();
        for (var doc in skippedQuery.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }

    final newCheckIn = CheckIn(
      id: '',
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
      skipped: skipped,
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
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final query = await _checkinsCollection
        .where('activityId', isEqualTo: activityId)
        .where('skipped', isEqualTo: true)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
  }
}
