import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
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

  IconData _selectedIcon = Icons.format_list_bulleted_rounded;
  Color _selectedColor = const Color(0xFF5B4DFB);
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

  void _selectColor(Color color) {
    if (_selectedColor == color) return;
    setState(() => _selectedColor = color);
  }

  void _openCourseSelector() {
    if (widget.isEditing) return;
    final allCourses = getIt<CoursesController>().courses;
    if (allCourses.isEmpty) return;

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
                  'Select Course',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const VGapMd(),
                ...allCourses.map((c) => ListTile(
                      title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: c.id == _selectedCourseId
                          ? const Icon(Icons.check_rounded, color: AppTheme.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCourseId = c.id;
                          _selectedCourseTitle = c.title;
                        });
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
    final icons = [
      Icons.format_list_bulleted_rounded,
      Icons.code_rounded,
      Icons.settings_suggest_rounded,
      Icons.smart_toy_rounded,
      Icons.android_rounded,
      Icons.cloud_outlined,
      Icons.hub_outlined,
      Icons.menu_book_rounded,
      Icons.terminal_rounded,
      Icons.data_object_rounded,
      Icons.psychology_rounded,
      Icons.school_rounded,
    ];

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
                  'Select Module Icon',
                  style: TextStyle(
                    fontSize: 16,
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
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: icons.length,
                  itemBuilder: (context, index) {
                    final icon = icons[index];
                    final isSelected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIcon = icon);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF3F0FF) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
                            width: isSelected ? 1.5 : 1.0,
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
            _AddModuleTopBar(
              title: widget.isEditing ? 'Edit Module' : 'Add Module',
              onBack: _handleBack,
              onSave: _handleSubmit,
              isSubmitting: _isSubmitting,
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
                    if (!widget.isEditing) ...[
                      _CourseSelectorField(
                        courseTitle: _selectedCourseTitle,
                        onTap: _openCourseSelector,
                      ),
                      const VGapLg(),
                    ],
                    _ModuleNameField(controller: _titleController),
                    const VGapLg(),
                    _ModuleDescriptionField(
                      controller: _descriptionController,
                      charCount: _descLength,
                    ),
                    const VGapLg(),
                    _ModuleIconModule(
                      selectedIcon: _selectedIcon,
                      onOpenPicker: _openIconPicker,
                    ),
                    const VGapLg(),
                    _ModuleColorModule(
                      selectedColor: _selectedColor,
                      onSelectColor: _selectColor,
                    ),
                    const VGapLg(),
                    _ModuleOrderField(controller: _orderController),
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

class _AddModuleTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool isSubmitting;
  final String title;

  const _AddModuleTopBar({
    required this.onBack,
    required this.onSave,
    required this.isSubmitting,
    this.title = 'Add Module',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
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
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          AddPillButton(
            label: 'Save',
            icon: Icons.check_rounded,
            isLoading: isSubmitting,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _CourseSelectorField extends StatelessWidget {
  final String courseTitle;
  final VoidCallback onTap;

  const _CourseSelectorField({
    required this.courseTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Course',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  courseTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF6B7280),
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

class _ModuleNameField extends StatelessWidget {
  final TextEditingController controller;

  const _ModuleNameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Module Name ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            Text(
              '*',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const VGapSm(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimaryColor(context),
            ),
            decoration: const InputDecoration(
              hintText: 'Enter module name',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleDescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final int charCount;

  const _ModuleDescriptionField({
    required this.controller,
    required this.charCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          padding: const EdgeInsets.all(14),
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
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter description',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Text(
                '$charCount/500',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleIconModule extends StatelessWidget {
  final IconData selectedIcon;
  final VoidCallback onOpenPicker;

  const _ModuleIconModule({
    required this.selectedIcon,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
                color: const Color(0xFFF3F0FF),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                selectedIcon,
                color: AppTheme.primaryColor,
                size: 26,
              ),
            ),
            const HGapMd(),
            Material(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onOpenPicker,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Change Icon',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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

class _ModuleColorModule extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onSelectColor;

  const _ModuleColorModule({
    required this.selectedColor,
    required this.onSelectColor,
  });

  static const List<Color> _availableColors = [
    Color(0xFF5B4DFB),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF6B7280),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          children: _availableColors.map((color) {
            final isSelected = color == selectedColor;
            return GestureDetector(
              onTap: () => onSelectColor(color),
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ModuleOrderField extends StatelessWidget {
  final TextEditingController controller;

  const _ModuleOrderField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter order (e.g., 1, 2, 3)',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const Icon(
                Icons.unfold_more_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
