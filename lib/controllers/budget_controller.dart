import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';

class BudgetController extends ChangeNotifier {
  final BudgetService _budgetService = BudgetService();
  StreamSubscription<List<Budget>>? _budgetSub;
  StreamSubscription<List<Transaction>>? _transactionSub;

  List<Budget> _budgets = [];
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _budgetsLoaded = false;
  bool _transactionsLoaded = false;
  String? _errorMessage;
  String? _selectedBudgetId;
  
  ValueChanged<Budget?>? onBudgetChanged;

  List<Budget> get budgets => _budgets;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedBudgetId => _selectedBudgetId;

  Budget? get selectedBudget {
    if (_selectedBudgetId != null) {
      final matches = _budgets.where((b) => b.id == _selectedBudgetId);
      if (matches.isNotEmpty) return matches.first;
    }
    
    if (_budgets.isNotEmpty) {
      final activeBudgets = _budgets.where((b) => b.checked).toList();
      return activeBudgets.isNotEmpty ? activeBudgets.first : _budgets.first;
    }
    return null;
  }

  List<Transaction> get selectedBudgetTransactions {
    final budget = selectedBudget;
    if (budget == null) return [];
    return _transactions.where((t) => t.budgetId == budget.id).toList();
  }

  BudgetController({this.onBudgetChanged, String? initialSelectedBudgetId}) {
    _selectedBudgetId = initialSelectedBudgetId;
    _initStream();
  }

  void updateSelectedBudgetId(String? id) {
    _selectedBudgetId = id;
    onBudgetChanged?.call(selectedBudget);
    notifyListeners();
  }

  void setSelectedBudgetIdSilently(String? id) {
    _selectedBudgetId = id;
  }

  void _initStream() {
    _isLoading = true;
    _budgetsLoaded = false;
    _transactionsLoaded = false;
    notifyListeners();
    _subscribeToStreams();
  }

  Future<void> refresh() async {
    _subscribeToStreams();
    await Future.delayed(const Duration(milliseconds: 800));
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
  }

  void _checkAndUpdateSelectedBudget() {
    if (_selectedBudgetId != null) {
      final matches = _budgets.where((b) => b.id == _selectedBudgetId);
      if (matches.isEmpty && _budgets.isNotEmpty) {
        _selectedBudgetId = _budgets.first.id;
        onBudgetChanged?.call(selectedBudget);
      }
    } else if (_budgets.isNotEmpty) {
      final activeBudgets = _budgets.where((b) => b.checked).toList();
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

  Future<void> deleteTransaction(Budget budget, String transactionId) async {
    await _budgetService.deleteTransaction(transactionId);
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    _transactionSub?.cancel();
    super.dispose();
  }
}
