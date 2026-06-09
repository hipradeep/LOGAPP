import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../models/budget_item.dart';
import '../services/budget_service.dart';

class AddBudgetScreen extends StatefulWidget {
  final BudgetItem? existingBudget;

  const AddBudgetScreen({
    super.key,
    this.existingBudget,
  });

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final BudgetService _budgetService = BudgetService();

  late TextEditingController _categoryController;
  late TextEditingController _limitController;
  late TextEditingController _descriptionController;

  late String _selectedPeriod;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _repeat;
  late List<int> _repeatDays;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();

    final budget = widget.existingBudget;
    _categoryController = TextEditingController(text: budget?.category ?? '');
    _limitController = TextEditingController(
      text: budget != null ? budget.limit.toStringAsFixed(0) : '',
    );
    _descriptionController = TextEditingController(text: budget?.description ?? '');
    _selectedPeriod = budget?.period ?? 'monthly';
    _startDate = budget?.startDate;
    _endDate = budget?.endDate;
    _repeat = budget?.repeat ?? true;
    _repeatDays = budget != null ? List<int>.from(budget.repeatDays) : [1, 2, 3, 4, 5, 6, 7];

    if (budget?.scheduledTime != null) {
      try {
        final parts = budget!.scheduledTime!.split(':');
        if (parts.length == 2) {
          _scheduledTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {
        _scheduledTime = null;
      }
    } else {
      _scheduledTime = null;
    }
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _limitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatTimeForDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hr = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    return '$hr:$min';
  }

  void _deleteBudget() async {
    if (widget.existingBudget == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Budget Category'),
        content: Text('Are you sure you want to delete "${widget.existingBudget!.category}"? This will delete all logged expenses under it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _budgetService.deleteBudget(widget.existingBudget!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget deleted successfully.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _toggleBudgetComplete() async {
    if (widget.existingBudget == null) return;
    final newChecked = !widget.existingBudget!.checked;

    await _budgetService.toggleBudget(widget.existingBudget!.id, newChecked);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newChecked ? 'Budget marked as active.' : 'Budget completed/ended.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_limitController.text) ?? 0.0;
    if (limit <= 0) return;

    final timeStr = _scheduledTime != null ? _formatTimeOfDay(_scheduledTime!) : null;
    final isEditing = widget.existingBudget != null;

    if (isEditing) {
      await _budgetService.updateBudget(
        widget.existingBudget!.id,
        limit: limit,
        period: _selectedPeriod,
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        repeat: _repeat,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget updated successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      final category = _categoryController.text.trim();
      if (category.isEmpty) return;

      await _budgetService.createBudget(
        category,
        limit,
        _selectedPeriod,
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        repeat: _repeat,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget created successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const VGapSm(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildPeriodChips() {
    return Row(
      children: [
        _buildPeriodChip('Weekly', 'weekly', Icons.calendar_view_week_rounded),
        const HGapSm(),
        _buildPeriodChip('Monthly', 'monthly', Icons.calendar_month_rounded),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value, IconData icon) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.04),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateDateRange(String period) {
    final now = DateTime.now();
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    if (period == 'weekly') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return '${formatter.format(monday)} - ${formatter.format(sunday)}';
    } else if (period == 'monthly') {
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      return '${formatter.format(firstDay)} - ${formatter.format(lastDay)}';
    }
    return '';
  }

  Widget _buildDateRangeIndicator() {
    final rangeText = _calculateDateRange(_selectedPeriod);
    if (rangeText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, color: AppTheme.primaryLight, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CURRENT CYCLE RANGE',
                    style: TextStyle(
                      color: AppTheme.primaryLight,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionInputField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: null,
      minLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter budget description (optional)...',
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBudget != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: true,
        title: isEditing ? 'Edit Budget' : 'New Budget',
        showBackButton: true,
        actions: [
          TextButton(
            onPressed: _saveBudget,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (isEditing) ...[
            const SizedBox(width: 8),
            Transform.translate(
              offset: const Offset(10, 0),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  color: AppTheme.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteBudget();
                    } else if (value == 'toggle_complete') {
                      _toggleBudgetComplete();
                    }
                  },
                  itemBuilder: (context) {
                    final isCompleted = !(widget.existingBudget?.checked ?? true);
                    return [
                      PopupMenuItem<String>(
                        value: 'toggle_complete',
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.play_circle_outline_rounded : Icons.check_circle_outline_rounded,
                              color: AppTheme.primaryLight,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCompleted ? 'Mark Active' : 'Mark Complete',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Delete Budget',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ),
          ],
        ],
        children: [
          const VGapMd(),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel('CATEGORY NAME'),
                const VGapSm(),
                TextFormField(
                  controller: _categoryController,
                  readOnly: isEditing,
                  style: GoogleFonts.outfit(
                    color: isEditing ? Colors.white54 : Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Groceries, Rent, Transport',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10, width: 1.5),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10, width: 1.5),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.label_outline_rounded,
                        color: AppTheme.primaryLight,
                        size: 28,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a category name';
                    }
                    return null;
                  },
                ),
                const VGapLg(),

                _buildSectionLabel('BUDGET LIMIT (₹)',),
                const VGapSm(),
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter limit (e.g. 150)',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: false,
                    border: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10, width: 1.5),
                    ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10, width: 1.5),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.attach_money_rounded,
                        color: AppTheme.primaryLight,
                        size: 28,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a limit';
                    }
                    final limit = double.tryParse(val);
                    if (limit == null || limit <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const VGapLg(),

                _buildSectionLabel('TRACKING PERIOD'),
                const VGapSm(),
                _buildPeriodChips(),
                _buildDateRangeIndicator(),
                const VGapLg(),

                // Repeat Config Card
                _buildSectionCard(
                  title: 'Repeat & Active Days',
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Repeat Budget Cycle', style: TextStyle(fontSize: 14, color: Colors.white)),
                      subtitle: const Text('Automatically reset and repeat this budget.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      value: _repeat,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _repeat = val;
                        });
                      },
                    ),
                    if (_repeat) ...[
                      const VGapSm(),
                      const Text(
                        'Track expenses logged on these weekdays:',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const VGapSm(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final dayValues = [1, 2, 3, 4, 5, 6, 7];
                          final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          final dayValue = dayValues[index];
                          final isSelected = _repeatDays.contains(dayValue);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  if (_repeatDays.length > 1) {
                                    _repeatDays.remove(dayValue);
                                  }
                                } else {
                                  _repeatDays.add(dayValue);
                                  _repeatDays.sort();
                                }
                              });
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                    : AppTheme.surfaceColor.withValues(alpha: 0.3),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.7)
                                      : Colors.white.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  dayLabels[index],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),

                // Scheduled Reminder Card
                _buildSectionCard(
                  title: 'Schedule Reminder',
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.alarm_rounded, color: AppTheme.primaryLight, size: 22),
                        title: Text(
                          _scheduledTime != null
                              ? 'Remind At: ${_formatTimeForDisplay(_scheduledTime!)}'
                              : 'Set Reminder Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: _scheduledTime != null ? Colors.white : AppTheme.textSecondary,
                            fontWeight: _scheduledTime != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: _scheduledTime != null
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                                onPressed: () {
                                  setState(() => _scheduledTime = null);
                                },
                              )
                            : const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppTheme.primaryColor,
                                  surface: AppTheme.surfaceColor,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() => _scheduledTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const VGapLg(),

                _buildSectionLabel('DESCRIPTION'),
                const VGapSm(),
                _buildDescriptionInputField(),

                const VGapLg(),

                const VGapXxl(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
