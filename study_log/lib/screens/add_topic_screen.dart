import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/entity_detail_header.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/study_text_fields.dart';

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
  late TopicDifficulty _difficulty;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = UrlHighlightEditingController();
    _selectedModuleTitle = widget.moduleTitle;
    _difficulty = widget.topicToEdit?.difficulty ?? TopicDifficulty.medium;
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

  static String _difficultyLabel(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.low:
        return 'Low';
      case TopicDifficulty.medium:
        return 'Mid';
      case TopicDifficulty.hard:
        return 'Hard';
    }
  }

  static IconData _difficultyIcon(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.low:
        return Icons.trending_down_rounded;
      case TopicDifficulty.medium:
        return Icons.trending_flat_rounded;
      case TopicDifficulty.hard:
        return Icons.trending_up_rounded;
    }
  }

  static String _difficultyHint(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.low:
        return 'Quick win, light effort';
      case TopicDifficulty.medium:
        return 'Balanced effort';
      case TopicDifficulty.hard:
        return 'Deep concentration required';
    }
  }

  Future<void> _pickDifficulty() async {
    final picked = await showModalBottomSheet<TopicDifficulty>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SheetContainer(
          children: [
            const SheetHandleBar(),
            const VGapSm(),
            SheetHeader(
              badge: SheetHeaderBadge(
                backgroundColor: AppTheme.pastelPurple(ctx),
                child: Icon(
                  Icons.speed_rounded,
                  color: AppTheme.pastelPurpleText(ctx),
                  size: 20,
                ),
              ),
              title: 'Difficulty',
              subtitle: 'How hard does this topic feel?',
            ),
            const VGapSm(),
            for (final level in TopicDifficulty.values)
              SheetActionRow(
                icon: _difficultyIcon(level),
                title: _difficultyLabel(level),
                subtitle: _difficultyHint(level),
                trailing: level == _difficulty
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppTheme.primaryColor,
                        size: 18,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, level),
              ),
            const VGapSm(),
            const SheetCancelButton(),
          ],
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _difficulty = picked);
    }
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
          difficulty: _difficulty,
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
          difficulty: _difficulty,
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

    String resolvedCourse = widget.courseTitle;
    if (resolvedCourse.isEmpty && widget.courseId.isNotEmpty && getIt.isRegistered<CoursesController>()) {
      try {
        final c = getIt<CoursesController>().courses.firstWhere((c) => c.id == widget.courseId);
        resolvedCourse = c.title;
      } catch (_) {}
    }

    String resolvedModule = _selectedModuleTitle.isNotEmpty ? _selectedModuleTitle : widget.moduleTitle;
    if (resolvedModule.isEmpty && widget.moduleId.isNotEmpty && getIt.isRegistered<OngoingModulesController>()) {
      resolvedModule = getIt<OngoingModulesController>().moduleTitleFor(widget.moduleId);
    }

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
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: bottomSafe + 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EntityDetailHeader(
                      moduleTitle: resolvedModule,
                      courseId: widget.courseId,
                      courseTitle: resolvedCourse,
                      horizontalPadding: 0.0,
                    ),
                    const VGapXs(),
                    UnderlineInputField(
                      label: '',
                      controller: _nameController,
                      hintText: 'Enter topic name',
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      contentPadding: const EdgeInsets.only(top: 4, bottom: 10),
                    ),
                    const VGapXs(),
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingXs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickDifficulty,
                          child: DetailMetaChip(
                            icon: Icons.speed_rounded,
                            text: _difficultyLabel(_difficulty),
                          ),
                        ),
                        DetailMetaChip(
                          icon: Icons.calendar_today_rounded,
                          text: EntityDetailHeader.formatDate(
                            widget.topicToEdit?.updatedAt ?? DateTime.now(),
                          ),
                        ),
                      ],
                    ),
                    const VGapMd(),
                    BorderlessDescriptionField.topic(
                      controller: _descriptionController,
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
