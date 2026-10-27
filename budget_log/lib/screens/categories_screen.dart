import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sheet_action_widgets.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppProvider.watch<FinanceController>(context);
    final expenses = controller.categories
        .where((item) => item.isExpense)
        .toList();
    final income = controller.categories
        .where((item) => item.isIncome)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'Categories',
              subtitle: 'Expense and income labels for your transactions.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingSm,
                  AppTheme.spacingMd,
                  96,
                ),
                children: [
                  if (expenses.isEmpty && income.isEmpty)
                    AppEmptyState(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      description:
                          'Add an expense or income category to organise your log.',
                      actionLabel: 'Add category',
                      onActionPressed: () => CategoryFormSheet.show(
                        context,
                        controller: controller,
                      ),
                    )
                  else ...[
                    if (expenses.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'EXPENSE',
                        count: expenses.length,
                        color: AppTheme.expenseColor,
                      ),
                      const VGapSm(),
                      _CategoryCard(
                        categories: expenses,
                        controller: controller,
                      ),
                    ],
                    if (expenses.isNotEmpty && income.isNotEmpty)
                      const VGapLg(),
                    if (income.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'INCOME',
                        count: income.length,
                        color: AppTheme.incomeColor,
                      ),
                      const VGapSm(),
                      _CategoryCard(categories: income, controller: controller),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppFab(
        onPressed: () =>
            CategoryFormSheet.show(context, controller: controller),
        icon: Icons.add_rounded,
        label: 'Category',
        tooltip: 'Add category',
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final List<Category> categories;
  final FinanceController controller;

  const _CategoryCard({required this.categories, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            _CategoryRow(
              category: categories[index],
              onTap: () => CategoryFormSheet.show(
                context,
                controller: controller,
                existing: categories[index],
              ),
            ),
            if (index < categories.length - 1)
              Divider(
                height: 1,
                indent: 68,
                color: AppTheme.borderColor(context),
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryRow({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, category.colorIndex);

    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: tint.$1,
          borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
        ),
        alignment: Alignment.center,
        child: Icon(
          CategoryVisuals.categoryIcon(category.name),
          color: tint.$2,
          size: 19,
        ),
      ),
      title: Text(category.name),
      subtitle: Text(category.isExpense ? 'Expense' : 'Income'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
        const Spacer(),
        Text('$count', style: textTheme.labelSmall),
      ],
    );
  }
}

class CategoryFormSheet extends StatefulWidget {
  final FinanceController controller;
  final Category? existing;

  const CategoryFormSheet({super.key, required this.controller, this.existing});

  static Future<void> show(
    BuildContext context, {
    required FinanceController controller,
    Category? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: CategoryFormSheet(controller: controller, existing: existing),
      ),
    );
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _nameController;
  late String _type;
  late int _colorIndex;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _type = existing?.type ?? 'expense';
    _colorIndex = existing?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final existing = widget.existing;
      if (existing == null) {
        await widget.controller.createCategory(
          name: _nameController.text,
          type: _type,
          colorIndex: _colorIndex,
        );
      } else {
        await widget.controller.updateCategory(
          existing.copyWith(
            name: _nameController.text,
            type: _type,
            colorIndex: _colorIndex,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = error is ArgumentError
            ? error.message.toString()
            : 'Could not save this category.';
      });
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _isSaving) return;

    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'category',
      message:
          'Transactions using this category will become uncategorized. '
          'This action cannot be undone.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await widget.controller.deleteCategory(existing.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Could not delete this category.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        SheetHeader(
          title: _isEditing ? 'Edit category' : 'New category',
          subtitle: 'Choose a name, type and colour.',
        ),
        const VGapMd(),
        TextField(
          controller: _nameController,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'Food',
          ),
        ),
        if (_error != null) ...[
          const VGapXs(),
          Text(
            _error!,
            style: textTheme.labelSmall?.copyWith(color: AppTheme.errorColor),
          ),
        ],
        const VGapMd(),
        Text('Type', style: textTheme.labelLarge),
        const VGapXs(),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Expense')),
              ButtonSegment(value: 'income', label: Text('Income')),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _type = selection.first);
            },
          ),
        ),
        const VGapMd(),
        Text('Colour', style: textTheme.labelLarge),
        const VGapSm(),
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            for (var index = 0; index < 8; index++)
              _ColorSwatch(
                index: index,
                selected: index == _colorIndex,
                onTap: () => setState(() => _colorIndex = index),
              ),
          ],
        ),
        const VGapLg(),
        SheetSubmitButton(
          text: _isEditing ? 'Save changes' : 'Add category',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
        if (_isEditing) ...[
          const VGapSm(),
          SheetDestructiveButton(title: 'Delete category', onTap: _delete),
        ],
        const VGapXs(),
        const SheetCancelButton(),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, index);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: tint.$1,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? tint.$2 : Colors.transparent,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Icon(Icons.check_rounded, color: tint.$2, size: 18)
            : null,
      ),
    );
  }
}
