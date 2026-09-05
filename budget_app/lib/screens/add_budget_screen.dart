import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_action_buttons.dart';
import '../models/budget.dart';
import '../services/budget_service.dart';
import '../services/preferences_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  final BudgetService _budgetService = BudgetService();
  final PreferencesService _prefs = PreferencesService();

  late TextEditingController _nameController;
  late TextEditingController _categoryNameController;
  late TextEditingController _limitController;
  late TextEditingController _descriptionController;

  late String _selectedPeriod;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _repeat;
  late double _alertThreshold;
  List<String> _predefinedCategories = ['Expenses', 'Salary', 'Travel', 'Earning', 'Personal'];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBudget;
    _nameController = TextEditingController(text: b?.name ?? '');
    _categoryNameController = TextEditingController(text: b?.categoryName ?? 'Expenses');
    _limitController = TextEditingController(text: b != null ? b.limit.toStringAsFixed(0) : '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _selectedPeriod = b?.period ?? 'monthly';
    _startDate = b?.startDate;
    _endDate = b?.endDate;
    _repeat = b?.repeat ?? true;
    _alertThreshold = b?.alertThreshold ?? 0.7;

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _prefs.getBudgetCategories();
    if (mounted) setState(() => _predefinedCategories = cats);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryNameController.dispose();
    _limitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;
    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget limit in ₹')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final name = _nameController.text.trim();
    final categoryName = _categoryNameController.text.trim();

    try {
      if (widget.existingBudget != null) {
        await _budgetService.updateBudget(
          widget.existingBudget!.id,
          name: name,
          categoryName: categoryName,
          limit: limit,
          period: _selectedPeriod,
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          repeat: _repeat,
          alertThreshold: _alertThreshold,
        );
      } else {
        await _budgetService.createBudget(
          name,
          categoryName,
          limit,
          _selectedPeriod,
          description: _descriptionController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          repeat: _repeat,
          alertThreshold: _alertThreshold,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save budget: $e')),
        );
      }
    }
  }

  void _deleteBudget() async {
    if (widget.existingBudget == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Budget'),
        content: Text('Are you sure you want to delete "${widget.existingBudget!.name}" and all its records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      await _budgetService.deleteBudget(widget.existingBudget!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingBudget != null;

    return FullScreenPage(
      showScaffold: true,
      title: isEditing ? 'Edit Budget' : 'New Budget Cap',
      showBackButton: true,
      actions: [
        if (isEditing)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
            onPressed: _deleteBudget,
          ),
      ],
      children: [
        const VGapMd(),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget Name
              _buildLabel('Budget Name'),
              const VGapXs(),
              TextFormField(
                controller: _nameController,
                style: AppTheme.bodyLarge.copyWith(color: AppTheme.textPrimaryColor(context)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Monthly Living, Vacation, Office Expense',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Budget name is required' : null,
              ),
              const VGapLg(),
              // Spending Limit in ₹ INR
              _buildLabel('Spending Limit / Cap (₹ INR)'),
              const VGapXs(),
              TextFormField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTheme.headingMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8, top: 12),
                    child: Text('₹', style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryColor)),
                  ),
                  hintText: '25000',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter limit amount';
                  if (double.tryParse(val.trim()) == null) return 'Enter valid number';
                  return null;
                },
              ),
              const VGapLg(),
              // Period selection
              _buildLabel('Cycle / Period'),
              const VGapXs(),
              Row(
                children: [
                  _buildPeriodChip('Daily', 'daily'),
                  const HGapSm(),
                  _buildPeriodChip('Weekly', 'weekly'),
                  const HGapSm(),
                  _buildPeriodChip('Monthly', 'monthly'),
                ],
              ),
              const VGapLg(),
              // Category chips
              _buildLabel('Category Tag'),
              const VGapXs(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _predefinedCategories.map((cat) {
                  final isSelected = _categoryNameController.text == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _categoryNameController.text = cat),
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.25),
                    backgroundColor: AppTheme.surface(context),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
                    ),
                  );
                }).toList(),
              ),
              const VGapLg(),
              // Alert threshold slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('Alert Threshold Warning'),
                  Text(
                    '${(_alertThreshold * 100).round()}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryAccentColor(context),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _alertThreshold,
                min: 0.5,
                max: 1.0,
                divisions: 10,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _alertThreshold = val),
              ),
              const VGapLg(),
              // Notes / Description
              _buildLabel('Notes & Instructions (Optional)'),
              const VGapXs(),
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimaryColor(context)),
                decoration: const InputDecoration(
                  hintText: 'Any specific rules or targets...',
                ),
              ),
              const VGapXxl(),
              AppActionButtons(
                primaryLabel: isEditing ? 'Save Changes' : 'Create Budget',
                onPrimaryPressed: _saveBudget,
                cancelLabel: 'Cancel',
                onCancelPressed: () => Navigator.pop(context),
                isPrimaryLoading: _isSaving,
              ),
              const VGapXl(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondaryColor(context),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedPeriod = value),
        selectedColor: AppTheme.segmentedSelectedBgColor(context),
        backgroundColor: AppTheme.surface(context),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
        ),
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
        showCheckmark: false,
      ),
    );
  }
}
