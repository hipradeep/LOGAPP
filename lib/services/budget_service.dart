import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/budget.dart';

class BudgetService {
  final CollectionReference _budgetsCollection =
      FirebaseFirestore.instance.collection('budgets');

  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');

  final DocumentReference _budgetSettingsDoc =
      FirebaseFirestore.instance.collection('metadata').doc('budget_settings');

  // ==================== BUDGET OPERATIONS ====================

  Stream<double> getSalaryStream() {
    return _budgetSettingsDoc.snapshots().map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        return (data['monthlySalary'] as num?)?.toDouble() ?? 3000.0;
      }
      return 3000.0;
    });
  }

  Future<void> updateSalary(double salary) async {
    await _budgetSettingsDoc.set({'monthlySalary': salary}, SetOptions(merge: true));
  }

  Stream<List<Budget>> getBudgetsStream() {
    return _budgetsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Budget.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Transaction>> getTransactionsStream() {
    return _transactionsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Transaction.fromFirestore(doc)).toList();
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
    final newItem = Budget(
      id: '',
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
    final docRef = await _budgetsCollection.add(newItem.toFirestore());
    if (isActive) {
      await _deactivateOtherFirestoreBudgets(docRef.id);
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
    final Map<String, dynamic> updates = {};
    if (name != null) {
      updates['name'] = name;
      updates['category'] = name;
    }
    if (categoryName != null) {
      updates['categoryName'] = categoryName;
    }
    if (limit != null) updates['limit'] = limit;
    if (period != null) updates['period'] = period;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
    if (repeatDays != null) updates['repeatDays'] = repeatDays;
    if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
    if (repeat != null) updates['repeat'] = repeat;
    if (isActive != null) {
      updates['isActive'] = isActive;
    }
    if (alertThreshold != null) updates['alertThreshold'] = alertThreshold;
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
    await _budgetsCollection.doc(budgetId).delete();
  }

  // ==================== TRANSACTION OPERATIONS ====================

  Future<void> addTransaction(String budgetId, String tag, String description, double amount, {DateTime? timestamp}) async {
    final expenseTime = timestamp ?? DateTime.now();
    await _transactionsCollection.add({
      'budgetId': budgetId,
      'tag': tag,
      'description': description,
      'amount': amount,
      'entryDate': Timestamp.fromDate(DateTime.now()),
      'expenseDate': Timestamp.fromDate(expenseTime),
      'isValidated': true,
      'rawBody': null,
    });
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactionsCollection.doc(transactionId).delete();
  }

  Future<void> updateTransaction(Transaction updatedTransaction) async {
    await _transactionsCollection.doc(updatedTransaction.id).update(updatedTransaction.toMap());
  }

  Future<void> moveTransaction({
    required String destBudgetId,
    required Transaction transaction,
  }) async {
    final Map<String, dynamic> data = transaction.toMap();
    data['budgetId'] = destBudgetId;
    await _transactionsCollection.doc(transaction.id).update(data);
  }
}
