import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
import 'pomodoro_timer_screen.dart';

class PomodoroReadyScreen extends StatefulWidget {
  final Activity activity;
  final List<Activity> remainingQueue;
  final Task? initialMilestoneTask;

  const PomodoroReadyScreen({
    super.key,
    required this.activity,
    required this.remainingQueue,
    this.initialMilestoneTask,
  });

  @override
  State<PomodoroReadyScreen> createState() => _PomodoroReadyScreenState();
}

class _PomodoroReadyScreenState extends State<PomodoroReadyScreen> {
  late final ValueNotifier<bool> _trackSessionNotifier;
  late final ValueNotifier<bool> _followUpNextNotifier;
  late final ValueNotifier<bool> _allowPauseNotifier;
  late final ValueNotifier<bool> _isRestrictModeNotifier;
  late final ValueNotifier<bool> _allowResetNotifier;

  Task? _milestoneTask;
  final Set<String> _selectedSubTaskIds = {};
  bool _isLoading = false;
  StreamSubscription<List<Task>>? _tasksSubscription;

  @override
  void initState() {
    super.initState();
    _trackSessionNotifier = ValueNotifier<bool>(true);
    _followUpNextNotifier = ValueNotifier<bool>(true);
    _allowPauseNotifier = ValueNotifier<bool>(true);
    _isRestrictModeNotifier = ValueNotifier<bool>(true);
    _allowResetNotifier = ValueNotifier<bool>(true);
    _loadTaskDetails();
  }

  @override
  void dispose() {
    _tasksSubscription?.cancel();
    _trackSessionNotifier.dispose();
    _followUpNextNotifier.dispose();
    _allowPauseNotifier.dispose();
    _isRestrictModeNotifier.dispose();
    _allowResetNotifier.dispose();
    super.dispose();
  }

