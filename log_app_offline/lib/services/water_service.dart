import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/water_log_entry.dart';
import '../services/hive_service.dart';
import '../utils/id_utils.dart';
import '../utils/hive_utils.dart';

class WaterService {
  // ─── Reactive streams ─────────────────────────────────────────────────────

  /// Emits sorted list of all water log entries whenever the box changes.
  Stream<List<WaterLogEntry>> getWaterLogsStream() {
    return HiveUtils.boxToStream<WaterLogEntry>(
      HiveService.waterLogsBox,
      (id, map) => WaterLogEntry.fromJson(id, map),
    ).map((logs) {
      final result = List<WaterLogEntry>.from(logs);
      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result;
    });
  }

  /// Emits WaterSettings whenever the settings box changes.
  Stream<WaterSettings> getWaterSettingsStream() {
    final controller = StreamController<WaterSettings>.broadcast();
    final box = HiveService.waterSettingsBox;
    final listenable = box.listenable();

    void emit() {
      final raw = HiveUtils.safeGet(box, 'settings');
      if (!controller.isClosed) {
        controller.add(raw != null ? WaterSettings.fromJson(raw) : WaterSettings());
      }
    }

    controller.onListen = () {
      listenable.addListener(emit);
      emit();
    };
    controller.onCancel = () {
      listenable.removeListener(emit);
    };

    return controller.stream;
  }

  // ─── Write operations ─────────────────────────────────────────────────────

  Future<void> addWaterLog(double amount, {DateTime? timestamp}) async {
    final id = IdUtils.generateId();
    final log = WaterLogEntry(
      id: id,
      amount: amount,
      timestamp: timestamp ?? DateTime.now(),
    );
    await HiveService.waterLogsBox.put(id, log.toJson());
  }

  Future<void> deleteWaterLog(String id) async {
    await HiveService.waterLogsBox.delete(id);
  }

  Future<void> updateWaterSettings(WaterSettings settings) async {
    await HiveService.waterSettingsBox.put('settings', settings.toJson());
  }
}
