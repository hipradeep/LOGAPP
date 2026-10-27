import 'package:flutter/services.dart';

import '../models/sms_record.dart';

class SmsNativeBridge {
  static const MethodChannel _methodChannel = MethodChannel(
    'in.logapp.budget_log/sms',
  );
  static const EventChannel _eventChannel = EventChannel(
    'in.logapp.budget_log/sms_events',
  );

  Future<List<SmsInboxRecord>> scanInbox({
    int days = 30,
    int limit = 500,
  }) async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'scanInbox',
      {'days': days, 'limit': limit},
    );
    return _recordsFromResult(result);
  }

  Future<List<SmsInboxRecord>> drainCaptured() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'drainCaptured',
    );
    return _recordsFromResult(result);
  }

  Future<void> syncPendingValidations(List<SmsValidationEntry> entries) async {
    await _methodChannel.invokeMethod<void>('syncPendingValidations', {
      'items': entries.map((entry) => entry.toMap()).toList(growable: false),
    });
  }

  Future<void> removeValidation(String id) async {
    await _methodChannel.invokeMethod<void>('removeValidation', {'id': id});
  }

  Future<bool> getBackgroundEnabled() async {
    return await _methodChannel.invokeMethod<bool>('getBackgroundEnabled') ??
        true;
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    await _methodChannel.invokeMethod<void>('setBackgroundEnabled', {
      'enabled': enabled,
    });
  }

  Future<SmsValidationTarget?> getLaunchTarget() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'getLaunchTarget',
    );
    if (result == null) return null;
    return SmsValidationTarget.fromMap(Map<String, dynamic>.from(result));
  }

  Stream<SmsValidationTarget> get validationTargets {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return SmsValidationTarget.fromMap(Map<String, dynamic>.from(event));
      }
      throw const FormatException('Invalid SMS validation event');
    });
  }

  List<SmsInboxRecord> _recordsFromResult(List<dynamic>? result) {
    if (result == null) return const [];
    return result
        .whereType<Map>()
        .map((row) => SmsInboxRecord.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}
