import 'package:budget_log/models/budget_tag_mapping.dart';
import 'package:budget_log/models/category.dart';
import 'package:budget_log/theme/app_theme.dart';
import 'package:budget_log/widgets/budget_tag_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  final categories = [
    Category(
      id: 'food',
      name: 'Food',
      type: 'expense',
      colorIndex: 0,
      createdAt: now,
    ),
    Category(
      id: 'salary',
      name: 'Salary',
      type: 'income',
      colorIndex: 1,
      createdAt: now,
    ),
    Category(
      id: 'shared',
      name: 'Joint',
      type: 'both',
      colorIndex: 2,
      createdAt: now,
    ),
  ];

  testWidgets('shows counts, shared categories, and misc tags', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _Harness(categories: categories),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expense (3/3)'), findsOneWidget);
    expect(find.text('Income (3/3)'), findsOneWidget);
    expect(find.text('Joint'), findsOneWidget);
    expect(find.text('Misc expense'), findsOneWidget);

    await tester.tap(find.text('Income (3/3)'));
    await tester.pumpAndSettle();

    expect(find.text('Joint'), findsOneWidget);
    expect(find.text('Misc income'), findsOneWidget);
    expect(find.text('Misc expense'), findsNothing);
  });

  testWidgets('toggles all tags and warns when both tabs are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _Harness(categories: categories),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deselect all'));
    await tester.pumpAndSettle();
    expect(find.text('Expense (0/3)'), findsOneWidget);

    await tester.tap(find.text('Income (3/3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deselect all'));
    await tester.pumpAndSettle();

    expect(find.text('Income (0/3)'), findsOneWidget);
    expect(
      find.text(
        'Select at least one tag so this budget can track transactions.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    expect(find.text('Income (3/3)'), findsOneWidget);
    expect(
      find.text(
        'Select at least one tag so this budget can track transactions.',
      ),
      findsNothing,
    );
  });
}

class _Harness extends StatefulWidget {
  final List<Category> categories;

  const _Harness({required this.categories});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String _activeTab = BudgetTagMapping.expenseType;
  final Set<String> _expenseTags = {
    'food',
    'shared',
    BudgetTagMapping.miscExpenseTag,
  };
  final Set<String> _incomeTags = {
    'salary',
    'shared',
    BudgetTagMapping.miscIncomeTag,
  };

  @override
  Widget build(BuildContext context) {
    return BudgetTagSelector(
      categories: widget.categories,
      selectedExpenseTags: _expenseTags,
      selectedIncomeTags: _incomeTags,
      activeTab: _activeTab,
      onTabChanged: (tab) => setState(() => _activeTab = tab),
      onExpenseTagsChanged: (tags) {
        setState(() {
          _expenseTags
            ..clear()
            ..addAll(tags);
        });
      },
      onIncomeTagsChanged: (tags) {
        setState(() {
          _incomeTags
            ..clear()
            ..addAll(tags);
        });
      },
    );
  }
}
