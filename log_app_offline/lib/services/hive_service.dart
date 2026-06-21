import 'package:hive_flutter/hive_flutter.dart';

/// Hive initialization singleton for log_app_offline.
///
/// Call [HiveService.init()] once in main() before runApp().
/// Opens all named boxes used by the app.
///
/// Storage strategy:
///   - notesBox       → NoteService  (NoteEntity documents)
///   - waterLogsBox   → WaterService (WaterLogEntry documents)
///   - waterSettingsBox → WaterService (single WaterSettings object)
///
/// No Hive adapters needed — all data is stored as plain
/// Map<String, dynamic> and converted via .fromJson() / .toJson().
class HiveService {
  HiveService._();

  static const String notesBoxName = 'notesBox';
  static const String waterLogsBoxName = 'waterLogsBox';
  static const String waterSettingsBoxName = 'waterSettingsBox';

  /// Opens Hive and all named boxes. Must be awaited before runApp().
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(notesBoxName),
      Hive.openBox(waterLogsBoxName),
      Hive.openBox(waterSettingsBoxName),
    ]);
  }

  // ─── Convenience accessors ────────────────────────────────────────────────

  static Box get notesBox => Hive.box(notesBoxName);
  static Box get waterLogsBox => Hive.box(waterLogsBoxName);
  static Box get waterSettingsBox => Hive.box(waterSettingsBoxName);
}
