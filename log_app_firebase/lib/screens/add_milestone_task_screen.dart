import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../widgets/app_spacers.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_popup_menu_button.dart';

class AddMilestoneTaskScreen extends StatefulWidget {
  final List<Activity> milestones;
  final String? initialActivityId;
  final Task? editTask;
  final Future<void> Function(Activity activity, String taskName, DateTime timestamp, List<SubTask> subTasks)? onAddTask;
  final Future<void> Function(Task task)? onEditTask;
  final Future<void> Function(Task task)? onDeleteTask;

  const AddMilestoneTaskScreen({
    super.key,
    required this.milestones,
    this.initialActivityId,
    this.editTask,
    this.onAddTask,
    this.onEditTask,
    this.onDeleteTask,
  });

  @override
  State<AddMilestoneTaskScreen> createState() => _AddMilestoneTaskScreenState();
}

class _AddMilestoneTaskScreenState extends State<AddMilestoneTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  late String _selectedMilestoneId;
  final List<SubTask> _subTasks = [];
  final List<TextEditingController> _subTaskControllers = [];
  final List<FocusNode> _subTaskFocusNodes = [];
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  
  int? _deletingSubTaskIndex;
  bool _isSaving = false;
  bool _taskChecked = false;

  @override
  void initState() {
    super.initState();
    _selectedMilestoneId = widget.milestones.isNotEmpty ? widget.milestones.first.id : '';
    if (widget.initialActivityId != null && widget.milestones.any((m) => m.id == widget.initialActivityId)) {
      _selectedMilestoneId = widget.initialActivityId!;
    }
    
    if (widget.editTask != null) {
      final task = widget.editTask!;
      _taskChecked = task.checked;
      _titleController.text = task.taskName;
      _selectedDate = task.timestamp;
      if (widget.milestones.any((m) => m.id == task.activityId)) {
        _selectedMilestoneId = task.activityId;
      }
      if (task.scheduledTime != null) {
        final parts = task.scheduledTime!.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            _selectedTime = TimeOfDay(hour: h, minute: m);
          }
        }
      }
      for (var st in task.subTasks) {
        _subTasks.add(st);
        _subTaskControllers.add(TextEditingController(text: st.title));
        _subTaskFocusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    for (var c in _subTaskControllers) {
      c.dispose();
    }
    for (var f in _subTaskFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final firstDate = todayMidnight.subtract(const Duration(days: 3));
    final lastDate = todayMidnight.add(const Duration(days: 7));

    var initialDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
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
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
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
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }
    
    setState(() => _isSaving = true);

    try {
      final activity = widget.milestones.firstWhere((m) => m.id == _selectedMilestoneId);
      
      var taskDateTime = _selectedDate;
      if (_selectedTime != null) {
        taskDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final taskName = _selectedTime == null
          ? title
          : '$title|${_formatTimeOfDay(_selectedTime!)}';

      final nonBlankSubTasks = _subTasks
          .where((st) => st.title.trim().isNotEmpty)
          .toList();

      if (widget.editTask != null) {
        final updatedTask = widget.editTask!.copyWith(
          activityId: _selectedMilestoneId,
          taskName: title,
          timestamp: taskDateTime,
          checked: _taskChecked,
          completionTime: _taskChecked
              ? (widget.editTask!.completionTime ?? DateTime.now())
              : null,
          scheduledTime: _selectedTime != null ? _formatTimeOfDay(_selectedTime!) : null,
          subTasks: nonBlankSubTasks,
        );
        if (widget.onEditTask != null) {
          await widget.onEditTask!(updatedTask);
        }
      } else {
        if (widget.onAddTask != null) {
          await widget.onAddTask!(activity, taskName, taskDateTime, nonBlankSubTasks);
        }
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addSubTask() {
    setState(() {
      final id = 'subtask-${DateTime.now().millisecondsSinceEpoch}';
      _subTasks.add(SubTask(id: id, title: '', checked: false));
      _subTaskControllers.add(TextEditingController());
      _subTaskFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subTaskFocusNodes.isNotEmpty && mounted) {
        _subTaskFocusNodes.last.requestFocus();
      }
    });
  }

  void _deleteSubTask(int idx) {
    setState(() {
      _subTasks.removeAt(idx);
      final controller = _subTaskControllers.removeAt(idx);
      controller.dispose();
      final focusNode = _subTaskFocusNodes.removeAt(idx);
      focusNode.dispose();
      _deletingSubTaskIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return FullScreenPage(
      title: widget.editTask != null ? 'Edit Task' : 'Add Task & Subtasks',
      showBackButton: true,
      isScrollable: true,
      actions: widget.editTask != null ? [ _buildTaskActionsMenu() ] : null,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 0,
        bottom: bottomPadding + 48 + viewInsetsBottom,
      ),
      children: [
        const VGapSm(),
        _buildDropdownRow(),
        const VGapMd(),
        _buildTitleField(),
        const Divider(height: 1),
        const VGapLg(),
        _buildSubTasksSection(),
        const VGapLg(),
        const Divider(height: 1),
        const VGapLg(),
        Text(
          'Select Due Date',
          style: AppTheme.headingSmall.copyWith(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
        ),
        const VGapMd(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _buildDateSelectorRow(),
        ),
        const VGapXxl(),
        _buildSaveButton(),
        const VGapXxl(),
      ],
    );
  }

  Widget _buildDropdownRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMilestoneId.isNotEmpty ? _selectedMilestoneId : null,
              dropdownColor: AppTheme.surface(context),
              isDense: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded, 
                size: 18, 
                color: AppTheme.textPrimaryColor(context).withValues(alpha: 0.8),
              ),
              items: widget.milestones.map((m) {
                return DropdownMenuItem<String>(
                  value: m.id,
                  child: Text(
                    m.name,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() => _selectedMilestoneId = id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: GoogleFonts.outfit(
        fontSize: 28, 
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor(context),
      ),
      decoration: InputDecoration(
        hintText: 'Enter task title...',
        filled: false,
        hintStyle: GoogleFonts.outfit(
          fontSize: 28, 
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSubTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_subTasks.isNotEmpty) ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _subTasks.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _subTasks.removeAt(oldIndex);
                _subTasks.insert(newIndex, item);

                final controller = _subTaskControllers.removeAt(oldIndex);
                _subTaskControllers.insert(newIndex, controller);

                final focusNode = _subTaskFocusNodes.removeAt(oldIndex);
                _subTaskFocusNodes.insert(newIndex, focusNode);
              });
            },
            itemBuilder: (context, idx) {
              final item = _subTasks[idx];
              return _buildSubTaskRow(item, idx);
            },
          ),
          const VGapSm(),
        ],
        GestureDetector(
          onTap: _addSubTask,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppTheme.primaryAccentColor(context), size: 20),
                const HGapSm(),
                Text(
                  'Add Sub-task',
                  style: TextStyle(
                    color: AppTheme.primaryAccentColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTaskRow(SubTask item, int idx) {
    final isDeleting = _deletingSubTaskIndex == idx;
    final controller = _subTaskControllers[idx];
    final focusNode = _subTaskFocusNodes[idx];
    
    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          FocusScope.of(context).unfocus();
          setState(() {
            if (isDeleting) {
              _deletingSubTaskIndex = null;
            } else {
              _deletingSubTaskIndex = idx;
            }
          });
        },
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (isDeleting) {
                  setState(() => _deletingSubTaskIndex = null);
                } else {
                  setState(() {
                    _subTasks[idx] = item.copyWith(checked: !item.checked);
                  });
                }
              },
              child: Container(
                width: AppTheme.subtaskCheckboxSize,
                height: AppTheme.subtaskCheckboxSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.checked
                      ? AppTheme.primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: item.checked
                        ? AppTheme.primaryColor
                        : AppTheme.borderColor(context),
                    width: 1.5,
                  ),
                ),
                child: item.checked
                    ? Icon(Icons.check, size: 11, color: Theme.of(context).colorScheme.onPrimary)
                    : null,
              ),
            ),
            const HGapMd(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    if (isDeleting) {
                      _deletingSubTaskIndex = null;
                    } else {
                      _deletingSubTaskIndex = idx;
                    }
                  });
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: isDeleting,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 1,
                  style: GoogleFonts.inter(
                    color: item.checked 
                        ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.5) 
                        : AppTheme.textPrimaryColor(context),
                    fontSize: 14,
                    decoration: item.checked ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Sub-task title',
                    filled: false,
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _subTasks[idx] = item.copyWith(title: val);
                  },
                ),
              ),
            ),
            if (isDeleting)
              GestureDetector(
                onTap: () => _deleteSubTask(idx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubTaskDurationMenu(idx, item),
                  const HGapSm(),
                  ReorderableDragStartListener(
                    index: idx,
                    child: Icon(
                      Icons.menu_rounded,
                      size: 18,
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTaskDurationMenu(int index, SubTask item) {
    return PopupMenuButton<String>(
      tooltip: 'Change duration',
      onSelected: (val) {
        final int? duration = val == 'none' ? null : int.tryParse(val);
        setState(() {
          _subTasks[index] = item.copyWith(durationMinutes: duration);
        });
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'none',
          child: Text('No limit', style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '10',
          child: Text('10 minutes', style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '30',
          child: Text('30 minutes', style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '60',
          child: Text('1 hour', style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13)),
        ),
      ],
      offset: const Offset(0, 30),
      color: AppTheme.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: item.durationMinutes != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.checked
                      ? AppTheme.surface(context).withValues(alpha: 0.2)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 10,
                      color: item.checked
                          ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                          : AppTheme.primaryAccentColor(context),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.durationMinutes}m',
                      style: TextStyle(
                        color: item.checked
                            ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                            : AppTheme.primaryAccentColor(context),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : Icon(
                Icons.timer_outlined,
                size: 16,
                color: item.checked
                    ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.2)
                    : AppTheme.borderColor(context),
              ),
      ),
    );
  }

  Widget _buildDateSelectorRow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final isToday = _isSameDay(_selectedDate, today);
    final isTomorrow = _isSameDay(_selectedDate, tomorrow);
    final isCustom = !isToday && !isTomorrow;

    return Row(
      children: [
        _buildCustomDateChip(isCustom),
        const HGapSm(),
        _buildDateChip('Today', today, isToday),
        const HGapSm(),
        _buildDateChip('Tomorrow', tomorrow, isTomorrow),
        const HGapSm(),
        _buildTimeSelectorChip(),
      ],
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : AppTheme.borderColor(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.selectedChipTextColor(context) : AppTheme.textSecondaryColor(context),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(bool isCustom) {
    final DateFormat formatter = DateFormat('MMM d');
    final label = isCustom ? formatter.format(_selectedDate) : null;

    return GestureDetector(
      onTap: _pickCustomDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isCustom 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded, 
              size: 13, 
              color: isCustom ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
            ),
            if (isCustom) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: AppTheme.selectedChipTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelectorChip() {
    final hasTime = _selectedTime != null;
    final label = hasTime ? _formatTimeForDisplay(_selectedTime!) : null;

    return GestureDetector(
      onTap: _pickCustomTime,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hasTime 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.subtleFillColor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasTime 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_rounded, 
              size: 13, 
              color: hasTime ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
            ),
            if (hasTime) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(
                  color: AppTheme.selectedChipTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTime = null;
                  });
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: _isSaving ? null : _saveTask,
        child: _isSaving
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2),
              )
            : Text(
                widget.editTask != null ? 'Save Changes' : 'Save Task',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay t) {
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

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  Widget _buildTaskActionsMenu() {
    return AppPopupMenuButton(
      onSelected: (val) async {
        if (val == 'toggle_status') {
          setState(() {
            _taskChecked = !_taskChecked;
          });
        } else if (val == 'delete_task') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surface(context),
              title: const Text('Delete Task'),
              content: const Text('Are you sure you want to delete this task?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                ),
              ],
            ),
          );
          if (confirm == true && widget.onDeleteTask != null && widget.editTask != null) {
            await widget.onDeleteTask!(widget.editTask!);
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'toggle_status',
          child: Row(
            children: [
              Icon(
                _taskChecked ? Icons.radio_button_unchecked_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: AppTheme.textPrimaryColor(context),
              ),
              const SizedBox(width: 8),
              Text(
                _taskChecked ? 'Mark as Pending' : 'Mark as Done',
                style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'delete_task',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorColor),
              const SizedBox(width: 8),
              Text(
                'Delete Task',
                style: TextStyle(color: AppTheme.errorColor, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
