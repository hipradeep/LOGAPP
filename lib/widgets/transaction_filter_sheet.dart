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
  String _selectedQuickDate = 'all'; // 'all', '1m', '3m', '6m', 'custom'

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
      } else if (diffDays == 90 || diffDays == 91 || diffDays == 92) {
        _selectedQuickDate = '3m';
      } else if (diffDays == 180 || diffDays == 181 || diffDays == 182 || diffDays == 183) {
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
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.primaryColor,
          onPrimary: Colors.white,
          surface: AppTheme.surfaceColor,
          onSurface: AppTheme.textPrimary,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: AppTheme.backgroundColor,
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

  void _handleTypeSelect(String type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _handleValidationSelect(String val) {
    setState(() {
      _selectedValidation = val;
    });
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildDateShortcutsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Date Range Shortcut'),
        const VGapSm(),
        _QuickDateSelector(
          selectedValue: _selectedQuickDate,
          onSelect: _handleQuickDateSelect,
        ),
      ],
    );
  }

  Widget _buildCustomRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Custom Range'),
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
      ],
    );
  }

  Widget _buildTypeSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Transaction Type'),
        const VGapSm(),
        _TypeSelector(
          selectedType: _selectedType,
          onSelect: _handleTypeSelect,
        ),
      ],
    );
  }

  Widget _buildValidationSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Validation Status'),
        const VGapSm(),
        _ValidationSelector(
          selectedVal: _selectedValidation,
          onSelect: _handleValidationSelect,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return AppActionButtons(
      primaryLabel: 'Apply Filters',
      onPrimaryPressed: _handleApply,
      secondaryLabel: 'Reset',
      onSecondaryPressed: _handleReset,
      primaryColor: AppTheme.primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03), width: 1.5),
      ),
      padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _FilterHeader(onClose: () => Navigator.pop(context)),
            const VGapSm(),
            const Divider(color: Colors.white10),
            const VGapMd(),
            _buildDateShortcutsSection(),
            const VGapMd(),
            _buildCustomRangeSection(),
            const VGapLg(),
            _buildTypeSelectorSection(),
            const VGapLg(),
            _buildValidationSelectorSection(),
            const VGapXxl(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}

class _FilterHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _FilterHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Filter Transactions',
            style: AppTheme.headingSmall.copyWith(fontSize: 20),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8),
    );
  }
}

class _QuickDateSelector extends StatelessWidget {
  final String selectedValue;
  final ValueChanged<String> onSelect;

  const _QuickDateSelector({required this.selectedValue, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip('1 Month', '1m'),
          const SizedBox(width: 8),
          _buildChip('3 Months', '3m'),
          const SizedBox(width: 8),
          _buildChip('6 Months', '6m'),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = selectedValue == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
      backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.35),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
        width: 1.2,
      ),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          color: AppTheme.surfaceColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSet ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSet ? AppTheme.primaryLight : Colors.white,
                      fontSize: 13,
                      fontWeight: isSet ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: isSet ? AppTheme.primaryLight : AppTheme.textSecondary.withValues(alpha: 0.5),
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

class _TypeSelector extends StatelessWidget {
  final String selectedType;
  final ValueChanged<String> onSelect;

  const _TypeSelector({required this.selectedType, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip('All', 'all'),
        const HGapSm(),
        _buildChip('Debit', 'debit'),
        const HGapSm(),
        _buildChip('Credit', 'credit'),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = selectedType == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
        backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.35),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
          width: 1.2,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ValidationSelector extends StatelessWidget {
  final String selectedVal;
  final ValueChanged<String> onSelect;

  const _ValidationSelector({required this.selectedVal, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip('All', 'all'),
        const HGapSm(),
        _buildChip('Validated', 'validated'),
        const HGapSm(),
        _buildChip('Pending', 'pending'),
      ],
    );
  }

  Widget _buildChip(String label, String value) {
    final isSelected = selectedVal == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.18),
        backgroundColor: AppTheme.surfaceColor.withValues(alpha: 0.35),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.05),
          width: 1.2,
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
