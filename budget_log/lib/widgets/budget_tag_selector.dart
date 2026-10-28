import 'package:flutter/material.dart';

import '../models/budget_tag_mapping.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import 'app_spacers.dart';

class BudgetTagSelector extends StatelessWidget {
  final List<Category> categories;
  final Set<String> selectedExpenseTags;
  final Set<String> selectedIncomeTags;
  final String activeTab;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<Set<String>> onExpenseTagsChanged;
  final ValueChanged<Set<String>> onIncomeTagsChanged;

  const BudgetTagSelector({
    super.key,
    required this.categories,
    required this.selectedExpenseTags,
    required this.selectedIncomeTags,
    required this.activeTab,
    required this.onTabChanged,
    required this.onExpenseTagsChanged,
    required this.onIncomeTagsChanged,
  });

  bool get _isExpenseTab => activeTab == BudgetTagMapping.expenseType;

  List<Category> get _visibleCategories => categories
      .where(
        (category) => _isExpenseTab ? category.isExpense : category.isIncome,
      )
      .toList(growable: false);

  String get _miscTag => _isExpenseTab
      ? BudgetTagMapping.miscExpenseTag
      : BudgetTagMapping.miscIncomeTag;

  Set<String> get _selectedTags =>
      _isExpenseTab ? selectedExpenseTags : selectedIncomeTags;

  List<String> get _availableTags => [
    ..._visibleCategories.map((category) => category.id),
    _miscTag,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final allSelected = _availableTags.every(_selectedTags.contains);
    final warningVisible =
        selectedExpenseTags.isEmpty && selectedIncomeTags.isEmpty;
    final totalExpense = _totalFor(expense: true);
    final totalIncome = _totalFor(expense: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tracked tags', style: textTheme.titleMedium),
        const VGapXs(),
        Text(
          'Select which expense and income tags count toward this budget.',
          style: textTheme.bodySmall,
        ),
        const VGapMd(),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: BudgetTagMapping.expenseType,
                label: Text(
                  'Expense (${selectedExpenseTags.length}/$totalExpense)',
                ),
              ),
              ButtonSegment(
                value: BudgetTagMapping.incomeType,
                label: Text(
                  'Income (${selectedIncomeTags.length}/$totalIncome)',
                ),
              ),
            ],
            selected: {activeTab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onTabChanged(selection.first),
          ),
        ),
        const VGapMd(),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_isExpenseTab ? 'EXPENSE' : 'INCOME'} TAGS '
                '(${_selectedTags.length} of ${_availableTags.length} selected)',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _setAllSelected(!allSelected),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(allSelected ? 'Deselect all' : 'Select all'),
            ),
          ],
        ),
        const VGapSm(),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            for (final category in _visibleCategories)
              _categoryChip(context, category),
            _miscChip(context),
          ],
        ),
        if (warningVisible) ...[
          const VGapMd(),
          const _BudgetTagWarning(
            message:
                'Select at least one tag so this budget can track transactions.',
          ),
        ],
      ],
    );
  }

  int _totalFor({required bool expense}) {
    return categories
            .where(
              (category) => expense ? category.isExpense : category.isIncome,
            )
            .length +
        1;
  }

  FilterChip _categoryChip(BuildContext context, Category category) {
    final selected = _selectedTags.contains(category.id);
    final tint = AppTheme.tintFor(context, category.colorIndex);

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) => _toggleTag(category.id, value),
      avatar: Icon(
        CategoryVisuals.categoryIcon(category.name),
        size: 16,
        color: selected ? tint.$2 : AppTheme.textSecondaryColor(context),
      ),
      label: Text(category.name),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? tint.$2 : AppTheme.textPrimaryColor(context),
      ),
      selectedColor: tint.$1,
      side: BorderSide(
        color: selected ? tint.$3 : AppTheme.borderColor(context),
        width: selected ? 1.2 : 0.8,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  FilterChip _miscChip(BuildContext context) {
    final selected = _selectedTags.contains(_miscTag);
    final tint = (
      AppTheme.pastelOrange(context),
      AppTheme.pastelOrangeText(context),
      AppTheme.pastelOrangeBorder(context),
    );
    final label = _isExpenseTab ? 'Misc expense' : 'Misc income';

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) => _toggleTag(_miscTag, value),
      avatar: Icon(
        Icons.label_off_outlined,
        size: 16,
        color: selected ? tint.$2 : AppTheme.textSecondaryColor(context),
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? tint.$2 : AppTheme.textPrimaryColor(context),
      ),
      selectedColor: tint.$1,
      side: BorderSide(
        color: selected ? tint.$3 : AppTheme.borderColor(context),
        width: selected ? 1.2 : 0.8,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _toggleTag(String tagId, bool selected) {
    final next = {..._selectedTags};
    if (selected) {
      next.add(tagId);
    } else {
      next.remove(tagId);
    }
    _emit(next);
  }

  void _setAllSelected(bool selected) {
    _emit(selected ? _availableTags.toSet() : <String>{});
  }

  void _emit(Set<String> tags) {
    if (_isExpenseTab) {
      onExpenseTagsChanged(tags);
    } else {
      onIncomeTagsChanged(tags);
    }
  }
}

class _BudgetTagWarning extends StatelessWidget {
  final String message;

  const _BudgetTagWarning({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppTheme.warningColor,
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
