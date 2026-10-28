import 'package:budget_log/models/budget_tag_mapping.dart';
import 'package:budget_log/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 1, 15, 10, 30);

  test('round-trips a budget tag mapping through its map form', () {
    final mapping = BudgetTagMapping(
      id: 'budget_1_exp',
      budgetId: 'budget_1',
      type: BudgetTagMapping.expenseType,
      tagIds: const ['cat_food', BudgetTagMapping.miscExpenseTag],
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = BudgetTagMapping.fromMap(mapping.toMap());

    expect(restored.id, mapping.id);
    expect(restored.budgetId, mapping.budgetId);
    expect(restored.type, BudgetTagMapping.expenseType);
    expect(restored.tagIds, mapping.tagIds);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, createdAt);
  });

  test('exposes type and misc tag helpers', () {
    final expense = BudgetTagMapping(
      id: 'budget_1_exp',
      budgetId: 'budget_1',
      type: BudgetTagMapping.expenseType,
      tagIds: const [BudgetTagMapping.miscExpenseTag],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final income = BudgetTagMapping(
      id: 'budget_1_income',
      budgetId: 'budget_1',
      type: BudgetTagMapping.incomeType,
      tagIds: const [BudgetTagMapping.miscIncomeTag],
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    expect(expense.isExpense, isTrue);
    expect(expense.isIncome, isFalse);
    expect(expense.includesMiscExpense, isTrue);
    expect(expense.includesMiscIncome, isFalse);
    expect(income.isIncome, isTrue);
    expect(income.includesMiscIncome, isTrue);
    expect(income.includesMiscExpense, isFalse);
  });

  test('supports shared categories for expense and income', () {
    final shared = Category(
      id: 'cat_shared',
      name: 'Shared',
      type: 'both',
      createdAt: createdAt,
    );

    expect(shared.isExpense, isTrue);
    expect(shared.isIncome, isTrue);
    expect(shared.isBoth, isTrue);
  });
}
