import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/preferences_service.dart';

class PresetRuleInfo {
  final String id;
  final String title;
  final String description;
  final double expenseRatio; // e.g. 0.80
  final double savingsRatio; // e.g. 0.20
  final double? needsRatio; // 0.50
  final double? wantsRatio; // 0.30
  final bool isAvailable;
  final bool isCustom;

  const PresetRuleInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.expenseRatio,
    required this.savingsRatio,
    this.needsRatio,
    this.wantsRatio,
    this.isAvailable = true,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'expenseRatio': expenseRatio,
      'savingsRatio': savingsRatio,
      if (needsRatio != null) 'needsRatio': needsRatio,
      if (wantsRatio != null) 'wantsRatio': wantsRatio,
      'isAvailable': isAvailable,
      'isCustom': isCustom,
    };
  }

  factory PresetRuleInfo.fromMap(Map<String, dynamic> map) {
    return PresetRuleInfo(
      id: map['id'] as String? ?? 'custom',
      title: map['title'] as String? ?? 'Custom Rule',
      description: map['description'] as String? ?? '',
      expenseRatio: (map['expenseRatio'] as num?)?.toDouble() ?? 0.80,
      savingsRatio: (map['savingsRatio'] as num?)?.toDouble() ?? 0.20,
      needsRatio: (map['needsRatio'] as num?)?.toDouble(),
      wantsRatio: (map['wantsRatio'] as num?)?.toDouble(),
      isAvailable: map['isAvailable'] as bool? ?? true,
      isCustom: map['isCustom'] as bool? ?? true,
    );
  }
}

class ManageBudget1Controller extends ChangeNotifier {
  final BudgetService _budgetService = BudgetService();
  final PreferencesService _prefs = PreferencesService();
  StreamSubscription<double>? _salarySub;
  StreamSubscription<List<Budget>>? _budgetSub;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Top Date Range (default: 1 month)
  late DateTime _startDate;
  late DateTime _endDate;

  // Salary
  double _salary = 50000.0;

  // Budget Name (user-defined, falls back to auto if empty)
  String _budgetName = '';

  // Preset Rules
  static const List<PresetRuleInfo> rules = [
    PresetRuleInfo(
      id: '80/20',
      title: '80 / 20 Rule',
      description: '80% Expenses | 20% Savings',
      expenseRatio: 0.80,
      savingsRatio: 0.20,
    ),
    PresetRuleInfo(
      id: '70/30',
      title: '70 / 30 Rule',
      description: '70% Expenses | 30% Savings',
      expenseRatio: 0.70,
      savingsRatio: 0.30,
    ),
    PresetRuleInfo(
      id: '50/30/20',
      title: '50 / 30 / 20 Rule',
      description: '50% Needs + 30% Wants (80% Exp) | 20% Sav',
      expenseRatio: 0.80,
      savingsRatio: 0.20,
      needsRatio: 0.50,
      wantsRatio: 0.30,
    ),
  ];

  final List<PresetRuleInfo> _customRules = [];

  String _selectedRuleId = '80/20';

  // Subcategory Percentages (Relative to parent category, default sum 100%)
  // Expense subcategories (5 major options)
  final Map<String, double> _expenseSubPercentages = {
    'Grocery': 35.0,
    'Bills': 25.0,
    'Travel': 15.0,
    'Dining': 15.0,
    'Shopping': 10.0,
  };

  // Savings subcategories
  final Map<String, double> _savingsSubPercentages = {
    'Invest (Stocks & MF)': 50.0,
    'Fixed Deposit (FD)': 25.0,
    'Emergency Fund': 25.0,
  };

  // Needs subcategories (for 3-way split)
  final Map<String, double> _needsSubPercentages = {
    'Grocery': 45.0,
    'Bills': 35.0,
    'Transport': 20.0,
  };

  // Wants subcategories (for 3-way split: Eating Out, Entertainment, Travel, Hobbies)
  final Map<String, double> _wantsSubPercentages = {
    'Eating Out': 35.0,
    'Entertainment': 25.0,
    'Travel': 20.0,
    'Hobbies': 20.0,
  };

  // Existing budget ID if modifying
  String? _existingBudgetId;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  double get salary => _salary;
  String get selectedRuleId => _selectedRuleId;
  String get budgetName => _budgetName;

