import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

/// Tag definition for expense categories
class _ExpenseTag {
  final String label;
  final IconData icon;
  final Color color;

  const _ExpenseTag(this.label, this.icon, this.color);
}

const List<_ExpenseTag> _expenseTags = [
  _ExpenseTag('Bill', Icons.receipt_long_rounded, Colors.redAccent),
  _ExpenseTag('Dinner', Icons.dinner_dining_rounded, Colors.amber),
  _ExpenseTag('Drink', Icons.local_cafe_rounded, Colors.brown),
  _ExpenseTag('Fuel', Icons.local_gas_station_rounded, Colors.blue),
  _ExpenseTag('Grocery', Icons.local_grocery_store_rounded, Colors.green),
  _ExpenseTag('Health', Icons.medical_services_rounded, Colors.teal),
  _ExpenseTag('Other', Icons.more_horiz_rounded, Colors.grey),
  _ExpenseTag('Shopping', Icons.shopping_bag_rounded, Colors.pinkAccent),
  _ExpenseTag('Snack', Icons.fastfood_rounded, Colors.orange),
  _ExpenseTag('Travel', Icons.flight_rounded, Colors.indigo),
];

class AddTransactionSheet extends StatefulWidget {
  final String budgetId;
  final String categoryName;
  final Future<void> Function(String tag, String description, double amount, DateTime date) onAddTransaction;

  const AddTransactionSheet({
    super.key,
    required this.budgetId,
    required this.categoryName,
    required this.onAddTransaction,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _descFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _isExpense = true;
  int? _selectedTagIndex;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _descFocus.dispose();
    _amountFocus.dispose();
    _sheetController.dispose();
    super.dispose();
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
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
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

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final customDesc = _descController.text.trim();

    if (_selectedTagIndex == null) {
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
    final desc = customDesc;
    // If no custom description, the tag label alone will be shown on display
    final finalAmount = _isExpense ? amount : -amount;

    setState(() => _isSaving = true);
    try {
      await widget.onAddTransaction(tag.label, desc, finalAmount, _selectedDate);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding transaction: $e'),
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
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
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
                        color: Colors.white24,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Log Expense',
                                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                                    ),
                                    Text(
                                      'Category: ${widget.categoryName}',
                                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const VGapLg(),
                          Text(
                            'Select Date',
                            style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const VGapMd(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDateSelectorRow(),
                          ),
                          const VGapLg(),

                          // ── Expense Tag Icons ──
                          Text(
                            'What was it for?',
                            style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const VGapMd(),
                          _buildTagGrid(),
                          const VGapLg(),

                          // ── Amount ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Amount (₹)',
                                style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _isExpense = !_isExpense),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isExpense
                                        ? AppTheme.errorColor.withValues(alpha: 0.15)
                                        : AppTheme.successColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isExpense
                                          ? AppTheme.errorColor.withValues(alpha: 0.4)
                                          : AppTheme.successColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    _isExpense ? 'Expense(-)' : 'Gain(+)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _isExpense ? AppTheme.errorColor : AppTheme.successColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const VGapMd(),
                          TextField(
                            controller: _amountController,
                            focusNode: _amountFocus,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 250.00',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24, width: 1),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          const VGapMd(),

                          // ── Description (optional, below amount) ──
                          Text(
                            'Description',
                            style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const VGapMd(),
                          TextField(
                            controller: _descController,
                            focusNode: _descFocus,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Add a note (optional)',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white24, width: 1),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          const VGapLg(),

                          ElevatedButton(
                            onPressed: _isSaving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Log Expense',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
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

  /// Builds the horizontally scrollable circular tag selector
  Widget _buildTagGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_expenseTags.length, (index) {
          final tag = _expenseTags[index];
          final isSelected = _selectedTagIndex == index;

          return Padding(
            padding: EdgeInsets.only(right: index < _expenseTags.length - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTagIndex = index),
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
                          : Colors.white.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? tag.color.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.8 : 1,
                      ),
                    ),
                    child: Icon(
                      tag.icon,
                      size: 18,
                      color: isSelected ? tag.color : AppTheme.textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tag.label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.6),
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

  Widget _buildDateSelectorRow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final isToday = _isSameDay(_selectedDate, today);
    final isYesterday = _isSameDay(_selectedDate, yesterday);
    final isCustom = !isToday && !isYesterday;

    return Row(
      children: [
        _buildDateChip('Today', today, isToday),
        const HGapSm(),
        _buildDateChip('Yesterday', yesterday, isYesterday),
        const HGapSm(),
        _buildCustomDateChip(isCustom),
      ],
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
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
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded, 
              size: 14, 
              color: isCustom ? AppTheme.primaryLight : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isCustom ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
