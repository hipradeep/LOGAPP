import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sms_record.dart';
import '../models/staged_sms_transaction.dart';
import 'database_service.dart';
import 'sms_native_bridge.dart';
import 'sms_parser_service.dart';

enum SmsPermissionState { granted, denied, permanentlyDenied, restricted }

class SmsImportResult {
  final int scanned;
  final int staged;
  final int skipped;
  final bool permissionDenied;

  const SmsImportResult({
    required this.scanned,
    required this.staged,
    required this.skipped,
    this.permissionDenied = false,
  });
}

class SmsInboxService {
  static const int lookbackDays = 30;

  SmsInboxService({
    SmsNativeBridge? bridge,
    SmsParserService? parser,
    DatabaseService? dbService,
    Future<bool> Function()? hasPermission,
    Future<bool> Function()? requestPermission,
  }) : _bridge = bridge ?? SmsNativeBridge(),
       _parser = parser ?? const SmsParserService(),
       _dbService = dbService ?? DatabaseService.instance,
       _hasPermission = hasPermission ?? _defaultHasPermission,
       _requestPermission = requestPermission ?? _defaultRequestPermission;

  final SmsNativeBridge _bridge;
  final SmsParserService _parser;
  final DatabaseService _dbService;
  final Future<bool> Function() _hasPermission;
  final Future<bool> Function() _requestPermission;

  Stream<SmsValidationTarget> get validationTargets =>
      _bridge.validationTargets;

  Future<bool> hasSmsPermission() => _hasPermission();

  Future<bool> requestSmsPermission() => _requestPermission();

  Future<SmsPermissionState> smsPermissionState() async {
    try {
      final status = await Permission.sms.status;
      if (status.isGranted || status.isLimited) {
        return SmsPermissionState.granted;
      }
      if (status.isPermanentlyDenied) {
        return SmsPermissionState.permanentlyDenied;
      }
      if (status.isRestricted) {
        return SmsPermissionState.restricted;
      }
      return SmsPermissionState.denied;
    } catch (_) {
      return SmsPermissionState.denied;
    }
  }

  Future<void> openSmsSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Settings cannot be opened in tests or unsupported platforms.
    }
  }

  static Future<bool> _defaultHasPermission() async {
    try {
      return (await Permission.sms.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _defaultRequestPermission() async {
    try {
      return (await Permission.sms.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> getBackgroundEnabled() async {
    try {
      return await _bridge.getBackgroundEnabled();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    await _bridge.setBackgroundEnabled(enabled);
  }

  Future<SmsValidationTarget?> getLaunchTarget() async {
    try {
      return await _bridge.getLaunchTarget();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<SmsImportResult> scanAndStage({
    int days = lookbackDays,
    int limit = 500,
  }) async {
    if (!await hasSmsPermission()) {
      return const SmsImportResult(
        scanned: 0,
        staged: 0,
        skipped: 0,
        permissionDenied: true,
      );
    }

    final records = await _bridge.scanInbox(
      days: days.clamp(1, lookbackDays).toInt(),
      limit: limit,
    );
    return _stageRecords(records);
  }

  Future<SmsImportResult> drainAndStage() async {
    final records = await _bridge.drainCaptured();
    final cutoff = _recentCutoff();
    var staged = 0;
    var skipped = 0;

    for (final record in records) {
      if (record.timestamp.isBefore(cutoff)) {
        await _removeValidation(record.sourceKey);
        skipped++;
        continue;
      }

      final transaction = _parser.parse(record);
      if (transaction == null) {
        await _removeValidation(record.sourceKey);
        skipped++;
        continue;
      }

      final existing = await _dbService.getStagedSmsById(transaction.id);
      if (existing != null) {
        await _removeValidation(record.sourceKey);
        skipped++;
        continue;
      }

      final duplicate = await _dbService.findDuplicateStagedSms(
        accountRef: transaction.accountRef,
        amount: transaction.extractedAmount!,
        smsTimestamp: transaction.smsTimestamp,
      );
      if (duplicate != null) {
        await _removeValidation(record.sourceKey);
        skipped++;
        continue;
      }

      final inserted = await _dbService.addStagedSmsBatch([transaction]);
      if (inserted > 0) staged++;
      await _removeValidation(record.sourceKey);
    }

    await syncPendingValidations();
    return SmsImportResult(
      scanned: records.length,
      staged: staged,
      skipped: skipped,
    );
  }

  Future<void> syncPendingValidations() async {
    try {
      final pending = await _dbService.getStagedSmsTransactions(
        status: 'pending',
      );
      final cutoff = _recentCutoff();
      final entries = pending
          .where((item) => !item.smsTimestamp.isBefore(cutoff))
          .map(
            (item) => SmsValidationEntry(
              id: item.id,
              amount: item.extractedAmount,
              direction: item.extractedType,
              title: item.extractedMerchant ?? item.smsSender,
            ),
          )
          .toList(growable: false);
      await _bridge.syncPendingValidations(entries);
    } on PlatformException {
      // The in-app list still works when native scheduling is unavailable.
    } on MissingPluginException {
      // The in-app list still works when native scheduling is unavailable.
    }
  }

  Future<void> removeValidation(String id) => _removeValidation(id);

  Future<SmsImportResult> _stageRecords(List<SmsInboxRecord> records) async {
    final newItems = <StagedSmsTransaction>[];
    final cutoff = _recentCutoff();

    for (final record in records) {
      if (record.timestamp.isBefore(cutoff)) continue;

      final transaction = _parser.parse(record);
      if (transaction == null) continue;

      final existing = await _dbService.getStagedSmsById(transaction.id);
      if (existing != null) continue;

      final duplicate = await _dbService.findDuplicateStagedSms(
        accountRef: transaction.accountRef,
        amount: transaction.extractedAmount!,
        smsTimestamp: transaction.smsTimestamp,
      );
      if (duplicate != null) continue;

      newItems.add(transaction);
    }

    final inserted = await _dbService.addStagedSmsBatch(newItems);
    await syncPendingValidations();
    return SmsImportResult(
      scanned: records.length,
      staged: inserted,
      skipped: records.length - inserted,
    );
  }

  Future<void> _removeValidation(String id) async {
    try {
      await _bridge.removeValidation(id);
    } on PlatformException {
      // Keep the queue for the next sync if native removal fails.
    } on MissingPluginException {
      // The in-app list still works when native scheduling is unavailable.
    }
  }

  static DateTime _recentCutoff() =>
      DateTime.now().subtract(const Duration(days: lookbackDays));
}