  List<PresetRuleInfo> get customRules => List.unmodifiable(_customRules);
  List<PresetRuleInfo> get allRules => [...rules, ..._customRules];

  PresetRuleInfo get activeRule =>
      allRules.firstWhere((r) => r.id == _selectedRuleId, orElse: () => allRules.first);

  double get expenseAmount => _salary * activeRule.expenseRatio;
  bool get isThreeWaySplit =>
      activeRule.needsRatio != null && activeRule.wantsRatio != null;
  double get needsAmount => _salary * (activeRule.needsRatio ?? 0.50);
  double get wantsAmount => _salary * (activeRule.wantsRatio ?? 0.30);
  double get savingsAmount => _salary * activeRule.savingsRatio;

  Map<String, double> get expenseSubPercentages => Map.unmodifiable(_expenseSubPercentages);
  Map<String, double> get savingsSubPercentages => Map.unmodifiable(_savingsSubPercentages);
  Map<String, double> get needsSubPercentages => Map.unmodifiable(_needsSubPercentages);
  Map<String, double> get wantsSubPercentages => Map.unmodifiable(_wantsSubPercentages);

  double get expenseSubPercentageSum =>
      _expenseSubPercentages.values.fold(0.0, (prev, val) => prev + val);

  double get savingsSubPercentageSum =>
      _savingsSubPercentages.values.fold(0.0, (prev, val) => prev + val);

  double get needsSubPercentageSum =>
      _needsSubPercentages.values.fold(0.0, (prev, val) => prev + val);

  double get wantsSubPercentageSum =>
      _wantsSubPercentages.values.fold(0.0, (prev, val) => prev + val);

  String? _pendingRuleId;

