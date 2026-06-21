import 'dart:async';
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../models/budget.dart';
import '../services/database_service.dart';
import '../utils/id_utils.dart';
import '../utils/db_utils.dart';

class BudgetService {
  Future<DatabaseService> get _db async => DatabaseService.instance;

  // ─── Stream helper (periodic polling) ────────────────────────────────────

  Stream<T> _pollStream<T>(Future<T> Function() query) {
    final controller = StreamController<T>.broadcast();
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
    controller.onCancel = () => timer?.cancel();

    return controller.stream;
  }

  // ─── Salary (budget_settings table) ──────────────────────────────────────

  Stream<double> getSalaryStream() =>
      _pollStream(() => _getSalary());

  Future<double> _getSalary() async {
    final db = await (await _db).database;
    final rows = await db.query(
      'budget_settings',
      where: 'key = ?',
      whereArgs: ['monthlySalary'],
      limit: 1,
    );
    if (rows.isEmpty) return 3000.0;
    return double.tryParse(rows.first['value'] as String? ?? '') ?? 3000.0;
  }

  Future<void> updateSalary(double salary) async {
    final db = await (await _db).database;
    await db.insert(
      'budget_settings',
      {'key': 'monthlySalary', 'value': salary.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── Budgets ──────────────────────────────────────────────────────────────

  Stream<List<Budget>> getBudgetsStream() =>
      _pollStream(() => _getAllBudgets());

  Future<List<Budget>> _getAllBudgets() async {
    final db = await (await _db).database;
    final rows = await db.query('budgets');
    return rows.map((r) => Budget.fromMap(r['id'] as String, r)).toList();
  }

  Future<void> createBudget(
    String name,
    String categoryName,
    double limit,
    String period, {
    String description = '',
    DateTime? startDate,
    DateTime? endDate,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    bool repeat = true,
    bool isActive = true,
    double alertThreshold = 0.7,
  }) async {
    final db = await (await _db).database;
    final id = IdUtils.generateId();
    final now = DateTime.now();

    final budget = Budget(
      id: id,
      name: name,
      categoryName: categoryName,
      limit: limit,
      period: period,
      description: description,
      startDate: startDate,
      endDate: endDate,
      repeatDays: repeatDays,
      scheduledTime: scheduledTime,
      repeat: repeat,
      isActive: isActive,
      alertThreshold: alertThreshold,
    );
    final map = budget.toMap();
    map['createdAt'] = now.millisecondsSinceEpoch;
    await db.insert('budgets', map);

    if (isActive) {
      await _deactivateOtherBudgets(db, id);
    }
  }

  Future<void> updateBudget(
    String budgetId, {
    String? name,
    String? categoryName,
    double? limit,
    String? period,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? repeatDays,
    String? scheduledTime,
    bool? repeat,
    bool? isActive,
    double? alertThreshold,
  }) async {
    final db = await (await _db).database;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (categoryName != null) updates['categoryName'] = categoryName;
    if (limit != null) updates['limit_amount'] = limit;
    if (period != null) updates['period'] = period;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = DbUtils.dateToMs(startDate);
    if (endDate != null) updates['endDate'] = DbUtils.dateToMs(endDate);
    if (repeatDays != null) updates['repeatDays'] = DbUtils.encodeIntList(repeatDays);
    if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
    if (repeat != null) updates['repeat'] = repeat ? 1 : 0;
    if (isActive != null) updates['isActive'] = isActive ? 1 : 0;
    if (alertThreshold != null) updates['alertThreshold'] = alertThreshold;

    if (updates.isEmpty) return;
    await db.update('budgets', updates, where: 'id = ?', whereArgs: [budgetId]);

    if (isActive == true) {
      await _deactivateOtherBudgets(db, budgetId);
    }
  }

  Future<void> toggleBudget(String budgetId, bool isActive) async {
    final db = await (await _db).database;
    await db.update('budgets', {'isActive': isActive ? 1 : 0}, where: 'id = ?', whereArgs: [budgetId]);
    if (isActive) {
      await _deactivateOtherBudgets(db, budgetId);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    final db = await (await _db).database;
    // Cascade deletes transactions via FK constraint
    await db.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
  }

  // ─── Transactions ─────────────────────────────────────────────────────────

  Stream<List<Transaction>> getTransactionsStream() =>
      _pollStream(() => _getAllTransactions());

  Future<List<Transaction>> _getAllTransactions() async {
    final db = await (await _db).database;
    final rows = await db.query('transactions', orderBy: 'expenseDate DESC');
    return rows.map((r) => Transaction.fromMap(r['id'] as String, r)).toList();
  }

  Future<void> addTransaction(
    String budgetId,
    String tag,
    String description,
    double amount, {
    DateTime? timestamp,
    String paymentMethod = 'Cash',
  }) async {
    final db = await (await _db).database;
    final id = IdUtils.generateId();
    final now = DateTime.now();
    final expenseTime = timestamp ?? now;

    final tx = Transaction(
      id: id,
      budgetId: budgetId,
      tag: tag,
      description: description,
      amount: amount,
      entryDate: now,
      expenseDate: expenseTime,
      isValidated: true,
      paymentMethod: paymentMethod,
    );
    final map = tx.toMap();
    map['createdAt'] = now.millisecondsSinceEpoch;
    await db.insert('transactions', map);
  }

  Future<void> deleteTransaction(String transactionId) async {
    final db = await (await _db).database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
  }

  Future<void> updateTransaction(Transaction updated) async {
    final db = await (await _db).database;
    await db.update('transactions', updated.toMap(), where: 'id = ?', whereArgs: [updated.id]);
  }

  Future<void> moveTransaction({
    required String destBudgetId,
    required Transaction transaction,
  }) async {
    final db = await (await _db).database;
    await db.update(
      'transactions',
      {'budgetId': destBudgetId},
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _deactivateOtherBudgets(dynamic db, String activeBudgetId) async {
    await db.update(
      'budgets',
      {'isActive': 0},
      where: 'id != ? AND isActive = 1',
      whereArgs: [activeBudgetId],
    );
  }
}
