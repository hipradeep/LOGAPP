import 'package:budget_log/models/budget.dart';
import 'package:budget_log/models/budget_tag_mapping.dart';
import 'package:budget_log/models/budget_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();

  Budget createBudget({double limit = 1000}) => Budget(
    id: 'budget_1',
    name: 'Monthly',
    categoryName: '',
    limit: limit,
    createdAt: now,
    updatedAt: now,
  );

  BudgetTransaction createTransaction({
    required String id,
    required String type,
    required double amount,
    String? categoryId,
    String? budgetId,
  }) => BudgetTransaction(
    id: id,
    amount: amount,
    type: type,
    categoryId: categoryId,
    budgetId: budgetId,
    title: id,
    timestamp: now,
    createdAt: now,
  );

  test('matches expenses by tag and misc tag', () {
    final budget = createBudget();
    final transactions = [
      createTransaction(
        id: 'food',
        type: 'expense',
        amount: 200,
        categoryId: 'cat_food',
      ),
      createTransaction(
        id: 'transport',
        type: 'expense',
        amount: 100,
        categoryId: 'cat_transport',
      ),
      createTransaction(id: 'misc', type: 'expense', amount: 50),
      createTransaction(
        id: 'salary',
        type: 'income',
        amount: 5000,
        categoryId: 'cat_salary',
      ),
    ];

    expect(
      budget.spentForCurrentPeriod(
        transactions,
        expenseTagIds: const ['cat_food', BudgetTagMapping.miscExpenseTag],
      ),
      250,
    );
    expect(
      budget.spentForCurrentPeriod(
        transactions,
        expenseTagIds: const ['cat_food'],
      ),
      200,
    );
  });

  test('matches income by tag and misc tag', () {
    final budget = createBudget();
    final transactions = [
      createTransaction(
        id: 'salary',
        type: 'income',
        amount: 5000,
        categoryId: 'cat_salary',
      ),
      createTransaction(
        id: 'other_income',
        type: 'income',
        amount: 700,
        categoryId: 'cat_other_income',
      ),
      createTransaction(id: 'misc', type: 'income', amount: 300),
      createTransaction(
        id: 'food',
        type: 'expense',
        amount: 200,
        categoryId: 'cat_food',
      ),
    ];

    expect(
      budget.incomeForCurrentPeriod(
        transactions,
        incomeTagIds: const ['cat_salary', BudgetTagMapping.miscIncomeTag],
      ),
      5300,
    );
    expect(
      budget.incomeForCurrentPeriod(
        transactions,
        incomeTagIds: const ['cat_salary'],
      ),
      5000,
    );
  });

  test('falls back to the linked budget id when tags are omitted', () {
    final budget = createBudget();
    final transactions = [
      createTransaction(
        id: 'linked_expense',
        type: 'expense',
        amount: 300,
        budgetId: budget.id,
      ),
      createTransaction(
        id: 'linked_income',
        type: 'income',
        amount: 900,
        budgetId: budget.id,
      ),
      createTransaction(
        id: 'other_expense',
        type: 'expense',
        amount: 100,
        budgetId: 'other_budget',
      ),
    ];

    expect(budget.spentForCurrentPeriod(transactions), 300);
    expect(budget.incomeForCurrentPeriod(transactions), 900);
  });

  test('matches transactions for both expense and income tags', () {
    final budget = createBudget();
    final expenseTags = {'cat_food', BudgetTagMapping.miscExpenseTag};
    final incomeTags = {'cat_salary', BudgetTagMapping.miscIncomeTag};

    expect(
      budget.matchesTransaction(
        createTransaction(
          id: 'food',
          type: 'expense',
          amount: 200,
          categoryId: 'cat_food',
        ),
        expenseTags: expenseTags,
        incomeTags: incomeTags,
      ),
      isTrue,
    );
    expect(
      budget.matchesTransaction(
        createTransaction(id: 'misc_expense', type: 'expense', amount: 50),
        expenseTags: expenseTags,
        incomeTags: incomeTags,
      ),
      isTrue,
    );
    expect(
      budget.matchesTransaction(
        createTransaction(
          id: 'salary',
          type: 'income',
          amount: 5000,
          categoryId: 'cat_salary',
        ),
        expenseTags: expenseTags,
        incomeTags: incomeTags,
      ),
      isTrue,
    );
    expect(
      budget.matchesTransaction(
        createTransaction(
          id: 'rent',
          type: 'expense',
          amount: 900,
          categoryId: 'cat_rent',
        ),
        expenseTags: expenseTags,
        incomeTags: incomeTags,
      ),
      isFalse,
    );
    expect(
      budget.matchesTransaction(
        createTransaction(
          id: 'linked_expense',
          type: 'expense',
          amount: 300,
          budgetId: budget.id,
        ),
      ),
      isTrue,
    );
    expect(
      budget.matchesTransaction(
        createTransaction(
          id: 'linked_income',
          type: 'income',
          amount: 900,
          budgetId: budget.id,
        ),
      ),
      isTrue,
    );
  });

  test('derives over-budget and safe-to-spend from tag matches', () {
    final budget = createBudget(limit: 200);
    final transactions = [
      createTransaction(
        id: 'food',
        type: 'expense',
        amount: 250,
        categoryId: 'cat_food',
      ),
    ];

    expect(
      budget.isOverBudget(transactions, expenseTagIds: const ['cat_food']),
      isTrue,
    );
    expect(
      budget.safeToSpendDaily(transactions, expenseTagIds: const ['cat_food']),
      0,
    );
  });
}
