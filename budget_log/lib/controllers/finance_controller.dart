import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/budget.dart';
import '../models/budget_transaction.dart';
import '../models/category.dart';
import '../models/debt_record.dart';
import '../models/payment_mode.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart';
import '../utils/id_utils.dart';

class LogFilter {
  final String query;
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;

  const LogFilter({
    this.query = '',
    this.type = 'all',
    this.startDate,
    this.endDate,
  });

  bool get isActive =>
      query.trim().isNotEmpty ||
      type != 'all' ||
      startDate != null ||
      endDate != null;
}

class CategorySpend {
  final Category? category;
  final double amount;

  const CategorySpend({required this.category, required this.amount});
}

class FinanceController extends ChangeNotifier {
  FinanceController({DatabaseService? dbService, bool watchDatabase = true})
    : _dbService = dbService ?? DatabaseService.instance {
    if (watchDatabase) {
      _changeSubscription = _dbService.onDatabaseChanged.listen((_) {
        _scheduleReload();
      });
    }
  }

  final DatabaseService _dbService;

  StreamSubscription<String>? _changeSubscription;
  Timer? _reloadTimer;
  Future<void>? _reloadFuture;
  bool _reloadQueued = false;
  bool _isDisposed = false;

  List<BudgetTransaction> _transactions = const [];
  List<BudgetTransaction> _filteredTransactions = const [];
  List<Budget> _budgets = const [];
  List<Category> _categories = const [];
  List<PaymentMode> _paymentModes = const [];
  List<BudgetTransaction> _recentTransactions = const [];
  List<CategorySpend> _topCategorySpend = const [];
  final Map<String, Category> _categoryById = {};
  final Map<String, PaymentMode> _paymentModeById = {};
  final Map<String, Budget> _budgetById = {};
  final Map<String, List<Category>> _categoriesByType = {};
  final Map<String, String> _searchIndex = {};
  final Map<String, double> _monthlyCategoryTotals = {};
  final Map<String, double> _spentByBudgetId = {};
  final Map<String, double> _safeDailyByBudgetId = {};

  Map<String, String> _settings = const {};
  LogFilter _logFilter = const LogFilter();
  String? _selectedBudgetId;
  double _monthlySalary = 0;
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  double _selectedBudgetSpent = 0;
  double _selectedBudgetSafeDaily = 0;
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  List<BudgetTransaction> get transactions => _transactions;
  List<BudgetTransaction> get filteredTransactions => _filteredTransactions;
  List<BudgetTransaction> get recentTransactions => _recentTransactions;
  List<Budget> get budgets => _budgets;
  List<Category> get categories => _categories;
  List<PaymentMode> get paymentModes => _paymentModes;
  List<CategorySpend> get topCategorySpend => _topCategorySpend;
  LogFilter get logFilter => _logFilter;
  Map<String, String> get settings => _settings;
  String? get selectedBudgetId => _selectedBudgetId;
  double get monthlySalary => _monthlySalary;
  double get monthlyIncome => _monthlyIncome;
  double get monthlyExpense => _monthlyExpense;
  double get monthlyNet => _monthlyIncome - _monthlyExpense;
  double get selectedBudgetSpent => _selectedBudgetSpent;
  double get selectedBudgetSafeDaily => _selectedBudgetSafeDaily;

  Budget? get selectedBudget => _budgetById[_selectedBudgetId];

  Budget? get activeBudget {
    final selected = selectedBudget;
    if (selected != null && selected.isActive) return selected;
    for (final budget in _budgets) {
      if (budget.isActive) return budget;
    }
    return null;
  }

  double get plannedIncome =>
      _monthlySalary > 0 ? _monthlySalary : _monthlyIncome;

  double get availableToSpend => plannedIncome - _monthlyExpense;

  Category? categoryById(String? id) => id == null ? null : _categoryById[id];

  PaymentMode? paymentModeById(String? id) =>
      id == null ? null : _paymentModeById[id];

  Budget? budgetById(String? id) => id == null ? null : _budgetById[id];

  List<Category> categoriesForType(String type) =>
      _categoriesByType[type] ?? const [];

  List<BudgetTransaction> transactionsForBudget(String budgetId) =>
      _transactions.where((item) => item.budgetId == budgetId).toList();

  double spentForBudget(String budgetId) => _spentByBudgetId[budgetId] ?? 0;

  double safeToSpendForBudget(String budgetId) =>
      _safeDailyByBudgetId[budgetId] ?? 0;

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
    final results = await Future.wait<Object>([
      _dbService.getTransactions(),
      _dbService.getBudgets(),
      _dbService.getCategories(),
      _dbService.getPaymentModes(),
      _dbService.getAllSettings(),
    ]);

    if (_isDisposed) return;

    _transactions = results[0] as List<BudgetTransaction>;
    _budgets = results[1] as List<Budget>;
    _categories = results[2] as List<Category>;
    _paymentModes = results[3] as List<PaymentMode>;
    _settings = results[4] as Map<String, String>;

    _reindex();
    _rebuildAggregates();

