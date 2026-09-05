import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_action_buttons.dart';

class TransactionFilterSheet extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String initialType;
  final String initialValidation;
  final void Function(DateTime? start, DateTime? end, String type, String validation) onApply;

  const TransactionFilterSheet({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.initialType,
    required this.initialValidation,
    required this.onApply,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  late String _selectedType; // 'all', 'debit', 'credit'
  late String _selectedValidation; // 'all', 'validated', 'pending'
  String _selectedQuickDate = 'all';

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedType = widget.initialType;
    _selectedValidation = widget.initialValidation;
    _initQuickDateState();
  }

  void _initQuickDateState() {
    if (_startDate == null || _endDate == null) {
      _selectedQuickDate = '1m';
    } else {
      final diffDays = _endDate!.difference(_startDate!).inDays;
      if (diffDays == 30 || diffDays == 31) {
        _selectedQuickDate = '1m';
      } else if (diffDays >= 89 && diffDays <= 93) {
        _selectedQuickDate = '3m';
      } else if (diffDays >= 179 && diffDays <= 184) {
        _selectedQuickDate = '6m';
      } else {
        _selectedQuickDate = 'custom';
      }
    }
  }

  void _handleSelectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: _buildDatePickerTheme,
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
        _selectedQuickDate = 'custom';
      });
    }
  }

  void _handleSelectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: _buildDatePickerTheme,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
        _selectedQuickDate = 'custom';
      });
    }
  }

  void _handleSelectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: _buildDatePickerTheme,
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(_endDate!)) {
          _startDate = _endDate;
        }
        _selectedQuickDate = 'custom';
      });
    }
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppTheme.primaryColor,
          onPrimary: AppTheme.selectedChipTextColor(context),
          surface: AppTheme.surface(context),
          onSurface: AppTheme.textPrimaryColor(context),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppTheme.background(context),
        ),
      ),
      child: child!,
    );
  }

  void _handleQuickDateSelect(String selection) {
    setState(() {
      _selectedQuickDate = selection;
      if (selection == '1m') {
        _startDate = DateTime.now().subtract(const Duration(days: 30));
        _endDate = DateTime.now();
      } else if (selection == '3m') {
        _startDate = DateTime.now().subtract(const Duration(days: 90));
        _endDate = DateTime.now();
      } else if (selection == '6m') {
        _startDate = DateTime.now().subtract(const Duration(days: 180));
        _endDate = DateTime.now();
      } else if (selection == 'custom') {
        _handleSelectDateRange();
      }
    });
  }

  void _handleReset() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
      _selectedType = 'all';
      _selectedValidation = 'all';
      _selectedQuickDate = '1m';
    });
  }

  void _handleApply() {
    widget.onApply(_startDate, _endDate, _selectedType, _selectedValidation);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
      ),
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Transactions',
                  style: AppTheme.headingSmall.copyWith(fontSize: 20),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context)),
                ),
              ],
            ),
            const VGapSm(),
            Divider(color: AppTheme.borderColor(context)),
            const VGapMd(),
            Text(
              'Date Range Shortcut',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 0.8,
              ),
            ),
            const VGapSm(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickChip('1 Month', '1m'),
                  const SizedBox(width: 8),
                  _buildQuickChip('3 Months', '3m'),
                  const SizedBox(width: 8),
                  _buildQuickChip('6 Months', '6m'),
                  const SizedBox(width: 8),
                  _buildQuickChip('Custom', 'custom'),
                ],
              ),
            ),
            const VGapMd(),
            Text(
              'Custom Dates',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 0.8,
              ),
            ),
            const VGapSm(),
            Row(
              children: [
                Expanded(
                  child: _DateInputField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: _handleSelectStartDate,
                  ),
                ),
                const HGapSm(),
                Expanded(
                  child: _DateInputField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: _handleSelectEndDate,
                  ),
                ),
              ],
            ),
            const VGapLg(),
            Text(
              'Transaction Type',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondaryColor(context),
                letterSpacing: 0.8,
              ),
            ),
            const VGapSm(),
            Row(
              children: [
                _buildTypeChip('All', 'all'),
                const HGapSm(),
                _buildTypeChip('Debit (Expense)', 'debit'),
                const HGapSm(),
                _buildTypeChip('Credit (Income)', 'credit'),
              ],
            ),
            const VGapXxl(),
            AppActionButtons(
              primaryLabel: 'Apply Filters',
              onPrimaryPressed: _handleApply,
              cancelLabel: 'Reset',
              onCancelPressed: _handleReset,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, String value) {
    final isSelected = _selectedQuickDate == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _handleQuickDateSelect(value),
      selectedColor: AppTheme.segmentedSelectedBgColor(context),
      backgroundColor: AppTheme.surface(context).withValues(alpha: 0.35),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
        width: 1.2,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label, style: const TextStyle(fontSize: 11))),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedType = value),
        selectedColor: AppTheme.segmentedSelectedBgColor(context),
        backgroundColor: AppTheme.surface(context).withValues(alpha: 0.35),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
          width: 1.2,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DateInputField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateInputField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = date != null;
    final text = isSet ? DateFormat('d MMM yyyy').format(date!) : 'Select Date';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSet ? AppTheme.primaryColor.withValues(alpha: 0.3) : AppTheme.borderColor(context),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSet ? AppTheme.primaryAccentColor(context) : AppTheme.textPrimaryColor(context),
                      fontSize: 13,
                      fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: isSet ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
