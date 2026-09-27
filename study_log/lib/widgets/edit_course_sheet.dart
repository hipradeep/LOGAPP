import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'pill_button.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';

class EditCourseSheet extends StatefulWidget {
  final Course course;

  const EditCourseSheet({
    super.key,
    required this.course,
  });

  static Future<void> show(BuildContext context, {required Course course}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditCourseSheet(course: course),
    );
  }

  @override
  State<EditCourseSheet> createState() => _EditCourseSheetState();
}

class _EditCourseSheetState extends State<EditCourseSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _selectedDeadline;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course.title);
    _descriptionController = TextEditingController(text: widget.course.description);
    _selectedDeadline = widget.course.deadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onPickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: AppTheme.themeData.copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  void _onSaveCourse() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final description = _descriptionController.text.trim();
    setState(() => _isSaving = true);

    final updated = widget.course.copyWith(
      title: title,
      description: description,
      deadline: _selectedDeadline,
    );

    try {
      await getIt<CoursesController>().updateCourse(updated);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Course "$title" updated'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onDeleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        ),
        title: const Text('Delete Course?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.course.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await getIt<CoursesController>().deleteCourse(widget.course.id);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // theme_rules Rule 3: repaint on theme switch.
    Theme.of(context);
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
                Text(
                  'Edit Course',
                  style: AppTheme.headingSmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 22),
                  onPressed: _onDeleteCourse,
                  tooltip: 'Delete Course',
                ),
              ],
            ),
            const VGapMd(),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(fontSize: 15, color: AppTheme.textPrimaryColor(context)),
              decoration: InputDecoration(
                labelText: 'Course Title',
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
                labelText: 'Description',
                filled: true,
                fillColor: AppTheme.surfaceVariant(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const VGapMd(),
            InkWell(
              onTap: _onPickDeadline,
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
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
                        _selectedDeadline == null
                            ? 'No Deadline set'
                            : 'Deadline: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VGapLg(),
            PillButton(
              text: 'Save Changes',
              onPressed: _onSaveCourse,
              icon: Icons.check_rounded,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
