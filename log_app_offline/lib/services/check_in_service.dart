import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/check_in.dart';
import '../services/database_service.dart';
import '../utils/id_utils.dart';
import '../utils/date_utils.dart';

class CheckInService {
  Future<DatabaseService> get _db async => DatabaseService.instance;

  // ─── Reactive stream helpers ──────────────────────────────────────────────
  // SQLite is not inherently reactive. We poll via a periodic stream.
  // Controllers (CalendarScheduler etc.) that need live updates
  // call the stream methods which re-query every 3 seconds.

  Stream<List<CheckIn>> _queryStream(Future<List<CheckIn>> Function() query) {
    final controller = StreamController<List<CheckIn>>.broadcast();
    Timer? timer;

    Future<void> emit() async {
      try {
        if (!controller.isClosed) controller.add(await query());
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller.onListen = () async {
      await emit();
      timer = Timer.periodic(const Duration(seconds: 3), (_) => emit());
    };
    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  Stream<List<CheckIn>> getCheckInsStream(String activityId) {
    return _queryStream(() => _getCheckInsForActivitySince(
          activityId,
          DateTime.now().subtract(const Duration(days: 2)),
        ));
  }

  Stream<List<CheckIn>> getCheckInsStreamForLast7Days(String activityId) {
    return _queryStream(() => _getCheckInsForActivitySince(
          activityId,
          AppDateUtils.startOfDay(DateTime.now()).subtract(const Duration(days: 6)),
        ));
  }

  Stream<List<CheckIn>> getCheckInsStreamForActivity(String activityId) {
    return _queryStream(() => _getCheckInsForActivitySince(activityId, null));
  }

  Stream<List<CheckIn>> getCheckInsStreamForCurrentWeek() {
    return _queryStream(() async {
      final cutoff = AppDateUtils.startOfWeek(DateTime.now()).subtract(const Duration(days: 1));
      final db = await (await _db).database;
      final rows = await db.query(
        'check_ins',
        where: 'timestamp >= ?',
        whereArgs: [cutoff.millisecondsSinceEpoch],
      );
      return rows.map((r) => CheckIn.fromMap(r['id'] as String, r)).toList();
    });
  }

  Stream<List<CheckIn>> getActiveActivitiesCheckInsStream() {
    return _queryStream(() async {
      final db = await (await _db).database;
      final rows = await db.query('check_ins', orderBy: 'timestamp DESC');
      return rows.map((r) => CheckIn.fromMap(r['id'] as String, r)).toList();
    });
  }

  // ─── Queries ──────────────────────────────────────────────────────────────

  Future<List<CheckIn>> getCheckInsForActivity(String activityId) async {
    return _getCheckInsForActivitySince(activityId, null);
  }

  Future<List<CheckIn>> _getCheckInsForActivitySince(
    String activityId,
    DateTime? since,
  ) async {
    final db = await (await _db).database;
    final where = since != null
        ? 'activityId = ? AND timestamp >= ?'
        : 'activityId = ?';
    final whereArgs = since != null
        ? [activityId, since.millisecondsSinceEpoch]
        : [activityId];
    final rows = await db.query(
      'check_ins',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => CheckIn.fromMap(r['id'] as String, r)).toList();
  }

  // ─── Write operations ─────────────────────────────────────────────────────

  Future<void> createCheckIn(
    String activityId,
    DateTime timestamp,
    bool checked, {
    bool skipped = false,
    String? subTaskName,
  }) async {
    final db = await (await _db).database;

    // If checking in, remove any existing skipped entry for today
    if (checked) {
      try {
        final today = AppDateUtils.startOfDay(timestamp);
        final tomorrow = today.add(const Duration(days: 1));
        await db.delete(
          'check_ins',
          where: 'activityId = ? AND skipped = 1 AND timestamp >= ? AND timestamp < ?',
          whereArgs: [activityId, today.millisecondsSinceEpoch, tomorrow.millisecondsSinceEpoch],
        );
      } catch (e) {
        debugPrint("Error deleting skipped check-in: $e");
      }
    }

    final id = IdUtils.generateId();
    final checkIn = CheckIn(
      id: id,
      activityId: activityId,
      timestamp: timestamp,
      checked: checked,
      skipped: skipped,
      subTaskName: subTaskName,
    );
    await db.insert('check_ins', checkIn.toMap());
  }

  Future<void> toggleCheckIn(String id, bool checked) async {
    final db = await (await _db).database;
    await db.update(
      'check_ins',
      {'checked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCheckIn(String id) async {
    final db = await (await _db).database;
    await db.delete('check_ins', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSkippedCheckInForToday(String activityId) async {
    final db = await (await _db).database;
    final today = AppDateUtils.startOfDay(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    try {
      await db.delete(
        'check_ins',
        where: 'activityId = ? AND skipped = 1 AND timestamp >= ? AND timestamp < ?',
        whereArgs: [activityId, today.millisecondsSinceEpoch, tomorrow.millisecondsSinceEpoch],
      );
    } catch (e) {
      debugPrint("Error deleting skipped check-in for today: $e");
    }
  }
}