  void _loadTaskDetails() {
    debugPrint('DEBUG_POMODORO: --- Ready Screen Load ---');
    debugPrint('DEBUG_POMODORO: Activity ID: ${widget.activity.id}');
    debugPrint('DEBUG_POMODORO: Activity Name: ${widget.activity.name}');
    debugPrint('DEBUG_POMODORO: Tracking Type: ${widget.activity.trackingType}');
    debugPrint('DEBUG_POMODORO: Initial Task passed: ${widget.initialMilestoneTask != null ? "Yes (${widget.initialMilestoneTask!.taskName}, subTasks: ${widget.initialMilestoneTask!.subTasks.map((s) => "${s.title}(checked=${s.checked})").join(", ")})" : "No"}');

    if (widget.initialMilestoneTask != null) {
      setState(() {
        _milestoneTask = widget.initialMilestoneTask;
        if (_milestoneTask!.subTasks.isNotEmpty) {
          final firstUnchecked = _milestoneTask!.subTasks
              .firstWhere((st) => !st.checked, orElse: () => _milestoneTask!.subTasks.first);
          _selectedSubTaskIds.add(firstUnchecked.id);
        }
      });
      debugPrint('DEBUG_POMODORO: Loaded initial task synchronously. Subtasks: ${_milestoneTask!.subTasks.length}');
      return;
    }

    if (widget.activity.trackingType == 'multiple') {
      setState(() => _isLoading = true);
      debugPrint('DEBUG_POMODORO: Ensuring today\'s task for routine exists...');
      GetIt.instance<ActivityService>().getOrCreateTodayTaskForRoutine(widget.activity).then((_) {
        if (mounted) {
          _subscribeToTasksStream();
        }
      }).catchError((e) {
        debugPrint('DEBUG_POMODORO: Routine create error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        debugPrint('Error creating routine task in ReadyScreen: $e');
      });
    } else if (widget.activity.trackingType == 'milestone') {
      _subscribeToTasksStream();
    }
  }

  void _subscribeToTasksStream() {
    _tasksSubscription?.cancel();
    setState(() => _isLoading = true);
    debugPrint('DEBUG_POMODORO: Subscribing to tasks stream for activity: ${widget.activity.id}');
    _tasksSubscription = GetIt.instance<ActivityService>().getTasksForActivityStream(widget.activity.id).listen((tasks) {
      debugPrint('DEBUG_POMODORO: Stream fired with ${tasks.length} tasks');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (tasks.isEmpty) {
            _milestoneTask = null;
            return;
          }
          
          Task? resolvedTask;
          if (widget.activity.trackingType == 'multiple') {
            final now = DateTime.now();
            bool isToday(DateTime date) =>
                date.day == now.day && date.month == now.month && date.year == now.year;
            try {
              resolvedTask = tasks.firstWhere((t) => isToday(t.timestamp));
            } catch (_) {
              resolvedTask = tasks.first;
            }
          } else {
            // First check if widget.activity.id is actually a task ID (virtual activity)
            try {
              resolvedTask = tasks.firstWhere((t) => t.id == widget.activity.id);
            } catch (_) {
              // Otherwise, widget.activity.id is the parent activity's ID. Find first unchecked task
              final unchecked = tasks.where((t) => t.activityId == widget.activity.id && !t.checked);
              if (unchecked.isNotEmpty) {
                resolvedTask = unchecked.first;
              } else {
                final allForActivity = tasks.where((t) => t.activityId == widget.activity.id);
                resolvedTask = allForActivity.isNotEmpty ? allForActivity.first : null;
              }
            }
          }

          final task = resolvedTask;
          _milestoneTask = task;
          if (task != null) {
            debugPrint('DEBUG_POMODORO: Resolved task: ${task.taskName} (subTasks: ${task.subTasks.length})');
            if (task.subTasks.isNotEmpty) {
              final firstUnchecked = task.subTasks
                  .firstWhere((st) => !st.checked, orElse: () => task.subTasks.first);
              if (_selectedSubTaskIds.isEmpty) {
                _selectedSubTaskIds.add(firstUnchecked.id);
              } else {
                final currentSubTaskIds = task.subTasks.map((s) => s.id).toSet();
                _selectedSubTaskIds.retainAll(currentSubTaskIds);
              }
            }
          }
        });
      }
    }, onError: (e) {
      debugPrint('DEBUG_POMODORO: Stream listen error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error fetching task details stream in ReadyScreen: $e');
    });
  }

  void _selectSubTaskToFocus(String subTaskId) {
    setState(() {
      if (_selectedSubTaskIds.contains(subTaskId)) {
        _selectedSubTaskIds.remove(subTaskId);
      } else {
        _selectedSubTaskIds.add(subTaskId);
      }
    });
  }

  void _onReorderSubTasks(int oldIndex, int newIndex) {
    final task = _milestoneTask;
    if (task == null) return;
    setState(() {
      final allSubTasks = List<SubTask>.from(task.subTasks);
      final uncheckedSubTasks = allSubTasks.where((st) => !st.checked).toList();
      final checkedSubTasks = allSubTasks.where((st) => st.checked).toList();

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = uncheckedSubTasks.removeAt(oldIndex);
      uncheckedSubTasks.insert(newIndex, item);

      final updatedTask = task.copyWith(subTasks: [...uncheckedSubTasks, ...checkedSubTasks]);
      _milestoneTask = updatedTask;
      
      GetIt.instance<ActivityService>().updateTask(updatedTask).catchError((e) {
        debugPrint('Error updating reordered subtasks in ReadyScreen: $e');
      });
    });
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _handleSubTaskTap(String id) {
    _selectSubTaskToFocus(id);
  }

  void _startFocus() {
    int durationMinutes = widget.activity.focusDuration;
    if (widget.activity.hasSubTasks && _milestoneTask != null && _selectedSubTaskIds.isNotEmpty) {
      final subTasks = _milestoneTask!.subTasks;
      try {
        final firstSelected = subTasks.firstWhere(
          (st) => _selectedSubTaskIds.contains(st.id) && !st.checked,
        );
        durationMinutes = firstSelected.durationMinutes ?? 25;
      } catch (_) {
        try {
          final firstSelected = subTasks.firstWhere(
            (st) => _selectedSubTaskIds.contains(st.id),
          );
          durationMinutes = firstSelected.durationMinutes ?? 25;
        } catch (_) {
          durationMinutes = widget.activity.focusDuration;
        }
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroTimerScreen(
          activity: widget.activity,
          remainingQueue: widget.remainingQueue,
          initialDurationMinutes: durationMinutes,
          trackSession: _trackSessionNotifier.value,
          followUpNext: _followUpNextNotifier.value,
          allowPause: _allowPauseNotifier.value,
          focusedSubTaskIds: _selectedSubTaskIds.toList(),
          initialMilestoneTask: _milestoneTask,
          isRestrictMode: _isRestrictModeNotifier.value,
          allowReset: _allowResetNotifier.value,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.resolvedBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _CountdownHeader(onCancel: _handleCancel),
                Expanded(
                  child: Column(
                    children: [
                      const VGapSm(),
                      _ReadyHeaderWidget(activity: widget.activity),
                      _ReadySubTaskList(
                        isLoading: _isLoading,
                        hasSubTasks: widget.activity.hasSubTasks,
                        activity: widget.activity,
                        milestoneTask: _milestoneTask,
                        selectedSubTaskIds: _selectedSubTaskIds,
                        onSelectSubTask: _handleSubTaskTap,
                        onReorderSubTasks: _onReorderSubTasks,
                      ),
                      const VGapMd(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CountdownPreferences(
                        hasQueue: widget.remainingQueue.isNotEmpty,
                        trackSessionNotifier: _trackSessionNotifier,
                        followUpNextNotifier: _followUpNextNotifier,
                        allowPauseNotifier: _allowPauseNotifier,
                        isRestrictModeNotifier: _isRestrictModeNotifier,
                        allowResetNotifier: _allowResetNotifier,
                      ),
                      const VGapMd(),
                      _ReadyStartButton(onStart: _startFocus),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownHeader extends StatelessWidget {
  final VoidCallback onCancel;
  const _CountdownHeader({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 16,
                ),
              ),
            ),
          ),
          Text(
            'Ready',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPreferences extends StatelessWidget {
  final bool hasQueue;
  final ValueNotifier<bool> trackSessionNotifier;
  final ValueNotifier<bool> followUpNextNotifier;
  final ValueNotifier<bool> allowPauseNotifier;
  final ValueNotifier<bool> isRestrictModeNotifier;
  final ValueNotifier<bool> allowResetNotifier;

  const _CountdownPreferences({
    required this.hasQueue,
    required this.trackSessionNotifier,
    required this.followUpNextNotifier,
    required this.allowPauseNotifier,
    required this.isRestrictModeNotifier,
    required this.allowResetNotifier,
  });

  void _handleTrackChanged(bool? value) {
    trackSessionNotifier.value = value ?? false;
  }

  void _handleFollowUpChanged(bool? value) {
    followUpNextNotifier.value = value ?? false;
  }

  void _handleAllowPauseChanged(bool? value) {
    allowPauseNotifier.value = value ?? false;
  }

  void _handleRestrictModeChanged(bool? value) {
    isRestrictModeNotifier.value = value ?? false;
  }

  void _handleAllowResetChanged(bool? value) {
    allowResetNotifier.value = value ?? false;
  }

  void _handleTrackTextTapped() {
    trackSessionNotifier.value = !trackSessionNotifier.value;
  }

  void _handleFollowUpTextTapped() {
    if (hasQueue) {
      followUpNextNotifier.value = !followUpNextNotifier.value;
    }
  }

  void _handleAllowPauseTextTapped() {
    allowPauseNotifier.value = !allowPauseNotifier.value;
  }

  void _handleRestrictModeTextTapped() {
    isRestrictModeNotifier.value = !isRestrictModeNotifier.value;
  }

  void _handleAllowResetTextTapped() {
    allowResetNotifier.value = !allowResetNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: trackSessionNotifier,
            builder: (context, trackSession, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: trackSession,
                    onChanged: _handleTrackChanged,
                    activeColor: AppTheme.primaryColor,
                    checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                    side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const HGapSm(),
                  GestureDetector(
                    onTap: _handleTrackTextTapped,
                    child: Text(
                      'Track Session',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const VGapXs(),
          Opacity(
            opacity: hasQueue ? 1.0 : 0.5,
            child: ValueListenableBuilder<bool>(
              valueListenable: followUpNextNotifier,
              builder: (context, followUpNext, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: followUpNext,
                      onChanged: hasQueue ? _handleFollowUpChanged : null,
                      activeColor: AppTheme.primaryColor,
                      checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                      side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const HGapSm(),
                    GestureDetector(
                      onTap: _handleFollowUpTextTapped,
                      child: Text(
                        'Follow up next',
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const VGapXs(),
          ValueListenableBuilder<bool>(
            valueListenable: allowPauseNotifier,
            builder: (context, allowPause, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: allowPause,
                    onChanged: _handleAllowPauseChanged,
                    activeColor: AppTheme.primaryColor,
                    checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                    side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const HGapSm(),
                  GestureDetector(
                    onTap: _handleAllowPauseTextTapped,
                    child: Text(
                      'Allow pause',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const VGapXs(),
          ValueListenableBuilder<bool>(
            valueListenable: isRestrictModeNotifier,
            builder: (context, isRestrictMode, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: isRestrictMode,
                    onChanged: _handleRestrictModeChanged,
                    activeColor: AppTheme.primaryColor,
                    checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                    side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const HGapSm(),
                  GestureDetector(
                    onTap: _handleRestrictModeTextTapped,
                    child: Text(
                      'Restrict mode',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const VGapXs(),
          ValueListenableBuilder<bool>(
            valueListenable: allowResetNotifier,
            builder: (context, allowReset, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: allowReset,
                    onChanged: _handleAllowResetChanged,
                    activeColor: AppTheme.primaryColor,
                    checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                    side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const HGapSm(),
                  GestureDetector(
                    onTap: _handleAllowResetTextTapped,
                    child: Text(
                      'Allow reset timer',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountdownSubTaskItem extends StatelessWidget {
  final SubTask subTask;
  final bool isFocused;
  final VoidCallback onTap;

  const _CountdownSubTaskItem({
    required this.subTask,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = subTask.checked;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: isCompleted ? true : isFocused,
            onChanged: isCompleted ? null : (_) => onTap(),
            activeColor: isCompleted
                ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                : AppTheme.primaryColor,
            checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
            side: BorderSide(
              color: isCompleted
                  ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.3)
                  : AppTheme.textSecondaryColor(context),
              width: 1.5,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: GestureDetector(
              onTap: isCompleted ? null : onTap,
              child: Text(
                subTask.title,
                style: TextStyle(
                  color: isCompleted
                      ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.5)
                      : (isFocused
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimaryColor(context)),
                  fontWeight: isFocused ? FontWeight.w800 : FontWeight.bold,
                  fontSize: 16,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const HGapSm(),
          Text(
            '${subTask.durationMinutes ?? 25} min',
            style: TextStyle(
              color: isCompleted
                  ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                  : AppTheme.textSecondaryColor(context),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownSubTaskPlaceholderItem extends StatelessWidget {
  const _CountdownSubTaskPlaceholderItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: false,
            onChanged: null,
            activeColor: AppTheme.primaryColor,
            checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
            side: BorderSide(color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2), width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyHeaderWidget extends StatelessWidget {
  final Activity activity;

  const _ReadyHeaderWidget({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          activity.name,
          style: TextStyle(
            fontSize: 32,
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const VGapXs(),
        Text(
          '${activity.focusDuration} min',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const VGapSm(),
        if (activity.hasSubTasks) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select task to focus',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const VGapSm(),
        ],
      ],
    );
  }
}

class _ReadyStartButton extends StatelessWidget {
  final VoidCallback onStart;

  const _ReadyStartButton({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onStart,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.isDarkMode(context)
              ? Colors.black
              : Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: const Text(
          'Start Focus',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ReadySubTaskList extends StatelessWidget {
  final bool isLoading;
  final bool hasSubTasks;
  final Activity activity;
  final Task? milestoneTask;
  final Set<String> selectedSubTaskIds;
  final ValueChanged<String> onSelectSubTask;
  final ReorderCallback onReorderSubTasks;

  const _ReadySubTaskList({
    required this.isLoading,
    required this.hasSubTasks,
    required this.activity,
    required this.milestoneTask,
    required this.selectedSubTaskIds,
    required this.onSelectSubTask,
    required this.onReorderSubTasks,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (index) => const _CountdownSubTaskPlaceholderItem(),
            ),
          ),
        ),
      );
    }

    if (!hasSubTasks) {
      return const SizedBox.shrink();
    }

    final subTasks = (milestoneTask?.subTasks ?? []).where((st) => !st.checked).toList();

    if (subTasks.isNotEmpty) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ReorderableListView.builder(
            padding: EdgeInsets.zero,
            onReorder: onReorderSubTasks,
            itemCount: subTasks.length,
            itemBuilder: (context, index) {
              final subTask = subTasks[index];
              return _ReadySubTaskRow(
                key: ValueKey(subTask.id),
                index: index,
                subTask: subTask,
                isFocused: selectedSubTaskIds.contains(subTask.id),
                onTap: () => onSelectSubTask(subTask.id),
              );
            },
          ),
        ),
      );
    }

    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.playlist_add_check_rounded,
                size: 48,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
              ),
              const VGapSm(),
              Text(
                milestoneTask == null
                    ? 'No active task found for "${activity.name}" (ID: ${activity.id}).'
                    : (milestoneTask!.subTasks.isEmpty
                        ? 'No sub-tasks defined for "${milestoneTask!.taskName}" (Task ID: ${milestoneTask!.id}, Activity ID: ${milestoneTask!.activityId}).'
                        : 'All sub-tasks are completed for "${milestoneTask!.taskName}".'),
                style: TextStyle(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadySubTaskRow extends StatelessWidget {
  final int index;
  final SubTask subTask;
  final bool isFocused;
  final VoidCallback onTap;

  const _ReadySubTaskRow({
    super.key,
    required this.index,
    required this.subTask,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CountdownSubTaskItem(
            subTask: subTask,
            isFocused: isFocused,
            onTap: onTap,
          ),
        ),
        ReorderableDragStartListener(
          index: index,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Icon(
              Icons.drag_handle_rounded,
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
