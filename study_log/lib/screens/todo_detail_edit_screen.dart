import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/study_text_fields.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../controllers/todo_controller.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import 'session_timer_screen.dart';

/// Screen for creating and editing a Todo item and its subtasks.
/// Adheres strictly to the milestone task UX from log_app, topic input styling,
/// CustomAppBar guidelines, [aa-rules.md], and [optimize.md].
class TodoDetailEditScreen extends StatefulWidget {
  final TodoItem? todo;
  final DateTime? initialDate;

  const TodoDetailEditScreen({
    super.key,
    this.todo,
    this.initialDate,
  });

  @override
  State<TodoDetailEditScreen> createState() => _TodoDetailEditScreenState();
}

class _TodoDetailEditScreenState extends State<TodoDetailEditScreen> {
  late final TodoController _todoController;
  late final DatabaseService _dbService;
  late final TextEditingController _titleController;
  late final UrlHighlightEditingController _descController;

  late TodoStatus _selectedStatus;
  late TodoPriority _selectedPriority;
  DateTime? _selectedDate;
  late RecurrenceType _selectedRecurrence;
  int _weeklyDay = 1;

  final List<TodoSubtask> _subtasks = [];
  final List<TextEditingController> _subtaskControllers = [];
  final List<FocusNode> _subtaskFocusNodes = [];

  int? _deletingSubtaskIndex;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _todoController = getIt<TodoController>();
    _dbService = getIt<DatabaseService>();
    final t = widget.todo;

    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = UrlHighlightEditingController(text: t?.description ?? '');

    _selectedStatus = t?.status ?? TodoStatus.todo;
    _selectedPriority = t?.priority ?? TodoPriority.med;
    final rule = t?.recurrenceRule;
    _selectedRecurrence = rule?.type ?? RecurrenceType.none;
    _weeklyDay = (rule?.daysOfWeek.isNotEmpty == true)
        ? rule!.daysOfWeek.first
        : DateTime.now().weekday;

    final initialDeadline = t?.deadline ?? widget.initialDate;
    if (initialDeadline != null) {
      _selectedDate = DateTime(initialDeadline.year, initialDeadline.month, initialDeadline.day);
      _weeklyDay = _selectedDate!.weekday;
    } else {
      _selectedDate = null;
    }

    if (t != null) {
      for (final s in t.subtasks) {
        _subtasks.add(s);
        _subtaskControllers.add(TextEditingController(text: s.title));
        _subtaskFocusNodes.add(FocusNode());
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final c in _subtaskControllers) {
      c.dispose();
    }
    for (final f in _subtaskFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Subtasks Operations
  // ─────────────────────────────────────────────────────────────────────────

  void _addSubtask() {
    final subtaskId = 'subtask_${DateTime.now().microsecondsSinceEpoch}';
    final parentId = widget.todo?.id ?? '';
    setState(() {
      _subtasks.add(
        TodoSubtask(
          id: subtaskId,
          todoId: parentId,
          title: '',
          isCompleted: false,
          orderIndex: _subtasks.length,
          createdAt: DateTime.now(),
        ),
      );
      _subtaskControllers.add(TextEditingController());
      _subtaskFocusNodes.add(FocusNode());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_subtaskFocusNodes.isNotEmpty && mounted) {
        _subtaskFocusNodes.last.requestFocus();
      }
    });
  }

  void _deleteSubtask(int idx) {
    setState(() {
      _subtasks.removeAt(idx);
      final c = _subtaskControllers.removeAt(idx);
      c.dispose();
      final f = _subtaskFocusNodes.removeAt(idx);
      f.dispose();
      _deletingSubtaskIndex = null;
    });
  }

  Future<void> _toggleSubtaskItem(int idx) async {
    if (idx < 0 || idx >= _subtasks.length) return;
    final s = _subtasks[idx];
    final willComplete = !s.isCompleted;
    final now = DateTime.now();
    final updated = s.copyWith(
      isCompleted: willComplete,
      completedAt: willComplete ? now : null,
    );

    setState(() {
      _subtasks[idx] = updated;
    });

    if (widget.todo != null) {
      final currentTitle = idx < _subtaskControllers.length
          ? _subtaskControllers[idx].text.trim()
          : '';
      final subtaskToPersist = updated.copyWith(
        todoId: widget.todo!.id,
        title: currentTitle.isNotEmpty
            ? currentTitle
            : (updated.title.isNotEmpty ? updated.title : 'Subtask'),
      );
      await _dbService.insertSubtask(subtaskToPersist);

      final allDone = _subtasks.isNotEmpty && _subtasks.every((st) => st.isCompleted);
      if (willComplete && allDone && _selectedStatus != TodoStatus.done) {
        setState(() => _selectedStatus = TodoStatus.done);
        await _todoController.updateStatus(widget.todo!.id, TodoStatus.done);
      } else if (!willComplete && _selectedStatus == TodoStatus.done) {
        setState(() => _selectedStatus = TodoStatus.inProgress);
        await _todoController.updateStatus(widget.todo!.id, TodoStatus.inProgress);
      }
    } else {
      final allDone = _subtasks.isNotEmpty && _subtasks.every((st) => st.isCompleted);
      if (willComplete && allDone && _selectedStatus != TodoStatus.done) {
        setState(() => _selectedStatus = TodoStatus.done);
      } else if (!willComplete && _selectedStatus == TodoStatus.done) {
        setState(() => _selectedStatus = TodoStatus.todo);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Date & Time Pickers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickCustomDate([VoidCallback? onUpdated]) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => _buildPickerTheme(context, child),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      });
      onUpdated?.call();
    }
  }



