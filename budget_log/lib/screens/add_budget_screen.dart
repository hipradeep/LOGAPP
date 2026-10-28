import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../models/budget_tag_mapping.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/budget_tag_selector.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? existingBudget;
  final bool isCopy;

  const AddBudgetScreen({super.key, this.existingBudget, this.isCopy = false})
    : assert(!isCopy || existingBudget != null);

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _limitController;
  late final TextEditingController _descriptionController;
  late String _period;
  late bool _isActive;
  late double _alertThreshold;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  bool _tagsInitialized = false;
  String _activeTagTab = BudgetTagMapping.expenseType;
  final Set<String> _selectedExpenseTags = {};
  final Set<String> _selectedIncomeTags = {};

  bool get _isEditing => widget.existingBudget != null && !widget.isCopy;

  @override
  void initState() {
    super.initState();
    final budget = widget.existingBudget;
    _nameController = TextEditingController(
      text: widget.isCopy ? '${budget!.name} (Copy)' : budget?.name ?? '',
    );
    _categoryController = TextEditingController(
      text: budget?.categoryName ?? '',
    );
    _limitController = TextEditingController(
      text: budget == null ? '' : budget.limit.toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(
      text: budget?.description ?? '',
    );
    final storedPeriod = budget?.period ?? 'monthly';
    _period =
        const {'daily', 'weekly', 'monthly', 'custom'}.contains(storedPeriod)
        ? storedPeriod
        : 'monthly';
    _isActive = budget?.isActive ?? true;
    _alertThreshold = budget?.alertThreshold ?? 0.7;
    _startDate = budget?.startDate;
    _endDate = budget?.endDate;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tagsInitialized) return;
    _tagsInitialized = true;

    final controller = AppProvider.read<FinanceController>(context);
    final budget = widget.existingBudget;
    final expenseOptions = controller.budgetTagOptions(expense: true);
    final incomeOptions = controller.budgetTagOptions(expense: false);
    final expenseTags = budget == null
        ? expenseOptions
        : controller.expenseTagsForBudget(budget.id);
    final incomeTags = budget == null
        ? incomeOptions
        : controller.incomeTagsForBudget(budget.id);

    _selectedExpenseTags
      ..clear()
      ..addAll(expenseTags.where(expenseOptions.contains));
    _selectedIncomeTags
      ..clear()
      ..addAll(incomeTags.where(incomeOptions.contains));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _limitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _setPeriod(String? period) {
    if (period == null) return;
    setState(() {
      _period = period;
      if (period == 'custom') {
        final now = DateTime.now();
        _startDate ??= now;
        _endDate ??= now.add(const Duration(days: 30));
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? _startDate ?? now
          : _endDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked.add(const Duration(days: 30));
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(
      _limitController.text.trim().replaceAll(',', ''),
    );
    if (limit == null || limit <= 0) return;

    if (_period == 'custom') {
      if (_startDate == null || _endDate == null) {
        _showMessage('Choose a start and end date.');
        return;
      }
      if (_endDate!.isBefore(_startDate!)) {
        _showMessage('End date must be after the start date.');
        return;
      }
    }

    final controller = AppProvider.read<FinanceController>(context);
    final existing = widget.existingBudget;
    if (_selectedExpenseTags.isEmpty && _selectedIncomeTags.isEmpty) {
      _showMessage('Select at least one tag for this budget.');
      return;
    }
    if (_activeBudgetLimitReached(controller)) {
      _showMessage(
        'Maximum ${DatabaseService.maxActiveBudgets} budgets can be active '
        'at a time. Deactivate one first.',
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final custom = _period == 'custom';
    final messenger = ScaffoldMessenger.of(context);
    final copySource = widget.isCopy ? existing : null;

    try {
      if (existing == null || widget.isCopy) {
        await controller.createBudget(
          name: name,
          limit: limit,
          period: _period,
          categoryName: category,
          description: description,
          alertThreshold: _alertThreshold,
          startDate: custom ? _startDate : null,
          endDate: custom ? _endDate : null,
          isActive: _isActive,
          repeatDays: copySource?.repeatDays,
          scheduledTime: copySource?.scheduledTime,
          repeat: copySource?.repeat,
          salary: copySource?.salary,
          rule: copySource?.rule,
          allocations: copySource?.allocations,
          expenseTags: _selectedExpenseTags.toList(),
          incomeTags: _selectedIncomeTags.toList(),
        );
      } else {
        await controller.updateBudget(
          Budget(
            id: existing.id,
            name: name,
            categoryName: category,
            limit: limit,
            period: _period,
            description: description,
            repeatDays: existing.repeatDays,
            scheduledTime: existing.scheduledTime,
            startDate: custom ? _startDate : null,
            endDate: custom ? _endDate : null,
            repeat: existing.repeat,
            isActive: _isActive,
            alertThreshold: _alertThreshold,
            salary: existing.salary,
            rule: existing.rule,
            allocations: existing.allocations,
            createdAt: existing.createdAt,
            updatedAt: now,
          ),
          expenseTags: _selectedExpenseTags.toList(),
          incomeTags: _selectedIncomeTags.toList(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isCopy
                ? 'Budget copied'
                : _isEditing
                ? 'Budget updated'
                : 'Budget created',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not save budget: $error');
    }
  }

  bool _activeBudgetLimitReached(FinanceController controller) {
    if (!_isActive) return false;
    final existing = widget.existingBudget;
    if (!widget.isCopy && existing != null && existing.isActive) return false;
    return controller.activeBudgets.length >= DatabaseService.maxActiveBudgets;
  }

  Future<void> _delete() async {
    final budget = widget.existingBudget;
    if (!_isEditing || budget == null) return;

    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'budget',
      message:
          'Transactions stay in your log, but they will no longer be linked '
          'to this budget.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppProvider.read<FinanceController>(
        context,
      ).deleteBudget(budget.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Budget deleted')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not delete budget: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final controller = AppProvider.watch<FinanceController>(context);
    final activeLimitReached = _activeBudgetLimitReached(controller);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing
                  ? 'Edit budget'
                  : widget.isCopy
                  ? 'Copy budget'
                  : 'New budget',
              subtitle: _isEditing
                  ? 'Adjust the cap, period or alert threshold.'
                  : widget.isCopy
                  ? 'Create a new budget with the same tags and settings.'
                  : 'Set a spending cap and track it automatically.',
              actions: [
                if (_isEditing)
                  IconButton(
                    onPressed: _isSaving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    tooltip: 'Delete budget',
                  ),
              ],
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacingMd,
                    AppTheme.spacingSm,
                    AppTheme.spacingMd,
                    AppTheme.spacingXl,
                  ),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Budget name',
                        hintText: 'Monthly living, groceries, travel...',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter a budget name';
                        }
                        return null;
                      },
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _limitController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Spending cap',
                        prefixText: '₹ ',
                        hintText: '25000',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(
                          (value ?? '').trim().replaceAll(',', ''),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a cap greater than zero';
                        }
                        return null;
                      },
                    ),
                    const VGapMd(),
                    DropdownButtonFormField<String>(
                      initialValue: _period,
                      decoration: const InputDecoration(labelText: 'Period'),
                      items: const [
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('Custom dates'),
                        ),
                      ],
                      onChanged: _setPeriod,
                    ),
                    if (_period == 'custom') ...[
                      const VGapMd(),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Starts',
                              date: _startDate,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const HGapSm(),
                          Expanded(
                            child: _DateField(
                              label: 'Ends',
                              date: _endDate,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const VGapLg(),
                    BudgetTagSelector(
                      categories: controller.categories,
                      selectedExpenseTags: _selectedExpenseTags,
                      selectedIncomeTags: _selectedIncomeTags,
                      activeTab: _activeTagTab,
                      onTabChanged: (tab) {
                        setState(() => _activeTagTab = tab);
                      },
                      onExpenseTagsChanged: (tags) {
                        setState(() {
                          _selectedExpenseTags
                            ..clear()
                            ..addAll(tags);
                        });
                      },
                      onIncomeTagsChanged: (tags) {
                        setState(() {
                          _selectedIncomeTags
                            ..clear()
                            ..addAll(tags);
                        });
                      },
                    ),
                    const VGapLg(),
                    TextFormField(
                      controller: _categoryController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Budget label',
                        hintText: 'Optional short label, e.g. Needs',
                      ),
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional note about this budget',
                      ),
                    ),
                    const VGapLg(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Alert threshold',
                            style: textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${(_alertThreshold * 100).round()}%',
                          style: textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Slider(
                      value: _alertThreshold,
                      min: 0.5,
                      max: 1,
                      divisions: 10,
                      label: '${(_alertThreshold * 100).round()}%',
                      onChanged: (value) {
                        setState(() => _alertThreshold = value);
                      },
                    ),
                    Text(
                      'The budget is highlighted once spending reaches this '
                      'share of the cap.',
                      style: textTheme.bodySmall,
                    ),
                    const VGapMd(),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _isActive,
                            onChanged: (value) {
                              setState(() => _isActive = value);
                            },
                            title: const Text('Active budget'),
                            subtitle: const Text(
                              'Up to ${DatabaseService.maxActiveBudgets} '
                              'budgets can be active at once.',
                            ),
                          ),
                          if (activeLimitReached)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppTheme.spacingMd,
                                0,
                                AppTheme.spacingMd,
                                AppTheme.spacingMd,
                              ),
                              child: _InlineWarning(
                                message:
                                    'Maximum '
                                    '${DatabaseService.maxActiveBudgets} '
                                    'budgets can be active at a time. '
                                    'Deactivate one first.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd,
                AppTheme.spacingSm,
                AppTheme.spacingMd,
                AppTheme.spacingSm,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppTheme.buttonHeight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isEditing
                        ? 'Save changes'
                        : widget.isCopy
                        ? 'Create copy'
                        : 'Create budget',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String message;

  const _InlineWarning({required this.message});

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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(label, style: textTheme.bodySmall),
        subtitle: Text(
          date == null ? 'Choose date' : AppFormat.mediumDate(date!),
          style: textTheme.titleMedium,
        ),
        trailing: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    );
  }
}
