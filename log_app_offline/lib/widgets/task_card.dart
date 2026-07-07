import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/task.dart';
import 'symbol_indicator.dart';
import 'app_toast.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final List<Activity> milestoneActivities;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(Activity?) onActivitySelected;
  final Function(Task, bool) onToggleTask;
  final Function(Task) onEditTask;
  final Function(Task, String?, String?) onUpdateTaskSymbols;

  const TaskCard({
    super.key,
    required this.task,
    required this.milestoneActivities,
    required this.isExpanded,
    required this.onTap,
    required this.onActivitySelected,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onUpdateTaskSymbols,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late TextEditingController _nestedController;
  final FocusNode _nestedFocusNode = FocusNode();
  String? _deletingNestedItemId;

  @override
  void initState() {
    super.initState();
    _nestedController = TextEditingController();
  }

  @override
  void dispose() {
    _nestedController.dispose();
    _nestedFocusNode.dispose();
    super.dispose();
  }

  void _toggleNestedItem(int index, bool val) {
    final newList = List<SubTask>.from(widget.task.subTasks);
    newList[index] = newList[index].copyWith(checked: val);
    widget.onToggleTask(widget.task.copyWith(subTasks: newList), widget.task.checked);
  }

  void _deleteNestedItem(int index) {
    final newList = List<SubTask>.from(widget.task.subTasks);
    newList.removeAt(index);
    widget.onToggleTask(widget.task.copyWith(subTasks: newList), widget.task.checked);
  }

  void _updateNestedItemDuration(int index, int? duration) {
    final newList = List<SubTask>.from(widget.task.subTasks);
    newList[index] = newList[index].copyWith(durationMinutes: duration);
    widget.onToggleTask(widget.task.copyWith(subTasks: newList), widget.task.checked);
  }

  @override
  Widget build(BuildContext context) {
    final parent = widget.milestoneActivities.firstWhere(
      (a) => a.id == widget.task.activityId,
      orElse: () => Activity(
        id: '',
        name: '',
        isActive: false,
        timestamp: DateTime.now(),
      ),
    );

    final totalCount = widget.task.subTasks.length;
    final completedCount = widget.task.subTasks.where((i) => i.checked).length;
    final totalDuration = widget.task.subTasks
        .where((i) => i.durationMinutes != null)
        .fold<int>(0, (sum, i) => sum + i.durationMinutes!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.task.checked
            ? AppTheme.surface(context).withValues(alpha: 0.15)
            : AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isExpanded
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => widget.onEditTask(widget.task),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Left Checkbox
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: GestureDetector(
                      onTap: () {
                        final newChecked = !widget.task.checked;
                        widget.onToggleTask(widget.task, newChecked);
                        if (newChecked && parent.id.isNotEmpty) {
                          AppToast.show(
                            context: context,
                            message: "Rewarded ${parent.points} Stars! ⭐",
                            backgroundColor: AppTheme.successColor,
                          );
                        }
                      },
                      child: Container(
                        width: AppTheme.taskCheckboxSize,
                        height: AppTheme.taskCheckboxSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.task.checked 
                              ? const Color(0xFF64748B) // Slate 500
                              : Colors.transparent,
                          border: Border.all(
                            color: widget.task.checked 
                                ? const Color(0xFF64748B)
                                : AppTheme.borderColor(context),
                            width: 2,
                          ),
                        ),
                        child: widget.task.checked
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // 2. Middle Content (Title + Subtitle)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.taskName,
                          style: TextStyle(
                            color: widget.task.checked ? AppTheme.textSecondary.withValues(alpha: 0.5) : Theme.of(context).textTheme.bodyLarge!.color,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: widget.task.checked ? TextDecoration.lineThrough : null,
                            decorationColor: AppTheme.textSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surface(context).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.borderColor(context),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 9,
                                    color: AppTheme.primaryLight,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.task.scheduledTime != null
                                        ? '${DateFormat('MMM d').format(widget.task.timestamp)} • ${_formatTimeString(widget.task.scheduledTime!)}'
                                        : DateFormat('MMM d').format(widget.task.timestamp),
                                    style: TextStyle(
                                      color: AppTheme.textSecondaryColor(context),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (totalCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.secondaryColor.withValues(alpha: 0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.account_tree_outlined,
                                      size: 9,
                                      color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$completedCount/$totalCount',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.secondaryColor.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (totalDuration > 0) ...[
                                      const SizedBox(width: 5),
                                      Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 9,
                                        color: AppTheme.secondaryColor.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${totalDuration}m',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.secondaryColor.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            if (parent.repeatDays.length < 7)
                              Icon(
                                Icons.repeat_rounded,
                                size: 12,
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // 3. Right Column (Symbol Indicator & Expand Arrow)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SymbolIndicator(
                        task: widget.task,
                        onTap: () => _showSymbolSelectionDialog(widget.task),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: widget.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            widget.isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Expanded panel showing nested items
          if (widget.isExpanded && widget.task.subTasks.isNotEmpty) ...[
            Divider(color: AppTheme.borderColor(context), height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Checklist Items:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(widget.task.subTasks.length, (idx) {
                    final item = widget.task.subTasks[idx];
                    final isDeleting = _deletingNestedItemId == item.id;

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          if (isDeleting) {
                            _deletingNestedItemId = null;
                          } else {
                            _deletingNestedItemId = item.id;
                          }
                        });
                      },
                      onTap: () {
                        if (isDeleting) {
                          setState(() {
                            _deletingNestedItemId = null;
                          });
                        } else {
                          _toggleNestedItem(idx, !item.checked);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  color: item.checked ? AppTheme.textSecondary.withValues(alpha: 0.5) : Theme.of(context).textTheme.bodyMedium!.color,
                                  fontSize: 13,
                                  decoration: item.checked ? TextDecoration.lineThrough : null,
                                  decorationColor: AppTheme.textSecondary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            if (isDeleting)
                              GestureDetector(
                                onTap: () {
                                  _deleteNestedItem(idx);
                                  setState(() {
                                    _deletingNestedItemId = null;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                              )
                            else
                              _buildChecklistItemDurationMenu(idx, item),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItemDurationMenu(int index, SubTask item) {
    return PopupMenuButton<String>(
      tooltip: 'Change duration or delete',
      onSelected: (val) {
        if (val == 'delete') {
          _deleteNestedItem(index);
        } else {
          final int? duration = val == 'none' ? null : int.tryParse(val);
          _updateNestedItemDuration(index, duration);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'none',
          child: Text('No limit', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '10',
          child: Text('10 minutes', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '30',
          child: Text('30 minutes', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: '60',
          child: Text('1 hour', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color, fontSize: 13)),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Delete Item', style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
            ],
          ),
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
                          ? AppTheme.textSecondary.withValues(alpha: 0.4)
                          : AppTheme.primaryLight,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${item.durationMinutes}m',
                      style: TextStyle(
                        color: item.checked
                            ? AppTheme.textSecondary.withValues(alpha: 0.4)
                            : AppTheme.primaryLight,
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
                    ? AppTheme.textSecondary.withValues(alpha: 0.2)
                    : AppTheme.borderColor(context),
              ),
      ),
    );
  }

  void _showSymbolSelectionDialog(Task st) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mark with symbol',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.onUpdateTaskSymbols(st, '', '');
                        Navigator.pop(context);
                      },
                      child: const Text('Clear', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                _buildDialogLabel('Flag'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFlagOption(st, 'red', Colors.redAccent),
                    _buildFlagOption(st, 'yellow', Colors.amber),
                    _buildFlagOption(st, 'purple', Colors.purpleAccent),
                    _buildFlagOption(st, 'blue', Colors.blueAccent),
                    _buildFlagOption(st, 'green', Colors.greenAccent),
                  ],
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Number'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    final numStr = '${index + 1}';
                    return _buildNumberOption(st, numStr);
                  }),
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Progress'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildProgressOption(st, '0.0', 0.0),
                    _buildProgressOption(st, '0.25', 0.25),
                    _buildProgressOption(st, '0.5', 0.5),
                    _buildProgressOption(st, '0.75', 0.75),
                    _buildProgressOption(st, '1.0', 1.0),
                  ],
                ),
                const SizedBox(height: 14),

                _buildDialogLabel('Mood'),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMoodOption(st, '😄'),
                    _buildMoodOption(st, '🙂'),
                    _buildMoodOption(st, '😐'),
                    _buildMoodOption(st, '😔'),
                    _buildMoodOption(st, '😫'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary.withValues(alpha: 0.8),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFlagOption(Task st, String value, Color color) {
    final isSelected = st.symbolType == 'flag' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateTaskSymbols(st, 'flag', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surface(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        child: Icon(Icons.flag_rounded, color: color, size: 20),
      ),
    );
  }

  Widget _buildNumberOption(Task st, String value) {
    final isSelected = st.symbolType == 'number' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateTaskSymbols(st, 'number', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : AppTheme.surface(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryLight : Theme.of(context).textTheme.bodySmall!.color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressOption(Task st, String value, double progress) {
    final isSelected = st.symbolType == 'progress' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateTaskSymbols(st, 'progress', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor.withValues(alpha: 0.15) : AppTheme.surface(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CustomPaint(
              painter: PieChartPainter(
                progress: progress,
                color: AppTheme.secondaryColor,
                backgroundColor: AppTheme.borderColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoodOption(Task st, String value) {
    final isSelected = st.symbolType == 'mood' && st.symbolValue == value;
    return GestureDetector(
      onTap: () {
        widget.onUpdateTaskSymbols(st, 'mood', value);
        Navigator.pop(context);
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.borderColor(context).withValues(alpha: 0.2) : AppTheme.surface(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.borderColor(context) : AppTheme.borderColor(context),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  String _formatTimeString(String time24h) {
    try {
      final parts = time24h.split(':');
      if (parts.length != 2) return time24h;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      final hourOfPeriod = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';
      final minuteStr = minute.toString().padLeft(2, '0');
      
      return '$hourOfPeriod:$minuteStr $period';
    } catch (_) {
      return time24h;
    }
  }
}