  Widget _buildPickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: AppTheme.primaryColor,
          onPrimary: Colors.white,
          surface: AppTheme.surface(context),
          onSurface: AppTheme.textPrimaryColor(context),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions & Mutation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a task title'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final rule = RecurrenceRule(
      type: _selectedRecurrence,
      interval: 1,
      daysOfWeek: _selectedRecurrence == RecurrenceType.weekly
          ? [_weeklyDay]
          : const [],
    );

    DateTime? deadline;
    if (_selectedDate != null) {
      deadline = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23,
        59,
      );
    }

    // Sync non-blank subtask titles from controllers
    final nonBlankSubtasks = <TodoSubtask>[];
    for (int i = 0; i < _subtasks.length; i++) {
      final t = _subtaskControllers[i].text.trim();
      if (t.isNotEmpty) {
        nonBlankSubtasks.add(_subtasks[i].copyWith(title: t, orderIndex: nonBlankSubtasks.length));
      }
    }

    final parentId = widget.todo?.id ?? 'todo_${now.millisecondsSinceEpoch}';
    final allSubtasksDone =
        nonBlankSubtasks.isNotEmpty && nonBlankSubtasks.every((s) => s.isCompleted);
    final isDone = _selectedStatus == TodoStatus.done || allSubtasksDone;
    final finalStatus = isDone ? TodoStatus.done : _selectedStatus;

    final reindexedSubtasks = [
      for (int i = 0; i < nonBlankSubtasks.length; i++)
        nonBlankSubtasks[i].copyWith(
          todoId: parentId,
          orderIndex: i,
          isCompleted: isDone ? true : nonBlankSubtasks[i].isCompleted,
          completedAt: isDone
              ? (nonBlankSubtasks[i].completedAt ?? now)
              : (nonBlankSubtasks[i].isCompleted ? nonBlankSubtasks[i].completedAt : null),
        )
    ];

    if (widget.todo == null) {
      final newTodo = TodoItem(
        id: parentId,
        title: title,
        description: _descController.text.trim(),
        status: finalStatus,
        priority: _selectedPriority,
        deadline: deadline,
        reminderTime: deadline,
        isRecurring: rule.isRepeating,
        recurrenceRule: rule,
        subtasks: reindexedSubtasks,
        createdAt: now,
        updatedAt: now,
        completedAt: finalStatus == TodoStatus.done ? now : null,
      );

      await _todoController.addTodo(newTodo, initialSubtasks: reindexedSubtasks);
    } else {
      final updatedTodo = widget.todo!.copyWith(
        title: title,
        description: _descController.text.trim(),
        status: finalStatus,
        priority: _selectedPriority,
        deadline: deadline,
        clearDeadline: deadline == null,
        reminderTime: deadline,
        clearReminderTime: deadline == null,
        isRecurring: rule.isRepeating,
        recurrenceRule: rule,
        subtasks: reindexedSubtasks,
        updatedAt: now,
        completedAt: finalStatus == TodoStatus.done ? (widget.todo!.completedAt ?? now) : null,
      );

      await _todoController.updateTodo(updatedTodo);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete() async {
    if (widget.todo == null) return;
    final confirmed = await StudyConfirmationDialog.showDeleteTask(context, taskTitle: widget.todo!.title);
    if (confirmed == true && mounted) {
      await _todoController.deleteTodo(widget.todo!.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _startPomodoroSession() {
    final title = _titleController.text.trim();
    final taskTitle =
        title.isNotEmpty ? title : (widget.todo?.title ?? 'Task Focus');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionTimerScreen(
          title: 'Task: $taskTitle',
          subtitle: 'Pomodoro Focus Session',
          durationMinutes: 25,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Builders
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar strictly matching study_log standard
            CustomAppBar(
              title: widget.todo != null ? 'Edit Task' : 'Add Task & Subtasks',
              onBack: () => Navigator.of(context).pop(),
              actions: [
                if (widget.todo != null) ...[
                  IconButton(
                    icon: const Icon(Icons.timer_outlined, size: 22),
                    color: AppTheme.primaryColor,
                    tooltip: 'Start Focus Session',
                    onPressed: _startPomodoroSession,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 22),
                    color: AppTheme.errorColor,
                    tooltip: 'Delete Task',
                    onPressed: _confirmDelete,
                  ),
                  const HGapXs(),
                ],
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
                  top: 12,
                  bottom: bottomSafe + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Title Field matching topic text input styling
                    UnderlineInputField(
                      label: 'Task Name',
                      controller: _titleController,
                      hintText: 'Enter task title...',
                      isRequired: true,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                    const VGapMd(),

                    // Subtasks Section matching milestone task screen
                    _buildSubtasksSection(),
                    const VGapMd(),
                    const Divider(height: 1),
                    const VGapMd(),

                    // Notes Section matching study topic notes/description style
                    BorderlessDescriptionField.todo(
                      controller: _descController,
                    ),
                    const VGapLg(),

                    // Configure Section directly below Notes
                    _buildConfigureSection(),

                    if (widget.todo != null) ...[
                      const VGapXl(),
                      Center(
                        child: TextButton.icon(
                          onPressed: _confirmDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.errorColor,
                            size: 18,
                          ),
                          label: const Text(
                            'Delete Task',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_subtasks.isNotEmpty) ...[
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _subtasks.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _subtasks.removeAt(oldIndex);
                _subtasks.insert(newIndex, item);

                final controller = _subtaskControllers.removeAt(oldIndex);
                _subtaskControllers.insert(newIndex, controller);

                final focusNode = _subtaskFocusNodes.removeAt(oldIndex);
                _subtaskFocusNodes.insert(newIndex, focusNode);
              });
            },
            itemBuilder: (context, idx) {
              final item = _subtasks[idx];
              return _buildSubtaskRow(item, idx);
            },
          ),
          const VGapSm(),
        ],
        GestureDetector(
          onTap: _addSubtask,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: AppTheme.primaryColor, size: 20),
                const HGapSm(),
                const Text(
                  'Add Sub-task',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskRow(TodoSubtask item, int idx) {
    final isDeleting = _deletingSubtaskIndex == idx;
    final controller = _subtaskControllers[idx];
    final focusNode = _subtaskFocusNodes[idx];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBorderColor =
        isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _deletingSubtaskIndex = isDeleting ? null : idx;
          });
        },
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isDeleting) {
                  setState(() => _deletingSubtaskIndex = null);
                } else {
                  _toggleSubtaskItem(idx);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isCompleted ? AppTheme.primaryColor : Colors.transparent,
                    border: Border.all(
                      color: item.isCompleted
                          ? AppTheme.primaryColor
                          : unselectedBorderColor,
                      width: 2.0,
                    ),
                  ),
                  child: item.isCompleted
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const HGapSm(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _deletingSubtaskIndex = isDeleting ? null : idx;
                  });
                },
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: isDeleting,
                  keyboardType: TextInputType.text,
                  style: TextStyle(
                    color: item.isCompleted
                        ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.5)
                        : AppTheme.textPrimaryColor(context),
                    fontSize: 15,
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Sub-task title',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.35),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    _subtasks[idx] = _subtasks[idx].copyWith(title: val);
                  },
                ),
              ),
            ),
            if (isDeleting)
              GestureDetector(
                onTap: () => _deleteSubtask(idx),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.errorColor,
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: idx,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(
                        Icons.menu_rounded,
                        size: 18,
                        color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigureSection() {
    final divider = Divider(
      height: 14,
      thickness: 1,
      color: AppTheme.borderColor(context).withValues(alpha: 0.4),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configure',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapSm(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // Priority row: priority  (icon)MED
              _buildConfigRow(
                label: 'Priority',
                trailing: _buildPriorityTrailing(),
              ),
              divider,

              // Due date row: due date  (icon)select date 
              _buildConfigRow(
                label: 'Due date',
                trailing: _buildDueDateTrailing(),
              ),
              divider,

              // Repeat row: repet  (icon) None
              _buildConfigRow(
                label: 'Repeat',
                trailing: _buildRepeatTrailing(),
              ),

              // Dynamic repeat sub-rows
              if (_selectedRecurrence == RecurrenceType.weekly) ...[
                divider,
                _buildConfigRow(
                  label: 'Day',
                  trailing: _buildWeeklyDayTrailing(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigRow({
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildPriorityTrailing() {
    final pColor = switch (_selectedPriority) {
      TodoPriority.high => AppTheme.pastelCoralText(context),
      TodoPriority.med => AppTheme.pastelOrangeText(context),
      TodoPriority.low => AppTheme.pastelBlueText(context),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TodoPriority>(
          value: _selectedPriority,
          isDense: true,
          dropdownColor: AppTheme.surface(context),
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: pColor),
          items: TodoPriority.values.map((p) {
            final color = switch (p) {
              TodoPriority.high => AppTheme.pastelCoralText(context),
              TodoPriority.med => AppTheme.pastelOrangeText(context),
              TodoPriority.low => AppTheme.pastelBlueText(context),
            };
            return DropdownMenuItem(
              value: p,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: color),
                  const HGapXs(),
                  Text(
                    p.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedPriority = val);
          },
        ),
      ),
    );
  }

  Widget _buildDueDateTrailing() {
    final dateText = _selectedDate != null
        ? DateFormat('d MMM yyyy').format(_selectedDate!)
        : 'select date';

    return InkWell(
      onTap: _pickCustomDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: _selectedDate != null ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
            ),
            const HGapXs(),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                color: _selectedDate != null
                    ? AppTheme.textPrimaryColor(context)
                    : AppTheme.textSecondaryColor(context),
              ),
            ),
            if (_selectedDate != null) ...[
              const HGapXs(),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDate = null;
                }),
                child: Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondaryColor(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatTrailing() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RecurrenceType>(
          value: _selectedRecurrence,
          isDense: true,
          dropdownColor: AppTheme.surface(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primaryColor),
          items: const [
            RecurrenceType.none,
            RecurrenceType.daily,
            RecurrenceType.weekly,
          ].map((r) {
            final label = switch (r) {
              RecurrenceType.none => 'None',
              RecurrenceType.daily => 'Daily',
              RecurrenceType.weekly => 'Weekly',
              _ => '',
            };
            return DropdownMenuItem(
              value: r,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat_rounded, size: 14, color: AppTheme.primaryColor),
                  const HGapXs(),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedRecurrence = val);
          },
        ),
      ),
    );
  }

  Widget _buildWeeklyDayTrailing() {
    const dayNames = [
      (1, 'Monday'),
      (2, 'Tuesday'),
      (3, 'Wednesday'),
      (4, 'Thursday'),
      (5, 'Friday'),
      (6, 'Saturday'),
      (7, 'Sunday'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _weeklyDay,
          isDense: true,
          dropdownColor: AppTheme.surface(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppTheme.primaryColor),
          items: dayNames.map((item) {
            return DropdownMenuItem(
              value: item.$1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.today_rounded, size: 14, color: AppTheme.primaryColor),
                  const HGapXs(),
                  Text(
                    item.$2,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _weeklyDay = val;
                if (_selectedDate != null) {
                  final curWeekday = _selectedDate!.weekday;
                  final diff = (val - curWeekday) % 7;
                  _selectedDate = _selectedDate!.add(Duration(days: diff));
                }
              });
            }
          },
        ),
      ),
    );
  }



}
