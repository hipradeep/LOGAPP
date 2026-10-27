import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'sheet_action_widgets.dart';

class TransactionFilterSheet extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String initialType;
  final void Function(DateTime? start, DateTime? end, String type) onApply;

  const TransactionFilterSheet({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.initialType,
    required this.onApply,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  late String _selectedType; // 'all', 'debit', 'credit'

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedType = widget.initialType;
  }

  void _handleSelectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filter Expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                  _selectedType = 'all';
                });
              },
              child: const Text('Reset'),
            ),
          ],
        ),
          const VGapMd(),
          Text(
            'TRANSACTION TYPE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapSm(),
          Row(
            children: [
              _buildTypeChip('all', 'All'),
              const HGapSm(),
              _buildTypeChip('debit', 'Debit (Expense)'),
              const HGapSm(),
              _buildTypeChip('credit', 'Credit (Gain)'),
            ],
          ),
          const VGapLg(),
          Text(
            'DATE RANGE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapSm(),
          GestureDetector(
            onTap: _handleSelectDateRange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppTheme.primaryLight,
                  ),
                  const HGapMd(),
                  Expanded(
                    child: Text(
                      _startDate != null && _endDate != null
                          ? '${DateFormat('MMM d, yyyy').format(_startDate!)} — ${DateFormat('MMM d, yyyy').format(_endDate!)}'
                          : 'Select date range (All time)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ),
                  if (_startDate != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Icon(Icons.close_rounded, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const VGapXl(),
          SizedBox(
            width: double.infinity,
            height: AppTheme.buttonHeight,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_startDate, _endDate, _selectedType);
                Navigator.of(context).pop();
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppTheme.primaryLight
                : AppTheme.textSecondaryColor(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