  ManageBudget1Controller() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
    _loadCustomRules();
    _initStreams();
  }

  Future<void> _loadCustomRules() async {
    final stored = await _prefs.getCustomRules();
    if (stored.isNotEmpty) {
      _customRules.clear();
      for (final item in stored) {
        try {
          _customRules.add(PresetRuleInfo.fromMap(item));
        } catch (_) {}
      }
      if (_pendingRuleId != null && allRules.any((r) => r.id == _pendingRuleId && r.isAvailable)) {
        _selectedRuleId = _pendingRuleId!;
      }
      notifyListeners();
    }
  }

  Future<void> addCustomRule(PresetRuleInfo rule) async {
    _customRules.removeWhere((r) => r.id == rule.id);
    _customRules.add(rule);
    await _prefs.saveCustomRules(_customRules.map((r) => r.toMap()).toList());
    notifyListeners();
  }

  Future<void> applyAndSaveRule(String ruleId) async {
    selectRule(ruleId);
    if (_existingBudgetId != null) {
      await saveBudgetPlan();
    }
  }

  Future<void> deleteCustomRule(String id) async {
    _customRules.removeWhere((r) => r.id == id);
    await _prefs.saveCustomRules(_customRules.map((r) => r.toMap()).toList());
    if (_selectedRuleId == id) {
      _selectedRuleId = '80/20';
      if (_existingBudgetId != null) {
        await saveBudgetPlan();
      }
    }
    notifyListeners();
  }

  List<Budget> _allBudgets = [];

  bool isRuleInUse(PresetRuleInfo rule) {
    if (_selectedRuleId == rule.id || _selectedRuleId == rule.title) {
      return true;
    }
    if (activeRule.id == rule.id || activeRule.title.toLowerCase() == rule.title.toLowerCase()) {
      return true;
    }
    if (_pendingRuleId != null && (_pendingRuleId == rule.id || _pendingRuleId == rule.title)) {
      return true;
    }
    for (final b in _allBudgets) {
      if (b.isActive && b.rule != null) {
        if (b.rule == rule.id || b.rule == rule.title) {
          return true;
        }
      }
    }
    return false;
  }

  void _initStreams() {
    _salarySub = _budgetService.getSalaryStream().listen((sal) {
      if (_isLoading) {
        _salary = sal > 0 ? sal : 50000.0;
      }
    });

    _budgetSub = _budgetService.getBudgetsStream().listen((budgets) {
      _allBudgets = budgets;
      if (_isLoading) {
        // Look for existing active rule budget
        final ruleBudget = budgets.firstWhere(
          (b) => b.isActive && b.rule != null,
          orElse: () => budgets.firstWhere((b) => b.isActive, orElse: () => budgets.isNotEmpty ? budgets.first : Budget(id: '', name: '', categoryName: '', limit: 0, period: 'monthly')),
        );

        if (ruleBudget.id.isNotEmpty && ruleBudget.rule != null) {
          _existingBudgetId = ruleBudget.id;
          if (ruleBudget.salary != null && ruleBudget.salary! > 0) {
            _salary = ruleBudget.salary!;
          }
          // Restore budget name (strip auto-prefix if needed)
          if (ruleBudget.name.isNotEmpty) {
            _budgetName = ruleBudget.name.startsWith('Budget (')
                ? ''
                : ruleBudget.name;
          }
          _pendingRuleId = ruleBudget.rule;
          if (allRules.any((r) => r.id == ruleBudget.rule && r.isAvailable)) {
            _selectedRuleId = ruleBudget.rule!;
          }
          if (ruleBudget.startDate != null && ruleBudget.endDate != null) {
            _startDate = ruleBudget.startDate!;
            _endDate = ruleBudget.endDate!;
          }

          // Restore subcategory percentages if present
          for (final cat in ruleBudget.allocations) {
            final lower = cat.name.toLowerCase();
            if (lower.contains('need')) {
              for (final sub in cat.subCategories) {
                if (_needsSubPercentages.containsKey(sub.name)) {
                  _needsSubPercentages[sub.name] = sub.percentage;
                }
              }
            } else if (lower.contains('want')) {
              for (final sub in cat.subCategories) {
                if (_wantsSubPercentages.containsKey(sub.name)) {
                  _wantsSubPercentages[sub.name] = sub.percentage;
                }
              }
            } else if (lower.contains('expense')) {
              for (final sub in cat.subCategories) {
                if (_expenseSubPercentages.containsKey(sub.name)) {
                  _expenseSubPercentages[sub.name] = sub.percentage;
                }
              }
            } else if (lower.contains('saving')) {
              for (final sub in cat.subCategories) {
                if (_savingsSubPercentages.containsKey(sub.name)) {
                  _savingsSubPercentages[sub.name] = sub.percentage;
                }
              }
            }
          }
        }
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void updateDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void updateSalary(double newSalary) {
    if (newSalary <= 0) return;
    _salary = newSalary;
    notifyListeners();
  }

  void updateBudgetName(String name) {
    _budgetName = name;
    notifyListeners();
  }

  void selectRule(String ruleId) {
    final match = allRules.firstWhere((r) => r.id == ruleId, orElse: () => allRules.first);
    if (!match.isAvailable) return;
    _selectedRuleId = ruleId;
    notifyListeners();
  }

  void updateNeedsSubPercentage(String subName, double percentage) {
    if (_needsSubPercentages.containsKey(subName)) {
      _needsSubPercentages[subName] = percentage.clamp(0.0, 100.0);
      notifyListeners();
    }
  }

  void updateWantsSubPercentage(String subName, double percentage) {
    if (_wantsSubPercentages.containsKey(subName)) {
      _wantsSubPercentages[subName] = percentage.clamp(0.0, 100.0);
      notifyListeners();
    }
  }

  void updateExpenseSubPercentage(String subName, double percentage) {
    if (_expenseSubPercentages.containsKey(subName)) {
      _expenseSubPercentages[subName] = percentage.clamp(0.0, 100.0);
      notifyListeners();
    }
  }

  void updateSavingsSubPercentage(String subName, double percentage) {
    if (_savingsSubPercentages.containsKey(subName)) {
      _savingsSubPercentages[subName] = percentage.clamp(0.0, 100.0);
      notifyListeners();
    }
  }

  void updateExpenseSubAmount(String subName, double amount) {
    if (expenseAmount <= 0) return;
    final pct = (amount / expenseAmount) * 100.0;
    updateExpenseSubPercentage(subName, pct);
  }

  void updateSavingsSubAmount(String subName, double amount) {
    if (savingsAmount <= 0) return;
    final pct = (amount / savingsAmount) * 100.0;
    updateSavingsSubPercentage(subName, pct);
  }

  void autoBalanceExpenseSubcategories() {
    final sum = expenseSubPercentageSum;
    if (sum <= 0) {
      final equalPct = 100.0 / _expenseSubPercentages.length;
      _expenseSubPercentages.updateAll((key, value) => equalPct);
    } else {
      final factor = 100.0 / sum;
      _expenseSubPercentages.updateAll((key, value) => value * factor);
    }
    notifyListeners();
  }

  void splitEquallyExpenseSubcategories() {
    if (_expenseSubPercentages.isEmpty) return;
    final equalPct = 100.0 / _expenseSubPercentages.length;
    _expenseSubPercentages.updateAll((key, value) => equalPct);
    notifyListeners();
  }

  void resetExpenseSubcategories() {
    _expenseSubPercentages
      ..clear()
      ..addAll({
        'Grocery': 35.0,
        'Bills': 25.0,
        'Travel': 15.0,
        'Dining': 15.0,
        'Shopping': 10.0,
      });
    notifyListeners();
  }

  void autoBalanceSavingsSubcategories() {
    final sum = savingsSubPercentageSum;
    if (sum <= 0) {
      final equalPct = 100.0 / _savingsSubPercentages.length;
      _savingsSubPercentages.updateAll((key, value) => equalPct);
    } else {
      final factor = 100.0 / sum;
      _savingsSubPercentages.updateAll((key, value) => value * factor);
    }
    notifyListeners();
  }

  void splitEquallySavingsSubcategories() {
    if (_savingsSubPercentages.isEmpty) return;
    final equalPct = 100.0 / _savingsSubPercentages.length;
    _savingsSubPercentages.updateAll((key, value) => equalPct);
    notifyListeners();
  }

  void resetSavingsSubcategories() {
    _savingsSubPercentages
      ..clear()
      ..addAll({
        'Invest (Stocks & MF)': 50.0,
        'Fixed Deposit (FD)': 25.0,
        'Emergency Fund': 25.0,
      });
    notifyListeners();
  }

  double calculateExpenseSubAmount(String subName) {
    final pct = _expenseSubPercentages[subName] ?? 0.0;
    return (pct / 100.0) * expenseAmount;
  }

  double calculateSavingsSubAmount(String subName) {
    final pct = _savingsSubPercentages[subName] ?? 0.0;
    return (pct / 100.0) * savingsAmount;
  }

  double calculateWantsSubAmount(String subName) {
    final pct = _wantsSubPercentages[subName] ?? 0.0;
    return (pct / 100.0) * wantsAmount;
  }

  void updateWantsSubAmount(String subName, double amount) {
    if (wantsAmount <= 0) return;
    final pct = (amount / wantsAmount) * 100.0;
    updateWantsSubPercentage(subName, pct);
  }

  void autoBalanceWantsSubcategories() {
    final sum = wantsSubPercentageSum;
    if (sum <= 0) {
      final equalPct = 100.0 / _wantsSubPercentages.length;
      _wantsSubPercentages.updateAll((key, value) => equalPct);
    } else {
      final factor = 100.0 / sum;
      _wantsSubPercentages.updateAll((key, value) => value * factor);
    }
    notifyListeners();
  }

  void splitEquallyWantsSubcategories() {
    if (_wantsSubPercentages.isEmpty) return;
    final equalPct = 100.0 / _wantsSubPercentages.length;
    _wantsSubPercentages.updateAll((key, value) => equalPct);
    notifyListeners();
  }

  void resetWantsSubcategories() {
    _wantsSubPercentages
      ..clear()
      ..addAll({
        'Eating Out': 35.0,
        'Entertainment': 25.0,
        'Travel': 20.0,
        'Hobbies': 20.0,
      });
    notifyListeners();
  }

  void _normalizeAllSubcategories() {
    void normalize(Map<String, double> map) {
      final sum = map.values.fold(0.0, (a, b) => a + b);
      if (sum > 0 && (sum - 100.0).abs() > 0.1) {
        final factor = 100.0 / sum;
        map.updateAll((k, v) => v * factor);
      }
    }
    normalize(_needsSubPercentages);
    normalize(_wantsSubPercentages);
    normalize(_expenseSubPercentages);
    normalize(_savingsSubPercentages);
  }

  List<BudgetCategoryAllocation> buildAllocations() {
    if (isThreeWaySplit) {
      final needsSubs = _needsSubPercentages.entries.map((e) {
        return BudgetSubCategory(
          name: e.key,
          percentage: e.value,
          amount: (e.value / 100.0) * needsAmount,
        );
      }).toList();

      final wantsSubs = _wantsSubPercentages.entries.map((e) {
        return BudgetSubCategory(
          name: e.key,
          percentage: e.value,
          amount: (e.value / 100.0) * wantsAmount,
        );
      }).toList();

      // Collect unallocated remainders from Needs & Wants
      final needsAllocated = needsSubs.fold(0.0, (s, e) => s + e.amount);
      final wantsAllocated = wantsSubs.fold(0.0, (s, e) => s + e.amount);
      final remainder = (needsAmount - needsAllocated).clamp(0.0, needsAmount) +
          (wantsAmount - wantsAllocated).clamp(0.0, wantsAmount);

      final effectiveSavings = savingsAmount + remainder;
      final savSubs = _savingsSubPercentages.entries.map((e) {
        return BudgetSubCategory(
          name: e.key,
          percentage: e.value,
          amount: (e.value / 100.0) * savingsAmount, // base savings only
        );
      }).toList();

      // Add unallocated as a separate savings sub-entry
      if (remainder > 0.5) {
        final unallocPct = (remainder / effectiveSavings) * 100.0;
        savSubs.add(BudgetSubCategory(
          name: 'Unallocated',
          percentage: unallocPct,
          amount: remainder,
        ));
      }

      return [
        BudgetCategoryAllocation(
          name: 'Needs',
          percentage: (activeRule.needsRatio ?? 0.50) * 100.0,
          amount: needsAmount,
          subCategories: needsSubs,
        ),
        BudgetCategoryAllocation(
          name: 'Wants',
          percentage: (activeRule.wantsRatio ?? 0.30) * 100.0,
          amount: wantsAmount,
          subCategories: wantsSubs,
        ),
        BudgetCategoryAllocation(
          name: 'Savings',
          percentage: activeRule.savingsRatio * 100.0,
          amount: effectiveSavings,
          subCategories: savSubs,
        ),
      ];
    }

    // 2-way split
    final expSubs = _expenseSubPercentages.entries.map((e) {
      return BudgetSubCategory(
        name: e.key,
        percentage: e.value,
        amount: (e.value / 100.0) * expenseAmount,
      );
    }).toList();

    final expAllocated = expSubs.fold(0.0, (s, e) => s + e.amount);
    final expRemainder = (expenseAmount - expAllocated).clamp(0.0, expenseAmount);
    final effectiveSavings2 = savingsAmount + expRemainder;

    final savSubs2 = _savingsSubPercentages.entries.map((e) {
      return BudgetSubCategory(
        name: e.key,
        percentage: e.value,
        amount: (e.value / 100.0) * savingsAmount,
      );
    }).toList();

    if (expRemainder > 0.5) {
      final unallocPct = (expRemainder / effectiveSavings2) * 100.0;
      savSubs2.add(BudgetSubCategory(
        name: 'Unallocated',
        percentage: unallocPct,
        amount: expRemainder,
      ));
    }

    return [
      BudgetCategoryAllocation(
        name: 'Expenses',
        percentage: activeRule.expenseRatio * 100.0,
        amount: expenseAmount,
        subCategories: expSubs,
      ),
      BudgetCategoryAllocation(
        name: 'Savings',
        percentage: activeRule.savingsRatio * 100.0,
        amount: effectiveSavings2,
        subCategories: savSubs2,
      ),
    ];
  }

  Future<bool> saveBudgetPlan() async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allocations = buildAllocations();
      final name = _budgetName.trim().isNotEmpty
          ? _budgetName.trim()
          : 'Budget (${activeRule.title})';

      await _budgetService.createOrUpdateRuleBudget(
        name: name,
        salary: _salary,
        rule: _selectedRuleId,
        expenseLimit: expenseAmount,
        allocations: allocations,
        startDate: _startDate,
        endDate: _endDate,
        existingBudgetId: _existingBudgetId,
      );

      _isSaving = false;
      _normalizeAllSubcategories(); // clear yellow — remainder committed to Savings
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _salarySub?.cancel();
    _budgetSub?.cancel();
    super.dispose();
  }
}
