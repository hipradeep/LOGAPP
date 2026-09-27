import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/pill_button.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';

/// Standalone Screen to add a new Course.
/// Adheres strictly to the 24 optimize.md rules, duo-tone palette,
/// and full_screen_rules.md guidelines.
class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDeadline;
  String _selectedStatus = 'active';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _handlePickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: AppTheme.themeData.copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  void _handleQuickDate(int days) {
    setState(() {
      _selectedDeadline = DateTime.now().add(Duration(days: days));
    });
  }

  void _handleClearDeadline() {
    setState(() {
      _selectedDeadline = null;
    });
  }

  void _handleStatusChanged(String status) {
    if (_selectedStatus == status) return;
    setState(() => _selectedStatus = status);
  }

  void _handleSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a course title'),
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
      await getIt<CoursesController>().addCourse(
        title: title,
        description: description.isEmpty ? 'No description provided.' : description,
        deadline: _selectedDeadline,
        status: _selectedStatus,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course "$title" created successfully'),
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
          content: Text('Failed to save course: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'New Course',
      showBackButton: true,
      onBackPress: _handleBack,
      children: [
        const VGapSm(),
        const _CourseHeaderCard(),
        const VGapLg(),
        _CourseTitleField(controller: _titleController),
        const VGapMd(),
        _CourseDescriptionField(controller: _descriptionController),
        const VGapLg(),
        _CourseDeadlineSection(
          selectedDeadline: _selectedDeadline,
          onPickDate: _handlePickDeadline,
          onQuickDate: _handleQuickDate,
          onClearDate: _handleClearDeadline,
        ),
        const VGapLg(),
        _CourseStatusSection(
          selectedStatus: _selectedStatus,
          onStatusChanged: _handleStatusChanged,
        ),
        const VGapXl(),
        _SubmitSection(
          isSubmitting: _isSubmitting,
          onSubmit: _handleSubmit,
        ),
        const VGapXl(),
      ],
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _CourseHeaderCard extends StatelessWidget {
  const _CourseHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Course Syllabus',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const VGapXs(),
                Text(
                  'Add subject info. You can structure sections and track syllabus progress.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTitleField extends StatelessWidget {
  final TextEditingController controller;

  const _CourseTitleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Course Title *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const VGapSm(),
        TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Distributed Systems, Machine Learning',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseDescriptionField extends StatelessWidget {
  final TextEditingController controller;

  const _CourseDescriptionField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Description (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const VGapSm(),
        TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Syllabus overview, textbook references, lecture goals...',
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseDeadlineSection extends StatelessWidget {
  final DateTime? selectedDeadline;
  final VoidCallback onPickDate;
  final void Function(int) onQuickDate;
  final VoidCallback onClearDate;

  const _CourseDeadlineSection({
    required this.selectedDeadline,
    required this.onPickDate,
    required this.onQuickDate,
    required this.onClearDate,
  });

  static final DateFormat _dateFormat = DateFormat('EEE, d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDeadline != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Target Deadline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (hasDate)
              GestureDetector(
                onTap: onClearDate,
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const VGapSm(),
        InkWell(
          onTap: onPickDate,
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              border: Border.all(
                color: hasDate
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : AppTheme.borderColor.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                const HGapSm(),
                Expanded(
                  child: Text(
                    hasDate
                        ? _dateFormat.format(selectedDeadline!)
                        : 'Select Target Date (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      color: hasDate ? AppTheme.textPrimary : AppTheme.textMuted,
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const VGapSm(),
        // Quick Presets
        Row(
          children: [
            _QuickDateChip(label: '+2 Wks', days: 14, onSelect: onQuickDate),
            const HGapSm(),
            _QuickDateChip(label: '+1 Mo', days: 30, onSelect: onQuickDate),
            const HGapSm(),
            _QuickDateChip(label: '+3 Mo', days: 90, onSelect: onQuickDate),
          ],
        ),
      ],
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final int days;
  final void Function(int) onSelect;

  const _QuickDateChip({
    required this.label,
    required this.days,
    required this.onSelect,
  });

  void _handleTap() => onSelect(days);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
          border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CourseStatusSection extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const _CourseStatusSection({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Course Status',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const VGapSm(),
        Row(
          children: [
            _StatusPill(
              label: 'Active',
              value: 'active',
              isSelected: selectedStatus == 'active',
              onTap: onStatusChanged,
            ),
            const HGapSm(),
            _StatusPill(
              label: 'Planned',
              value: 'planned',
              isSelected: selectedStatus == 'planned',
              onTap: onStatusChanged,
            ),
            const HGapSm(),
            _StatusPill(
              label: 'Archived',
              value: 'archived',
              isSelected: selectedStatus == 'archived',
              onTap: onStatusChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final ValueChanged<String> onTap;

  const _StatusPill({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  void _handleTap() => onTap(value);

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
            color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitSection extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _SubmitSection({
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return PillButton(
      text: 'Create Course',
      icon: Icons.arrow_forward_rounded,
      isLoading: isSubmitting,
      onPressed: onSubmit,
    );
  }
}
