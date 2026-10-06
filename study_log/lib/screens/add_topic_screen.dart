import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/study_text_fields.dart';
import '../services/local_topic_storage.dart';
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
  late final TextEditingController _orderController;

  late String _selectedModuleTitle;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _orderController = TextEditingController();
    _selectedModuleTitle = widget.moduleTitle;
    _descriptionController.addListener(_onDescriptionChanged);

    final editing = widget.topicToEdit;
    if (editing != null) {
      _nameController.text = editing.title;
      _descriptionController.text = editing.description;
      _orderController.text = '${editing.orderIndex}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    _orderController.dispose();
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
    final order = int.tryParse(_orderController.text.trim()) ?? 0;
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

        final existing = await LocalTopicStorage.loadTopicsForModule(
          moduleId: moduleId,
          fallbackTitle: _selectedModuleTitle,
        );
        final updated = existing.map((t) => t.id == savedTopic.id ? savedTopic : t).toList();
        final key = moduleId.isNotEmpty ? moduleId : _selectedModuleTitle;
        await LocalTopicStorage.saveTopics(key, updated);


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

        final existing = await LocalTopicStorage.loadTopicsForModule(
          moduleId: moduleId,
          fallbackTitle: _selectedModuleTitle,
        );
        final updated = existing
            .where((t) =>
                t.id != savedTopic.id &&
                t.title.trim().toLowerCase() != savedTopic.title.trim().toLowerCase())
            .toList()
          ..add(savedTopic);
        final key = moduleId.isNotEmpty ? moduleId : _selectedModuleTitle;
        await LocalTopicStorage.saveTopics(key, updated);


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
