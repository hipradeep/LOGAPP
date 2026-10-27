import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/budget_transaction.dart';
import '../models/contact.dart';
import '../models/debt_record.dart';
import '../services/database_service.dart';
import '../utils/id_utils.dart';

class DebtController extends ChangeNotifier {
  DebtController({DatabaseService? dbService, bool watchDatabase = true})
    : _dbService = dbService ?? DatabaseService.instance {
    if (watchDatabase) {
      _changeSubscription = _dbService.onDatabaseChanged.listen((_) {
        if (_isDisposed) return;
        _reloadTimer?.cancel();
        _reloadTimer = Timer(
          const Duration(milliseconds: 150),
          () => unawaited(reload()),
        );
      });
    }
  }

  final DatabaseService _dbService;

  StreamSubscription<String>? _changeSubscription;
  Timer? _reloadTimer;
  Future<void>? _reloadFuture;
  bool _reloadQueued = false;
  bool _isDisposed = false;
  bool _isLoading = true;

  List<DebtRecord> _records = const [];
  final Map<String, DebtRecord> _recordById = {};
  final Map<String, List<DebtRecord>> _recordsByContact = {};
  final Map<String, double> _givenByContact = {};
  final Map<String, double> _takenByContact = {};
  final Map<String, int> _outstandingCountByContact = {};
  double _totalGiven = 0;
  double _totalTaken = 0;

  bool get isLoading => _isLoading;
  List<DebtRecord> get records => _records;
  double get totalGiven => _totalGiven;
  double get totalTaken => _totalTaken;
  double get netBalance => _totalGiven - _totalTaken;
  bool get isSettled => _totalGiven < 0.01 && _totalTaken < 0.01;

  DebtRecord? recordById(String? id) => id == null ? null : _recordById[id];

  List<DebtRecord> recordsForContact(String contactId) =>
      _recordsByContact[contactId] ?? const [];

  double givenForContact(String contactId) => _givenByContact[contactId] ?? 0;

  double takenForContact(String contactId) => _takenByContact[contactId] ?? 0;

  double netForContact(String contactId) =>
      givenForContact(contactId) - takenForContact(contactId);

  int outstandingCountForContact(String contactId) =>
      _outstandingCountByContact[contactId] ?? 0;

  Future<void> load() async {
    _reloadTimer?.cancel();
    await reload();
  }

  Future<void> reload() async {
    if (_isDisposed) return;
    if (_reloadFuture != null) {
      _reloadQueued = true;
      return _reloadFuture;
    }

    final future = _performLoad();
    _reloadFuture = future;
    try {
      await future;
    } finally {
      _reloadFuture = null;
      if (_reloadQueued && !_isDisposed) {
        _reloadQueued = false;
        await reload();
      }
    }
  }

  Future<void> _performLoad() async {
    final records = await _dbService.getDebtRecords();
    if (_isDisposed) return;

    _records = records;
    _recordById
      ..clear()
      ..addEntries(records.map((item) => MapEntry(item.id, item)));
    _recordsByContact.clear();
    _givenByContact.clear();
    _takenByContact.clear();
    _outstandingCountByContact.clear();
    _totalGiven = 0;
    _totalTaken = 0;

    for (final record in records) {
      _recordsByContact.putIfAbsent(record.contactId, () => []).add(record);
      final outstanding = record.outstanding;
      if (outstanding <= 0) continue;
      if (record.isGiven) {
        _givenByContact[record.contactId] =
            (_givenByContact[record.contactId] ?? 0) + outstanding;
        _totalGiven += outstanding;
      } else if (record.isTaken) {
        _takenByContact[record.contactId] =
            (_takenByContact[record.contactId] ?? 0) + outstanding;
        _totalTaken += outstanding;
      }
      _outstandingCountByContact[record.contactId] =
          (_outstandingCountByContact[record.contactId] ?? 0) + 1;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<DebtRecord> addDebt({
    required String contactId,
    required String direction,
    required double amount,
    DateTime? dueDate,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero');
    }
    if (direction != 'give' && direction != 'take') {
      throw ArgumentError.value(direction, 'direction', 'Must be give or take');
    }

    final record = DebtRecord(
      id: IdUtils.generate('debt'),
      contactId: contactId,
      direction: direction,
      amount: amount,
      notes: _clean(notes),
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    await _dbService.addDebtRecord(record);
    await reload();
    return record;
  }

  Future<void> deleteDebt(String id) async {
    await _dbService.deleteDebtRecord(id);
    await reload();
  }

  Future<void> settleDebt({
    required DebtRecord record,
    required Contact contact,
    required double amount,
    required String paymentModeId,
  }) async {
    final outstanding = record.outstanding;
    if (outstanding <= 0) return;
    final applied = amount.clamp(0, outstanding).toDouble();
    if (applied <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Must be greater than zero');
    }

    final now = DateTime.now();
    final name = contact.name.trim().isEmpty ? 'Contact' : contact.name.trim();
    final settlementTransaction = BudgetTransaction(
      id: IdUtils.generate('txn'),
      amount: applied,
      type: record.isGiven ? 'income' : 'expense',
      paymentModeId: paymentModeId,
      title: record.isGiven ? '$name repaid' : 'Repaid $name',
      note: 'Debt settlement',
      timestamp: now,
      createdAt: now,
    );

    await _dbService.settleDebt(
      record.id,
      applied,
      settledAt: now,
      settlementTransaction: settlementTransaction,
    );
    await reload();
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reloadTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}
