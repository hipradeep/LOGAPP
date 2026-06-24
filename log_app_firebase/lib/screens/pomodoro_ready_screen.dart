import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../models/activity.dart';
import '../models/task.dart';
import '../services/service_locator.dart';
import '../services/activity_service.dart';
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
  bool _trackSession = true;
  bool _followUpNext = true;
  bool _allowPause = true;
  bool _isRestrictMode = true;
  Task? _milestoneTask;
  final Set<String> _selectedSubTaskIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  void _loadTaskDetails() {
    if (widget.initialMilestoneTask != null) {
      setState(() {
        _milestoneTask = widget.initialMilestoneTask;
        if (_milestoneTask!.subTasks.isNotEmpty) {
          final firstUnchecked = _milestoneTask!.subTasks
              .firstWhere((st) => !st.checked, orElse: () => _milestoneTask!.subTasks.first);
          _selectedSubTaskIds.add(firstUnchecked.id);
        }
      });
      return;
    }

    if (widget.activity.trackingType == 'milestone') {
      setState(() => _isLoading = true);
      getIt<ActivityService>().getActiveTaskForActivity(widget.activity.id).then((task) {
        if (mounted) {
          setState(() {
            _milestoneTask = task;
            _isLoading = false;
            if (task != null && task.subTasks.isNotEmpty) {
              final firstUnchecked = task.subTasks
                  .firstWhere((st) => !st.checked, orElse: () => task.subTasks.first);
              _selectedSubTaskIds.add(firstUnchecked.id);
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        debugPrint('Error fetching milestone task details in ReadyScreen: $e');
      });
    } else if (widget.activity.trackingType == 'multiple') {
      setState(() => _isLoading = true);
      getIt<ActivityService>().getOrCreateTodayTaskForRoutine(widget.activity).then((task) {
        if (mounted) {
          setState(() {
            _milestoneTask = task;
            _isLoading = false;
            if (task != null && task.subTasks.isNotEmpty) {
              final firstUnchecked = task.subTasks
                  .firstWhere((st) => !st.checked, orElse: () => task.subTasks.first);
              _selectedSubTaskIds.add(firstUnchecked.id);
            }
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        debugPrint('Error fetching routine task details in ReadyScreen: $e');
      });
    }
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
      
      getIt<ActivityService>().updateTask(updatedTask).catchError((e) {
        debugPrint('Error updating reordered subtasks in ReadyScreen: $e');
      });
    });
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
          trackSession: _trackSession,
          followUpNext: _followUpNext,
          allowPause: _allowPause,
          focusedSubTaskIds: _selectedSubTaskIds.toList(),
          initialMilestoneTask: _milestoneTask,
          isRestrictMode: _isRestrictMode,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final subTasks = (_milestoneTask?.subTasks ?? []).where((st) => !st.checked).toList();

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
                _CountdownHeader(onCancel: () => Navigator.pop(context)),
                Expanded(
                  child: Column(
                    children: [
                      const VGapSm(),
                      Text(
                        widget.activity.name,
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
                        '${widget.activity.focusDuration} min',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isLoading || subTasks.isNotEmpty) ...[
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
                      if (_isLoading) ...[
                        Align(
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
                        ),
                      ] else if (subTasks.isNotEmpty) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ReorderableListView(
                              padding: EdgeInsets.zero,
                              onReorder: _onReorderSubTasks,
                              children: [
                                for (int index = 0; index < subTasks.length; index++) ...[
                                  Row(
                                    key: ValueKey(subTasks[index].id),
                                    children: [
                                      Expanded(
                                        child: _CountdownSubTaskItem(
                                          subTask: subTasks[index],
                                          isFocused: _selectedSubTaskIds.contains(subTasks[index].id),
                                          onTap: () => _selectSubTaskToFocus(subTasks[index].id),
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
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
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
                        trackSession: _trackSession,
                        followUpNext: _followUpNext,
                        allowPause: _allowPause,
                        isRestrictMode: _isRestrictMode,
                        onTrackSessionChanged: (val) {
                          setState(() => _trackSession = val);
                        },
                        onFollowUpNextChanged: (val) {
                          setState(() => _followUpNext = val);
                        },
                        onAllowPauseChanged: (val) {
                          setState(() => _allowPause = val);
                        },
                        onRestrictModeChanged: (val) {
                          setState(() => _isRestrictMode = val);
                        },
                      ),
                      const VGapMd(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _startFocus,
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
                      ),
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
  final bool trackSession;
  final bool followUpNext;
  final bool allowPause;
  final bool isRestrictMode;
  final ValueChanged<bool> onTrackSessionChanged;
  final ValueChanged<bool> onFollowUpNextChanged;
  final ValueChanged<bool> onAllowPauseChanged;
  final ValueChanged<bool> onRestrictModeChanged;

  const _CountdownPreferences({
    required this.hasQueue,
    required this.trackSession,
    required this.followUpNext,
    required this.allowPause,
    required this.isRestrictMode,
    required this.onTrackSessionChanged,
    required this.onFollowUpNextChanged,
    required this.onAllowPauseChanged,
    required this.onRestrictModeChanged,
  });

  void _handleTrackChanged(bool? value) {
    onTrackSessionChanged(value ?? false);
  }

  void _handleFollowUpChanged(bool? value) {
    onFollowUpNextChanged(value ?? false);
  }

  void _handleAllowPauseChanged(bool? value) {
    onAllowPauseChanged(value ?? false);
  }

  void _handleRestrictModeChanged(bool? value) {
    onRestrictModeChanged(value ?? false);
  }

  void _handleTrackTextTapped() {
    onTrackSessionChanged(!trackSession);
  }

  void _handleFollowUpTextTapped() {
    if (hasQueue) {
      onFollowUpNextChanged(!followUpNext);
    }
  }

  void _handleAllowPauseTextTapped() {
    onAllowPauseChanged(!allowPause);
  }

  void _handleRestrictModeTextTapped() {
    onRestrictModeChanged(!isRestrictMode);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ),
          const VGapXs(),
          Opacity(
            opacity: hasQueue ? 1.0 : 0.5,
            child: Row(
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
            ),
          ),
          const VGapXs(),
          Row(
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
          ),
          const VGapXs(),
          Row(
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
