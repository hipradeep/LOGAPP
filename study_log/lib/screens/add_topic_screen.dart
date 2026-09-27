import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../services/local_topic_storage.dart';
import '../services/local_module_storage.dart';
import '../services/service_locator.dart';
import '../services/firestore_service.dart';
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

  const AddTopicScreen({
    super.key,
    required this.moduleTitle,
    required this.courseId,
    required this.courseTitle,
    this.moduleId = '',
    this.availableModules = const [],
  });

  @override
  State<AddTopicScreen> createState() => _AddTopicScreenState();
}

class _AddTopicScreenState extends State<AddTopicScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _orderController;

  late String _selectedModuleTitle;
  IconData _selectedIcon = Icons.format_list_bulleted_rounded;
  int _selectedColorIndex = 0;
  bool _isSaving = false;
  bool _isPickingModule = false;

  static const List<Color> _swatchColors = [
    Color(0xFF6366F1), // Purple (default)
    Color(0xFF10B981), // Emerald Green
    Color(0xFF3B82F6), // Blue
    Color(0xFFF59E0B), // Amber/Orange
    Color(0xFFEF4444), // Red/Coral
    Color(0xFF6B7280), // Slate/Gray
  ];

  static const List<IconData> _pickerIcons = [
    Icons.format_list_bulleted_rounded,
    Icons.code_rounded,
    Icons.functions_rounded,
    Icons.data_object_rounded,
    Icons.terminal_rounded,
    Icons.hub_outlined,
    Icons.account_tree_outlined,
    Icons.menu_book_rounded,
    Icons.psychology_rounded,
    Icons.insights_rounded,
    Icons.auto_stories_rounded,
    Icons.bolt_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _orderController = TextEditingController();
    _selectedModuleTitle = widget.moduleTitle;
    _descriptionController.addListener(_onDescriptionChanged);
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

  void _selectColor(int index) {
    if (_selectedColorIndex == index) return;
    setState(() => _selectedColorIndex = index);
  }

  void _selectIcon(IconData icon) {
    setState(() => _selectedIcon = icon);
  }

  Future<void> _openModulePicker() async {
    List<String> modules = List<String>.of(widget.availableModules);

    if (modules.isEmpty && widget.courseId.isNotEmpty) {
      setState(() => _isPickingModule = true);
      final stored = await LocalModuleStorage.loadModules(widget.courseId);
      if (!mounted) return;
      setState(() => _isPickingModule = false);
      modules = stored.map((s) => s.title).toList();
    }

    if (modules.isEmpty && widget.moduleTitle.isNotEmpty) {
      modules = <String>[widget.moduleTitle];
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const VGapMd(),
                Text(
                  'Select Module',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const VGapMd(),
                if (modules.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'No modules found for this course yet.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  )
                else
                  ...modules.map((sec) => ListTile(
                        title: Text(
                          sec,
                          style: TextStyle(
                            fontWeight: sec == _selectedModuleTitle
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: sec == _selectedModuleTitle
                                ? AppTheme.primaryColor
                                : AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        trailing: sec == _selectedModuleTitle
                            ? const Icon(Icons.check_rounded, color: AppTheme.primaryColor)
                            : null,
                        onTap: () {
                          setState(() => _selectedModuleTitle = sec);
                          Navigator.pop(ctx);
                        },
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openIconPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const VGapMd(),
                Text(
                  'Choose Icon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const VGapMd(),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _pickerIcons.length,
                  itemBuilder: (context, index) {
                    final icon = _pickerIcons[index];
                    final isSelected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () {
                        _selectIcon(icon);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF4B5563),
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
                const VGapMd(),
              ],
            ),
          ),
        );
      },
    );
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
      final now = DateTime.now();
      final newId = 'topic_${now.millisecondsSinceEpoch}';

      final newItem = Topic(
        id: newId,
        courseId: courseId,
        moduleId: moduleId,
        title: name,
        status: TopicStatus.notStarted,
        description: description,
        orderIndex: order,
        iconCodePoint: _selectedIcon.codePoint,
        colorValue: _swatchColors[_selectedColorIndex].toARGB32(),
      );

      // 1. Persist locally to storage cache
      final existing = await LocalTopicStorage.loadTopics(_selectedModuleTitle);
      final updated = List<Topic>.from(existing)..add(newItem);
      await LocalTopicStorage.saveTopics(_selectedModuleTitle, updated);

      // 2. Optionally sync the same record to Firestore if configured
      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable) {
          try {
            await firestore
                .addTopic(newItem)
                .timeout(const Duration(seconds: 3), onTimeout: () {});
          } catch (_) {}
        }
      }

      if (getIt.isRegistered<OngoingModulesController>()) {
        getIt<OngoingModulesController>().refresh();
      }

      if (!mounted) return;
      Navigator.of(context).pop(newItem);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Topic "$name" added successfully'),
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
            _AddTopicTopBar(
              onBack: _handleBack,
              onSave: _handleSave,
              isSaving: _isSaving,
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
                    _ModuleField(
                      selectedTitle: _selectedModuleTitle,
                      isLoading: _isPickingModule,
                      onTap: _openModulePicker,
                    ),
                    const VGapLg(),
                    _TopicNameField(controller: _nameController),
                    const VGapLg(),
                    _DescriptionField(
                      controller: _descriptionController,
                      currentLength: _descriptionController.text.length,
                    ),
                    const VGapLg(),
                    _IconField(
                      icon: _selectedIcon,
                      onPickIcon: _openIconPicker,
                    ),
                    const VGapLg(),
                    _ColorPaletteField(
                      colors: _swatchColors,
                      selectedIndex: _selectedColorIndex,
                      onSelectColor: _selectColor,
                    ),
                    const VGapLg(),
                    _OrderField(controller: _orderController),
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

class _AddTopicTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool isSaving;

  const _AddTopicTopBar({
    required this.onBack,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 28,
                ),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const HGapXs(),
              Text(
                'Add Topic',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          AddPillButton(
            label: 'Save',
            icon: Icons.check_rounded,
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _ModuleField extends StatelessWidget {
  final String selectedTitle;
  final VoidCallback onTap;
  final bool isLoading;

  const _ModuleField({
    required this.selectedTitle,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Module',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                else
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicNameField extends StatelessWidget {
  final TextEditingController controller;

  const _TopicNameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Topic Name ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
            children: [
              TextSpan(
                text: '*',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const VGapSm(),
        TextField(
          controller: controller,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter topic name',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppTheme.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final int currentLength;

  const _DescriptionField({
    required this.controller,
    required this.currentLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                decoration: const InputDecoration(
                  hintText: 'Enter description',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.normal,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Text(
                '$currentLength/500',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconField extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPickIcon;

  const _IconField({
    required this.icon,
    required this.onPickIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icon',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 26,
              ),
            ),
            const HGapMd(),
            InkWell(
              onTap: onPickIcon,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Change Icon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorPaletteField extends StatelessWidget {
  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onSelectColor;

  const _ColorPaletteField({
    required this.colors,
    required this.selectedIndex,
    required this.onSelectColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Row(
          children: List.generate(colors.length, (index) {
            final color = colors[index];
            final isSelected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () => onSelectColor(index),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _OrderField extends StatelessWidget {
  final TextEditingController controller;

  const _OrderField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Order (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter order (e.g., 1, 2, 3)',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: AppTheme.surface(context),
            suffixIcon: const Icon(
              Icons.unfold_more_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
