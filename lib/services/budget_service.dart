import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/budget_item.dart';

class BudgetService {
  final CollectionReference _budgetsCollection =
      FirebaseFirestore.instance.collection('budgets');

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

  Stream<List<BudgetItem>> getBudgetsStream() {
    return _budgetsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BudgetItem.fromFirestore(doc)).toList();
    });
  }

  Future<void> _deactivateOtherFirestoreBudgets(String activeBudgetId) async {
    final query = await _budgetsCollection.where('checked', isEqualTo: true).get();
    for (var doc in query.docs) {
      if (doc.id != activeBudgetId) {
        await doc.reference.update({'checked': false});
      }
    }
  }

  Future<void> createBudget(
    String category,
    double limit,
    String period, {
    String description = '',
    DateTime? startDate,
    DateTime? endDate,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    bool repeat = true,
    bool checked = true,
  }) async {
    final newItem = BudgetItem(
      id: '',
      category: category,
      limit: limit,
      period: period,
      expenses: const [],
      description: description,
      startDate: startDate,
      endDate: endDate,
      repeatDays: repeatDays,
      scheduledTime: scheduledTime,
      repeat: repeat,
      checked: checked,
    );
    final docRef = await _budgetsCollection.add(newItem.toFirestore());
    if (checked) {
      await _deactivateOtherFirestoreBudgets(docRef.id);
    }
  }

  Future<void> updateBudget(
    String budgetId, {
    double? limit,
    String? period,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? repeatDays,
    String? scheduledTime,
    bool? repeat,
    bool? checked,
  }) async {
    final Map<String, dynamic> updates = {};
    if (limit != null) updates['limit'] = limit;
    if (period != null) updates['period'] = period;
    if (description != null) updates['description'] = description;
    if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
    if (repeatDays != null) updates['repeatDays'] = repeatDays;
    if (scheduledTime != null) updates['scheduledTime'] = scheduledTime;
    if (repeat != null) updates['repeat'] = repeat;
    if (checked != null) updates['checked'] = checked;
    await _budgetsCollection.doc(budgetId).update(updates);
    if (checked == true) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> toggleBudget(String budgetId, bool checked) async {
    await _budgetsCollection.doc(budgetId).update({'checked': checked});
    if (checked) {
      await _deactivateOtherFirestoreBudgets(budgetId);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    await _budgetsCollection.doc(budgetId).delete();
  }

  Future<void> addExpenseToBudget(String budgetId, String tag, String description, double amount, {DateTime? timestamp}) async {
    final expenseTime = timestamp ?? DateTime.now();
    final doc = await _budgetsCollection.doc(budgetId).get();
    if (doc.exists) {
      final budget = BudgetItem.fromFirestore(doc);
      final list = List<BudgetExpense>.from(budget.expenses);
      list.add(BudgetExpense(
        id: 'e-${DateTime.now().millisecondsSinceEpoch}',
        tag: tag,
        description: description,
        amount: amount,
        timestamp: expenseTime,
      ));
      await _budgetsCollection.doc(budgetId).update({
        'expenses': list.map((e) => e.toMap()).toList(),
      });
    }
  }

  Future<void> deleteExpenseFromBudget(String budgetId, String expenseId) async {
    final doc = await _budgetsCollection.doc(budgetId).get();
    if (doc.exists) {
      final budget = BudgetItem.fromFirestore(doc);
      final list = List<BudgetExpense>.from(budget.expenses);
      list.removeWhere((e) => e.id == expenseId);
      await _budgetsCollection.doc(budgetId).update({
        'expenses': list.map((e) => e.toMap()).toList(),
      });
    }
  }
}