    final storedBudgetId = _settings['selected_budget_id'];
    if (storedBudgetId != null && _budgetById.containsKey(storedBudgetId)) {
      _selectedBudgetId = storedBudgetId;
    } else {
      _selectedBudgetId = activeBudget?.id;
      if (_selectedBudgetId == null && _budgets.isNotEmpty) {
        _selectedBudgetId = _budgets.first.id;
      }
    }

    _monthlySalary = double.tryParse(_settings['monthly_salary'] ?? '') ?? 0;
    _recomputeSelectedBudget();
    _applyFilter();

    _isLoading = false;
    if (!_isDisposed) notifyListeners();
  }

  void _reindex() {
    _categoryById
      ..clear()
      ..addEntries(_categories.map((item) => MapEntry(item.id, item)));
    _paymentModeById
      ..clear()
      ..addEntries(_paymentModes.map((item) => MapEntry(item.id, item)));
    _budgetById
      ..clear()
      ..addEntries(_budgets.map((item) => MapEntry(item.id, item)));

    _categoriesByType
      ..clear()
      ..['expense'] = _categories.where((item) => item.isExpense).toList()
      ..['income'] = _categories.where((item) => item.isIncome).toList();

    _searchIndex.clear();
    for (final transaction in _transactions) {
      final categoryName = _categoryById[transaction.categoryId]?.name ?? '';
      final paymentName =
          _paymentModeById[transaction.paymentModeId]?.name ?? '';
      _searchIndex[transaction.id] =
          '${transaction.title} ${transaction.note ?? ''} '
                  '$categoryName $paymentName'
              .toLowerCase();
    }
  }

  void _rebuildAggregates() {
    final now = DateTime.now();
    var income = 0.0;
    var expense = 0.0;
    _monthlyCategoryTotals.clear();

    for (final transaction in _transactions) {
      if (transaction.timestamp.year != now.year ||
          transaction.timestamp.month != now.month) {
        continue;
      }
      if (transaction.isIncome) {
        income += transaction.amount;
      } else if (transaction.isExpense) {
        expense += transaction.amount;
        final key = transaction.categoryId ?? 'uncategorized';
        _monthlyCategoryTotals[key] =
            (_monthlyCategoryTotals[key] ?? 0) + transaction.amount;
      }
    }

    _monthlyIncome = income;
    _monthlyExpense = expense;

    final entries = _monthlyCategoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _topCategorySpend = entries
        .take(5)
        .map(
          (entry) => CategorySpend(
            category: _categoryById[entry.key],
            amount: entry.value,
          ),
        )
        .toList(growable: false);

    _recentTransactions = _transactions.take(5).toList(growable: false);

    _spentByBudgetId.clear();
    _safeDailyByBudgetId.clear();
    for (final budget in _budgets) {
      _spentByBudgetId[budget.id] = budget.spentForCurrentPeriod(_transactions);
      _safeDailyByBudgetId[budget.id] = budget.safeToSpendDaily(_transactions);
    }
  }

  void _recomputeSelectedBudget() {
    final budget = selectedBudget;
    if (budget == null) {
      _selectedBudgetSpent = 0;
      _selectedBudgetSafeDaily = 0;
      return;
    }
    _selectedBudgetSpent = budget.spentForCurrentPeriod(_transactions);
    _selectedBudgetSafeDaily = budget.safeToSpendDaily(_transactions);
  }

  void _applyFilter() {
    final query = _logFilter.query.trim().toLowerCase();
    final hasQuery = query.isNotEmpty;
    final start = _logFilter.startDate == null
        ? null
        : AppDateUtils.startOfDay(_logFilter.startDate!);
    final end = _logFilter.endDate == null
        ? null
        : DateTime(
            _logFilter.endDate!.year,
            _logFilter.endDate!.month,
            _logFilter.endDate!.day,
            23,
            59,
            59,
            999,
          );

    if (!_logFilter.isActive) {
      _filteredTransactions = _transactions;
      return;
    }

    _filteredTransactions = _transactions
        .where((transaction) {
          if (_logFilter.type == 'expense' && !transaction.isExpense) {
            return false;
          }
          if (_logFilter.type == 'income' && !transaction.isIncome) {
            return false;
          }
          if (start != null && transaction.timestamp.isBefore(start)) {
            return false;
          }
          if (end != null && transaction.timestamp.isAfter(end)) {
            return false;
          }
          if (hasQuery &&
              !(_searchIndex[transaction.id]?.contains(query) ?? false)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _scheduleReload() {
    if (_isDisposed) return;
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(reload());
    });
  }

  void setLogFilter(LogFilter filter) {
    _logFilter = filter;
    _applyFilter();
    if (!_isDisposed) notifyListeners();
  }

  void clearLogFilter() {
    setLogFilter(const LogFilter());
  }

  Future<void> setSelectedBudget(String? id) async {
    if (_selectedBudgetId == id) return;
    _selectedBudgetId = id != null && _budgetById.containsKey(id) ? id : null;
    _recomputeSelectedBudget();
    if (!_isDisposed) notifyListeners();

    if (_selectedBudgetId == null) {
      await _dbService.deleteSetting('selected_budget_id', notify: false);
    } else {
      await _dbService.setSetting(
        'selected_budget_id',
        _selectedBudgetId!,
        notify: false,
      );
    }
  }

  Future<void> setMonthlySalary(double salary) async {
    _monthlySalary = salary < 0 ? 0 : salary;
    if (!_isDisposed) notifyListeners();
    await _dbService.setSetting(
      'monthly_salary',
      _monthlySalary.toString(),
      notify: false,
    );
  }

  Future<void> createBudget({
    required String name,
    required double limit,
    required String period,
    String categoryName = '',
    String description = '',
    double alertThreshold = 0.7,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final now = DateTime.now();
    final budget = Budget(
      id: IdUtils.generate('budget'),
      name: name,
      categoryName: categoryName,
      limit: limit,
      period: period,
      description: description,
      startDate: startDate,
      endDate: endDate,
      isActive: isActive,
      alertThreshold: alertThreshold,
      createdAt: now,
      updatedAt: now,
    );

    await _dbService.addBudget(budget, activate: isActive);
    await reload();
    if (isActive) {
      await setSelectedBudget(budget.id);
    }
  }

  Future<void> updateBudget(Budget budget) async {
    await _dbService.updateBudget(budget.copyWith(updatedAt: DateTime.now()));
    await reload();
    if (budget.isActive) {
      await setSelectedBudget(budget.id);
    } else if (_selectedBudgetId == budget.id) {
      await setSelectedBudget(activeBudget?.id);
    }
  }

  Future<void> deleteBudget(String id) async {
    await _dbService.deleteBudget(id);
    await reload();
    if (_selectedBudgetId == id) {
      await setSelectedBudget(activeBudget?.id);
    }
  }

  Future<Category> createCategory({
    required String name,
    required String type,
    int colorIndex = 0,
  }) async {
    final cleaned = _validateCategoryName(name);
    _validateCategoryType(type);
    final category = Category(
      id: IdUtils.generate('cat'),
      name: cleaned,
      type: type,
      colorIndex: colorIndex,
      createdAt: DateTime.now(),
    );
    await _dbService.addCategory(category);
    await reload();
    return category;
  }

  Future<void> updateCategory(Category category) async {
    final cleaned = _validateCategoryName(category.name, ignoreId: category.id);
    _validateCategoryType(category.type);
    await _dbService.updateCategory(category.copyWith(name: cleaned));
    await reload();
  }

  Future<void> deleteCategory(String id) async {
    await _dbService.deleteCategory(id);
    await reload();
  }

  Future<PaymentMode> createPaymentMode({
    required String name,
    required String type,
  }) async {
    final cleaned = _validatePaymentModeName(name);
    _validatePaymentModeType(type);
    final mode = PaymentMode(
      id: IdUtils.generate('pm'),
      name: cleaned,
      type: type,
      createdAt: DateTime.now(),
    );
    await _dbService.addPaymentMode(mode);
    await reload();
    return mode;
  }

  Future<void> updatePaymentMode(PaymentMode mode) async {
    final cleaned = _validatePaymentModeName(mode.name, ignoreId: mode.id);
    _validatePaymentModeType(mode.type);
    await _dbService.updatePaymentMode(mode.copyWith(name: cleaned));
    await reload();
  }

  Future<void> deletePaymentMode(String id) async {
    await _dbService.deletePaymentMode(id);
    await reload();
  }

  String _validateCategoryName(String name, {String? ignoreId}) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
    final duplicate = _categories.any(
      (item) =>
          item.id != ignoreId &&
          item.name.trim().toLowerCase() == cleaned.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError.value(name, 'name', 'Already exists');
    }
    return cleaned;
  }

  void _validateCategoryType(String type) {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError.value(type, 'type', 'Must be expense or income');
    }
  }

  String _validatePaymentModeName(String name, {String? ignoreId}) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty');
    }
    final duplicate = _paymentModes.any(
      (item) =>
          item.id != ignoreId &&
          item.name.trim().toLowerCase() == cleaned.toLowerCase(),
    );
    if (duplicate) {
      throw ArgumentError.value(name, 'name', 'Already exists');
    }
    return cleaned;
  }

  void _validatePaymentModeType(String type) {
    const types = {'cash', 'bank', 'card', 'wallet'};
    if (!types.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported payment mode');
    }
  }

  Future<void> saveTransaction(BudgetTransaction transaction) async {
    final exists = _transactions.any((item) => item.id == transaction.id);
    if (exists) {
      await _dbService.updateTransaction(transaction);
    } else {
      await _dbService.addTransaction(transaction);
    }
    await reload();
  }

  Future<void> saveTransactionWithDebts(
    BudgetTransaction transaction,
    List<DebtRecord> debtRecords,
  ) async {
    if (debtRecords.isEmpty) {
      await saveTransaction(transaction);
      return;
    }
    await _dbService.addTransactionWithDebtRecords(transaction, debtRecords);
    await reload();
  }

  Future<void> deleteTransaction(String id) async {
    await _dbService.deleteTransaction(id);
    await reload();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reloadTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}
