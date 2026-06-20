import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_title_dropdown.dart';

class AddMilestoneTaskSheet extends StatefulWidget {
  final List<Activity> milestones;
  final Future<void> Function(Activity activity, String taskName, DateTime timestamp)? onAddTask;
  final Task? editTask;
  final Future<void> Function(Task task)? onEditTask;
  final String? initialActivityId;

  const AddMilestoneTaskSheet({
    super.key,
    required this.milestones,
    this.onAddTask,
    this.editTask,
    this.onEditTask,
    this.initialActivityId,
  });

  @override
  State<AddMilestoneTaskSheet> createState() => _AddMilestoneTaskSheetState();
}

class _AddMilestoneTaskSheetState extends State<AddMilestoneTaskSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ActivityService _firebaseService = ActivityService();
  late Stream<List<Task>> _tasksStream;
  late String _selectedMilestoneId;
  String? _deletingTaskId;
  TimeOfDay? _selectedTime;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _selectedMilestoneId = widget.milestones.first.id;
    if (widget.initialActivityId != null && widget.milestones.any((m) => m.id == widget.initialActivityId)) {
      _selectedMilestoneId = widget.initialActivityId!;
    }
    if (widget.editTask != null) {
      final task = widget.editTask!;
      _controller.text = task.taskName;
      _selectedDate = task.timestamp;
      if (widget.milestones.any((m) => m.id == task.activityId)) {
        _selectedMilestoneId = task.activityId;
      }
      if (task.scheduledTime != null) {
        final parts = task.scheduledTime!.split(':');
        if (parts.length == 2) {
          _selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        }
      }
    }
    _tasksStream = _firebaseService.getTasksForActivityStream(_selectedMilestoneId);
  }

  void _onMilestoneChanged(String? id) {
    if (id == null) return;
    setState(() {
      _selectedMilestoneId = id;
      _tasksStream = _firebaseService.getTasksForActivityStream(id);
    });
  }

  Activity get _selectedMilestone =>
      widget.milestones.firstWhere((m) => m.id == _selectedMilestoneId);

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    super.dispose();
  }


  Future<void> _saveTask() async {
    final rawName = _controller.text.trim();
    if (rawName.isEmpty || _isSaving) return;

    final taskName = _selectedTime == null
        ? rawName
        : '$rawName|${_formatTimeOfDay(_selectedTime!)}';

    // Apply selected time to selected date
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

    setState(() => _isSaving = true);
    try {
      if (widget.editTask != null) {
        final task = widget.editTask!;
        final updatedTask = Task(
          id: task.id,
          activityId: task.activityId,
          taskName: rawName,
          timestamp: taskDateTime,
          checked: task.checked,
          symbolType: task.symbolType,
          symbolValue: task.symbolValue,
          scheduledTime: _selectedTime != null
              ? _formatTimeOfDay(_selectedTime!)
              : null,
          completionTime: task.completionTime,
          subTasks: task.subTasks,
        );
        await widget.onEditTask?.call(updatedTask);
        if (mounted) Navigator.pop(context);
      } else {
        await widget.onAddTask?.call(_selectedMilestone, taskName, taskDateTime);
        if (mounted) {
          _controller.clear();
          setState(() {
            _selectedTime = null;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add task: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteTask(String id) async {
    try {
      await _firebaseService.deleteTask(id);
      if (mounted && widget.editTask != null) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete task: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
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


  Future<void> _pickCustomDate() async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final isEditing = widget.editTask != null;
    final firstDate = isEditing 
        ? todayMidnight.subtract(const Duration(days: 365)) 
        : todayMidnight.subtract(const Duration(days: 3));
    final lastDate = isEditing 
        ? todayMidnight.add(const Duration(days: 365 * 2)) 
        : todayMidnight.add(const Duration(days: 7));

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

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_wasKeyboardVisible && !isKeyboardVisible && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.unfocus();
        }
      });
    }
    _wasKeyboardVisible = isKeyboardVisible;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          Theme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.background(context).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppTheme.borderColor(context), width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Column(
                  children: [
                    const VGapMd(),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const VGapLg(),
                    
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.editTask != null ? 'Edit Task' : 'Add Task',
                                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                                    ),
                                    const SizedBox(height: 4),
                                    AppTitleDropdown<String>(
                                      value: _selectedMilestoneId,
                                      items: widget.milestones.map((m) {
                                        return DropdownMenuItem<String>(
                                          value: m.id,
                                          child: Text(
                                            m.name,
                                            style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: widget.editTask != null ? null : _onMilestoneChanged,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.subtleFillColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.borderColor(context)),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close_rounded, color: AppTheme.textSecondaryColor(context), size: 20),
                                ),
                              ),
                            ],
                          ),
                          const VGapLg(),
                          Text(
                            'Select Date',
                            style: AppTheme.headingSmall.copyWith(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
                          ),
                          const VGapMd(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDateSelectorRow(),
                          ),
                          const VGapLg(),
                          Text(
                            'Task Name',
                            style: AppTheme.headingSmall.copyWith(fontSize: 13, color: AppTheme.textSecondaryColor(context)),
                          ),
                          const VGapMd(),
                          TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 5,
                            onTap: () {
                              _sheetController.animateTo(
                                0.95,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                            style: TextStyle(color: AppTheme.textPrimaryColor(context), fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add milestone task...',
                              hintStyle: TextStyle(color: AppTheme.textSecondaryColor(context), fontSize: 13),
                              filled: true,
                              fillColor: AppTheme.subtleFillColor(context),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.borderColor(context)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.borderColor(context)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _saveTask(),
                          ),
                          const VGapMd(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (widget.editTask != null) ...[
                                GestureDetector(
                                  onTap: () => _deleteTask(widget.editTask!.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              GestureDetector(
                                onTap: _saveTask,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _isSaving
                                      ? SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primaryAccentColor(context),
                                          ),
                                        )
                                      : Text(
                                          'SAVE',
                                          style: TextStyle(
                                            color: AppTheme.primaryAccentColor(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.editTask == null) ...[
                          const VGapLg(),
                          const VGapLg(),
                          StreamBuilder<List<Task>>(
                            stream: _tasksStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'Error loading tasks',
                                    style: TextStyle(color: AppTheme.errorColor),
                                  ),
                                );
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                    ),
                                  );
                              }
                              final allTasks = snapshot.data ?? [];
                              final filteredTasks = allTasks
                                  .where((s) => _isSameDay(s.timestamp, _selectedDate))
                                  .toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tasks',
                                    style: AppTheme.headingSmall.copyWith(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor(context),
                                    ),
                                  ),
                                  const VGapMd(),
                                  if (filteredTasks.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'No tasks for this date. Add one above!',
                                          style: AppTheme.bodySmall.copyWith(
                                            fontSize: 10,
                                            color: AppTheme.textSecondaryColor(context),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: filteredTasks.map((task) {
                                        return _buildTaskRow(task);
                                      }).toList(),
                                    ),
                              ],
                            );
                          },
                          ),
                          ],
                          const VGapXxl(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _buildTaskRow(Task task) {
    final displayName = task.taskName;
    final timeString = task.scheduledTime;
    final hasTime = timeString != null;
    final isDeletingThis = _deletingTaskId == task.id;

    final Widget itemContainer = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.checked 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_deletingTaskId != null) {
                  setState(() {
                    _deletingTaskId = null;
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: task.checked ? AppTheme.textSecondaryColor(context) : AppTheme.textPrimaryColor(context),
                        decoration: task.checked ? TextDecoration.lineThrough : null,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (hasTime) ...[
                    const HGapSm(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.checked
                            ? AppTheme.subtleFillColor(context)
                            : AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: task.checked
                                ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                                : AppTheme.primaryAccentColor(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeString(timeString),
                            style: TextStyle(
                              color: task.checked
                                  ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                                  : AppTheme.primaryAccentColor(context),
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
          ),
          const HGapMd(),
          GestureDetector(
            onTap: () => _deleteTask(task.id),
            child: Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.errorColor.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isDeletingThis) {
            _deletingTaskId = null;
          } else {
            _deletingTaskId = task.id;
          }
        });
      },
      child: itemContainer,
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
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
}

