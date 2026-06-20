import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/water_log_entry.dart';

class WaterService {
  final CollectionReference _waterLogsCollection =
      FirebaseFirestore.instance.collection('water_logs');

  final DocumentReference _waterSettingsDoc =
      FirebaseFirestore.instance.collection('metadata').doc('water_settings');

  // Stream of individual water logs sorted by date (newest first)
  Stream<List<WaterLogEntry>> getWaterLogsStream() {
    return _waterLogsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WaterLogEntry.fromFirestore(doc))
          .toList();
    });
  }

  // Stream of water settings (daily goal, reminder active, scheduled times)
  Stream<WaterSettings> getWaterSettingsStream() {
    return _waterSettingsDoc.snapshots().map((snapshot) {
      return WaterSettings.fromFirestore(snapshot);
    });
  }

  // Add water intake log
  Future<void> addWaterLog(double amount, {DateTime? timestamp}) async {
    final entryTime = timestamp ?? DateTime.now();
    final log = WaterLogEntry(
      id: '',
      amount: amount,
      timestamp: entryTime,
    );
    await _waterLogsCollection.add(log.toFirestore());
  }

  // Delete water intake log
  Future<void> deleteWaterLog(String id) async {
    await _waterLogsCollection.doc(id).delete();
  }

  // Save/Update water settings (merge true)
  Future<void> updateWaterSettings(WaterSettings settings) async {
    await _waterSettingsDoc.set(settings.toFirestore(), SetOptions(merge: true));
  }
}
