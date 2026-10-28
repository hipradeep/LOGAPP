import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
import '../widgets/app_action_buttons.dart';
import '../widgets/app_binary_toggle.dart';
import '../widgets/app_provider.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_title_input.dart';
import '../widgets/budget_selector_sheet.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/split_expense_sheet.dart';

class AddTransactionSheet extends StatefulWidget {
  final FinanceController controller;
  final BudgetTransaction? existingTransaction;
  final String? initialBudgetId;
  final String? initialTitle;
  final String? initialNote;
  final String? initialType;
  final double? initialAmount;
  final DateTime? initialTimestamp;
  final String? rawSmsBody;
  final bool isBottomSheet;
  final Future<void> Function(
    BudgetTransaction transaction,
    List<DebtRecord> debtRecords,
  )?
  onSave;

  const AddTransactionSheet({
    super.key,
    required this.controller,
    this.existingTransaction,
    this.initialBudgetId,
    this.initialTitle,
    this.initialNote,
    this.initialType,
    this.initialAmount,
    this.initialTimestamp,
    this.rawSmsBody,
    this.isBottomSheet = true,
    this.onSave,
  });

  /// Opens the transaction recording interface as a modal bottom sheet matching log_app design
  static Future<void> showModal(
    BuildContext context, {
    FinanceController? controller,
    BudgetTransaction? existingTransaction,
    String? initialBudgetId,
    String? initialTitle,
    String? initialNote,
    String? initialType,
    double? initialAmount,
    DateTime? initialTimestamp,
    String? rawSmsBody,
    Future<void> Function(
      BudgetTransaction transaction,
      List<DebtRecord> debtRecords,
    )?
    onSave,
  }) {
    final activeController =
        controller ?? AppProvider.read<FinanceController>(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        controller: activeController,
        existingTransaction: existingTransaction,
        initialBudgetId: initialBudgetId,
        initialTitle: initialTitle,
        initialNote: initialNote,
        initialType: initialType,
        initialAmount: initialAmount,
        initialTimestamp: initialTimestamp,
        rawSmsBody: rawSmsBody,
        isBottomSheet: true,
        onSave: onSave,
      ),
    );
  }

  /// Default navigation helper: opens the transaction sheet
  static Future<void> navigate(
    BuildContext context, {
    BudgetTransaction? existingTransaction,
    String? initialBudgetId,
    String? initialTitle,
    String? initialNote,
    String? initialType,
    double? initialAmount,
    DateTime? initialTimestamp,
    String? rawSmsBody,
    Future<void> Function(
      BudgetTransaction transaction,
      List<DebtRecord> debtRecords,
    )?
    onSave,
  }) {
    return showModal(
      context,
      existingTransaction: existingTransaction,
      initialBudgetId: initialBudgetId,
      initialTitle: initialTitle,
      initialNote: initialNote,
      initialType: initialType,
      initialAmount: initialAmount,
      initialTimestamp: initialTimestamp,
      rawSmsBody: rawSmsBody,
      onSave: onSave,
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();

  late bool _isExpense;
  late DateTime _timestamp;
  String? _categoryId;
  String? _paymentModeId;
  String? _budgetId;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _splitExpense = false;
  List<SplitShare> _splitShares = const [];
  List<PaymentMode> _sortedPaymentModes = const [];

  bool get _isEditing => widget.existingTransaction != null;
  ContactsController get _contactsController => getIt<ContactsController>();
  bool get _canSplit => !_isEditing && _isExpense;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    final controller = widget.controller;

    // Arrange payment modes by usage count descending (legacy behavior)
    final modeUsageCounts = <String, int>{};
    for (final tx in controller.transactions) {
      if (tx.paymentModeId != null && tx.paymentModeId!.isNotEmpty) {
        modeUsageCounts[tx.paymentModeId!] =
            (modeUsageCounts[tx.paymentModeId!] ?? 0) + 1;
      }
    }
    final sortedModes = List<PaymentMode>.from(controller.paymentModes)
      ..sort((a, b) {
        final countA = modeUsageCounts[a.id] ?? 0;
        final countB = modeUsageCounts[b.id] ?? 0;
        return countB.compareTo(countA);
      });
    _sortedPaymentModes = sortedModes;

    if (existing != null) {
      _isExpense = existing.type != 'income';
      _timestamp = existing.timestamp;
      _categoryId = existing.categoryId;
      _paymentModeId = existing.paymentModeId;
      _budgetId = existing.budgetId;
      _amountController.text = _formatAmount(existing.amount);
      _noteController.text = existing.note ?? '';
    } else {
      _isExpense = widget.initialType == 'expense';
      _timestamp = widget.initialTimestamp ?? DateTime.now();
      _budgetId = widget.initialBudgetId ?? controller.selectedBudgetId;
      final categories = controller.categoriesForType(
        _isExpense ? 'expense' : 'income',
      );
      _categoryId = categories.isEmpty ? null : categories.first.id;

      // Select default payment mode: prioritize 'PNB' if present, otherwise most frequently used
      final pnbMode = sortedModes
          .where((m) => m.name.toUpperCase().contains('PNB'))
          .firstOrNull;
      if (pnbMode != null) {
        _paymentModeId = pnbMode.id;
      } else {
        _paymentModeId = sortedModes.isEmpty ? null : sortedModes.first.id;
      }

      _noteController.text = widget.initialNote ?? '';
      final initialAmount = widget.initialAmount;
      if (initialAmount != null && initialAmount > 0) {
        _amountController.text = _formatAmount(initialAmount);
      }
    }

    final validCategories = controller.categoriesForType(
      _isExpense ? 'expense' : 'income',
    );
    if (!validCategories.any((item) => item.id == _categoryId)) {
      _categoryId = validCategories.isEmpty ? null : validCategories.first.id;
    }
    if (!controller.paymentModes.any((item) => item.id == _paymentModeId)) {
      final pnbMode = sortedModes
          .where((m) => m.name.toUpperCase().contains('PNB'))
          .firstOrNull;
      _paymentModeId =
          pnbMode?.id ?? (sortedModes.isEmpty ? null : sortedModes.first.id);
    }
    if (!controller.budgets.any((item) => item.id == _budgetId)) {
      _budgetId = null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    return amount % 1 == 0
        ? amount.abs().toStringAsFixed(0)
        : amount.abs().toStringAsFixed(2);
  }

  void _onExpenseTypeChanged(bool isExpense) {
    if (_isExpense == isExpense) return;
    final nextType = isExpense ? 'expense' : 'income';
    final categories = widget.controller.categoriesForType(nextType);
    final hasSelected = categories.any((item) => item.id == _categoryId);
    setState(() {
      _isExpense = isExpense;
      if (!hasSelected) {
        _categoryId = categories.isEmpty ? null : categories.first.id;
      }
      if (!isExpense) {
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

  void _onDateChanged(DateTime date) {
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        _timestamp.hour,
        _timestamp.minute,
      );
    });
  }

  Future<void> _save() async {
    final amount = _enteredAmount;
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount greater than zero.');
      return;
    }
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
    final note = _noteController.text.trim();
    final categoryName = category?.name ?? (_isExpense ? 'Expense' : 'Income');
    final title = note.isNotEmpty ? '$categoryName | $note' : categoryName;

    final transaction = BudgetTransaction(
      id: existing?.id ?? IdUtils.generate('txn'),
      amount: amount,
      type: _isExpense ? 'expense' : 'income',
      categoryId: _categoryId,
      paymentModeId: _paymentModeId,
      budgetId: _budgetId,
      title: title,
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
            _isEditing ? 'Transaction updated' : 'Transaction recorded',
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

  Widget _buildBudgetSelector() {
    final budgets = widget.controller.budgets;
    if (budgets.isEmpty) return const SizedBox.shrink();

    final selectedBudget = _budgetId != null && _budgetId!.isNotEmpty
        ? budgets.where((b) => b.id == _budgetId).firstOrNull
        : null;

    return Row(
      children: [
        Text(
          'Budget: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        InkWell(
          onTap: () {
            BudgetSelectorSheet.show(
              context,
              budgets: budgets,
              selectedBudgetId: _budgetId,
              onSelected: (id) {
                setState(() {
                  _budgetId = id;
                });
              },
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selectedBudget?.name ?? 'No Budget',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedBudget != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selectedBudget != null
                        ? AppTheme.textPrimaryColor(context)
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
                const HGapXs(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return AppTitleInput(
      controller: _amountController,
      focusNode: _amountFocus,
      label: 'Amount (₹)',
      hintText: 'e.g. 250.00',
      icon: Icons.currency_rupee_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      trailing: AppBinaryToggle(
        isFirstSelected: !_isExpense,
        onChanged: (isCredit) {
          _onExpenseTypeChanged(!isCredit);
        },
        firstLabel: 'Credit',
        secondLabel: 'Debit',
        firstActiveColor: AppTheme.successColor,
        secondActiveColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildNoteInput() {
    return AppTitleInput(
      controller: _noteController,
      focusNode: _noteFocus,
      label: 'Note',
      hintText: 'Add an optional note',
      icon: Icons.notes_rounded,
      maxLines: 2,
    );
  }

  Widget _buildCategorySelector(List<Category> categories) {
    if (categories.isEmpty) {
      return Text(
        'No categories available',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(categories.length, (index) {
          final cat = categories[index];
          final isSelected = cat.id == _categoryId;
          final tint = AppTheme.tintFor(context, cat.colorIndex);

          return Padding(
            padding: EdgeInsets.only(
              right: index < categories.length - 1 ? 12 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() => _categoryId = cat.id);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tint.$1
                          : AppTheme.surfaceVariant(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? tint.$2
                            : AppTheme.borderColor(context),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Icon(
                      CategoryVisuals.categoryIcon(cat.name),
                      size: 20,
                      color: isSelected
                          ? tint.$2
                          : AppTheme.textSecondaryColor(
                              context,
                            ).withValues(alpha: 0.7),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.textPrimaryColor(context)
                          : AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPaymentModeChips() {
    final paymentModes = _sortedPaymentModes.isNotEmpty
        ? _sortedPaymentModes
        : widget.controller.paymentModes;
    if (paymentModes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapSm(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: paymentModes.map((mode) {
              final isSelected = mode.id == _paymentModeId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(
                    CategoryVisuals.paymentModeIcon(mode.type),
                    size: 14,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor(context),
                  ),
                  label: Text(mode.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _paymentModeId = mode.id;
                      });
                    }
                  },
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  backgroundColor: AppTheme.surfaceVariant(context),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                    width: 1,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor(context),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.cardBorderRadius,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitSection() {
    if (!_canSplit) return const SizedBox.shrink();

    return Card(
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
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.iconBoxRadius),
              ),
              child: const Icon(Icons.call_split_rounded, size: 18),
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
            Divider(height: 1, color: AppTheme.borderColor(context)),
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
                          ? 'Your share appears after entering the amount.'
                          : _enteredAmount! - _allocatedSplitTotal >= 0
                          ? 'Your share: ${AppFormat.currency(_enteredAmount! - _allocatedSplitTotal)}'
                          : 'Over total by ${AppFormat.currency((_enteredAmount! - _allocatedSplitTotal).abs())}',
                      style: Theme.of(context).textTheme.bodySmall,
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
    );
  }

  Widget _buildActionButtons() {
    if (_isEditing) {
      return AppActionButtons(
        primaryLabel: 'Save Changes',
        onPrimaryPressed: _save,
        isPrimaryLoading: _isSaving,
        primaryColor: AppTheme.primaryColor,
        secondaryLabel: 'Delete',
        onSecondaryPressed: _delete,
        isSecondaryLoading: _isDeleting,
        secondaryColor: AppTheme.errorColor,
      );
    } else if (widget.rawSmsBody != null) {
      return AppActionButtons(
        primaryLabel: 'Verify & Record',
        onPrimaryPressed: _save,
        isPrimaryLoading: _isSaving,
        primaryColor: AppTheme.successColor,
        cancelLabel: 'Cancel',
        onCancelPressed: () => Navigator.of(context).pop(),
      );
    } else {
      return AppActionButtons(
        primaryLabel: _isExpense ? 'Log Expense' : 'Record Income',
        onPrimaryPressed: _save,
        isPrimaryLoading: _isSaving,
        primaryColor: _isExpense
            ? AppTheme.primaryColor
            : AppTheme.successColor,
      );
    }
  }

  Widget _buildSheetHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing
                  ? 'Edit Transaction'
                  : widget.rawSmsBody != null
                  ? 'Verify SMS Transaction'
                  : 'Record Transaction',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const VGapXs(),
            _buildBudgetSelector(),
          ],
        ),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFormItems(List<Category> categories) {
    return [
      if (!widget.isBottomSheet) ...[_buildBudgetSelector(), const VGapMd()],
      if (widget.rawSmsBody != null) ...[
        _RawBodyCard(rawText: widget.rawSmsBody!),
        const VGapMd(),
      ],
      Text(
        'Select Date',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textSecondaryColor(context),
        ),
      ),
      const VGapSm(),
      _DateSelector(initialDate: _timestamp, onDateChanged: _onDateChanged),
      const VGapLg(),
      Text(
        'What was it for?',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.textSecondaryColor(context),
        ),
      ),
      const VGapSm(),
      _buildCategorySelector(categories),
      const VGapLg(),
      _buildAmountInput(),
      const VGapLg(),
      _buildNoteInput(),
      const VGapLg(),
      _buildPaymentModeChips(),
      if (_canSplit) ...[const VGapLg(), _buildSplitSection()],
      const VGapXl(),
      _buildActionButtons(),
      const VGapLg(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.controller.categoriesForType(
      _isExpense ? 'expense' : 'income',
    );

    if (widget.isBottomSheet) {
      final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
      final screenHeight = MediaQuery.sizeOf(context).height;

      return Container(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const VGapSm(),
            const SheetHandleBar(),
            const VGapSm(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMd,
              ),
              child: _buildSheetHeader(),
            ),
            const VGapSm(),
            Divider(height: 1, color: AppTheme.borderColor(context)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingMd,
                ),
                children: _buildFormItems(categories),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: _isEditing ? 'Edit transaction' : 'Record Transaction',
              subtitle: _isEditing
                  ? 'Update details or remove entry.'
                  : 'Add transaction to your records',
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
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMd,
                  vertical: AppTheme.spacingSm,
                ),
                children: _buildFormItems(categories),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSelector extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  const _DateSelector({required this.initialDate, required this.onDateChanged});

  @override
  State<_DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<_DateSelector> {
  static final DateFormat _calendarFormatter = DateFormat('MMM d');
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void didUpdateWidget(covariant _DateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _selectedDate = widget.initialDate;
      });
    }
  }

  void _handleDateSelection(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateChanged(date);
  }

  Future<void> _pickCustomDate() async {
    final today = DateTime.now();
    final firstDate = today.subtract(const Duration(days: 365));
    final lastDate = today.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      _handleDateSelection(picked);
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final isToday = _isSameDay(_selectedDate, today);
    final isYesterday = _isSameDay(_selectedDate, yesterday);
    final isCustom = !isToday && !isYesterday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCalendarIconButton(isCustom),
          const HGapSm(),
          _buildDateChip('Today', isToday, () => _handleDateSelection(today)),
          const HGapSm(),
          _buildDateChip(
            'Yesterday',
            isYesterday,
            () => _handleDateSelection(yesterday),
          ),
          const HGapSm(),
          _TimePickerButton(
            selectedDate: _selectedDate,
            onTimeChanged: (newDateTime) {
              setState(() {
                _selectedDate = newDateTime;
              });
              widget.onDateChanged(newDateTime);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : AppTheme.textSecondaryColor(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarIconButton(bool isCustom) {
    final label = isCustom ? _calendarFormatter.format(_selectedDate) : null;

    return GestureDetector(
      onTap: _pickCustomDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCustom
              ? AppTheme.primaryColor
              : AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: isCustom
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 14,
              color: isCustom
                  ? Colors.white
                  : AppTheme.textSecondaryColor(context),
            ),
            if (label != null) ...[
              const HGapXs(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  static final DateFormat _timeFormatter = DateFormat('h:mm a');
  final DateTime selectedDate;
  final ValueChanged<DateTime> onTimeChanged;

  const _TimePickerButton({
    required this.selectedDate,
    required this.onTimeChanged,
  });

  Future<void> _pickTime(BuildContext context) async {
    final timeOfDay = TimeOfDay.fromDateTime(selectedDate);
    final picked = await showTimePicker(
      context: context,
      initialTime: timeOfDay,
    );

    if (picked != null) {
      final newDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        picked.hour,
        picked.minute,
      );
      onTimeChanged(newDateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _timeFormatter.format(selectedDate);

    return GestureDetector(
      onTap: () => _pickTime(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time_rounded,
              size: 14,
              color: AppTheme.primaryColor,
            ),
            const HGapXs(),
            Text(
              formattedTime,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawBodyCard extends StatelessWidget {
  final String rawText;

  const _RawBodyCard({required this.rawText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingSm + 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppTheme.warningColor,
                size: 14,
              ),
              const HGapXs(),
              Text(
                'Auto-Intercepted SMS Body',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const VGapXs(),
          Text(
            rawText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor(context),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Backwards compatibility typedef for existing imports and screens
typedef AddTransactionScreen = AddTransactionSheet;
