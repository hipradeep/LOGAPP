import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import 'app_icons.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/sub_task.dart';
import '../services/firebase_service.dart';

class ActivityCheckInSheet extends StatefulWidget {
  final Activity activity;
  final bool useMockData;

  const ActivityCheckInSheet({
    super.key,
    required this.activity,
    required this.useMockData,
  });

  @override
  State<ActivityCheckInSheet> createState() => _ActivityCheckInSheetState();
}

class _ActivityCheckInSheetState extends State<ActivityCheckInSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  final DateTime _now = DateTime.now();
  final TextEditingController _subTaskTextController = TextEditingController();
  final FocusNode _subTaskFocusNode = FocusNode();
  late Stream<List<CheckIn>> _checkInsStream;
  late Stream<List<SubTask>> _subTasksStream;
  TimeOfDay? _subTaskTime;
  String? _deletingSubTaskId;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  void initState() {
    super.initState();
    _checkInsStream = _firebaseService.getCheckInsStream(widget.activity.id);
    _subTasksStream = _firebaseService.getSubTasksForActivityStream(widget.activity.id);
  }

  @override
  void dispose() {
    _subTaskTextController.dispose();
    _subTaskFocusNode.dispose();
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
              child: widget.useMockData
                  ? _buildSheetContent(scrollController, _getLocalCheckIns(), _getLocalSubTasks())
                  : StreamBuilder<List<CheckIn>>(
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

                        return StreamBuilder<List<SubTask>>(
                          stream: _subTasksStream,
                          builder: (context, subtaskSnapshot) {
                            if (subtaskSnapshot.hasError) {
                              return const Center(
                                child: Text('Error loading sub-tasks', style: TextStyle(color: AppTheme.errorColor)),
                              );
                            }
                            if (subtaskSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(color: AppTheme.primaryColor),
                              );
                            }
                            final subTasks = subtaskSnapshot.data ?? [];
                            return _buildSheetContent(scrollController, checkIns, subTasks);
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

  List<CheckIn> _getLocalCheckIns() {
    final checkIns = FirebaseService.mockCheckIns
        .where((c) => c.activityId == widget.activity.id)
        .toList();
    // Sort descending by timestamp
    checkIns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return checkIns;
  }

  List<SubTask> _getLocalSubTasks() {
    final subTasks = FirebaseService.mockSubTasks
        .where((s) => s.activityId == widget.activity.id)
        .toList();
    // Sort descending by timestamp
    subTasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return subTasks;
  }

  Widget _buildSheetContent(ScrollController scrollController, List<CheckIn> checkIns, List<SubTask> subTasks) {
    // Calculate today's completed check-ins
    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();
    final todayCount = widget.activity.trackingType == 'multiple'
        ? subTasks.where((s) => _isToday(s.timestamp) && s.checked).length
        : todayCheckIns.length;
    final targetCount = widget.activity.targetCount;
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
                          isMultiple
                              ? 'Target: $targetCount times per day (Today: $todayCount)'
                              : (widget.activity.trackingType == 'milestone'
                                  ? 'Goal milestone'
                                  : 'Daily check-in'),
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
              if (widget.activity.trackingType != 'multiple') ...[
                _buildCurrentCheckInCard(isCompleted, todayCount, targetCount, isMultiple, todayCheckIns, subTasks),
                const VGapLg(),
              ],
              
              // Progress indicator for multiple check-ins
              if (isMultiple) ...[
                _buildProgressBar(todayCount, targetCount),
                const VGapLg(),
              ],
              


              // Sub-tasks checklist section (if activity has sub-tasks enabled)
              if (widget.activity.hasSubTasks) ...[
                _buildSubTasksSection(subTasks, !widget.useMockData),
                const VGapLg(),
              ],

              // Description section (shown below subtasks if present)
              if (widget.activity.description != null && widget.activity.description!.isNotEmpty) ...[
                _buildDescriptionSection(widget.activity.description!),
                const VGapLg(),
              ],
              
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
              const VGapSm(),

              // 3. History Checklist List
              _buildHistorySection(checkIns, subTasks),
            ],
          ),
        ),
      ],
    );
  }

  // CURRENT DATE & TIME CHECK-IN WIDGET
  Widget _buildCurrentCheckInCard(bool isCompleted, int todayCount, int targetCount, bool isMultiple, List<CheckIn> todayCheckIns, List<SubTask> subTasks) {
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
                  isMultiple ? 'Daily Routine Log' : (widget.activity.trackingType == 'milestone' ? 'Goal Milestone' : 'Daily Habit Check-in'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const VGapXs(),
                Text(
                  isMultiple
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
          GestureDetector(
            onTap: () => _handleTodayCheckIn(isCompleted, todayCheckIns, subTasks),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppTheme.primaryColor : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Icon(
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
  Widget _buildHistorySection(List<CheckIn> checkIns, List<SubTask> subTasks) {
    final List<_HistoryItem> historyItems = [];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final limitDate = todayStart.subtract(const Duration(days: 2)); // Last 3 calendar days (today, yesterday, day before)
    
    // Add checked main checkins
    for (var c in checkIns) {
      if (c.checked && c.timestamp.isAfter(limitDate)) {
        historyItems.add(_HistoryItem(
          id: c.id,
          timestamp: c.timestamp,
          checked: c.checked,
          isSubTask: false,
          originalObject: c,
        ));
      }
    }
    
    // Add checked subtask completions
    for (var s in subTasks) {
      if (s.checked && s.timestamp.isAfter(limitDate)) {
        historyItems.add(_HistoryItem(
          id: s.id,
          timestamp: s.timestamp,
          checked: s.checked,
          subTaskName: s.subTaskName,
          isSubTask: true,
          originalObject: s,
        ));
      }
    }

    if (historyItems.isEmpty) {
      return _buildEmptyHistoryState();
    }

    // Sort descending by timestamp
    historyItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _buildHistoryList(historyItems, isLive: !widget.useMockData);
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

  Widget _buildHistoryList(List<_HistoryItem> items, {required bool isLive}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final formattedDate = _formatHistoryDate(item.timestamp);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                                  ? 'Sub-task: ${item.subTaskName!.split('|').first} (${_formatTimeString(item.subTaskName!.split('|').last)})'
                                  : 'Sub-task: ${item.subTaskName}',
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
              GestureDetector(
                onTap: () => _deleteHistoryItem(item, isLive),
                child: const Icon(
                   Icons.delete_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _deleteHistoryItem(_HistoryItem item, bool isLive) async {
    if (item.isSubTask) {
      _deleteSubTask(item.id, isLive);
    } else {
      _deleteCheckIn(item.id, isLive);
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
  void _handleTodayCheckIn(bool isCompleted, List<CheckIn> todayCheckIns, List<SubTask> subTasks) async {
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

    // For multiple activity sync subtasks logic
    if (widget.activity.trackingType == 'multiple') {
      final todaySubTasks = subTasks.where((s) => _isToday(s.timestamp)).toList();
      final List<_SubTaskUiItem> uiItems = [];

      for (var template in widget.activity.subTaskTemplates) {
        final match = todaySubTasks.firstWhere(
          (s) => s.subTaskName == template,
          orElse: () => SubTask(id: '', activityId: '', subTaskName: '', timestamp: DateTime.now(), checked: false),
        );
        uiItems.add(_SubTaskUiItem(
          name: template,
          checked: match.id.isNotEmpty ? match.checked : false,
          subTaskId: match.id.isNotEmpty ? match.id : null,
          isTemplate: true,
        ));
      }

      for (var s in todaySubTasks) {
        if (!widget.activity.subTaskTemplates.contains(s.subTaskName)) {
          uiItems.add(_SubTaskUiItem(
            name: s.subTaskName,
            checked: s.checked,
            subTaskId: s.id,
            isTemplate: false,
          ));
        }
      }

      final newCheckInCount = todayCheckIns.length + 1;
      if (newCheckInCount >= uiItems.length && uiItems.isNotEmpty) {
        // Also check the subtask checkboxes (all subtasks)
        for (var item in uiItems) {
          if (!item.checked) {
            if (widget.useMockData) {
              if (item.subTaskId != null) {
                final idx = FirebaseService.mockSubTasks.indexWhere((s) => s.id == item.subTaskId);
                if (idx != -1) {
                  FirebaseService.mockSubTasks[idx] = FirebaseService.mockSubTasks[idx].copyWith(checked: true);
                }
              } else {
                FirebaseService.mockSubTasks.add(
                  SubTask(
                    id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
                    activityId: widget.activity.id,
                    timestamp: DateTime.now(),
                    checked: true,
                    subTaskName: item.name,
                  ),
                );
              }
              // Also add mock check-in!
              final exists = FirebaseService.mockCheckIns.any((c) => c.activityId == widget.activity.id && c.subTaskName == item.name);
              if (!exists) {
                FirebaseService.mockCheckIns.add(CheckIn(
                  id: 'c-sub-${DateTime.now().millisecondsSinceEpoch}',
                  activityId: widget.activity.id,
                  timestamp: DateTime.now(),
                  checked: true,
                  subTaskName: item.name,
                ));
              }
            } else {
              try {
                if (item.subTaskId != null) {
                  await _firebaseService.toggleSubTask(item.subTaskId!, true);
                } else {
                  await _firebaseService.createSubTask(widget.activity.id, item.name, DateTime.now(), true);
                }
              } catch (e) {
                // Ignore errors
              }
            }
          }
        }
        if (widget.useMockData) {
          FirebaseService.notifySubTasksChanged();
        }
      }
    }

    if (!mounted) return;
    final checkInNow = DateTime.now();
    if (widget.useMockData) {
      FirebaseService.mockCheckIns.add(
        CheckIn(
          id: 'c-${DateTime.now().millisecondsSinceEpoch}',
          activityId: widget.activity.id,
          timestamp: checkInNow,
          checked: true,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged check-in locally.'), duration: Duration(seconds: 1)),
      );
      setState(() {});
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.createCheckIn(widget.activity.id, checkInNow, true);
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
  }


  void _deleteCheckIn(String id, bool isLive) async {
    if (!isLive) {
      setState(() {
        FirebaseService.mockCheckIns.removeWhere((c) => c.id == id);
      });
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.deleteCheckIn(id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete check-in: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  // SUB-TASKS UI SECTION
  Widget _buildSubTasksSection(List<SubTask> subTasks, bool isLive) {
    final todaySubTasks = subTasks.where((s) => _isToday(s.timestamp)).toList();

    final List<_SubTaskUiItem> uiItems = [];

    // 1. Add template sub-tasks
    for (var template in widget.activity.subTaskTemplates) {
      final match = todaySubTasks.firstWhere(
        (s) => s.subTaskName == template,
        orElse: () => SubTask(id: '', activityId: '', subTaskName: '', timestamp: DateTime.now(), checked: false),
      );
      uiItems.add(_SubTaskUiItem(
        name: template,
        checked: match.id.isNotEmpty ? match.checked : false,
        subTaskId: match.id.isNotEmpty ? match.id : null,
        isTemplate: true,
      ));
    }

    // 2. Add custom sub-tasks
    for (var s in todaySubTasks) {
      if (!widget.activity.subTaskTemplates.contains(s.subTaskName)) {
        uiItems.add(_SubTaskUiItem(
          name: s.subTaskName,
          checked: s.checked,
          subTaskId: s.id,
          isTemplate: false,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconSm(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary),
            const HGapSm(),
            Text(
              'Sub-tasks Checklist'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const VGapSm(),

        // Underline Input Row
        if (widget.activity.trackingType != 'multiple')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subTaskTextController,
                    focusNode: _subTaskFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: widget.activity.trackingType == 'milestone'
                          ? 'Add milestone sub-task...'
                          : 'Add daily sub-task...',
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
                    onSubmitted: (value) => _addSubTask(value, isLive),
                  ),
                ),
                if (_subTaskTime != null) ...[
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
                          _formatTimeForDisplay(_subTaskTime!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
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
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _pickSubTaskTime,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: _subTaskTime != null ? AppTheme.primaryLight : AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _addSubTask(_subTaskTextController.text, isLive),
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
        const VGapSm(),

        // List of sub-tasks
        if (uiItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                widget.activity.trackingType == 'multiple'
                    ? 'No sub-tasks defined for this activity.'
                    : 'No sub-tasks yet today. Add one above!',
                style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          Column(
            children: uiItems.map((item) {
              final isMilestoneCustom = widget.activity.trackingType == 'milestone' && !item.isTemplate && item.subTaskId != null;

              final Widget itemContainer = Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: item.checked 
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
                                item.name.split('|').first,
                                style: TextStyle(
                                  color: item.checked ? AppTheme.textSecondary : Colors.white,
                                  decoration: item.checked ? TextDecoration.lineThrough : null,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.name.contains('|')) ...[
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
                                      _formatTimeString(item.name.split('|').last),
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
                    ),
                    const HGapMd(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final isDeletingThis = _deletingSubTaskId == item.subTaskId && item.subTaskId != null;
                        if (isDeletingThis) {
                          _deleteSubTask(item.subTaskId!, isLive);
                          setState(() {
                            _deletingSubTaskId = null;
                          });
                        } else {
                          _toggleSubTask(item, isLive);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: _deletingSubTaskId == item.subTaskId && item.subTaskId != null
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
                    if (!item.isTemplate && widget.activity.trackingType != 'milestone') ...[
                      const HGapMd(),
                      GestureDetector(
                        onTap: () => _deleteSubTask(item.subTaskId!, isLive),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppTheme.errorColor.withValues(alpha: 0.7),
                          size: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              );

              if (isMilestoneCustom) {
                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      if (_deletingSubTaskId == item.subTaskId) {
                        _deletingSubTaskId = null;
                      } else {
                        _deletingSubTaskId = item.subTaskId;
                      }
                    });
                  },
                  child: itemContainer,
                );
              }
              return itemContainer;
            }).toList(),
          ),
      ],
    );
  }

  void _addSubTask(String name, bool isLive) async {
    name = name.trim();
    if (name.isEmpty) return;
    final taskNameWithSchedule = _subTaskTime != null
        ? '$name|${_formatTimeOfDay(_subTaskTime)}'
        : name;
    _subTaskTextController.clear();
    
    final timestamp = DateTime.now();
    if (!isLive) {
      setState(() {
        FirebaseService.mockSubTasks.add(
          SubTask(
            id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
            activityId: widget.activity.id,
            timestamp: timestamp,
            checked: false,
            subTaskName: taskNameWithSchedule,
          ),
        );
        _subTaskTime = null;
      });
      FirebaseService.notifySubTasksChanged();
    } else {
      try {
        await _firebaseService.createSubTask(widget.activity.id, taskNameWithSchedule, timestamp, false);
        setState(() {
          _subTaskTime = null;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
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

  void _toggleSubTask(_SubTaskUiItem item, bool isLive) async {
    final newChecked = !item.checked;
    if (!isLive) {
      if (item.subTaskId != null) {
        setState(() {
          final idx = FirebaseService.mockSubTasks.indexWhere((s) => s.id == item.subTaskId);
          if (idx != -1) {
            FirebaseService.mockSubTasks[idx] = FirebaseService.mockSubTasks[idx].copyWith(checked: newChecked);
          }
        });
        FirebaseService.notifySubTasksChanged();
      } else {
        setState(() {
          FirebaseService.mockSubTasks.add(
            SubTask(
              id: 'sub-${DateTime.now().millisecondsSinceEpoch}',
              activityId: widget.activity.id,
              timestamp: DateTime.now(),
              checked: newChecked,
              subTaskName: item.name,
            ),
          );
        });
        FirebaseService.notifySubTasksChanged();
      }
      if (newChecked) {
        final exists = FirebaseService.mockCheckIns.any((c) =>
            c.activityId == widget.activity.id && c.subTaskName == item.name);
        if (!exists) {
          DateTime taskTimestamp = DateTime.now();
          if (item.subTaskId != null) {
            final idx = FirebaseService.mockSubTasks.indexWhere((s) => s.id == item.subTaskId);
            if (idx != -1) {
              taskTimestamp = FirebaseService.mockSubTasks[idx].timestamp;
            }
          }
          FirebaseService.mockCheckIns.add(CheckIn(
            id: 'c-sub-${DateTime.now().millisecondsSinceEpoch}',
            activityId: widget.activity.id,
            timestamp: taskTimestamp,
            checked: true,
            subTaskName: item.name,
          ));
        }
      } else {
        FirebaseService.mockCheckIns.removeWhere((c) =>
            c.activityId == widget.activity.id && c.subTaskName == item.name);
      }
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        if (item.subTaskId != null) {
          await _firebaseService.toggleSubTask(item.subTaskId!, newChecked);
        } else {
          await _firebaseService.createSubTask(widget.activity.id, item.name, DateTime.now(), newChecked);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _deleteSubTask(String id, bool isLive) async {
    if (!isLive) {
      setState(() {
        final idx = FirebaseService.mockSubTasks.indexWhere((s) => s.id == id);
        if (idx != -1) {
          final subTask = FirebaseService.mockSubTasks[idx];
          FirebaseService.mockSubTasks.removeAt(idx);
          FirebaseService.mockCheckIns.removeWhere((c) =>
              c.activityId == subTask.activityId &&
              c.subTaskName == subTask.subTaskName);
        }
      });
      FirebaseService.notifySubTasksChanged();
      FirebaseService.notifyCheckInsChanged();
    } else {
      try {
        await _firebaseService.deleteSubTask(id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete sub-task: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class _SubTaskUiItem {
  final String name;
  final bool checked;
  final String? subTaskId;
  final bool isTemplate;

  _SubTaskUiItem({
    required this.name,
    required this.checked,
    this.subTaskId,
    required this.isTemplate,
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


