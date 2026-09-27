import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/budget.dart';
import '../utils/id_utils.dart';

class BudgetService {
  final CollectionReference _budgetsCollection =
      FirebaseFirestore.instance.collection('budgets');

  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');

  final DocumentReference _budgetSettingsDoc =
      FirebaseFirestore.instance.collection('metadata').doc('bgt_budget_settings');

  // ==================== SALARY / INCOME SETTINGS ====================

  Stream<double> getSalaryStream() {
    return _budgetSettingsDoc.snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        return (data['monthlySalary'] as num?)?.toDouble() ?? 50000.0;
      }
      return 50000.0;
    });
  }

  Future<void> updateSalary(double salary) async {
    await _budgetSettingsDoc.set(
      {'monthlySalary': salary},
      SetOptions(merge: true),
    );
  }

  // ==================== BUDGET OPERATIONS ====================

  Stream<List<Budget>> getBudgetsStream() {
    return _budgetsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Budget.fromFirestore(doc)).toList();
    });
  }

  Future<void> _deactivateOtherFirestoreBudgets(String activeBudgetId) async {
    final query = await _budgetsCollection.where('isActive', isEqualTo: true).get();
    for (var doc in query.docs) {
      if (doc.id != activeBudgetId) {
        await doc.reference.update({'isActive': false});
      }
    }
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
    final docId = 'bgt_${IdUtils.generateId()}';
    final newItem = Budget(
      id: docId,
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

    await _budgetsCollection.doc(docId).set(newItem.toFirestore());
    if (isActive) {
      await _deactivateOtherFirestoreBudgets(docId);
    }
  }

  Future<String> createOrUpdateRuleBudget({
    required String name,
    required double salary,
    required String rule,
    required double expenseLimit,
    required List<BudgetCategoryAllocation> allocations,
    DateTime? startDate,
    DateTime? endDate,
    String? existingBudgetId,
  }) async {
    final docId = existingBudgetId ?? 'bgt_${IdUtils.generateId()}';
    final budget = Budget(
      id: docId,
      name: name,
      categoryName: 'Expenses',
      limit: expenseLimit,
      period: 'monthly',
      description: '$rule rule budget based on monthly salary ₹${salary.toStringAsFixed(0)}',
      startDate: startDate,
      endDate: endDate,
      salary: salary,
      rule: rule,
      allocations: allocations,
      isActive: true,
    );

    await _budgetsCollection.doc(docId).set(budget.toFirestore());
    await _deactivateOtherFirestoreBudgets(docId);
    await updateSalary(salary);
    return docId;
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
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (categoryName != null) updates['categoryName'] = categoryName;
    if (limit != null) updates['limit'] = limit;
    if (period != null) updates['period'] = period;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
    if (repeatDays != null) updates['repeatDays'] = repeatDays;
    if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
    if (repeat != null) updates['repeat'] = repeat;
    if (isActive != null) updates['isActive'] = isActive;
    if (alertThreshold != null) updates['alertThreshold'] = alertThreshold;

    if (updates.isEmpty) return;
    await _budgetsCollection.doc(budgetId).update(updates);

    if (isActive == true) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> toggleBudget(String budgetId, bool isActive) async {
    await _budgetsCollection.doc(budgetId).update({'isActive': isActive});
    if (isActive) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    // Delete all associated transactions first
    final txQuery = await _transactionsCollection.where('budgetId', isEqualTo: budgetId).get();
    for (var doc in txQuery.docs) {
      await doc.reference.delete();
    }
    await _budgetsCollection.doc(budgetId).delete();
  }

  // ==================== TRANSACTION OPERATIONS ====================

  Stream<List<Transaction>> getTransactionsStream() {
    return _transactionsCollection.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList();
      list.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      return list;
    });
  }

  Future<void> addTransaction(
    String budgetId,
    String tag,
    String description,
    double amount, {
    String? merchant,
    String type = 'expense',
    DateTime? timestamp,
    String paymentMethod = 'Cash',
  }) async {
    final now = DateTime.now();
    final expenseTime = timestamp ?? now;
    final txId = 'bgt_${IdUtils.generateId()}';

    final tx = Transaction(
      id: txId,
      budgetId: budgetId,
      tag: tag,
      description: description,
      merchant: merchant,
      type: type,
      amount: amount,
      entryDate: now,
      expenseDate: expenseTime,
      isValidated: true,
      paymentMethod: paymentMethod,
    );

    await _transactionsCollection.doc(txId).set(tx.toMap()).timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  Future<void> updateTransaction(Transaction updated) async {
    await _transactionsCollection.doc(updated.id).update(updated.toMap()).timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactionsCollection.doc(transactionId).delete().timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }

  Future<void> moveTransaction({
    required String destBudgetId,
    required Transaction transaction,
  }) async {
    await _transactionsCollection.doc(transaction.id).update({
      'budgetId': destBudgetId,
    }).timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }
}
