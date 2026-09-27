import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';

class BudgetController extends ChangeNotifier {
  final BudgetService _budgetService = BudgetService();
  StreamSubscription<List<Budget>>? _budgetSub;
  StreamSubscription<List<Transaction>>? _transactionSub;
  StreamSubscription<double>? _salarySub;

  List<Budget> _budgets = [];
  List<Transaction> _transactions = [];
  double _monthlySalary = 50000.0;
  bool _isLoading = true;
  bool _budgetsLoaded = false;
  bool _transactionsLoaded = false;
  String? _errorMessage;
  String? _selectedBudgetId;

  ValueChanged<Budget?>? onBudgetChanged;

  List<Budget> get budgets => _budgets;
  List<Transaction> get transactions => _transactions;
  double get monthlySalary => _monthlySalary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedBudgetId => _selectedBudgetId;

  Budget? get selectedBudget {
    if (_selectedBudgetId != null) {
      final matches = _budgets.where((b) => b.id == _selectedBudgetId);
      if (matches.isNotEmpty) return matches.first;
    }
    if (_budgets.isNotEmpty) {
      final activeNotEnded = _budgets.where((b) => b.isActive && !b.isPeriodOver).toList();
      if (activeNotEnded.isNotEmpty) return activeNotEnded.first;

      final activeBudgets = _budgets.where((b) => b.isActive).toList();
      return activeBudgets.isNotEmpty ? activeBudgets.first : _budgets.first;
    }
    return null;
  }

  List<Transaction> get selectedBudgetTransactions {
    final budget = selectedBudget;
    if (budget == null) return [];
    return _transactions.where((t) => t.budgetId == budget.id).toList();
  }

  double get totalSpentCurrentMonth {
    final now = DateTime.now();
    double total = 0.0;
    for (final t in _transactions) {
      if (t.isExpense && t.expenseDate.year == now.year && t.expenseDate.month == now.month) {
        total += t.amount;
      }
    }
    return total;
  }

  double get totalIncomeCurrentMonth {
    final now = DateTime.now();
    double total = 0.0;
    for (final t in _transactions) {
      if (t.isIncome && t.expenseDate.year == now.year && t.expenseDate.month == now.month) {
        total += t.amount;
      }
    }
    return total;
  }

  BudgetController({this.onBudgetChanged, String? initialSelectedBudgetId}) {
    _selectedBudgetId = initialSelectedBudgetId;
    _initStreams();
  }

  void updateSelectedBudgetId(String? id) {
    _selectedBudgetId = id;
    onBudgetChanged?.call(selectedBudget);
    notifyListeners();
  }

  void setSelectedBudgetIdSilently(String? id) {
    _selectedBudgetId = id;
  }

  void _initStreams() {
    _isLoading = true;
    _budgetsLoaded = false;
    _transactionsLoaded = false;
    notifyListeners();
    _subscribeToStreams();
  }

  Future<void> refresh() async {
    _subscribeToStreams();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _subscribeToStreams() {
    _budgetSub?.cancel();
    _budgetSub = _budgetService.getBudgetsStream().listen(
      (budgetsData) {
        _budgets = budgetsData;
        _budgetsLoaded = true;
        _errorMessage = null;

        _checkAndUpdateSelectedBudget();
        _checkLoadingState();
        notifyListeners();
      },
      onError: _handleError,
    );

    _transactionSub?.cancel();
    _transactionSub = _budgetService.getTransactionsStream().listen(
      (transactionsData) {
        _transactions = transactionsData;
        _transactionsLoaded = true;
        _errorMessage = null;

        _checkLoadingState();
        notifyListeners();
      },
      onError: _handleError,
    );

    _salarySub?.cancel();
    _salarySub = _budgetService.getSalaryStream().listen(
      (salary) {
        _monthlySalary = salary;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  void _checkAndUpdateSelectedBudget() {
    if (_selectedBudgetId != null) {
      final matches = _budgets.where((b) => b.id == _selectedBudgetId);
      if (matches.isEmpty && _budgets.isNotEmpty) {
        _selectedBudgetId = _budgets.first.id;
        onBudgetChanged?.call(selectedBudget);
      }
    } else if (_budgets.isNotEmpty) {
      final activeBudgets = _budgets.where((b) => b.isActive).toList();
      _selectedBudgetId = activeBudgets.isNotEmpty ? activeBudgets.first.id : _budgets.first.id;
      onBudgetChanged?.call(selectedBudget);
    }
  }

  void _checkLoadingState() {
    if (_budgetsLoaded && _transactionsLoaded) {
      _isLoading = false;
    }
  }

  void _handleError(Object error) {
    _isLoading = false;
    _errorMessage = error.toString();
    notifyListeners();
  }

  Future<void> updateSalary(double salary) async {
    await _budgetService.updateSalary(salary);
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _budgetService.deleteTransaction(transactionId);
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    _transactionSub?.cancel();
    _salarySub?.cancel();
    super.dispose();
  }
}
