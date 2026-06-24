import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/expandable_description.dart';
import '../models/activity.dart';
import '../widgets/app_popup_menu_button.dart';
import '../widgets/app_text_action_button.dart';

class AddActivityScreen extends StatefulWidget {
  final Function(String name, String trackingType, int targetCount, {
    List<int> repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates,
    String? description,
    bool skippable,
    bool reminderEnabled,
    double weight,
    int points,
    int focusDuration,
    bool isPomodoroFocusEnabled,
  }) onAdd;
  final Activity? initialActivity;
  final String? initialTrackingType;
  final Function(String name, String trackingType, int targetCount, {
    List<int> repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates,
    String? description,
    bool skippable,
    bool reminderEnabled,
    double weight,
    int points,
    int focusDuration,
    bool isPomodoroFocusEnabled,
  })? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;

  const AddActivityScreen({
    super.key,
    required this.onAdd,
    this.initialActivity,
    this.initialTrackingType,
    this.onEdit,
    this.onDelete,
    this.onToggleActive,
  });

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> with WidgetsBindingObserver {
  final TextEditingController _activityNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subTaskInputController = TextEditingController();
  final List<String> _subTasks = [];
  final FocusNode _focusNode = FocusNode();
  String _trackingType = 'single'; // 'single', 'multiple', or 'milestone'
  bool _canUnfocus = false;
  final Set<int> _draggedIndices = {};
  bool _dragSelectMode = true;
  bool _skippable = false;
  bool _reminderEnabled = true;
  double _weight = 1.0;
  int _points = 10;
  int _focusDuration = 25;
  bool _isPomodoroFocusEnabled = false;

  // Schedule fields
  List<int> _repeatDays = [1, 2, 3, 4, 5, 6, 7];
  TimeOfDay? _scheduledTime;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _subTaskTime;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayValues = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialActivity != null) {
      final a = widget.initialActivity!;
      _activityNameController.text = a.name;
      _descriptionController.text = a.description ?? '';
      _trackingType = a.trackingType;
      _repeatDays = List<int>.from(a.repeatDays);
      if (a.scheduledTime != null) {
        final parts = a.scheduledTime!.split(':');
        _scheduledTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      _startDate = a.startDate;
      _endDate = a.endDate;
      if (a.subTaskTemplates.isNotEmpty) {
        _subTasks.addAll(a.subTaskTemplates);
      }
      _skippable = a.skippable;
      _reminderEnabled = a.reminderEnabled;
      _weight = a.weight;
      _points = a.points;
      _focusDuration = a.focusDuration;
      _isPomodoroFocusEnabled = a.isPomodoroFocusEnabled;
    } else if (widget.initialTrackingType != null) {
      _trackingType = widget.initialTrackingType!;
    }

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activityNameController.dispose();
    _descriptionController.dispose();
    _subTaskInputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (mounted) {
      final view = View.of(context);
      final bottomInset = view.viewInsets.bottom;
      if (bottomInset > 0) {
        _canUnfocus = true;
      } else if (bottomInset == 0 && _canUnfocus) {
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
        _canUnfocus = false;
      }
    }
  }

