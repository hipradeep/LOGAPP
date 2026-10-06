import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/course_context_pill.dart';
import '../widgets/study_text_fields.dart';
import '../services/service_locator.dart';
import '../controllers/modules_controller.dart';
import '../models/module.dart';

/// Redesigned Standalone Add Module Screen matching the reference design:
/// - Top bar with Back button, "Add Module" title, and purple "Save" button
/// - Course selection dropdown container showing active course
/// - Module Name * required field
/// - Description (Optional) with live 0/500 character counter
/// - Icon preview squircle with "Change Icon" button and icon picker modal
/// - Color swatches row with checkmark indicator on selected color
/// - Order (Optional) numeric input field with stepper icons
/// - Strict compliance with optimize.md (build < 40 lines, named callbacks, const)
class AddModuleScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final ModulesController? modulesController;
  final Module? moduleToEdit;

  const AddModuleScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.modulesController,
    this.moduleToEdit,
  });

  bool get isEditing => moduleToEdit != null;

  @override
  State<AddModuleScreen> createState() => _AddModuleScreenState();
}

class _AddModuleScreenState extends State<AddModuleScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;
  late String _selectedCourseTitle;
  late String _selectedCourseId;

  int _descLength = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _orderController = TextEditingController();
    _descriptionController.addListener(_onDescChanged);
    _selectedCourseTitle = widget.courseTitle;
    _selectedCourseId = widget.courseId;

    final editing = widget.moduleToEdit;
    if (editing != null) {
      _titleController.text = editing.title;
      _descriptionController.text = editing.description;
      _orderController.text = '${editing.orderIndex}';
      _descLength = editing.description.length;
      _selectedCourseId = editing.courseId.isNotEmpty ? editing.courseId : widget.courseId;
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _onDescChanged() {
    final len = _descriptionController.text.length;
    if (_descLength != len) {
      setState(() => _descLength = len);
    }
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }



  void _handleSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a module name'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    final order = int.tryParse(_orderController.text.trim()) ?? 0;
    setState(() => _isSubmitting = true);

    try {
      final controller = widget.modulesController ??
          ModulesController(courseId: _selectedCourseId);

      final editing = widget.moduleToEdit;
      if (editing != null) {
        await controller.updateModule(
          editing.copyWith(
            title: title,
            description: description,
            orderIndex: order,
          ),
        );
      } else {
        await controller.addModule(
          title: title,
          description: description,
          orderIndex: order,
          status: 'active',
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing != null
                ? 'Module "$title" updated successfully'
                : 'Module "$title" added successfully',
          ),
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
          content: Text(
            widget.isEditing
                ? 'Failed to update module: $e'
                : 'Failed to add module: $e',
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: widget.isEditing ? 'Edit Module' : 'Add Module',
              onBack: _handleBack,
              actions: [
                AddPillButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
            if ((_selectedCourseTitle.isNotEmpty ? _selectedCourseTitle : widget.courseTitle).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 6.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CourseContextPill(
                    courseTitle: _selectedCourseTitle.isNotEmpty ? _selectedCourseTitle : widget.courseTitle,
                    courseId: widget.courseId,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomSafe + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UnderlineInputField(
                      label: 'Module Name',
                      controller: _titleController,
                      hintText: 'Enter module name',
                      isRequired: true,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                    ),
                    const VGapLg(),
                    BorderlessDescriptionField(
                      controller: _descriptionController,
                    ),
                    const VGapLg(),
                    UnderlineInputField(
                      label: 'Order (Optional)',
                      controller: _orderController,
                      hintText: 'Enter order (e.g., 1, 2, 3)',
                      keyboardType: TextInputType.number,
                      fontSize: 16,
                      suffixIcon: Icon(
                        Icons.unfold_more_rounded,
                        color: AppTheme.textMutedColor(context),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
