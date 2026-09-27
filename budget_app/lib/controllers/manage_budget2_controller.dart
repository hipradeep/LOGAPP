import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';

class ManageBudget2Controller extends ChangeNotifier {
  final BudgetService _budgetService = BudgetService();

  // ── Step ────────────────────────────────────────────────────────────────────
  int _step = 1; // 1 | 2 | 3
  int get step => _step;

  bool get canGoNext {
    if (_step == 1) return _budgetName.trim().isNotEmpty && _amount > 0;
    if (_step == 2) return _salary > 0;
    return true;
  }

  void nextStep() {
    if (_step < 3 && canGoNext) {
      _step++;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_step > 1) {
      _step--;
      notifyListeners();
    }
  }

  // ── Step 1 fields ───────────────────────────────────────────────────────────
  String _budgetName = '';
  double _amount = 0.0;
  String _category = 'Monthly';
  double _threshold = 0.8; // 80%
  String _description = '';

  String get budgetName => _budgetName;
  double get amount => _amount;
  String get category => _category;
  double get threshold => _threshold;
  String get description => _description;

  static const List<String> categories = [
    'Monthly',
    'Weekly',
    'Daily',
    'Custom',
  ];

  void updateBudgetName(String v) { _budgetName = v; notifyListeners(); }
  void updateAmount(double v) { _amount = v; notifyListeners(); }
  void updateCategory(String v) { _category = v; notifyListeners(); }
  void updateThreshold(double v) { _threshold = v.clamp(0.0, 1.0); notifyListeners(); }
  void updateDescription(String v) { _description = v; notifyListeners(); }

  // ── Step 2 – Salary & Division ───────────────────────────────────────────────
  double _salary = 50000.0;
  // Ratios (must sum to 1.0)
  double _needsRatio = 0.50;
  double _wantsRatio = 0.30;
  double _savingsRatio = 0.20;

  double get salary => _salary;
  double get needsRatio => _needsRatio;
  double get wantsRatio => _wantsRatio;
  double get savingsRatio => _savingsRatio;

  double get needsAmount => _salary * _needsRatio;
  double get wantsAmount => _salary * _wantsRatio;
  double get savingsAmount => _salary * _savingsRatio;

  void updateSalary(double v) {
    if (v > 0) { _salary = v; notifyListeners(); }
  }

  /// Adjust needs ratio; auto-rebalances wants & savings proportionally.
  void updateNeedsRatio(double v) {
    _needsRatio = v.clamp(0.0, 1.0);
    final rem = (1.0 - _needsRatio).clamp(0.0, 1.0);
    final wantsPlusSav = _wantsRatio + _savingsRatio;
    if (wantsPlusSav > 0) {
      _wantsRatio = rem * (_wantsRatio / wantsPlusSav);
      _savingsRatio = rem * (_savingsRatio / wantsPlusSav);
    } else {
      _wantsRatio = rem / 2;
      _savingsRatio = rem / 2;
    }
    notifyListeners();
  }

  void updateWantsRatio(double v) {
    _wantsRatio = v.clamp(0.0, 1.0);
    final rem = (1.0 - _wantsRatio).clamp(0.0, 1.0);
    final needsPlusSav = _needsRatio + _savingsRatio;
    if (needsPlusSav > 0) {
      _needsRatio = rem * (_needsRatio / needsPlusSav);
      _savingsRatio = rem * (_savingsRatio / needsPlusSav);
    } else {
      _needsRatio = rem / 2;
      _savingsRatio = rem / 2;
    }
    notifyListeners();
  }

  void updateSavingsRatio(double v) {
    _savingsRatio = v.clamp(0.0, 1.0);
    final rem = (1.0 - _savingsRatio).clamp(0.0, 1.0);
    final needsPlusWants = _needsRatio + _wantsRatio;
    if (needsPlusWants > 0) {
      _needsRatio = rem * (_needsRatio / needsPlusWants);
      _wantsRatio = rem * (_wantsRatio / needsPlusWants);
    } else {
      _needsRatio = rem / 2;
      _wantsRatio = rem / 2;
    }
    notifyListeners();
  }

  // ── Step 3 – Subcategory allocations ─────────────────────────────────────────
  final Map<String, double> _needsSubs = {
    'Grocery': 45.0,
    'Bills': 35.0,
    'Transport': 20.0,
  };
  final Map<String, double> _wantsSubs = {
    'Eating Out': 35.0,
    'Entertainment': 25.0,
    'Travel': 20.0,
    'Hobbies': 20.0,
  };
  final Map<String, double> _savingsSubs = {
    'Invest (Stocks & MF)': 50.0,
    'Fixed Deposit (FD)': 25.0,
    'Emergency Fund': 25.0,
  };

  Map<String, double> get needsSubs => Map.unmodifiable(_needsSubs);
  Map<String, double> get wantsSubs => Map.unmodifiable(_wantsSubs);
  Map<String, double> get savingsSubs => Map.unmodifiable(_savingsSubs);

  double get needsSubSum => _needsSubs.values.fold(0.0, (a, b) => a + b);
  double get wantsSubSum => _wantsSubs.values.fold(0.0, (a, b) => a + b);
  double get savingsSubSum => _savingsSubs.values.fold(0.0, (a, b) => a + b);

  void updateNeedsSub(String k, double v) {
    if (_needsSubs.containsKey(k)) { _needsSubs[k] = v.clamp(0, 100); notifyListeners(); }
  }
  void updateWantsSub(String k, double v) {
    if (_wantsSubs.containsKey(k)) { _wantsSubs[k] = v.clamp(0, 100); notifyListeners(); }
  }
  void updateSavingsSub(String k, double v) {
    if (_savingsSubs.containsKey(k)) { _savingsSubs[k] = v.clamp(0, 100); notifyListeners(); }
  }

  // ── Save ────────────────────────────────────────────────────────────────────
  bool _isSaving = false;
  String? _error;
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<BudgetCategoryAllocation> _buildAllocations() {
    List<BudgetSubCategory> toSubs(Map<String, double> map, double parentAmt) =>
        map.entries.map((e) => BudgetSubCategory(
              name: e.key,
              percentage: e.value,
              amount: (e.value / 100.0) * parentAmt,
            )).toList();

    return [
      BudgetCategoryAllocation(
        name: 'Needs',
        percentage: _needsRatio * 100,
        amount: needsAmount,
        subCategories: toSubs(_needsSubs, needsAmount),
      ),
      BudgetCategoryAllocation(
        name: 'Wants',
        percentage: _wantsRatio * 100,
        amount: wantsAmount,
        subCategories: toSubs(_wantsSubs, wantsAmount),
      ),
      BudgetCategoryAllocation(
        name: 'Savings',
        percentage: _savingsRatio * 100,
        amount: savingsAmount,
        subCategories: toSubs(_savingsSubs, savingsAmount),
      ),
    ];
  }

  Future<bool> save() async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      await _budgetService.createOrUpdateRuleBudget(
        name: _budgetName.trim(),
        salary: _salary,
        rule: 'custom',
        expenseLimit: _amount,
        allocations: _buildAllocations(),
        startDate: now,
        endDate: DateTime(now.year, now.month + 1, 0),
      );
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
