import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../models/budget.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? existingBudget;

  const AddBudgetScreen({super.key, this.existingBudget});

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

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    final budget = widget.existingBudget;
    _nameController = TextEditingController(text: budget?.name ?? '');
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

    setState(() => _isSaving = true);
    final controller = AppProvider.read<FinanceController>(context);
    final now = DateTime.now();
    final existing = widget.existingBudget;
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final custom = _period == 'custom';
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (existing == null) {
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
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Budget updated' : 'Budget created'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not save budget: $error');
    }
  }

  Future<void> _delete() async {
    final budget = widget.existingBudget;
    if (budget == null) return;

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

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing ? 'Edit budget' : 'New budget',
              subtitle: _isEditing
                  ? 'Adjust the cap, period or alert threshold.'
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
                    const VGapMd(),
                    TextFormField(
                      controller: _categoryController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Category tag',
                        hintText: 'Expenses, Needs, Wants...',
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
                      child: SwitchListTile(
                        value: _isActive,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                        },
                        title: const Text('Active budget'),
                        subtitle: const Text(
                          'Only one budget can be active at a time.',
                        ),
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
                  label: Text(_isEditing ? 'Save changes' : 'Create budget'),
                ),
              ),
            ),
          ],
        ),
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
