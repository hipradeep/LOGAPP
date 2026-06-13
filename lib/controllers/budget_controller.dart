import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/budget_item.dart';
import '../services/budget_service.dart';

class BudgetController extends ChangeNotifier {
  final BudgetService _budgetService = BudgetService();
  StreamSubscription<List<BudgetItem>>? _budgetSub;

  List<BudgetItem> _budgets = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedBudgetId;
  
  ValueChanged<BudgetItem?>? onBudgetChanged;

  List<BudgetItem> get budgets => _budgets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get selectedBudgetId => _selectedBudgetId;

  BudgetItem? get selectedBudget {
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
    notifyListeners();
    _subscribeToStream();
  }

  Future<void> refresh() async {
    _subscribeToStream();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _subscribeToStream() {
    _budgetSub?.cancel();
    _budgetSub = _budgetService.getBudgetsStream().listen(
      (budgetsData) {
        _budgets = budgetsData;
        _isLoading = false;
        _errorMessage = null;

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

        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> deleteExpense(BudgetItem budget, String expenseId) async {
    await _budgetService.deleteExpenseFromBudget(budget.id, expenseId);
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    super.dispose();
  }
}
