import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../controllers/modules_controller.dart';
import 'app_spacers.dart';
import 'pill_button.dart';

/// Modal bottom sheet to create a new Module for a course.
class AddModuleSheet extends StatefulWidget {
  final ModulesController controller;
  final String courseTitle;

  const AddModuleSheet({
    super.key,
    required this.controller,
    required this.courseTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required ModulesController controller,
    required String courseTitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddModuleSheet(
        controller: controller,
        courseTitle: courseTitle,
      ),
    );
  }

  @override
  State<AddModuleSheet> createState() => _AddModuleSheetState();
}

class _AddModuleSheetState extends State<AddModuleSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedStatus = 'active';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onStatusChanged(String status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
  }

  void _onSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a module title'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    setState(() => _isSubmitting = true);

    try {
      await widget.controller.addModule(
        title: title,
        description: description,
        status: _selectedStatus,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Module "$title" added successfully'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add module: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardBorderRadius),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const VGapLg(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Module',
                      style: AppTheme.headingSmall.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      'For ${widget.courseTitle}',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context)),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondaryColor(context)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const VGapLg(),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Module Title',
                hintText: 'e.g. Chapter 1: Foundations',
                filled: true,
                fillColor: AppTheme.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const VGapMd(),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: AppTheme.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Core topics, reading material, key concepts',
                filled: true,
                fillColor: AppTheme.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const VGapLg(),
            Row(
              children: [
                _StatusChip(
                  label: 'Active',
                  value: 'active',
                  isSelected: _selectedStatus == 'active',
                  onSelect: _onStatusChanged,
                ),
                const HGapSm(),
                _StatusChip(
                  label: 'Planned',
                  value: 'planned',
                  isSelected: _selectedStatus == 'planned',
                  onSelect: _onStatusChanged,
                ),
              ],
            ),
            const VGapXl(),
            PillButton(
              text: 'Add Module',
              icon: Icons.add_rounded,
              isLoading: _isSubmitting,
              onPressed: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final ValueChanged<String> onSelect;

  const _StatusChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onSelect,
  });

  void _handleTap() => onSelect(value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}
