import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity.dart';
import '../models/sub_task.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class AddMilestoneSubTaskSheet extends StatefulWidget {
  final Activity activity;
  final Future<void> Function(Activity activity, String subTaskName, DateTime timestamp) onAddSubTask;

  const AddMilestoneSubTaskSheet({
    super.key,
    required this.activity,
    required this.onAddSubTask,
  });

  @override
  State<AddMilestoneSubTaskSheet> createState() => _AddMilestoneSubTaskSheetState();
}

class _AddMilestoneSubTaskSheetState extends State<AddMilestoneSubTaskSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final FirebaseService _firebaseService = FirebaseService();
  late Stream<List<SubTask>> _subTasksStream;
  String? _deletingSubTaskId;
  TimeOfDay? _selectedTime;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subTasksStream = _firebaseService.getSubTasksForActivityStream(widget.activity.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sheetController.dispose();
    super.dispose();
  }


  Future<void> _saveSubTask() async {
    final rawName = _controller.text.trim();
    if (rawName.isEmpty || _isSaving) return;

    final taskName = _selectedTime == null
        ? rawName
        : '$rawName|${_formatTimeOfDay(_selectedTime!)}';

    // Apply selected time to selected date
    var subTaskDateTime = _selectedDate;
    if (_selectedTime != null) {
      subTaskDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    setState(() => _isSaving = true);
    try {
      await widget.onAddSubTask(widget.activity, taskName, subTaskDateTime);
      if (mounted) {
        _controller.clear();
        setState(() {
          _selectedTime = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add sub-task: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleSubTask(SubTask subTask) async {
    final newChecked = !subTask.checked;
    try {
      await _firebaseService.toggleSubTask(subTask.id, newChecked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to toggle sub-task: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _deleteSubTask(String id) async {
    try {
      await _firebaseService.deleteSubTask(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete sub-task: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _formatSelectedDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) return 'Today';
    if (compareDate == yesterday) return 'Yesterday';
    if (compareDate == tomorrow) return 'Tomorrow';
    return DateFormat('MMMM d, yyyy').format(date);
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


  Future<void> _pickSubTaskTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
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
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickCustomDate() async {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 3));
    final lastDate = DateTime(today.year, today.month, today.day).add(const Duration(days: 7));

    var initialDate = _selectedDate;
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
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
                        color: Colors.white24,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.activity.name,
                                      style: AppTheme.headingMedium.copyWith(fontSize: 24),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Add Sub-task',
                                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const VGapLg(),
                          Text(
                            'Select Date',
                            style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const VGapMd(),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDateSelectorRow(),
                          ),
                          const VGapLg(),
                          Text(
                            'Sub-task Title',
                            style: AppTheme.headingSmall.copyWith(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                          const VGapMd(),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  onTap: () {
                                    _sheetController.animateTo(
                                      0.95,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Add milestone sub-task...',
                                    hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white24, width: 1),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _saveSubTask(),
                                ),
                              ),
                              if (_selectedTime != null) ...[
                                const SizedBox(width: 8),
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
                                      Text(
                                        _formatTimeForDisplay(_selectedTime!),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedTime = null),
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _pickSubTaskTime,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.access_time_rounded,
                                    color: _selectedTime != null ? AppTheme.primaryLight : AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: _saveSubTask,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.primaryLight,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_rounded,
                                          color: AppTheme.primaryLight,
                                          size: 18,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const VGapLg(),
                          StreamBuilder<List<SubTask>>(
                            stream: _subTasksStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'Error loading sub-tasks',
                                    style: TextStyle(color: AppTheme.errorColor),
                                  ),
                                );
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                  ),
                                );
                              }
                              final allSubTasks = snapshot.data ?? [];
                              final filteredSubTasks = allSubTasks
                                  .where((s) => _isSameDay(s.timestamp, _selectedDate))
                                  .toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sub-tasks for ${_formatSelectedDateHeader(_selectedDate)}',
                                    style: AppTheme.headingSmall.copyWith(
                                      fontSize: 15,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const VGapMd(),
                                  if (filteredSubTasks.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Center(
                                        child: Text(
                                          'No sub-tasks for this date. Add one above!',
                                          style: AppTheme.bodySmall.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Column(
                                      children: filteredSubTasks.map((subTask) {
                                        return _buildSubTaskRow(subTask);
                                      }).toList(),
                                    ),
                                ],
                              );
                            },
                          ),
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
        _buildDateChip('Today', today, isToday),
        const HGapSm(),
        _buildDateChip('Tomorrow', tomorrow, isTomorrow),
        const HGapSm(),
        _buildCustomDateChip(isCustom),
      ],
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDateChip(bool isCustom) {
    final DateFormat formatter = DateFormat('MMM d');
    final label = isCustom ? formatter.format(_selectedDate) : 'Select Date';

    return GestureDetector(
      onTap: _pickCustomDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isCustom 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustom 
                ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_rounded, 
              size: 14, 
              color: isCustom ? AppTheme.primaryLight : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isCustom ? Colors.white : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isCustom ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTaskRow(SubTask subTask) {
    final hasTime = subTask.subTaskName.contains('|');
    final displayName = subTask.subTaskName.split('|').first;
    final timeString = hasTime ? subTask.subTaskName.split('|').last : null;
    final isDeletingThis = _deletingSubTaskId == subTask.id;

    final Widget itemContainer = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: subTask.checked 
              ? AppTheme.primaryColor.withValues(alpha: 0.15) 
              : Colors.white.withValues(alpha: 0.02),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_deletingSubTaskId != null) {
                  setState(() {
                    _deletingSubTaskId = null;
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
                        color: subTask.checked ? AppTheme.textSecondary : Colors.white,
                        decoration: subTask.checked ? TextDecoration.lineThrough : null,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasTime && timeString != null) ...[
                    const HGapSm(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: subTask.checked
                            ? Colors.white.withValues(alpha: 0.02)
                            : AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: subTask.checked
                                ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                : AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeString(timeString),
                            style: TextStyle(
                              color: subTask.checked
                                  ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                  : AppTheme.primaryLight,
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
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (isDeletingThis) {
                _deleteSubTask(subTask.id);
                setState(() {
                  _deletingSubTaskId = null;
                });
              } else {
                _toggleSubTask(subTask);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: isDeletingThis
                  ? const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.errorColor,
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: subTask.checked ? AppTheme.primaryColor : Colors.transparent,
                        border: Border.all(
                          color: subTask.checked 
                              ? AppTheme.primaryColor 
                              : AppTheme.textSecondary.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: subTask.checked
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
            ),
          ),
          const HGapMd(),
          GestureDetector(
            onTap: () => _deleteSubTask(subTask.id),
            child: Icon(
              Icons.close_rounded,
              color: AppTheme.errorColor.withValues(alpha: 0.7),
              size: 16,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isDeletingThis) {
            _deletingSubTaskId = null;
          } else {
            _deletingSubTaskId = subTask.id;
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

