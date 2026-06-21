import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../widgets/app_title_input.dart';
import '../widgets/app_text_action_button.dart';
import '../widgets/app_popup_menu_button.dart';
import '../services/cache_service.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? existingBudget;

  const AddBudgetScreen({
    super.key,
    this.existingBudget,
  });

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  static final DateFormat _rangeFormatter = DateFormat('MMMM d, yyyy');
  final _formKey = GlobalKey<FormState>();
  final BudgetService _budgetService = BudgetService();

  List<String> _predefinedCategories = [
    'Expenses',
    'Salary',
    'Travel',
    'Earning',
  ];

  late TextEditingController _nameController;
  late TextEditingController _categoryNameController;
  late TextEditingController _limitController;
  late TextEditingController _descriptionController;

  late String _selectedPeriod;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _repeat;
  late List<int> _repeatDays;
  late TimeOfDay? _scheduledTime;
  late double _alertThreshold;

  Future<void> _loadBudgetCategories() async {
    final categories = await CacheService().getBudgetCategories();
    if (mounted) {
      setState(() {
        _predefinedCategories = categories;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBudgetCategories();

    final budget = widget.existingBudget;
    _nameController = TextEditingController(text: budget?.name ?? '');
    _categoryNameController = TextEditingController(text: budget?.categoryName ?? '');
    _categoryNameController.addListener(() {
      if (mounted) setState(() {});
    });
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
    _alertThreshold = budget?.alertThreshold ?? 0.7;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryNameController.dispose();
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
        content: Text('Are you sure you want to delete "${widget.existingBudget!.name}"? This will delete all logged expenses under it.'),
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
    final newActive = !widget.existingBudget!.isActive;

    await _budgetService.toggleBudget(widget.existingBudget!.id, newActive);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newActive ? 'Budget marked as active.' : 'Budget completed/ended.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    final categoryName = _categoryNameController.text.trim();
    if (categoryName.isNotEmpty) {
      await CacheService().addBudgetCategory(categoryName);
    }

    final limit = double.tryParse(_limitController.text) ?? 0.0;
    if (limit <= 0) return;

    final timeStr = _scheduledTime != null ? _formatTimeOfDay(_scheduledTime!) : null;
    final isEditing = widget.existingBudget != null;

    if (isEditing) {
      await _budgetService.updateBudget(
        widget.existingBudget!.id,
        name: _nameController.text.trim(),
        categoryName: _categoryNameController.text.trim(),
        limit: limit,
        period: _selectedPeriod,
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        repeat: _repeat,
        alertThreshold: _alertThreshold,
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
      final name = _nameController.text.trim();
      final categoryName = _categoryNameController.text.trim();
      if (name.isEmpty || categoryName.isEmpty) return;

      await _budgetService.createBudget(
        name,
        categoryName,
        limit,
        _selectedPeriod,
        description: _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        repeat: _repeat,
        alertThreshold: _alertThreshold,
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
        color: AppTheme.surface(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryAccentColor(context),
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

  Widget _buildQuickCategoryChip(String label) {
    final isSelected = _categoryNameController.text.trim().toLowerCase() == label.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _categoryNameController.text = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
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
                ? AppTheme.selectedChipTextColor(context)
                : AppTheme.textSecondaryColor(context),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
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
                : AppTheme.surface(context).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : AppTheme.borderColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppTheme.primaryAccentColor(context)
                    : AppTheme.textSecondaryColor(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.textPrimaryColor(context)
                      : AppTheme.textSecondaryColor(context),
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
    if (period == 'weekly') {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return '${_rangeFormatter.format(monday)} - ${_rangeFormatter.format(sunday)}';
    } else if (period == 'monthly') {
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      return '${_rangeFormatter.format(firstDay)} - ${_rangeFormatter.format(lastDay)}';
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
            Icon(
              Icons.date_range_rounded,
              color: AppTheme.primaryAccentColor(context),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT CYCLE RANGE',
                    style: TextStyle(
                      color: AppTheme.primaryAccentColor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeText,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
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


  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final isEditing = widget.existingBudget != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: true,
        title: isEditing ? 'Edit Budget' : 'New Budget',
        showBackButton: true,
        actions: [
          AppTextActionButton(
            label: 'Save',
            onPressed: _saveBudget,
          ),
          if (isEditing) ...[
            AppPopupMenuButton(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteBudget();
                } else if (value == 'toggle_complete') {
                  _toggleBudgetComplete();
                }
              },
              itemBuilder: (context) {
                final isCompleted = !(widget.existingBudget?.isActive ?? true);
                return [
                  PopupMenuItem<String>(
                    value: 'toggle_complete',
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.play_circle_outline_rounded : Icons.check_circle_outline_rounded,
                          color: AppTheme.primaryAccentColor(context),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isCompleted ? 'Mark Active' : 'Mark Complete',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
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
          ],
        ],
        children: [
          const VGapMd(),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSectionLabel('BUDGET NAME'),
                const VGapSm(),
                TextFormField(
                  controller: _nameController,
                  readOnly: isEditing,
                  style: GoogleFonts.outfit(
                    color: AppTheme.categoryTextColor(context, isEditing: isEditing),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g., Monthly Budget',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: false,
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.star_border_rounded,
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
                      return 'Please enter a budget name';
                    }
                    return null;
                  },
                ),
                const VGapLg(),

                _buildSectionLabel('CATEGORY NAME'),
                const VGapSm(),
                if (isEditing)
                  TextFormField(
                    controller: _categoryNameController,
                    readOnly: true,
                    style: GoogleFonts.outfit(
                      color: AppTheme.categoryTextColor(context, isEditing: true),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: false,
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
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
                  )
                else
                  TextFormField(
                    controller: _categoryNameController,
                    style: GoogleFonts.outfit(
                      color: AppTheme.categoryTextColor(context, isEditing: false),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter or select category',
                      hintStyle: GoogleFonts.outfit(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: false,
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(right: 12),
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
                        return 'Please enter a category';
                      }
                      return null;
                    },
                  ),
                if (!isEditing) ...[
                  const VGapSm(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _predefinedCategories
                        .map((category) => _buildQuickCategoryChip(category))
                        .toList(),
                  ),
                ],
                const VGapLg(),

                _buildSectionLabel('BUDGET LIMIT (₹)',),
                const VGapSm(),
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimaryColor(context),
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
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '₹',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryLight,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
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

                _buildSectionLabel('ALERT THRESHOLD'),
                const VGapSm(),
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active_rounded,
                                  size: 16, color: AppTheme.warningColor),
                              const HGapSm(),
                              Text(
                                'Alert me when spent reaches',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(_alertThreshold * 100).round()}%',
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.warningColor,
                          inactiveTrackColor: AppTheme.warningColor.withValues(alpha: 0.15),
                          thumbColor: AppTheme.warningColor,
                          overlayColor: AppTheme.warningColor.withValues(alpha: 0.12),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        ),
                        child: Slider(
                          value: _alertThreshold,
                          min: 0.1,
                          max: 1.0,
                          divisions: 90,
                          onChanged: (val) => setState(() => _alertThreshold = val),
                        ),
                      ),
                    ],
                  ),
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
                      title: Text(
                        'Repeat Budget Cycle',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      subtitle: Text(
                        'Automatically reset and repeat this budget.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
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
                      Text(
                        'Track expenses logged on these weekdays:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
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
                                    : AppTheme.surface(context).withValues(alpha: 0.3),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.7)
                                      : AppTheme.borderColor(context),
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
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textSecondaryColor(context),
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
                        color: AppTheme.surface(context).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderColor(context),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.alarm_rounded,
                          color: AppTheme.primaryAccentColor(context),
                          size: 22,
                        ),
                        title: Text(
                          _scheduledTime != null
                              ? 'Remind At: ${_formatTimeForDisplay(_scheduledTime!)}'
                              : 'Set Reminder Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: _scheduledTime != null
                                ? AppTheme.textPrimaryColor(context)
                                : AppTheme.textSecondaryColor(context),
                            fontWeight: _scheduledTime != null ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: _scheduledTime != null
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppTheme.textSecondaryColor(context),
                                ),
                                onPressed: () {
                                  setState(() => _scheduledTime = null);
                                },
                              )
                            : Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _scheduledTime ?? const TimeOfDay(hour: 9, minute: 0),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
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

                AppTitleInput(
                  controller: _descriptionController,
                  label: 'description',
                  hintText: 'Enter budget description (optional)...',
                  icon: Icons.description_outlined,
                  validator: (val) => null,
                ),

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
