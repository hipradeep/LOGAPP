import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/cache_service.dart';
import 'app_spacers.dart';
import 'app_title_input.dart';
import 'app_title_dropdown.dart';
import 'app_binary_toggle.dart';
import 'app_action_buttons.dart';

/// Tag definition for expense categories
class _ExpenseTag {
  final String label;
  final IconData icon;
  final Color color;

  const _ExpenseTag(this.label, this.icon, this.color);
}

IconData getIconDataByName(String name) {
  switch (name) {
    case 'flight_rounded': return Icons.flight_rounded;
    case 'fastfood_rounded': return Icons.fastfood_rounded;
    case 'local_cafe_rounded': return Icons.local_cafe_rounded;
    case 'local_grocery_store_rounded': return Icons.local_grocery_store_rounded;
    case 'storefront_rounded': return Icons.storefront_rounded;
    case 'shopping_bag_rounded': return Icons.shopping_bag_rounded;
    case 'receipt_long_rounded': return Icons.receipt_long_rounded;
    case 'dinner_dining_rounded': return Icons.dinner_dining_rounded;
    case 'local_gas_station_rounded': return Icons.local_gas_station_rounded;
    case 'medical_services_rounded': return Icons.medical_services_rounded;
    case 'school_rounded': return Icons.school_rounded;
    case 'sports_esports_rounded': return Icons.sports_esports_rounded;
    case 'pets_rounded': return Icons.pets_rounded;
    case 'home_rounded': return Icons.home_rounded;
    case 'directions_car_rounded': return Icons.directions_car_rounded;
    default: return Icons.more_horiz_rounded;
  }
}

class AddTransactionSheet extends StatefulWidget {
  final String budgetId;
  final String categoryName;
  final Future<void> Function(String tag, String description, double amount, DateTime date) onAddTransaction;
  final Transaction? existingTransaction;
  final List<Budget>? budgets;

