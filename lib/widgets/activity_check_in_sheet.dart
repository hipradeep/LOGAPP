import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_icons.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import 'burn_chart.dart';

class ActivityCheckInSheet extends StatefulWidget {
  final Activity activity;

  const ActivityCheckInSheet({
    super.key,
    required this.activity,
  });

  @override
  State<ActivityCheckInSheet> createState() => _ActivityCheckInSheetState();
}

class _ActivityCheckInSheetState extends State<ActivityCheckInSheet> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();
  final DateTime _now = DateTime.now();
  late Stream<List<CheckIn>> _checkInsStream;
  late Stream<List<Task>> _tasksStream;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  void initState() {
    super.initState();
    _checkInsStream = _checkInService.getCheckInsStreamForActivity(widget.activity.id);
    _tasksStream = _activityService.getTasksForActivityStream(widget.activity.id);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
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
              child: StreamBuilder<List<CheckIn>>(
                  stream: _checkInsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Error loading history', style: TextStyle(color: AppTheme.errorColor)),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      );
                    }
                    final checkIns = snapshot.data ?? [];

                    return StreamBuilder<List<Task>>(
                      stream: _tasksStream,
                      builder: (context, tasksSnapshot) {
                        if (tasksSnapshot.hasError) {
                          return const Center(
                            child: Text('Error loading tasks', style: TextStyle(color: AppTheme.errorColor)),
                          );
                        }
                        if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          );
                        }
                        final tasks = tasksSnapshot.data ?? [];
                        return _buildSheetContent(scrollController, checkIns, tasks);
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheetContent(ScrollController scrollController, List<CheckIn> checkIns, List<Task> tasks) {
    // Calculate today's completed check-ins
    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();
    
    final todayTask = widget.activity.trackingType == 'multiple'
        ? tasks.firstWhere(
            (s) => _isToday(s.timestamp) && s.subTasks.isNotEmpty,
            orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
          )
        : null;

    final todayCount = widget.activity.trackingType == 'multiple'
        ? todayTask!.subTasks.where((s) => s.checked).length
        : (widget.activity.trackingType == 'milestone'
            ? tasks.where((s) => _isToday(s.timestamp) && s.checked).length
            : todayCheckIns.length);

    final targetCount = widget.activity.trackingType == 'multiple'
        ? (todayTask!.id.isNotEmpty ? todayTask.subTasks.length : widget.activity.subTaskTemplates.length)
        : widget.activity.targetCount;

    final isMultiple = targetCount > 1;
    final bool isCompleted = todayCount >= targetCount;

    return Column(
      children: [
        const VGapMd(),
        // Drawer drag handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const VGapLg(),
        
        // Sheet Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          isMultiple || widget.activity.trackingType == 'milestone'
                              ? 'Target: $targetCount times per day (Today: $todayCount)'
                              : 'Daily check-in',
                          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        if ((widget.activity.trackingType == 'single' ||
                                widget.activity.trackingType == 'milestone') &&
                            widget.activity.scheduledTime != null &&
                            widget.activity.scheduledTime!.isNotEmpty) ...[
                          Text(
                            '  •  ',
                            style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                          ),
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppTheme.primaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimeString(widget.activity.scheduledTime!),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.primaryLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                ),
              ),
            ],
          ),
        ),
        const VGapLg(),
        const Divider(color: Colors.white10, height: 1, indent: 24, endIndent: 24),
        const VGapMd(),

        Expanded(
          child: ListView(
            // Detached scrollController to prevent keyboard focus-stealing
            controller: null,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              // 1. Current Check-In Section
              if (widget.activity.trackingType == 'single') ...[
                _buildCurrentCheckInCard(isCompleted, todayCount, targetCount, isMultiple, todayCheckIns, tasks),
                const VGapLg(),
              ],
              
              // Progress indicator for check-ins (single, multiple, or milestone)
              if (widget.activity.trackingType == 'single' || isMultiple || widget.activity.trackingType == 'milestone') ...[
                _buildProgressBar(todayCount, targetCount),
                const VGapLg(),
              ],
              
              // Tasks checklist section (if activity has tasks enabled)
              if (widget.activity.hasSubTasks) ...[
                _buildSubTasksSection(tasks),
                const VGapLg(),
              ],

              // Description section (shown below subtasks if present)
              if (widget.activity.description != null && widget.activity.description!.isNotEmpty) ...[
                _buildDescriptionSection(widget.activity.description!),
                const VGapLg(),
              ],
              
              // Activity details graph
              BurnChart(
                activity: widget.activity,
                checkIns: checkIns,
                tasks: tasks,
              ),
              const VGapLg(),
              
              // 2. History Section Title
              Row(
                children: [
                  const IconSm(Icons.history_rounded, color: AppTheme.textSecondary),
                  const HGapSm(),
                  Text(
                    'History Logs'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const VGapMd(),

              // 3. History Checklist List
              _buildHistorySection(checkIns, tasks),
            ],
          ),
        ),
      ],
    );
  }

  // CURRENT DATE & TIME CHECK-IN WIDGET
  Widget _buildCurrentCheckInCard(bool isCompleted, int todayCount, int targetCount, bool isMultiple, List<CheckIn> todayCheckIns, List<Task> tasks) {
    final formattedTime = todayCheckIns.isNotEmpty
        ? DateFormat('h:mm a').format(todayCheckIns.first.timestamp)
        : DateFormat('h:mm a').format(_now);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Text Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMultiple || widget.activity.trackingType == 'milestone' ? 'Daily Progress' : 'Daily Habit Check-in',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const VGapXs(),
                Text(
                  isMultiple || widget.activity.trackingType == 'milestone'
                      ? '$todayCount of $targetCount logged today'
                      : (isCompleted ? 'Checked in today at $formattedTime' : 'Not checked in yet today'),
                  style: AppTheme.bodySmall.copyWith(
                    color: isCompleted ? AppTheme.successColor.withValues(alpha: 0.8) : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const HGapMd(),
          
          // Action Checkbox/Button on the right
          if (widget.activity.trackingType != 'milestone')
            GestureDetector(
              onTap: () => _handleTodayCheckIn(isCompleted, todayCheckIns, tasks),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: widget.activity.trackingType == 'single' ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: widget.activity.trackingType == 'single' ? BorderRadius.circular(6) : null,
                  color: isCompleted ? AppTheme.primaryColor : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: widget.activity.trackingType == 'single'
                    ? (isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null)
                    : Icon(
                        Icons.add,
                        size: 14,
                        color: isCompleted ? Colors.white : AppTheme.primaryLight,
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int count, int target) {
    final double percent = (count / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Progress',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
            ),
            Text(
              '${(percent * 100).toInt()}% completed',
              style: AppTheme.bodySmall.copyWith(
                color: percent >= 1.0 ? AppTheme.successColor : AppTheme.primaryLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const VGapXs(),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 8,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.05),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: percent >= 1.0
                        ? [AppTheme.successColor, AppTheme.successColor.withValues(alpha: 0.7)]
                        : [AppTheme.primaryColor, AppTheme.primaryLight],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  // HISTORY CHECKLIST LIST VIEW
  Widget _buildHistorySection(List<CheckIn> checkIns, List<Task> tasks) {
    final List<_HistoryItem> historyItems = [];
    
    // Sort a copy of the checkIns list descending by timestamp
    final List<CheckIn> sortedCheckIns = List<CheckIn>.from(checkIns);
    sortedCheckIns.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Get the last 3 calendar days (Today, Yesterday, 2 Days Ago)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limitDate = today.subtract(const Duration(days: 2));

    // Add checked check-ins that fall within the last 3 calendar days
    for (var c in sortedCheckIns) {
      if (c.checked) {
        final date = DateTime(c.timestamp.year, c.timestamp.month, c.timestamp.day);
        if (!date.isBefore(limitDate)) {
          historyItems.add(_HistoryItem(
            id: c.id,
            timestamp: c.timestamp,
            checked: c.checked,
            subTaskName: c.subTaskName,
            isSubTask: c.subTaskName != null && c.subTaskName!.isNotEmpty,
            originalObject: c,
          ));
        }
      }
    }

    if (historyItems.isEmpty) {
      return _buildEmptyHistoryState();
    }

    // Sort descending by timestamp
    historyItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _buildHistoryList(historyItems, tasks);
  }

  String _formatHistoryDate(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    final timeStr = DateFormat('h:mm a').format(timestamp);

    if (itemDate == today) {
      return 'Today • $timeStr';
    } else if (itemDate == yesterday) {
      return 'Yesterday • $timeStr';
    } else {
      final dayName = DateFormat('EEEE').format(timestamp);
      return '$dayName • $timeStr';
    }
  }

  Widget _buildHistoryList(List<_HistoryItem> items, List<Task> tasks) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final formattedDate = _formatHistoryDate(item.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.checked ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.02),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: item.checked ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                    ),
                    const HGapMd(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedDate,
                            style: AppTheme.bodyMedium.copyWith(
                              color: item.checked ? Colors.white : AppTheme.textSecondary,
                              fontWeight: item.checked ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                          if (item.subTaskName != null) ...[
                            const VGapXs(),
                            Text(
                              item.subTaskName!.contains('|')
                                  ? (widget.activity.trackingType == 'multiple'
                                      ? 'Task: ${item.subTaskName!.split('|').first} (${_formatTimeString(item.subTaskName!.split('|').last)})'
                                      : 'Task: ${item.subTaskName!.split('|').first}')
                                  : 'Task: ${item.subTaskName}',
                              style: const TextStyle(
                                color: AppTheme.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const HGapMd(),
              // Delete Check-in
              if (_isToday(item.timestamp))
                GestureDetector(
                  onTap: () => _deleteHistoryItem(item, tasks),
                  child: const Icon(
                     Icons.delete_outline_rounded,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        );
      },
    );
  }

  void _deleteHistoryItem(_HistoryItem item, List<Task> tasks) async {
    if (!_isToday(item.timestamp)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete previous day\'s log entry.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (item.isSubTask) {
      try {
        await _checkInService.deleteCheckIn(item.id);
        
        if (widget.activity.trackingType == 'multiple') {
          // Find the corresponding container Task in loaded tasks
          final taskForDay = tasks.firstWhere(
            (s) => _isSameDay(s.timestamp, item.timestamp) && s.subTasks.isNotEmpty,
            orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: item.timestamp, checked: false),
          );
          if (taskForDay.id.isNotEmpty) {
            final List<SubTask> updatedSubTasks = List<SubTask>.from(taskForDay.subTasks);
            final index = updatedSubTasks.indexWhere((st) {
              final cleanTitle = st.title.contains('|') ? st.title.split('|').first : st.title;
              return cleanTitle == item.subTaskName;
            });
            if (index != -1) {
              updatedSubTasks[index] = updatedSubTasks[index].copyWith(checked: false);
              
              final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
              final updatedTask = taskForDay.copyWith(subTasks: updatedSubTasks, checked: allChecked);
              await _activityService.updateTask(updatedTask);
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete history item: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } else {
      _deleteCheckIn(item.id);
    }
  }

  Widget _buildEmptyHistoryState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        'No check-ins logged yet.',
        style: AppTheme.bodyMedium.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildDescriptionSection(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconSm(Icons.description_rounded, color: AppTheme.textSecondary),
            const HGapSm(),
            Text(
              'Description'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const VGapSm(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
              width: 1,
            ),
          ),
          child: Text(
            description,
            style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  // ACTIONS
  void _handleTodayCheckIn(bool isCompleted, List<CheckIn> todayCheckIns, List<Task> tasks) async {
    // For single check-ins, limit to 1 per day
    if (widget.activity.trackingType == 'single' && isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already checked in today!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final checkInNow = DateTime.now();

    // For multiple activity sync subtasks logic
    if (widget.activity.trackingType == 'multiple') {
      final todayTask = tasks.firstWhere(
        (s) => _isToday(s.timestamp) && s.subTasks.isNotEmpty,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
      );

      if (todayTask.id.isEmpty) {
        // Create today's container and check all subtasks
        final List<SubTask> initialSubTasks = widget.activity.subTaskTemplates.map((template) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          return SubTask(
            id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}',
            title: title,
            checked: true,
            scheduledTime: timeStr,
          );
        }).toList();

        await _activityService.createTask(
          widget.activity.id,
          widget.activity.name,
          DateTime.now(),
          true,
          subTasks: initialSubTasks,
        );

        // Create check-in entries for each subtask
        for (var st in initialSubTasks) {
          await _checkInService.createCheckIn(
            widget.activity.id,
            checkInNow,
            true,
            subTaskName: st.title,
          );
        }
      } else {
        // Toggle all unchecked subtasks to checked
        final List<SubTask> updatedSubTasks = List<SubTask>.from(todayTask.subTasks);
        bool modified = false;
        for (int i = 0; i < updatedSubTasks.length; i++) {
          if (!updatedSubTasks[i].checked) {
            updatedSubTasks[i] = updatedSubTasks[i].copyWith(checked: true);
            modified = true;

            await _checkInService.createCheckIn(
              widget.activity.id,
              checkInNow,
              true,
              subTaskName: updatedSubTasks[i].title,
            );
          }
        }
        if (modified) {
          final updatedTask = todayTask.copyWith(subTasks: updatedSubTasks, checked: true);
          await _activityService.updateTask(updatedTask);
        }
      }
    }

    if (!mounted) return;
    try {
      await _checkInService.createCheckIn(widget.activity.id, checkInNow, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged check-in to Firestore.'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check in: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _deleteCheckIn(String id) async {
    try {
      await _checkInService.deleteCheckIn(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete check-in: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  // TASKS UI SECTION
  Widget _buildSubTasksSection(List<Task> tasks) {
    final List<_SubTaskUiItem> uiItems = [];

    if (widget.activity.trackingType == 'multiple') {
      // Find today's container Task document
      final todayTask = tasks.firstWhere(
        (s) => _isToday(s.timestamp) && s.subTasks.isNotEmpty,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
      );

      if (todayTask.id.isEmpty) {
        // Container not created in Firestore yet: show templates as unchecked
        for (var template in widget.activity.subTaskTemplates) {
          final parts = template.split('|');
          final title = parts.first;
          final timeStr = parts.length > 1 ? parts.last : null;
          uiItems.add(_SubTaskUiItem(
            name: title,
            checked: false,
            subTaskId: null,
            isTemplate: true,
            scheduledTime: timeStr,
          ));
        }
      } else {
        // Show subtasks from today's container Task
        for (var st in todayTask.subTasks) {
          final isTemplate = widget.activity.subTaskTemplates.any((t) => t.split('|').first == st.title);
          uiItems.add(_SubTaskUiItem(
            name: st.title,
            checked: st.checked,
            subTaskId: st.id,
            isTemplate: isTemplate,
            scheduledTime: st.scheduledTime,
          ));
        }
      }
    } else {
      // Milestone: show today's tasks
      final todayTasks = tasks.where((s) => _isToday(s.timestamp)).toList();
      for (var s in todayTasks) {
        uiItems.add(_SubTaskUiItem(
          name: s.taskName,
          checked: s.checked,
          subTaskId: s.id,
          isTemplate: false,
          scheduledTime: s.scheduledTime,
        ));
      }
    }

    // For milestone, show only active (unchecked) tasks
    final displayItems = widget.activity.trackingType == 'milestone'
        ? uiItems.where((i) => !i.checked).toList()
        : uiItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconSm(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary),
            const HGapSm(),
            Text(
              'Tasks Checklist'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const VGapMd(),

        // List of sub-tasks
        if (displayItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                widget.activity.trackingType == 'milestone'
                    ? 'No pending tasks for today.'
                    : 'No tasks defined for this activity.',
                style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              children: displayItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == displayItems.length - 1;
                final isMilestoneCustom = widget.activity.trackingType == 'milestone' && !item.isTemplate && item.subTaskId != null;

                final Widget itemContainer = Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.checked 
                        ? AppTheme.primaryColor.withValues(alpha: 0.08) 
                        : AppTheme.surfaceColor.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.checked 
                          ? AppTheme.primaryColor.withValues(alpha: 0.25) 
                          : Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  color: item.checked ? AppTheme.textSecondary : Colors.white,
                                  decoration: item.checked ? TextDecoration.lineThrough : null,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.activity.trackingType == 'multiple' && item.scheduledTime != null && item.scheduledTime!.isNotEmpty) ...[
                              const HGapSm(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.checked
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
                                      color: item.checked
                                          ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                          : AppTheme.primaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatTimeString(item.scheduledTime!),
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
                              ),
                            ],
                          ],
                        ),
                      ),
                      const HGapMd(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _toggleSubTask(item, tasks);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: item.checked ? AppTheme.primaryColor : Colors.transparent,
                              border: Border.all(
                                color: item.checked 
                                    ? AppTheme.primaryColor 
                                    : AppTheme.textSecondary.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: item.checked
                                ? const Icon(Icons.check, size: 12, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (isMilestoneCustom) {
                  return GestureDetector(
                    onLongPress: () {
                      // Custom milestone details are managed on Milestones Tab, here we just show/check it.
                    },
                    child: itemContainer,
                  );
                }
                return itemContainer;
              }).toList(),
            ),
          ),
      ],
    );
  }

  String _formatTimeForDisplay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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

  void _toggleSubTask(_SubTaskUiItem item, List<Task> tasks) async {
    final newChecked = !item.checked;
    final checkInNow = DateTime.now();

    if (widget.activity.trackingType == 'multiple') {
      // Find today's container Task
      final todayTask = tasks.firstWhere(
        (s) => _isToday(s.timestamp) && s.subTasks.isNotEmpty,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
      );

      try {
        if (todayTask.id.isEmpty) {
          // Create a new Task container for today with all templates
          final List<SubTask> initialSubTasks = widget.activity.subTaskTemplates.map((template) {
            final parts = template.split('|');
            final title = parts.first;
            final timeStr = parts.length > 1 ? parts.last : null;
            final isToggled = title == item.name && timeStr == item.scheduledTime;

            return SubTask(
              id: 'subtask-${DateTime.now().millisecondsSinceEpoch}-${template.hashCode}',
              title: title,
              checked: isToggled,
              scheduledTime: timeStr,
            );
          }).toList();

          final allChecked = initialSubTasks.every((st) => st.checked);

          await _activityService.createTask(
            widget.activity.id,
            widget.activity.name,
            DateTime.now(),
            allChecked,
            subTasks: initialSubTasks,
          );

          if (newChecked) {
            await _checkInService.createCheckIn(
              widget.activity.id,
              checkInNow,
              true,
              subTaskName: item.name,
            );
          }
        } else {
          // Toggle the subtask inside the existing container
          final List<SubTask> updatedSubTasks = List<SubTask>.from(todayTask.subTasks);
          final index = updatedSubTasks.indexWhere((st) {
            if (item.subTaskId != null) {
              return st.id == item.subTaskId;
            } else {
              return st.title == item.name && st.scheduledTime == item.scheduledTime;
            }
          });

          if (index != -1) {
            updatedSubTasks[index] = updatedSubTasks[index].copyWith(checked: newChecked);
            
            final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
            final updatedTask = todayTask.copyWith(subTasks: updatedSubTasks, checked: allChecked);
            await _activityService.updateTask(updatedTask);

            // Create or delete check-in log entry
            if (newChecked) {
              await _checkInService.createCheckIn(
                widget.activity.id,
                checkInNow,
                true,
                subTaskName: item.name,
              );
            } else {
              final existing = await _checkInService.getCheckInsForActivity(widget.activity.id);
              final todayCheckIn = existing.firstWhere(
                (c) => _isToday(c.timestamp) && c.subTaskName == item.name && c.checked,
                orElse: () => CheckIn(id: '', activityId: '', timestamp: DateTime.now(), checked: false),
              );
              if (todayCheckIn.id.isNotEmpty) {
                await _checkInService.deleteCheckIn(todayCheckIn.id);
              }
            }
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } else {
      // Milestone standard toggle
      if (item.subTaskId != null) {
        await _activityService.toggleTask(item.subTaskId!, newChecked);
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }
}

class _SubTaskUiItem {
  final String name;
  final bool checked;
  final String? subTaskId;
  final bool isTemplate;
  final String? scheduledTime;

  _SubTaskUiItem({
    required this.name,
    required this.checked,
    this.subTaskId,
    required this.isTemplate,
    this.scheduledTime,
  });
}

class _HistoryItem {
  final String id;
  final DateTime timestamp;
  final bool checked;
  final String? subTaskName;
  final bool isSubTask;
  final dynamic originalObject;

  _HistoryItem({
    required this.id,
    required this.timestamp,
    required this.checked,
    this.subTaskName,
    required this.isSubTask,
    required this.originalObject,
  });
}