  String? _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimeForDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _submit() {
    final name = _activityNameController.text.trim();
    if (name.isEmpty) return;

    if (_trackingType == 'multiple' && _subTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one recurring task is required for Multiple activities.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final finalSubTasks = _trackingType == 'multiple' ? _subTasks : <String>[];
    final finalTargetCount = _trackingType == 'single'
        ? 1
        : (_trackingType == 'multiple' ? finalSubTasks.length : 1);

    final timeStr = _trackingType == 'multiple' ? null : _formatTimeOfDay(_scheduledTime);

    final descriptionStr = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();

    if (widget.initialActivity != null && widget.onEdit != null) {
      widget.onEdit!(
        name,
        _trackingType,
        finalTargetCount,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        startDate: _startDate,
        endDate: _endDate,
        subTaskTemplates: finalSubTasks,
        description: descriptionStr,
        skippable: _skippable,
        reminderEnabled: _reminderEnabled,
        weight: _weight,
        points: _points,
        focusDuration: _focusDuration,
        isPomodoroFocusEnabled: _isPomodoroFocusEnabled,
      );
    } else {
      widget.onAdd(
        name,
        _trackingType,
        finalTargetCount,
        repeatDays: _repeatDays,
        scheduledTime: timeStr,
        startDate: _startDate,
        endDate: _endDate,
        subTaskTemplates: finalSubTasks,
        description: descriptionStr,
        skippable: _skippable,
        reminderEnabled: _reminderEnabled,
        weight: _weight,
        points: _points,
        focusDuration: _focusDuration,
        isPomodoroFocusEnabled: _isPomodoroFocusEnabled,
      );
    }
    Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        final currentTheme = Theme.of(context);
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surface(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        final currentTheme = Theme.of(context);
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surface(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FullScreenPage(
        showScaffold: true,
        isScrollable: true,
        title: widget.initialActivity != null ? 'Edit Activity' : 'New Activity',
        showBackButton: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          if (widget.initialActivity == null || widget.initialActivity!.isActive)
            AppTextActionButton(
              label: 'Save',
              onPressed: _submit,
            ),
          if (widget.initialActivity != null) ...[
            AppPopupMenuButton(
              onSelected: (value) {
                if (value == 'delete') {
                  widget.onDelete?.call();
                } else if (value == 'toggle') {
                  widget.onToggleActive?.call();
                }
              },
              itemBuilder: (context) {
                final isInactive = !(widget.initialActivity!.isActive);
                return [
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isInactive ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          color: isInactive ? AppTheme.successColor : AppTheme.warningColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isInactive ? 'Activate Tracking' : 'Deactivate Tracking',
                          style: TextStyle(
                            color: isInactive ? AppTheme.successColor : AppTheme.warningColor,
                            fontWeight: isInactive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Delete Activity',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ],

        children: [
          // Text Field
          _buildInputField(),
          const VGapLg(),

          // Activity Type
          _buildSectionLabel('ACTIVITY TYPE'),
          const VGapSm(),
          _buildTypeChips(),
          const VGapMd(),
          _buildTypeDescription(),

          // Show recurring tasks input for Multiple
          if (_trackingType == 'multiple') ...[
            const VGapLg(),
            _buildSectionLabel('RECURRING TASKS (REQUIRED)'),
            const VGapSm(),
            _buildSubTaskTemplatesField(),
          ],
          const VGapLg(),

          // Repeat Days
          _buildSectionLabel('REPEAT DAYS'),
          const VGapSm(),
          _buildRepeatDaysRow(),
          const VGapLg(),

          // Remind Me At (Only for Single and Milestone activities)
          if (_trackingType != 'multiple') ...[
            _buildSectionLabel('REMIND ME AT'),
            const VGapSm(),
            _buildTimePickerRow(),
            const VGapLg(),
          ],

          // Start & End Date
          _buildSectionLabel('DATE RANGE'),
          const VGapSm(),
          _buildDateRangeRow(),
          if (_startDate != null && _endDate != null) ...[
            const VGapMd(),
          ],
          const VGapLg(),

          // Options
          _buildSectionLabel('OPTIONS'),
          const VGapSm(),
          _buildSkippableToggle(),
          const VGapMd(),
          _buildReminderEnabledToggle(),
          if (_trackingType != 'multiple') ...[
            const VGapMd(),
            _buildPomodoroFocusToggle(),
          ],
          const VGapLg(),

          // Focus Time (Only for Single activities and if enabled)
          if (_trackingType == 'single' && _isPomodoroFocusEnabled) ...[
            _buildSectionLabel('FOCUS TIME'),
            const VGapSm(),
            _buildFocusDurationSelector(),
            const VGapLg(),
          ],

          // Weight / Priority
          _buildSectionLabel('WEIGHT / PRIORITY'),
          const VGapSm(),
          _buildWeightSelector(),
          const VGapLg(),

          // Base Points / XP
          _buildSectionLabel('BASE REWARD (XP / COINS)'),
          const VGapSm(),
          _buildPointsSelector(),
          const VGapLg(),

          // Description
          _buildSectionLabel('DESCRIPTION'),
          const VGapSm(),
          _buildDescriptionInputField(),
          const VGapLg(),
        ],
      ),
    );
  }

  Widget _buildDescriptionInputField() {
    return TextField(
      controller: _descriptionController,
      maxLines: null,
      minLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(
        color: AppTheme.textPrimaryColor(context),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: 'Enter activity description (optional)...',
        hintStyle: TextStyle(
          color: AppTheme.hintColor(context),
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppTheme.surface(context).withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSkippableToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.double_arrow_rounded,
                  color: _skippable ? AppTheme.warningColor : AppTheme.textSecondaryColor(context),
                  size: 20,
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Skippable',
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const VGapXs(),
                      Text(
                        'Allow skipping this activity for the day',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _skippable,
            onChanged: (val) {
              setState(() {
                _skippable = val;
              });
            },
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primaryColor,
            inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
            inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
          ),
        ],
      ),
    );
  }

  static const List<int> _focusPresets = [15, 20, 25, 30, 45, 60, 90];

  Widget _buildFocusDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _focusPresets.map((mins) {
            final selected = _focusDuration == mins;
            return GestureDetector(
              onTap: () => setState(() => _focusDuration = mins),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.surface(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: Text(
                  '${mins}m',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? AppTheme.primaryAccentColor(context)
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const VGapMd(),
        Row(
          children: [
            Icon(Icons.timer_rounded, size: 18, color: AppTheme.primaryAccentColor(context)),
            const HGapSm(),
            Expanded(
              child: Slider(
                value: _focusDuration.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                activeColor: AppTheme.primaryColor,
                inactiveColor: AppTheme.subtleFillColor(context),
                label: '${_focusDuration}m',
                onChanged: (val) => setState(() => _focusDuration = val.round()),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${_focusDuration}m',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPomodoroFocusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.center_focus_strong_rounded,
                  color: _isPomodoroFocusEnabled
                      ? AppTheme.primaryAccentColor(context)
                      : AppTheme.textSecondaryColor(context),
                  size: 20,
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         'Enable Pomodoro Focus',
                         style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                       ),
                       const VGapXs(),
                       Text(
                         'Start a focus timer when this activity runs',
                         style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context), fontSize: 11),
                       ),
                     ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPomodoroFocusEnabled,
            onChanged: (val) => setState(() => _isPomodoroFocusEnabled = val),
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primaryColor,
            inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
            inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderEnabledToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: _reminderEnabled ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
                  size: 20,
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reminders Enabled',
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const VGapXs(),
                      Text(
                        'Receive alarm notifications for this activity',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondaryColor(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _reminderEnabled,
            onChanged: (val) {
              setState(() {
                _reminderEnabled = val;
              });
            },
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            activeThumbColor: AppTheme.primaryColor,
            inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
            inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondaryColor(context),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('ACTIVITY NAME'),
        const VGapSm(),
        TextField(
          controller: _activityNameController,
          focusNode: _focusNode,
          autofocus: false,
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          keyboardType: TextInputType.text,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: 'Enter activity name...',
            hintStyle: GoogleFonts.outfit(
              color: AppTheme.hintColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: false,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.inputBorderColor(context),
                width: 1.5,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.inputBorderColor(context),
                width: 1.5,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.edit_note_rounded,
                color: AppTheme.primaryAccentColor(context),
                size: 28,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChips() {
    return Row(
      children: [
        _buildTypeChip('Single', 'single', Icons.bolt_rounded),
        const HGapSm(),
        _buildTypeChip('Multiple', 'multiple', Icons.repeat_rounded),
        const HGapSm(),
        _buildTypeChip('Milestone', 'milestone', Icons.flag_rounded),
      ],
    );
  }

  Widget _buildTypeChip(String label, String value, IconData icon) {
    final isSelected = _trackingType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _trackingType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : AppTheme.surface(context).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : AppTheme.borderColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDragStart(Offset localPosition, double rowWidth) {
    final colWidth = rowWidth / 7;
    final index = (localPosition.dx / colWidth).floor().clamp(0, 6);
    final dayValue = _dayValues[index];
    final isSelected = _repeatDays.contains(dayValue);

    _draggedIndices.clear();
    _draggedIndices.add(index);
    _dragSelectMode = !isSelected;

    setState(() {
      if (_dragSelectMode) {
        if (!_repeatDays.contains(dayValue)) {
          _repeatDays.add(dayValue);
          _repeatDays.sort();
        }
      } else {
        if (_repeatDays.length > 1) {
          _repeatDays.remove(dayValue);
        }
      }
    });
  }

  void _handleDragUpdate(Offset localPosition, double rowWidth) {
    final colWidth = rowWidth / 7;
    final index = (localPosition.dx / colWidth).floor().clamp(0, 6);
    if (!_draggedIndices.contains(index)) {
      _draggedIndices.add(index);
      final dayValue = _dayValues[index];
      setState(() {
        if (_dragSelectMode) {
          if (!_repeatDays.contains(dayValue)) {
            _repeatDays.add(dayValue);
            _repeatDays.sort();
          }
        } else {
          if (_repeatDays.length > 1) {
            _repeatDays.remove(dayValue);
          }
        }
      });
    }
  }

  Widget _buildRepeatDaysRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        return Listener(
          onPointerDown: (event) => _handleDragStart(event.localPosition, rowWidth),
          onPointerMove: (event) => _handleDragUpdate(event.localPosition, rowWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final dayValue = _dayValues[index];
              final isSelected = _repeatDays.contains(dayValue);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.surface(context).withValues(alpha: 0.3),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.7)
                        : AppTheme.borderColor(context),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _dayLabels[index],
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildTimePickerRow() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _scheduledTime != null
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: _scheduledTime != null ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
              size: 20,
            ),
            const HGapMd(),
            Expanded(
              child: Text(
                _scheduledTime != null
                    ? _formatTimeForDisplay(_scheduledTime!)
                    : 'No specific time set',
                style: TextStyle(
                  color: _scheduledTime != null ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                  fontSize: 14,
                ),
              ),
            ),
            if (_scheduledTime != null)
              GestureDetector(
                onTap: () => setState(() => _scheduledTime = null),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeRow() {
    return Row(
      children: [
        Expanded(child: _buildDateField('Start', _startDate, isStart: true)),
        const HGapMd(),
        Expanded(child: _buildDateField('End', _endDate, isStart: false)),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, {required bool isStart}) {
    return GestureDetector(
      onTap: () => _pickDate(isStart: isStart),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: date != null ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? DateFormat('MMM d, yyyy').format(date) : 'Not set',
                    style: TextStyle(
                      color: date != null ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isStart) {
                      _startDate = null;
                    } else {
                      _endDate = null;
                    }
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }





  void _addSubTask() {
    final text = _subTaskInputController.text.trim();
    if (text.isNotEmpty) {
      final taskWithSchedule = _subTaskTime != null
          ? '$text|${_formatTimeOfDay(_subTaskTime)}'
          : text;
      final nameExists = _subTasks.any((t) => t.split('|').first.toLowerCase() == text.toLowerCase());
      if (!nameExists) {
        setState(() {
          _subTasks.add(taskWithSchedule);
          _subTaskTime = null;
        });
      }
      _subTaskInputController.clear();
    }
  }

  Future<void> _pickSubTaskTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _subTaskTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        final currentTheme = Theme.of(context);
        return Theme(
          data: currentTheme.copyWith(
            colorScheme: currentTheme.colorScheme.copyWith(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surface(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _subTaskTime = picked);
    }
  }

  String _formatTimeString(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2) return time24h;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final time = TimeOfDay(hour: hour, minute: minute);
      return _formatTimeForDisplay(time);
    } catch (_) {
      return time24h;
    }
  }

  Widget _buildTypeDescription() {
    String description;
    IconData icon;
    switch (_trackingType) {
      case 'single':
        description = 'Single tracking is for simple habits or daily tasks that you check off once a day (e.g., gym, reading).';
        icon = Icons.bolt_rounded;
        break;
      case 'multiple':
        description = 'Multiple tracking is for activities that consist of a checklist of recurring sub-tasks that you complete individually throughout the day.';
        icon = Icons.repeat_rounded;
        break;
      case 'milestone':
      default:
        description = 'Milestone activities help you track progress toward long-term goals by completing specific, chronological tasks. These tasks are added and managed directly on the Milestones Tab.';
        icon = Icons.flag_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              icon,
              color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          const HGapMd(),
          Expanded(
            child: ExpandableDescription(
              text: description,
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTaskTemplatesField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Underline Input Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskInputController,
                    style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 14),
                    onSubmitted: (_) => _addSubTask(),
                    decoration: InputDecoration(
                      hintText: 'Add task...',
                      hintStyle: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 13),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.borderColor(context), width: 1),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickSubTaskTime,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: _subTaskTime != null ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _addSubTask,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppTheme.primaryAccentColor(context),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_subTaskTime != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppTheme.primaryAccentColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeForDisplay(_subTaskTime!),
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _subTaskTime = null),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_subTasks.isNotEmpty) ...[
            const VGapMd(),
            Divider(color: AppTheme.borderColor(context), height: 1, indent: 0, endIndent: 0),
            const VGapSm(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _subTasks.length,
              itemBuilder: (context, index) {
                final subTaskStr = _subTasks[index];
                final parts = subTaskStr.split('|');
                final subTaskName = parts.first;
                final subTaskTimeStr = parts.length > 1 ? parts[1] : null;
                final isLast = index == _subTasks.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: Row(
                    children: [
                      // Sub-task indicator dot/circle
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryAccentColor(context).withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      const HGapMd(),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                subTaskName,
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (subTaskTimeStr != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 10,
                                      color: AppTheme.primaryAccentColor(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimeString(subTaskTimeStr),
                                      style: TextStyle(
                                        color: AppTheme.primaryAccentColor(context),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _subTasks.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleFillColor(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightSelector() {
    return Row(
      children: [
        _buildWeightChip('Low (1.0)', 1.0, AppTheme.successColor),
        const HGapSm(),
        _buildWeightChip('Medium (2.0)', 2.0, AppTheme.secondaryColor),
        const HGapSm(),
        _buildWeightChip('High (3.0)', 3.0, AppTheme.warningColor),
      ],
    );
  }

  Widget _buildWeightChip(String label, double value, Color activeColor) {
    final isSelected = _weight == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _weight = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : AppTheme.surface(context).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.6)
                  : AppTheme.borderColor(context),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointsSelector() {
    final pointOptions = [5, 10, 20, 50];
    return Row(
      children: pointOptions.map((pts) {
        final isSelected = _points == pts;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => setState(() => _points = pts),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.12)
                      : AppTheme.surface(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.6)
                        : AppTheme.borderColor(context),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$pts XP',
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
