import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/preferences_service.dart';
import 'app_spacers.dart';
import 'app_action_buttons.dart';

class AddTransactionSheet extends StatefulWidget {
  final String? budgetId;
  final Transaction? existingTransaction;
  final List<Budget>? budgets;

  const AddTransactionSheet({
    super.key,
    this.budgetId,
    this.existingTransaction,
    this.budgets,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final BudgetService _budgetService = BudgetService();
  final PreferencesService _prefs = PreferencesService();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();

  late String _selectedBudgetId;
  late DateTime _selectedDate;
  String _selectedType = 'expense'; // 'expense', 'income', 'transfer'
  String _selectedTag = 'Grocery';
  String _selectedPaymentMethod = 'Cash';

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _paymentModes = [];
  List<Budget> _availableBudgets = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.budgetId ?? '';
    _selectedDate = DateTime.now();

    final tx = widget.existingTransaction;
    if (tx != null) {
      _amountController.text = tx.amount > 0 ? tx.amount.toStringAsFixed(0) : '';
      _descController.text = tx.description;
      _merchantController.text = tx.merchant ?? '';
      _selectedDate = tx.expenseDate;
      _selectedType = tx.type;
      _selectedTag = tx.tag;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedBudgetId = tx.budgetId;
    }

    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await _prefs.getExpenseCategories();
    final pModes = await _prefs.getPaymentModes();
    List<Budget> bList = widget.budgets ?? [];
    if (bList.isEmpty) {
      try {
        final streamData = await _budgetService.getBudgetsStream().first;
        bList = streamData;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _categories = cats;
        _paymentModes = pModes;
        _availableBudgets = bList;
        if (_selectedBudgetId.isEmpty && bList.isNotEmpty) {
          final active = bList.where((b) => b.isActive).toList();
          _selectedBudgetId = active.isNotEmpty ? active.first.id : bList.first.id;
        }
        if (_categories.isNotEmpty && !_categories.any((c) => c['label'] == _selectedTag)) {
          _selectedTag = _categories.first['label'] as String;
        }
        if (_paymentModes.isNotEmpty && !_paymentModes.any((p) => p['label'] == _selectedPaymentMethod)) {
          _selectedPaymentMethod = _paymentModes.first['label'] as String;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _handleSelectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surface(context),
              onSurface: AppTheme.textPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount in ₹')),
      );
      return;
    }

    if (_selectedBudgetId.isEmpty && _availableBudgets.isNotEmpty) {
      _selectedBudgetId = _availableBudgets.first.id;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.existingTransaction != null) {
        final updated = Transaction(
          id: widget.existingTransaction!.id,
          budgetId: _selectedBudgetId,
          tag: _selectedTag,
          description: _descController.text.trim(),
          merchant: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
          type: _selectedType,
          amount: amount,
          entryDate: widget.existingTransaction!.entryDate,
          expenseDate: _selectedDate,
          isValidated: true,
          paymentMethod: _selectedPaymentMethod,
        );
        await _budgetService.updateTransaction(updated);
      } else {
        await _budgetService.addTransaction(
          _selectedBudgetId,
          _selectedTag,
          _descController.text.trim(),
          amount,
          merchant: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
          type: _selectedType,
          timestamp: _selectedDate,
          paymentMethod: _selectedPaymentMethod,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  void _deleteTransaction() async {
    if (widget.existingTransaction == null) return;
    setState(() => _isSaving = true);
    await _budgetService.deleteTransaction(widget.existingTransaction!.id);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const VGapSm(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.existingTransaction != null ? 'Edit Entry' : 'Log Transaction',
                          style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (widget.existingTransaction != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
                            onPressed: _deleteTransaction,
                          ),
                      ],
                    ),
                    const VGapMd(),
                    // Type selector (Expense / Income / Transfer)
                    Row(
                      children: [
                        _buildTypeChip('Expense', 'expense', Icons.arrow_downward_rounded, AppTheme.errorColor),
                        const HGapSm(),
                        _buildTypeChip('Income', 'income', Icons.arrow_upward_rounded, AppTheme.successColor),
                        const HGapSm(),
                        _buildTypeChip('Transfer', 'transfer', Icons.swap_horiz_rounded, AppTheme.secondaryColor),
                      ],
                    ),
                    const VGapLg(),
                    // Amount Input in ₹ INR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background(context),
                        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '₹',
                            style: AppTheme.headingLarge.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const HGapMd(),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              autofocus: widget.existingTransaction == null,
                              style: AppTheme.headingLarge.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: AppTheme.headingLarge.copyWith(
                                  color: AppTheme.hintColor(context),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VGapLg(),
                    // Merchant / Store field
                    Text(
                      'Merchant / Store (Optional)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    TextField(
                      controller: _merchantController,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Swiggy, Amazon, DMart',
                        prefixIcon: Icon(Icons.storefront_rounded, size: 20, color: AppTheme.textSecondaryColor(context)),
                      ),
                    ),
                    const VGapMd(),
                    // Description / Note
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    TextField(
                      controller: _descController,
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                      decoration: InputDecoration(
                        hintText: 'What was this for?',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20, color: AppTheme.textSecondaryColor(context)),
                      ),
                    ),
                    const VGapLg(),
                    // Category Selection
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                    const VGapSm(),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const HGapSm(),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final label = cat['label'] as String;
                          final isSelected = _selectedTag == label;
                          final color = Color(cat['color'] as int? ?? 0xFF8B5CF6);

                          return ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedTag = label),
                            selectedColor: color.withValues(alpha: 0.25),
                            backgroundColor: AppTheme.background(context),
                            side: BorderSide(
                              color: isSelected ? color : AppTheme.borderColor(context),
                              width: 1.2,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected ? color : AppTheme.textSecondaryColor(context),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    const VGapLg(),
                    // Payment Method & Date Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                              const VGapXs(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface(context),
                                  borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                                  border: Border.all(color: AppTheme.borderColor(context)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedPaymentMethod,
                                    isExpanded: true,
                                    dropdownColor: AppTheme.surface(context),
                                    items: _paymentModes.map((m) {
                                      final label = m['label'] as String;
                                      return DropdownMenuItem(
                                        value: label,
                                        child: Text(
                                          label,
                                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedPaymentMethod = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const HGapMd(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                              ),
                              const VGapXs(),
                              InkWell(
                                onTap: _handleSelectDate,
                                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface(context),
                                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                                    border: Border.all(color: AppTheme.borderColor(context)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(_selectedDate),
                                        style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                                      ),
                                      Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryLight),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const VGapXl(),
                    AppActionButtons(
                      primaryLabel: widget.existingTransaction != null ? 'Update Entry' : 'Log ₹ $amountLabel',
                      onPrimaryPressed: _saveTransaction,
                      cancelLabel: 'Cancel',
                      onCancelPressed: () => Navigator.pop(context),
                      isPrimaryLoading: _isSaving,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String get amountLabel {
    final amt = _amountController.text.trim();
    return amt.isNotEmpty ? amt : '';
  }

  Widget _buildTypeChip(String label, String type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderColor(context),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : AppTheme.textSecondaryColor(context)),
              const HGapXs(),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AppTheme.textSecondaryColor(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
