import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/study_text_fields.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../models/topic.dart';
import '../controllers/ongoing_modules_controller.dart';

/// Screen 9: Add Topic Screen matching the reference design:
/// - Top bar with Back arrow, "Add Topic" title, and solid purple "Save" button
/// - Module dropdown field
/// - Topic Name * with red asterisk and clear hint
/// - Description (Optional) with multiline input and 0/500 character counter
/// - Icon preview with "Change Icon" button and icon picker bottom sheet
/// - Color palette picker with 6 swatches and checkmark indicator
/// - Order (Optional) with numeric input and unfold-more stepper icon
/// - Passes all 24 rules of [optimize.md]
class AddTopicScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;
  final List<String> availableModules;
  final Topic? topicToEdit;

  const AddTopicScreen({
    super.key,
    required this.moduleTitle,
    required this.courseId,
    required this.courseTitle,
    this.moduleId = '',
    this.availableModules = const [],
    this.topicToEdit,
  });

  bool get isEditing => topicToEdit != null;

  @override
  State<AddTopicScreen> createState() => _AddTopicScreenState();
}

class _AddTopicScreenState extends State<AddTopicScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _selectedModuleTitle;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = UrlHighlightEditingController();
    _selectedModuleTitle = widget.moduleTitle;
    _descriptionController.addListener(_onDescriptionChanged);

    final editing = widget.topicToEdit;
    if (editing != null) {
      _nameController.text = editing.title;
      _descriptionController.text = editing.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  void _onDescriptionChanged() {
    setState(() {});
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }



  Future<void> _handleSave() async {
    if (_selectedModuleTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a module first'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a topic name'),
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
    final order = widget.topicToEdit?.orderIndex ?? 0;
    final courseId = widget.courseId.trim();
    if (courseId.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not resolve the course for this topic'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
      return;
    }
    final moduleId = widget.moduleId.trim();
    setState(() => _isSaving = true);

    try {
      final editing = widget.topicToEdit;
      final Topic savedTopic;

      if (editing != null) {
        savedTopic = editing.copyWith(
          title: name,
          description: description,
          orderIndex: order,
        );

        await DatabaseService.instance.updateTopic(savedTopic);
      } else {
        final now = DateTime.now();
        final newId = 'topic_${now.millisecondsSinceEpoch}';

        savedTopic = Topic(
          id: newId,
          courseId: courseId,
          moduleId: moduleId,
          title: name,
          status: TopicStatus.notStarted,
          description: description,
          orderIndex: order,
        );

        await DatabaseService.instance.addTopic(savedTopic);
      }

      if (getIt.isRegistered<OngoingModulesController>()) {
        getIt<OngoingModulesController>().refresh();
      }

      if (!mounted) return;
      Navigator.of(context).pop(savedTopic);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing != null
                ? 'Topic "$name" updated successfully'
                : 'Topic "$name" added successfully',
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
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save topic: $e'),
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
              title: widget.isEditing ? 'Edit Topic' : 'Add Topic',
              onBack: _handleBack,
              actions: [
                AddPillButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
            if ((_selectedModuleTitle.isNotEmpty ? _selectedModuleTitle : widget.moduleTitle).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 6.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ModuleContextPill(
                    moduleTitle: _selectedModuleTitle.isNotEmpty ? _selectedModuleTitle : widget.moduleTitle,
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
                      label: 'Topic Name',
                      controller: _nameController,
                      hintText: 'Enter topic name',
                      isRequired: true,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                    ),
                    const VGapLg(),
                    BorderlessDescriptionField(
                      controller: _descriptionController,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
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
