import 'package:flutter/material.dart';

import '../controllers/contacts_controller.dart';
import '../controllers/finance_controller.dart';
import '../models/budget_transaction.dart';
import '../models/category.dart';
import '../models/debt_record.dart';
import '../models/payment_mode.dart';
import '../models/split_share.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../utils/category_visuals.dart';
import '../utils/format_utils.dart';
import '../utils/id_utils.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/split_expense_sheet.dart';

class AddTransactionScreen extends StatefulWidget {
  final FinanceController controller;
  final BudgetTransaction? existingTransaction;
  final String? initialBudgetId;
  final String? initialTitle;
  final String? initialNote;
  final String? initialType;
  final double? initialAmount;
  final DateTime? initialTimestamp;
  final Future<void> Function(
    BudgetTransaction transaction,
    List<DebtRecord> debtRecords,
  )?
  onSave;

  const AddTransactionScreen({
    super.key,
    required this.controller,
    this.existingTransaction,
    this.initialBudgetId,
    this.initialTitle,
    this.initialNote,
    this.initialType,
    this.initialAmount,
    this.initialTimestamp,
    this.onSave,
  });

  static Future<void> navigate(
    BuildContext context, {
    BudgetTransaction? existingTransaction,
    String? initialBudgetId,
    String? initialTitle,
    String? initialNote,
    String? initialType,
    double? initialAmount,
    DateTime? initialTimestamp,
    Future<void> Function(
      BudgetTransaction transaction,
      List<DebtRecord> debtRecords,
    )?
    onSave,
  }) {
    final controller = AppProvider.read<FinanceController>(context);
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          controller: controller,
          existingTransaction: existingTransaction,
          initialBudgetId: initialBudgetId,
          initialTitle: initialTitle,
          initialNote: initialNote,
          initialType: initialType,
          initialAmount: initialAmount,
          initialTimestamp: initialTimestamp,
          onSave: onSave,
        ),
      ),
    );
  }

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  late String _type;
  late DateTime _timestamp;
  String? _categoryId;
  String? _paymentModeId;
  String? _budgetId;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _splitExpense = false;
  List<SplitShare> _splitShares = const [];

  bool get _isEditing => widget.existingTransaction != null;
  ContactsController get _contactsController => getIt<ContactsController>();
  bool get _canSplit => !_isEditing && _type == 'expense';

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    final controller = widget.controller;

    if (existing != null) {
      _type = existing.type == 'income' ? 'income' : 'expense';
      _timestamp = existing.timestamp;
      _categoryId = existing.categoryId;
      _paymentModeId = existing.paymentModeId;
      _budgetId = existing.budgetId;
      _amountController.text = _formatAmount(existing.amount);
      _titleController.text = existing.title;
      _noteController.text = existing.note ?? '';
    } else {
      _type = widget.initialType == 'income' ? 'income' : 'expense';
      _timestamp = widget.initialTimestamp ?? DateTime.now();
      _budgetId = widget.initialBudgetId ?? controller.selectedBudgetId;
      final categories = controller.categoriesForType(_type);
      _categoryId = categories.isEmpty ? null : categories.first.id;
      _paymentModeId = controller.paymentModes.isEmpty
          ? null
          : controller.paymentModes.first.id;
      _titleController.text = widget.initialTitle ?? '';
      _noteController.text = widget.initialNote ?? '';
      final initialAmount = widget.initialAmount;
      if (initialAmount != null && initialAmount > 0) {
        _amountController.text = _formatAmount(initialAmount);
      }
    }

    final validCategories = controller.categoriesForType(_type);
    if (!validCategories.any((item) => item.id == _categoryId)) {
      _categoryId = validCategories.isEmpty ? null : validCategories.first.id;
    }
    if (!controller.paymentModes.any((item) => item.id == _paymentModeId)) {
      _paymentModeId = controller.paymentModes.isEmpty
          ? null
          : controller.paymentModes.first.id;
    }
    if (!controller.budgets.any((item) => item.id == _budgetId)) {
      _budgetId = null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return amount % 1 == 0
        ? amount.abs().toStringAsFixed(0)
        : amount.abs().toStringAsFixed(2);
  }

  void _setType(String type) {
    if (_type == type) return;
    final categories = widget.controller.categoriesForType(type);
    final hasSelected = categories.any((item) => item.id == _categoryId);
    setState(() {
      _type = type;
      if (!hasSelected) {
        _categoryId = categories.isEmpty ? null : categories.first.id;
      }
      if (type != 'expense') {
        _splitExpense = false;
        _splitShares = const [];
      }
    });
  }

  double? get _enteredAmount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', ''));

  double get _allocatedSplitTotal =>
      _splitShares.fold<double>(0, (sum, share) => sum + share.amount);

  Future<void> _editSplit() async {
    final amount = _enteredAmount;
    if (amount == null || amount <= 0) {
      _showMessage('Enter the expense amount first.');
      return;
    }
    final contacts = _contactsController.contacts;
    if (contacts.isEmpty) {
      _showMessage('Add contacts in Udar before splitting an expense.');
      return;
    }
    final shares = await SplitExpenseSheet.show(
      context,
      total: amount,
      contacts: contacts,
      initialShares: _splitShares,
    );
    if (shares == null || shares.isEmpty || !mounted) return;
    setState(() {
      _splitExpense = true;
      _splitShares = shares;
    });
  }

  Future<void> _toggleSplit(bool value) async {
    if (!value) {
      setState(() {
        _splitExpense = false;
        _splitShares = const [];
      });
      return;
    }
    await _editSplit();
  }

  String _splitSummary() {
    final count = _splitShares.length;
    return '$count contact${count == 1 ? '' : 's'} · '
        '${AppFormat.currency(_allocatedSplitTotal)} split';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _timestamp = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _timestamp.hour,
        _timestamp.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    if (amount == null || amount <= 0) return;
    if (_categoryId == null) {
      _showMessage('Select a category first.');
      return;
    }
    if (_paymentModeId == null) {
      _showMessage('Select a payment mode first.');
      return;
    }
    if (_canSplit && _splitExpense) {
      if (_splitShares.isEmpty) {
        _showMessage('Choose at least one contact for the split.');
        return;
      }
      final allocated = _allocatedSplitTotal;
      if (allocated <= 0) {
        _showMessage('Allocate at least some amount to your contacts.');
        return;
      }
      if (allocated > amount + 0.01) {
        _showMessage('Split allocation cannot exceed the expense amount.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final category = widget.controller.categoryById(_categoryId);
    final now = DateTime.now();
    final existing = widget.existingTransaction;
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();

    final transaction = BudgetTransaction(
      id: existing?.id ?? IdUtils.generate('txn'),
      amount: amount,
      type: _type,
      categoryId: _categoryId,
      paymentModeId: _paymentModeId,
      budgetId: _budgetId,
      title: title.isEmpty ? category?.name ?? 'Transaction' : title,
      note: note.isEmpty ? null : note,
      timestamp: _timestamp,
      createdAt: existing?.createdAt ?? now,
    );

    final debts = <DebtRecord>[];
    if (_canSplit && _splitExpense) {
      for (final share in _splitShares) {
        debts.add(
          DebtRecord(
            id: IdUtils.generate('debt'),
            contactId: share.contactId,
            transactionId: transaction.id,
            direction: 'give',
            amount: share.amount,
            notes: 'Split expense: ${transaction.title}',
            createdAt: now,
          ),
        );
      }
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final onSave = widget.onSave;
      if (onSave != null) {
        await onSave(transaction, debts);
      } else {
        await widget.controller.saveTransactionWithDebts(transaction, debts);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Transaction updated' : 'Transaction added',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Could not save transaction: $error');
    }
  }

  Future<void> _delete() async {
    final existing = widget.existingTransaction;
    if (existing == null) return;

    final confirmed = await ConfirmationDialog.showDelete(
      context,
      entityName: 'transaction',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.controller.deleteTransaction(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      _showMessage('Could not delete transaction: $error');
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
    final categories = widget.controller.categoriesForType(_type);
    final paymentModes = widget.controller.paymentModes;
    final budgets = widget.controller.budgets;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing ? 'Edit transaction' : 'Add transaction',
              subtitle: _isEditing
                  ? 'Update the details or remove this entry.'
                  : 'Log an expense or income entry.',
              actions: [
                if (_isEditing)
                  IconButton(
                    onPressed: _isDeleting ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppTheme.errorColor,
                    tooltip: 'Delete transaction',
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
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'expense',
                          label: Text('Expense'),
                          icon: Icon(Icons.arrow_upward_rounded),
                        ),
                        ButtonSegment(
                          value: 'income',
                          label: Text('Income'),
                          icon: Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                      selected: {_type},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        _setType(selection.first);
                      },
                    ),
                    const VGapLg(),
                    TextFormField(
                      controller: _amountController,
                      autofocus: !_isEditing,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      style: textTheme.displaySmall,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '₹ ',
                        hintText: '0',
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(
                          (value ?? '').trim().replaceAll(',', ''),
                        );
                        if (parsed == null || parsed <= 0) {
                          return 'Enter an amount greater than zero';
                        }
                        return null;
                      },
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Lunch, fuel, salary...',
                      ),
                    ),
                    const VGapMd(),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        hintText: 'Optional details',
                      ),
                    ),
                    const VGapLg(),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text('Date', style: textTheme.bodyMedium),
                        trailing: Text(
                          AppFormat.mediumDate(_timestamp),
                          style: textTheme.titleMedium,
                        ),
                        onTap: _pickDate,
                      ),
                    ),
                    const VGapLg(),
                    _FieldLabel(
                      label: 'Category',
                      value: widget.controller.categoryById(_categoryId)?.name,
                    ),
                    const VGapSm(),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: categories.map((category) {
                        return _CategoryChip(
                          category: category,
                          selected: category.id == _categoryId,
                          onSelected: () {
                            setState(() => _categoryId = category.id);
                          },
                        );
                      }).toList(),
                    ),
                    const VGapLg(),
                    _FieldLabel(
                      label: 'Payment mode',
                      value: widget.controller
                          .paymentModeById(_paymentModeId)
                          ?.name,
                    ),
                    const VGapSm(),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingSm,
                      children: paymentModes.map((mode) {
                        return _PaymentModeChip(
                          mode: mode,
                          selected: mode.id == _paymentModeId,
                          onSelected: () {
                            setState(() => _paymentModeId = mode.id);
                          },
                        );
                      }).toList(),
                    ),
                    const VGapLg(),
                    DropdownButtonFormField<String>(
                      initialValue: _budgetId ?? '',
                      decoration: const InputDecoration(labelText: 'Budget'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No budget'),
                        ),
                        ...budgets.map(
                          (budget) => DropdownMenuItem(
                            value: budget.id,
                            child: Text(budget.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _budgetId = value == null || value.isEmpty
                              ? null
                              : value;
                        });
                      },
                    ),
                    if (_canSplit) ...[
                      const VGapLg(),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: _splitExpense,
                              onChanged: _isSaving ? null : _toggleSplit,
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.iconBoxRadius,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.call_split_rounded,
                                  size: 18,
                                ),
                              ),
                              title: const Text('Split this expense'),
                              subtitle: Text(
                                _contactsController.contacts.isEmpty
                                    ? 'Add contacts in Udar first.'
                                    : _splitExpense
                                    ? _splitSummary()
                                    : 'Track who owes you for this expense.',
                              ),
                            ),
                            if (_splitExpense) ...[
                              Divider(
                                height: 1,
                                color: AppTheme.borderColor(context),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacingMd,
                                  AppTheme.spacingSm,
                                  AppTheme.spacingSm,
                                  AppTheme.spacingSm,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _enteredAmount == null
                                            ? 'Your share appears after '
                                                  'entering the amount.'
                                            : _enteredAmount! -
                                                      _allocatedSplitTotal >=
                                                  0
                                            ? 'Your share: '
                                                  '${AppFormat.currency(_enteredAmount! - _allocatedSplitTotal)}'
                                            : 'Over total by '
                                                  '${AppFormat.currency((_enteredAmount! - _allocatedSplitTotal).abs())}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isSaving ? null : _editSplit,
                                      child: const Text('Edit split'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
                  label: Text(_isEditing ? 'Save changes' : 'Add transaction'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String? value;

  const _FieldLabel({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(label, style: textTheme.titleMedium),
        if (value != null) ...[
          const Spacer(),
          Text(value!, style: textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, category.colorIndex);
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        CategoryVisuals.categoryIcon(category.name),
        size: 16,
        color: selected ? AppTheme.primaryColor : tint.$2,
      ),
      label: Text(category.name),
      onSelected: (_) => onSelected(),
    );
  }
}

class _PaymentModeChip extends StatelessWidget {
  final PaymentMode mode;
  final bool selected;
  final VoidCallback onSelected;

  const _PaymentModeChip({
    required this.mode,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        CategoryVisuals.paymentModeIcon(mode.type),
        size: 16,
        color: selected
            ? AppTheme.primaryColor
            : AppTheme.textSecondaryColor(context),
      ),
      label: Text(mode.name),
      onSelected: (_) => onSelected(),
    );
  }
}
