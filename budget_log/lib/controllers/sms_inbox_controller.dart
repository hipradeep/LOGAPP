import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/budget_transaction.dart';
import '../models/debt_record.dart';
import '../models/sms_record.dart';
import '../models/staged_sms_transaction.dart';
import '../services/database_service.dart';
import '../services/sms_inbox_service.dart';

class SmsInboxController extends ChangeNotifier {
  SmsInboxController({
    required SmsInboxService service,
    required DatabaseService dbService,
  }) : _service = service,
       _dbService = dbService;

  final SmsInboxService _service;
  final DatabaseService _dbService;

  StreamSubscription<List<StagedSmsTransaction>>? _stagedSubscription;
  List<StagedSmsTransaction> _pending = const [];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _hasSmsPermission = false;
  SmsPermissionState _smsPermissionState = SmsPermissionState.denied;
  bool _backgroundEnabled = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _message;

  List<StagedSmsTransaction> get pending => _pending;
  int get pendingCount => _pending.length;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  bool get hasSmsPermission => _hasSmsPermission;
  bool get smsPermissionPermanentlyDenied =>
      _smsPermissionState == SmsPermissionState.permanentlyDenied;
  bool get smsPermissionRestricted =>
      _smsPermissionState == SmsPermissionState.restricted;
  bool get backgroundEnabled => _backgroundEnabled;
  String? get errorMessage => _errorMessage;
  String? get message => _message;
  Stream<SmsValidationTarget> get validationTargets =>
      _service.validationTargets;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _isLoading = true;
    _notify();

    _stagedSubscription ??= _dbService.watchStagedSms().listen(
      (items) {
        _pending = items
            .where((item) => item.isPending)
            .toList(growable: false);
        _notify();
      },
      onError: (Object error) {
        _errorMessage = 'Could not load pending SMS transactions.';
        _notify();
      },
    );

    try {
      _hasSmsPermission = await _service.hasSmsPermission();
      _smsPermissionState = _hasSmsPermission
          ? SmsPermissionState.granted
          : await _service.smsPermissionState();
      _backgroundEnabled = await _service.getBackgroundEnabled();
      await _service.drainAndStage();
      await _service.syncPendingValidations();
    } catch (error) {
      _errorMessage = _describeError(error);
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<bool> requestSmsPermission() async {
    _errorMessage = null;
    final granted = await _service.requestSmsPermission();
    _hasSmsPermission = granted;
    _smsPermissionState = granted
        ? SmsPermissionState.granted
        : await _service.smsPermissionState();
    if (!granted) {
      _errorMessage =
          _smsPermissionState == SmsPermissionState.permanentlyDenied
          ? 'SMS access is blocked. Enable it from app settings.'
          : 'SMS permission is required to scan bank messages.';
    }
    _notify();
    return granted;
  }

  Future<void> requestPermissionOnLaunch() async {
    try {
      _hasSmsPermission = await _service.hasSmsPermission();
      _smsPermissionState = _hasSmsPermission
          ? SmsPermissionState.granted
          : await _service.smsPermissionState();
      _notify();
      if (_hasSmsPermission ||
          _smsPermissionState == SmsPermissionState.permanentlyDenied ||
          _smsPermissionState == SmsPermissionState.restricted) {
        return;
      }
      await requestSmsPermission();
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
    }
  }

  Future<void> openSmsSettings() => _service.openSmsSettings();

  Future<void> refresh() async {
    try {
      _pending = (await _dbService.getStagedSmsTransactions(
        status: 'pending',
      )).toList(growable: false);
      _hasSmsPermission = await _service.hasSmsPermission();
      _smsPermissionState = _hasSmsPermission
          ? SmsPermissionState.granted
          : await _service.smsPermissionState();
      _backgroundEnabled = await _service.getBackgroundEnabled();
      _notify();
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
    }
  }

  Future<SmsImportResult?> scanNow({bool requestPermission = false}) async {
    _errorMessage = null;
    _message = null;
    _isScanning = true;
    _notify();

    try {
      if (!_hasSmsPermission) {
        _hasSmsPermission = requestPermission
            ? await _service.requestSmsPermission()
            : await _service.hasSmsPermission();
        _smsPermissionState = _hasSmsPermission
            ? SmsPermissionState.granted
            : await _service.smsPermissionState();
      }
      if (!_hasSmsPermission) {
        _errorMessage =
            _smsPermissionState == SmsPermissionState.permanentlyDenied
            ? 'SMS access is blocked. Enable it from app settings.'
            : 'SMS permission is required to scan bank messages.';
        return null;
      }

      final result = await _service.scanAndStage();
      if (result.permissionDenied) {
        _hasSmsPermission = false;
        _smsPermissionState = await _service.smsPermissionState();
        _errorMessage = 'SMS permission is required to scan bank messages.';
        return result;
      }

      _message = result.staged == 0
          ? 'No new credit or debit transactions found.'
          : '${result.staged} transaction${result.staged == 1 ? '' : 's'} '
                'added for validation.';
      return result;
    } catch (error) {
      _errorMessage = _describeError(error);
      return null;
    } finally {
      _isScanning = false;
      _notify();
    }
  }

  Future<void> drainBackground() async {
    try {
      await _service.drainAndStage();
      await _service.syncPendingValidations();
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
    }
  }

  Future<void> setBackgroundEnabled(bool enabled) async {
    try {
      await _service.setBackgroundEnabled(enabled);
      _backgroundEnabled = enabled;
      _message = enabled
          ? 'Background SMS capture is on.'
          : 'Background SMS capture is off.';
      _notify();
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
    }
  }

  Future<bool> accept({
    required StagedSmsTransaction staged,
    required BudgetTransaction transaction,
    List<DebtRecord> debtRecords = const [],
  }) async {
    _errorMessage = null;
    _message = null;
    try {
      final accepted = await _dbService.acceptStagedSms(
        stagedSmsId: staged.id,
        transaction: transaction,
        debtRecords: debtRecords,
      );
      if (accepted == null) {
        _errorMessage = 'This SMS transaction is no longer pending.';
        _notify();
        return false;
      }

      await _service.removeValidation(staged.id);
      await _service.syncPendingValidations();
      _message = 'Transaction added';
      _notify();
      return true;
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
      return false;
    }
  }

  Future<void> reject(String id) async {
    _errorMessage = null;
    _message = null;
    try {
      await _dbService.markStagedSmsStatus(id, 'rejected');
      await _service.removeValidation(id);
      await _service.syncPendingValidations();
      _message = 'SMS transaction rejected';
      _notify();
    } catch (error) {
      _errorMessage = _describeError(error);
      _notify();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _message = null;
    _notify();
  }

  String _describeError(Object error) {
    return 'SMS inbox error: $error';
  }

  void _notify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stagedSubscription?.cancel();
    super.dispose();
  }
}
