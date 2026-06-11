import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/activity_check_in_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/activity_chip.dart';

import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import '../services/log_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();
  final LogService _logService = LogService();
  
  late Stream<List<Activity>> _checkedActivitiesStream;
  late Stream<List<CheckIn>> _checkInsStream;
  late Stream<List<Task>> _subTasksStream;

  final Set<String> _selectedActivityIds = {};

  final List<Map<String, String>> _moods = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '🚀', 'label': 'Excited'},
    {'emoji': '🌌', 'label': 'Calm'},
    {'emoji': '😔', 'label': 'Down'},
    {'emoji': '🔥', 'label': 'Motivated'},
    {'emoji': '💤', 'label': 'Tired'},
  ];

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    _checkedActivitiesStream = _activityService.getCheckedActivitiesStream();
    _checkInsStream = _checkInService.getCheckedActivitiesCheckInsStream();
    _subTasksStream = _activityService.getSubTasksStream();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: true,
        title: 'Your Daily LOG',
        padding: EdgeInsets.zero,
        backgroundWidgets: [
          const GlowBlob(
            top: -50,
            left: -50,
            size: 250,
            color: AppTheme.primaryColor,
            opacity: 0.12,
          ),
          GlowBlob(
            bottom: Responsive.heightPercent(context, 20),
            right: -60,
            size: 300,
            color: AppTheme.primaryLight,
            opacity: 0.06,
          ),
        ],
        children: [
          // Subheader indicating date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const VGapMd(),
          
          // Quick Mood Check-in
          _buildQuickMoodSection(),
          const VGapSm(),

          // Unified Checked Activities & Summary Section
          StreamBuilder<List<Activity>>(
            stream: _checkedActivitiesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final checkedActivities = snapshot.data ?? [];
              
              return StreamBuilder<List<CheckIn>>(
                stream: _checkInsStream,
                builder: (context, checkinSnapshot) {
                  final checkIns = checkinSnapshot.data ?? [];
                  
                  return StreamBuilder<List<Task>>(
                    stream: _subTasksStream,
                    builder: (context, subtaskSnapshot) {
                      final subTasks = subtaskSnapshot.data ?? [];
                      
                      final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();

                      // Classify activities into pending, completed, and skipped today
                      final List<Activity> pendingActivities = [];
                      final List<Activity> completedActivities = [];
                      final List<Activity> skippedActivities = [];
                      
                      for (var activity in checkedActivities) {
                        final bool isSkipped = checkIns.any((c) =>
                            _isToday(c.timestamp) &&
                            c.activityId == activity.id &&
                            c.skipped == true);
                        if (isSkipped) {
                          skippedActivities.add(activity);
                          continue;
                        }
                        final int todayCount;
                        if (activity.trackingType == 'multiple') {
                           final todayTask = subTasks.firstWhere(
                             (s) => s.activityId == activity.id && _isToday(s.timestamp) && s.subTasks.isNotEmpty,
                             orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
                           );
                          todayCount = todayTask.subTasks.where((st) => st.checked).length;
                        } else {
                          todayCount = todayCheckIns.where((c) => c.activityId == activity.id).length;
                        }
                        final bool isCompleted = todayCount >= activity.targetCount;
                            
                        if (isCompleted) {
                          completedActivities.add(activity);
                        } else {
                          pendingActivities.add(activity);
                        }
                      }

                      String? getSortingTime(Activity activity) {
                        if (activity.trackingType == 'multiple') {
                          final todayTask = subTasks.firstWhere(
                            (s) => s.activityId == activity.id && _isToday(s.timestamp) && s.subTasks.isNotEmpty,
                            orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
                          );
                          for (var template in activity.subTaskTemplates) {
                            final parts = template.split('|');
                            if (parts.length > 1) {
                              final timeStr = parts.last;
                              final isCheckedIn = todayTask.subTasks.any((st) => st.title == parts.first && st.checked);
                              if (!isCheckedIn) {
                                return timeStr;
                              }
                            }
                          }
                          // Fallback: first scheduled subtask's time
                          for (var template in activity.subTaskTemplates) {
                            final parts = template.split('|');
                            if (parts.length > 1) {
                              return parts.last;
                            }
                          }
                        }
                        return activity.scheduledTime;
                      }

                      int compareActivities(Activity a, Activity b) {
                        final aTime = getSortingTime(a);
                        final bTime = getSortingTime(b);
                        if (aTime != null && bTime != null) {
                          return aTime.compareTo(bTime);
                        }
                        if (aTime != null && bTime == null) {
                          return -1;
                        }
                        if (aTime == null && bTime != null) {
                          return 1;
                        }
                        return a.timestamp.compareTo(b.timestamp);
                      }

                      pendingActivities.sort(compareActivities);
                      completedActivities.sort(compareActivities);
                      skippedActivities.sort(compareActivities);
                      
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCheckedActivitiesList(context, pendingActivities, todayCheckIns, subTasks, isCompletedList: false),
                          if (skippedActivities.isNotEmpty) ...[
                            const VGapSm(),
                            _buildCheckedActivitiesList(context, skippedActivities, todayCheckIns, subTasks, isCompletedList: false, isSkippedList: true),
                          ],
                          if (completedActivities.isNotEmpty) ...[
                            const VGapSm(),
                            _buildCheckedActivitiesList(context, completedActivities, todayCheckIns, subTasks, isCompletedList: true),
                          ],
                          const VGapSm(),
                          _buildDailySummaryCard(checkedActivities, checkIns, subTasks),
                          const VGapSm(),
                          _buildWeeklyCalendarCard(checkedActivities, checkIns, subTasks),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const VGapXxl(),
          const VGapXxl(),
          const VGapXxl(),
        ],
      ),
    );
  }

  Widget _buildCheckedActivitiesList(
    BuildContext context,
    List<Activity> activities,
    List<CheckIn> todayCheckIns,
    List<Task> allSubTasks, {
    required bool isCompletedList,
    bool isSkippedList = false,
  }) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final hasSelection = activities.any((activity) => _selectedActivityIds.contains(activity.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSkippedList
            ? AppTheme.warningColor.withValues(alpha: 0.04)
            : (isCompletedList 
                ? AppTheme.successColor.withValues(alpha: 0.04)
                : AppTheme.surfaceColor.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isSkippedList
              ? AppTheme.warningColor.withValues(alpha: 0.15)
              : (isCompletedList
                  ? AppTheme.successColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.02)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSkippedList
                        ? Icons.next_plan_rounded
                        : (isCompletedList ? Icons.check_circle_rounded : Icons.star_rounded), 
                    color: isSkippedList
                        ? AppTheme.warningColor
                        : (isCompletedList ? AppTheme.successColor : Colors.amber), 
                    size: 16,
                  ),
                  const HGapSm(),
                  Text(
                    (isSkippedList
                        ? 'Skipped Today'
                        : (isCompletedList ? 'Completed Today' : 'Active Activities')).toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: isSkippedList
                          ? AppTheme.warningColor
                          : (isCompletedList ? AppTheme.successColor : AppTheme.textPrimary),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (!isCompletedList && !isSkippedList && hasSelection)
                GestureDetector(
                  onTap: () => _handleSkipSelected(context, activities),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.double_arrow_rounded, 
                          color: AppTheme.warningColor, 
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Skip',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.warningColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isSkippedList && hasSelection)
                GestureDetector(
                  onTap: () => _handleActivateSelected(context, activities),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppTheme.successColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.undo_rounded, 
                          color: AppTheme.successColor, 
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Activate',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const VGapSm(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((activity) {
              final int count = activity.trackingType == 'multiple'
                  ? allSubTasks.where((s) => s.activityId == activity.id && s.checked && _isToday(s.timestamp)).length
                  : todayCheckIns.where((c) => c.activityId == activity.id).length;

              return ActivityChip(
                activity: activity,
                todayCount: count,
                isSkipped: isSkippedList,
                isSelected: _selectedActivityIds.contains(activity.id),
                onTap: () {
                  // In multi-select mode: tap toggles selection (not for completed section)
                  if (_selectedActivityIds.isNotEmpty && !isCompletedList) {
                    setState(() {
                      if (_selectedActivityIds.contains(activity.id)) {
                        _selectedActivityIds.remove(activity.id);
                      } else {
                        _selectedActivityIds.add(activity.id);
                      }
                    });
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ActivityCheckInSheet(
                      activity: activity,
                    ),
                  ).then((_) {
                    setState(() {});
                  });
                },
                // Disable long press for completed section (no action available)
                onLongPress: isCompletedList ? null : () {
                  setState(() {
                    if (_selectedActivityIds.contains(activity.id)) {
                      _selectedActivityIds.remove(activity.id);
                    } else {
                      _selectedActivityIds.add(activity.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // QUICK MOOD CHECK-IN PANEL
  Widget _buildQuickMoodSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: AppTheme.defaultCardPadding,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling right now?',
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          const VGapSm(),
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _moods.length,
              itemBuilder: (context, index) {
                final mood = _moods[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => _handleQuickMood(mood['emoji']!, mood['label']!),
                    borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                    child: Container(
                      width: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        mood['emoji']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleSkipSelected(BuildContext context, List<Activity> sectionActivities) {
    final selected = sectionActivities.where((a) => _selectedActivityIds.contains(a.id)).toList();
    final toSkip = selected.where((a) => a.skippable).toList();
    final nonSkippable = selected.where((a) => !a.skippable).toList();

    if (nonSkippable.isNotEmpty && toSkip.isEmpty) {
      AppToast.show(
        context: context,
        message: nonSkippable.length == 1
            ? '"${nonSkippable.first.name}" is not skippable'
            : '${nonSkippable.length} activities are not skippable',
        backgroundColor: AppTheme.warningColor,
      );
      setState(() => _selectedActivityIds.clear());
      return;
    }

    for (var activity in toSkip) {
      _executeSkipActivity(context, activity);
    }

    if (nonSkippable.isNotEmpty) {
      AppToast.show(
        context: context,
        message: '${nonSkippable.length} skipped (${nonSkippable.map((a) => a.name).join(", ")} not skippable)',
        backgroundColor: AppTheme.warningColor,
      );
    }

    setState(() => _selectedActivityIds.clear());
  }

  void _handleActivateSelected(BuildContext context, List<Activity> sectionActivities) {
    final toActivate = sectionActivities.where((a) => _selectedActivityIds.contains(a.id)).toList();
    if (toActivate.isEmpty) return;
    for (var activity in toActivate) {
      _executeActivateActivity(context, activity);
    }
    setState(() => _selectedActivityIds.clear());
  }

  void _executeActivateActivity(BuildContext context, Activity activity) async {
    try {
      await _checkInService.deleteSkippedCheckInForToday(activity.id);
      await _logService.createEntry(
        'Activated "${activity.name}"',
        'Activated a previously skipped activity.',
        '↩️',
        ['Activate'],
      );
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: '"${activity.name}" activated',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: 'Failed to activate: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _executeSkipActivity(BuildContext context, Activity activity) async {
    try {
      await _checkInService.createCheckIn(activity.id, DateTime.now(), false, skipped: true);
      await _logService.createEntry(
        'Skipped "${activity.name}"',
        'Marked activity as skipped for the day.',
        '⏭️',
        ['Skip'],
      );
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: '"${activity.name}" marked as skipped',
        backgroundColor: AppTheme.warningColor,
        actionLabel: 'UNDO',
        onActionPressed: () async {
          try {
            await _checkInService.deleteSkippedCheckInForToday(activity.id);
            if (!mounted) return;
            await _logService.createEntry(
              'Undo skip: "${activity.name}"',
              'Reversed the skipped status.',
              '↩️',
              ['UndoSkip'],
            );
            if (!mounted) return;
            AppToast.show(
              context: context,
              message: 'Skip undone successfully',
              backgroundColor: AppTheme.successColor,
            );
          } catch (e) {
            if (!mounted) return;
            AppToast.show(
              context: context,
              message: 'Failed to undo: $e',
              backgroundColor: AppTheme.errorColor,
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: 'Failed to skip: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }



  // QUICK MOOD LOGGING ACTION
  void _handleQuickMood(String emoji, String label) async {
    try {
      await _logService.createEntry(
        'Feeling $label',
        'Logged a quick check-in.',
        emoji,
        ['QuickCheck'],
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quick check-in logged: Feeling $label $emoji'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save to Firestore. Check connection. ($e)'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _buildDailySummaryCard(List<Activity> activities, List<CheckIn> checkIns, List<Task> subTasks) {
    if (activities.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary, size: 40),
            const VGapSm(),
            Text(
              'No active activities selected.',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
            ),
            const VGapXs(),
            Text(
              'Go to Settings > Track Activities to choose activities for your daily layout.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    int completedActivities = 0;
    final totalActivities = activities.length;

    final todayCheckIns = checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();

    for (var activity in activities) {
      final int todayCount;
      if (activity.trackingType == 'multiple') {
        final todayTask = subTasks.firstWhere(
          (s) => s.activityId == activity.id && _isToday(s.timestamp),
          orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
        );
        todayCount = todayTask.subTasks.where((st) => st.checked).length;
      } else {
        todayCount = todayCheckIns.where((c) => c.activityId == activity.id).length;
      }
      if (todayCount >= activity.targetCount) {
        completedActivities++;
      }
    }

    final double completionRate = totalActivities > 0 ? completedActivities / totalActivities : 0.0;
    
    String motivationalMessage = 'Start your day by checking in to an activity!';
    if (completionRate > 0 && completionRate < 0.5) {
      motivationalMessage = 'Off to a good start! Keep it going!';
    } else if (completionRate >= 0.5 && completionRate < 1.0) {
      motivationalMessage = 'More than halfway there! Almost done!';
    } else if (completionRate == 1.0) {
      motivationalMessage = 'Perfect day! You\'ve completed all active activities! ðŸŽ‰';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Progress'.toUpperCase(),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const VGapSm(),
                Text(
                  '$completedActivities of $totalActivities Completed',
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                ),
                const VGapSm(),
                Text(
                  motivationalMessage,
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const HGapMd(),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: completionRate,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completionRate >= 1.0 ? AppTheme.successColor : AppTheme.primaryColor,
                  ),
                ),
              ),
              Text(
                '${(completionRate * 100).toInt()}%',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ==================== WEEKLY CALENDAR VIEW ====================

  Widget _buildWeeklyCalendarCard(List<Activity> activities, List<CheckIn> checkIns, List<Task> subTasks) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    // Calculate Monday of current week (DateTime.monday == 1 in Dart)
    final monday = now.subtract(Duration(days: now.weekday - 1));

    // Generate 7 days starting from Monday
    final weekDays = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                color: AppTheme.primaryLight,
                size: 14,
              ),
              const HGapSm(),
              Text(
                'Weekly Progress'.toUpperCase(),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = weekDays[index];
              final isToday = _isSameDay(day, now);
              final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

              // Calculate completion for this day
              int completed = 0;
              for (var activity in activities) {
                final int todayCount;
                if (activity.trackingType == 'multiple') {
                  final dayTask = subTasks.firstWhere(
                    (s) => s.activityId == activity.id && _isSameDay(s.timestamp, day),
                    orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
                  );
                  todayCount = dayTask.subTasks.where((st) => st.checked).length;
                } else {
                  todayCount = checkIns
                      .where((c) =>
                          c.activityId == activity.id &&
                          _isSameDay(c.timestamp, day) &&
                          c.checked)
                      .length;
                }
                final bool isDone = todayCount >= activity.targetCount;
                if (isDone) completed++;
              }

              final double completionRate =
                  activities.isNotEmpty ? completed / activities.length : 0.0;

              return _buildDayCircle(
                label: dayLabels[index],
                date: day.day.toString(),
                progress: isFuture ? 0.0 : completionRate,
                isToday: isToday,
                isFuture: isFuture,
                isCompleted: completionRate >= 1.0 && !isFuture,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCircle({
    required String label,
    required String date,
    required double progress,
    required bool isToday,
    required bool isFuture,
    required bool isCompleted,
  }) {
    final Color progressColor = isCompleted
        ? AppTheme.successColor
        : (progress > 0 ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.1));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isToday ? AppTheme.primaryLight : AppTheme.textSecondary,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const VGapXs(),
        Container(
          decoration: isToday
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: isFuture ? 0.0 : (progress > 0 ? progress : 0.0),
                  strokeWidth: 3,
                  backgroundColor: isFuture
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Text(
                date,
                style: AppTheme.bodySmall.copyWith(
                  color: isToday
                      ? Colors.white
                      : (isFuture
                          ? AppTheme.textSecondary.withValues(alpha: 0.4)
                          : AppTheme.textSecondary),
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const VGapXs(),
        // Today indicator dot
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: isToday ? AppTheme.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        ),
      ],
    );
  }
}