  const AddTransactionSheet({
    super.key,
    required this.budgetId,
    required this.categoryName,
    required this.onAddTransaction,
    this.existingTransaction,
    this.budgets,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final BudgetService _budgetService = BudgetService();
  final CacheService _cacheService = CacheService();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _descFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  late String _selectedBudgetId;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isExpense = true;
  int? _selectedTagIndex;

  List<_ExpenseTag> _expenseTags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _selectedBudgetId = widget.budgetId;
    
    final tx = widget.existingTransaction;
    if (tx != null) {
      _descController.text = tx.description;
      if (tx.amount.abs() % 1 == 0) {
        _amountController.text = tx.amount.abs().toStringAsFixed(0);
      } else {
        _amountController.text = tx.amount.abs().toStringAsFixed(2);
      }
      _selectedDate = tx.expenseDate;
      _isExpense = tx.amount >= 0;
    } else {
      _selectedDate = DateTime.now();
      _isExpense = true;
    }

    _loadExpenseTags();
  }

  Future<void> _loadExpenseTags() async {
    final list = await _cacheService.getExpenseCategories();
    // Sort by count descending
    list.sort((a, b) => (b['count'] as int? ?? 0).compareTo(a['count'] as int? ?? 0));
    
    final tags = list.map((item) {
      return _ExpenseTag(
        item['label'] as String,
        getIconDataByName(item['icon'] as String),
        Color(item['color'] as int),
      );
    }).toList();

    if (mounted) {
      setState(() {
        _expenseTags = tags;
        _isLoadingTags = false;
        _initializeSelectedTag();
      });
    }
  }

  void _initializeSelectedTag() {
    final tx = widget.existingTransaction;
    if (tx != null && _expenseTags.isNotEmpty) {
      final tagLower = tx.tag.toLowerCase().trim();
      for (int i = 0; i < _expenseTags.length; i++) {
        if (_expenseTags[i].label.toLowerCase() == tagLower) {
          _selectedTagIndex = i;
          break;
        }
      }
      _selectedTagIndex ??= _expenseTags.indexWhere((t) => t.label.toLowerCase() == 'other');
      if (_selectedTagIndex == -1) _selectedTagIndex = 0;
    } else {
      _selectedTagIndex = 0;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _descFocus.dispose();
    _amountFocus.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final customDesc = _descController.text.trim();

    if (_selectedTagIndex == null || _expenseTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expense tag'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final tag = _expenseTags[_selectedTagIndex!];
    final finalAmount = _isExpense ? amount : -amount;

    setState(() => _isSaving = true);
    try {
      if (widget.existingTransaction != null) {
        final updatedExpense = Transaction(
          id: widget.existingTransaction!.id,
          budgetId: _selectedBudgetId,
          tag: tag.label,
          description: customDesc,
          amount: finalAmount,
          entryDate: widget.existingTransaction!.entryDate,
          expenseDate: _selectedDate,
          isValidated: true,
          rawBody: widget.existingTransaction!.rawBody,
        );

        if (_selectedBudgetId != widget.budgetId) {
          await _budgetService.moveTransaction(
            destBudgetId: _selectedBudgetId,
            transaction: updatedExpense,
          );
        } else {
          await _budgetService.updateTransaction(updatedExpense);
        }

        await _cacheService.incrementCategoryCount(tag.label);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction validated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        await widget.onAddTransaction(tag.label, customDesc, finalAmount, _selectedDate);
        
        await _cacheService.incrementCategoryCount(tag.label);

        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.existingTransaction == null) return;
    setState(() => _isDeleting = true);
    try {
      await _budgetService.deleteTransaction(widget.existingTransaction!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted/ignored'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _onDateChanged(DateTime date) {
    _selectedDate = date;
  }

  void _onTagSelected(int index) {
    _selectedTagIndex = index;
  }

  void _onExpenseTypeChanged(bool isExpense) {
    _isExpense = isExpense;
  }

  void _handleBudgetChanged(String? val) {
    if (val != null) {
      setState(() {
        _selectedBudgetId = val;
      });
    }
  }

  void _handleClose() => Navigator.pop(context);

  String? _validateDescription(String? val) => null;

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingTransaction != null
                    ? (widget.existingTransaction!.isValidated
                        ? 'Edit Transaction'
                        : 'Validate Auto-Transaction')
                    : 'Log Expense',
                style: AppTheme.headingMedium.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              if (widget.existingTransaction != null && widget.budgets != null)
                AppTitleDropdown<String>(
                  value: _selectedBudgetId,
                  items: widget.budgets!.map((b) {
                    return DropdownMenuItem<String>(
                      value: b.id,
                      child: Text(
                        b.category,
                        style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: _handleBudgetChanged,
                )
              else
                Text(
                  'Category: ${widget.categoryName}',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondaryColor(context)),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.subtleFillColor(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context), size: 20),
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
      icon: Icons.attach_money_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      trailing: widget.existingTransaction != null
          ? AppBinaryToggle(
              value: _isExpense,
              onChanged: _onExpenseTypeChanged,
              trueLabel: 'Debit',
              falseLabel: 'Credit',
            )
          : null,
    );
  }

  Widget _buildDescriptionInput() {
    return AppTitleInput(
      controller: _descController,
      focusNode: _descFocus,
      label: 'Description',
      hintText: 'Add a note (optional)',
      icon: Icons.description_outlined,
      validator: _validateDescription,
    );
  }

  Widget _buildActionButtons() {
    if (widget.existingTransaction != null) {
      return AppActionButtons(
        primaryLabel: widget.existingTransaction!.isValidated
            ? 'Save Changes'
            : 'Validate Transaction',
        onPrimaryPressed: _submit,
        isPrimaryLoading: _isSaving,
        primaryColor: AppTheme.successColor,
        secondaryLabel: 'Ignore',
        onSecondaryPressed: _delete,
        isSecondaryLoading: _isDeleting,
        height: 50,
      );
    } else {
      return AppActionButtons(
        primaryLabel: 'Log Expense',
        onPrimaryPressed: _submit,
        isPrimaryLoading: _isSaving,
        primaryColor: AppTheme.primaryColor,
        height: 50,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.background(context).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppTheme.borderColor(context), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Column(
                  children: [
                    const VGapMd(),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const VGapLg(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        children: [
                          _buildHeader(),
                          if (widget.existingTransaction?.rawBody != null) ...[
                            const VGapMd(),
                            _RawBodyCard(rawText: widget.existingTransaction!.rawBody!),
                          ],
                          const VGapLg(),
                          Text(
                            'Select Date',
                            style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const VGapMd(),
                          _DateSelector(
                            initialDate: _selectedDate,
                            onDateChanged: _onDateChanged,
                          ),
                          const VGapLg(),
                          Text(
                            'What was it for?',
                            style: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const VGapMd(),
                          if (_isLoadingTags)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: AppTheme.primaryColor),
                              ),
                            )
                          else
                            _TagSelector(
                              tags: _expenseTags,
                              initialSelectedIndex: _selectedTagIndex,
                              onTagSelected: _onTagSelected,
                            ),
                          const VGapLg(),
                          _buildAmountInput(),
                          const VGapLg(),
                          _buildDescriptionInput(),
                          const VGapLg(),
                          _buildActionButtons(),
                          const VGapXl(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: AppTheme.warningColor, size: 14),
              SizedBox(width: 6),
              Text(
                'Auto-Intercepted Notification Body',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warningColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rawText,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor(context), height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _TagSelector extends StatefulWidget {
  final List<_ExpenseTag> tags;
  final int? initialSelectedIndex;
  final ValueChanged<int> onTagSelected;

  const _TagSelector({
    required this.tags,
    required this.initialSelectedIndex,
    required this.onTagSelected,
  });

  @override
  State<_TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<_TagSelector> {
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSelectedIndex;
  }

  @override
  void didUpdateWidget(covariant _TagSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSelectedIndex != oldWidget.initialSelectedIndex) {
      setState(() {
        _selectedIndex = widget.initialSelectedIndex;
      });
    }
  }

  void _handleTagTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onTagSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(widget.tags.length, (index) {
          final tag = widget.tags[index];
          final isSelected = _selectedIndex == index;

          return Padding(
            padding: EdgeInsets.only(right: index < widget.tags.length - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: () => _handleTagTap(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? tag.color.withValues(alpha: 0.18)
                          : AppTheme.subtleFillColor(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? tag.color.withValues(alpha: 0.5)
                            : AppTheme.borderColor(context),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Icon(
                      tag.icon,
                      size: 18,
                      color: isSelected ? tag.color : AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tag.label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppTheme.selectedChipTextColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
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
}

class _DateSelector extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;

  const _DateSelector({
    required this.initialDate,
    required this.onDateChanged,
  });

  @override
  State<_DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<_DateSelector> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  void _handleDateSelection(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateChanged(date);
  }

  Future<void> _pickCustomDate() async {
    final today = DateTime.now();
    final firstDate = today.subtract(const Duration(days: 30));
    final lastDate = today.add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surface(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _handleDateSelection(picked);
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void _onTodayTap(DateTime today) => _handleDateSelection(today);
  void _onYesterdayTap(DateTime yesterday) => _handleDateSelection(yesterday);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final isToday = _isSameDay(_selectedDate, today);
    final isYesterday = _isSameDay(_selectedDate, yesterday);
    final isCustom = !isToday && !isYesterday;

    return Row(
      children: [
        _buildDateChip('Today', today, isToday, () => _onTodayTap(today)),
        const HGapSm(),
        _buildDateChip('Yesterday', yesterday, isYesterday, () => _onYesterdayTap(yesterday)),
        const HGapSm(),
        _buildCustomDateChip(isCustom),
      ],
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : AppTheme.borderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.selectedChipTextColor(context) : AppTheme.textSecondaryColor(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(bool isCustom) {
    final DateFormat formatter = DateFormat('MMM d');
    final label = isCustom ? formatter.format(_selectedDate) : 'Select Date';

    return GestureDetector(
      onTap: _pickCustomDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCustom 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded, 
              size: 14, 
              color: isCustom ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isCustom ? AppTheme.selectedChipTextColor(context) : AppTheme.textSecondaryColor(context),
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


