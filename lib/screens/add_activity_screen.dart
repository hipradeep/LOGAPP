import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../models/activity.dart';

class AddActivityScreen extends StatefulWidget {
  final Function(String name, String trackingType, int targetCount, {
    List<int> repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates,
    String? description,
  }) onAdd;
  final Activity? initialActivity;
  final Function(String name, String trackingType, int targetCount, {
    List<int> repeatDays,
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates,
    String? description,
  })? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleComplete;

  const AddActivityScreen({
    Key? key,
    required this.onAdd,
    this.initialActivity,
    this.onEdit,
    this.onDelete,
    this.onToggleComplete,
  }) : super(key: key);

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
    }
    // Request focus on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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
          content: Text('At least one recurring sub-task is required for Multiple activities.'),
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
      );
    }
    Navigator.pop(context);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
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
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FullScreenPage(
        showScaffold: true,
        isScrollable: true,
        title: widget.initialActivity != null ? 'Edit Activity' : 'New Activity',
        showBackButton: true,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          if (widget.initialActivity != null) ...[
            const SizedBox(width: 8),
            Transform.translate(
              offset: const Offset(10, 0),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  color: AppTheme.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      widget.onDelete?.call();
                    } else if (value == 'toggle') {
                      widget.onToggleComplete?.call();
                    }
                  },
                  itemBuilder: (context) {
                    final isCompleted = !(widget.initialActivity!.checked);
                    return [
                      PopupMenuItem<String>(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                              color: isCompleted ? Colors.white70 : AppTheme.successColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCompleted ? 'Mark Active' : 'Mark Complete',
                              style: TextStyle(
                                color: isCompleted ? Colors.white : AppTheme.successColor,
                                fontWeight: isCompleted ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Delete Activity',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ),
          ],
        ],
        backgroundWidgets: const [
          GlowBlob(
            top: -40,
            left: -40,
            size: 240,
            color: AppTheme.primaryColor,
            opacity: 0.1,
          ),
          GlowBlob(
            bottom: -50,
            right: -50,
            size: 280,
            color: AppTheme.secondaryColor,
            opacity: 0.05,
          ),
        ],
        children: [
          // Text Field
          _buildInputField(),
          const VGapLg(),

          // Activity Type
          _buildSectionLabel('ACTIVITY TYPE'),
          const VGapSm(),
          _buildTypeChips(),

          // Show recurring sub-tasks input for Multiple, or informational label for Milestone
          if (_trackingType == 'multiple') ...[
            const VGapLg(),
            _buildSectionLabel('RECURRING SUB-TASKS (REQUIRED)'),
            const VGapSm(),
            _buildSubTaskTemplatesField(),
          ] else if (_trackingType == 'milestone') ...[
            const VGapLg(),
            _buildSectionLabel('MILESTONE SUB-TASKS'),
            const VGapSm(),
            _buildMilestoneInfoLabel(),
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
            _buildDateRangeProgress(),
          ],
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
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter activity description (optional)...',
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 14,
        ),
        filled: true,
        fillColor: AppTheme.surfaceColor.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
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

  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.textSecondary,
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
          autofocus: true,
          style: GoogleFonts.outfit(
            color: Colors.white,
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
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: false,
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10, width: 1.5),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white10, width: 1.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.edit_note_rounded,
                color: AppTheme.primaryLight,
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
                : AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.04),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.primaryLight : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
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
                      : AppTheme.surfaceColor.withValues(alpha: 0.3),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _dayLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
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
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _scheduledTime != null
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time_rounded,
              color: _scheduledTime != null ? AppTheme.primaryLight : AppTheme.textSecondary,
              size: 20,
            ),
            const HGapMd(),
            Expanded(
              child: Text(
                _scheduledTime != null
                    ? _formatTimeForDisplay(_scheduledTime!)
                    : 'No specific time set',
                style: TextStyle(
                  color: _scheduledTime != null ? Colors.white : AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (_scheduledTime != null)
              GestureDetector(
                onTap: () => setState(() => _scheduledTime = null),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
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
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: date != null ? AppTheme.primaryLight : AppTheme.textSecondary,
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
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? DateFormat('MMM d, yyyy').format(date) : 'Not set',
                    style: TextStyle(
                      color: date != null ? Colors.white : AppTheme.textSecondary,
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeProgress() {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) return const SizedBox.shrink();

    final today = DateTime.now();
    final startMidnight = DateTime(start.year, start.month, start.day);
    final endMidnight = DateTime(end.year, end.month, end.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);

    final totalDays = endMidnight.difference(startMidnight).inDays + 1;
    if (totalDays <= 0) return const SizedBox.shrink();

    int elapsedDays = todayMidnight.difference(startMidnight).inDays + 1;
    if (todayMidnight.isBefore(startMidnight)) {
      elapsedDays = 0;
    } else if (todayMidnight.isAfter(endMidnight)) {
      elapsedDays = totalDays;
    }

    final progressPercent = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final percent = (progressPercent * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('PROGRESS'),
        const VGapSm(),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progressPercent,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
        const VGapSm(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Day $elapsedDays of $totalDays elapsed',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$percent%',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
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
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              surface: AppTheme.surfaceColor,
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

  Widget _buildMilestoneInfoLabel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryLight.withValues(alpha: 0.7),
            size: 18,
          ),
          const HGapMd(),
          const Expanded(
            child: Text(
              'daily sub tasks will create',
              style: TextStyle(
                color: AppTheme.textSecondary,
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
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: (_) => _addSubTask(),
                    decoration: const InputDecoration(
                      hintText: 'Add sub-task...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24, width: 1),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                      color: _subTaskTime != null ? AppTheme.primaryLight : AppTheme.textSecondary,
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
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppTheme.primaryLight,
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
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: AppTheme.primaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeForDisplay(_subTaskTime!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _subTaskTime = null),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_subTasks.isNotEmpty) ...[
            const VGapMd(),
            const Divider(color: Colors.white10, height: 1, indent: 0, endIndent: 0),
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
                            color: AppTheme.primaryLight.withValues(alpha: 0.6),
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
                                style: const TextStyle(
                                  color: Colors.white,
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
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 10,
                                      color: AppTheme.primaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimeString(subTaskTimeStr),
                                      style: const TextStyle(
                                        color: AppTheme.primaryLight,
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
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
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
}
