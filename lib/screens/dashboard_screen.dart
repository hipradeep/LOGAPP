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
import '../services/log_service.dart';
import '../services/check_in_service.dart';
import '../services/cache_service.dart';
import 'write_log_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/app_provider.dart';
import '../widgets/focus_timer_sheet.dart';
import '../widgets/calorie_log_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();
  final LogService _logService = LogService();
  final CacheService _cacheService = CacheService();
  
  final Set<String> _selectedActivityIds = {};
  late final DashboardController _controller;

  final List<Map<String, String>> _moods = [
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '🚀', 'label': 'Excited'},
    {'emoji': '🌌', 'label': 'Calm'},
    {'emoji': '😔', 'label': 'Down'},
    {'emoji': '🔥', 'label': 'Motivated'},
    {'emoji': '💤', 'label': 'Tired'},
  ];

  late final Widget _moodSection;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
    _moodSection = _buildQuickMoodSection();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    return date.day == _today.day && date.month == _today.month && date.year == _today.year;
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppProvider<DashboardController>(
        notifier: _controller,
        child: Builder(
          builder: (context) {
            final controller = AppProvider.watch<DashboardController>(context);
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            return FullScreenPage(
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
                _moodSection,
                const VGapSm(),

                // Quick Actions
                _buildQuickActionsSection(),
                const VGapSm(),

                // Unified Checked Activities & Summary Section
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCheckedActivitiesList(context, controller.pendingActivities, controller.todayCheckIns, controller.subTasks, isCompletedList: false),
                    if (controller.skippedActivities.isNotEmpty) ...[
                      const VGapSm(),
                      _buildCheckedActivitiesList(context, controller.skippedActivities, controller.todayCheckIns, controller.subTasks, isCompletedList: false, isSkippedList: true),
                    ],
                    if (controller.completedActivities.isNotEmpty) ...[
                      const VGapSm(),
                      _buildCheckedActivitiesList(context, controller.completedActivities, controller.todayCheckIns, controller.subTasks, isCompletedList: true),
                    ],
                    const VGapSm(),
                    _buildDailySummaryCard(controller.checkedActivities, controller.checkIns, controller.subTasks),
                    const VGapSm(),
                    _buildWeeklyCalendarCard(controller.checkedActivities, controller.checkIns, controller.subTasks),
                  ],
                ),
                const VGapXxl(),
                const VGapXxl(),
                const VGapXxl(),
              ],
            );
          }
        ),
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
              final int count;
              if (activity.trackingType == 'multiple') {
                final todayTask = allSubTasks.firstWhere(
                  (s) => s.activityId == activity.id && _isToday(s.timestamp) && s.subTasks.isNotEmpty,
                  orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
                );
                count = todayTask.subTasks.where((st) => st.checked).length;
              } else if (activity.trackingType == 'milestone') {
                count = allSubTasks.where((s) => s.activityId == activity.id && _isToday(s.timestamp) && s.checked).length;
              } else {
                count = todayCheckIns.where((c) => c.activityId == activity.id).length;
              }

              return ActivityChip(
                key: ValueKey(activity.id),
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
                  );
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

  // QUICK ACTIONS SECTION
  Widget? _getActionCard(String action) {
    if (action == 'Focus 25m') {
      return _buildActionCard(
        title: 'Focus 25m',
        emoji: '🎯',
        subtitle: 'Start Pomodoro',
        accentColor: AppTheme.primaryColor,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const FocusTimerSheet(),
          );
        },
      );
    } else if (action == 'Log Food') {
      return _buildActionCard(
        title: 'Log Food',
        emoji: '🍎',
        subtitle: 'Track calories',
        accentColor: AppTheme.successColor,
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CalorieLogSheet(),
          );
        },
      );
    } else if (action == 'Water 250ml') {
      return _buildActionCard(
        title: 'Water 250ml',
        emoji: '💧',
        subtitle: 'Log hydration',
        accentColor: AppTheme.secondaryColor,
        onTap: () async {
          try {
            await _logService.createEntry(
              'Logged Water Intake',
              'Drank 250ml of water.',
              '💧',
              ['Health', 'Water'],
            );
            if (mounted) {
              AppToast.show(
                context: context,
                message: 'Drank 250ml water logged! 💧',
                backgroundColor: AppTheme.successColor,
              );
            }
          } catch (e) {
            if (mounted) {
              AppToast.show(
                context: context,
                message: 'Failed to log: $e',
                backgroundColor: AppTheme.errorColor,
              );
            }
          }
        },
      );
    } else if (action == 'New Journal') {
      return _buildActionCard(
        title: 'New Journal',
        emoji: '📝',
        subtitle: 'Daily reflection',
        accentColor: AppTheme.primaryLight,
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WriteLogScreen(),
            ),
          );
          if (result != null && result is Map<String, dynamic>) {
            final title = result['title'] as String;
            final content = result['content'] as String;
            final mood = result['mood'] as String;
            final tags = result['tags'] as List<String>;
            try {
              await _logService.createEntry(title, content, mood, tags);
              if (mounted) {
                AppToast.show(
                  context: context,
                  message: 'Journal entry saved! 📝',
                  backgroundColor: AppTheme.successColor,
                );
              }
            } catch (e) {
              if (mounted) {
                AppToast.show(
                  context: context,
                  message: 'Failed to save: $e',
                  backgroundColor: AppTheme.errorColor,
                );
              }
            }
          }
        },
      );
    }
    return null;
  }

  Widget _buildQuickActionsSection() {
    return FutureBuilder<List<String>>(
      future: _cacheService.getQuickActions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final enabledActions = snapshot.data ?? ['Focus 25m', 'Log Food', 'Water 250ml', 'New Journal'];
        if (enabledActions.isEmpty) return const SizedBox.shrink();

        final List<Widget> cards = [];
        for (var action in enabledActions) {
          final card = _getActionCard(action);
          if (card != null) {
            cards.add(card);
          }
        }

        final List<Widget> rows = [];
        for (int i = 0; i < cards.length; i += 2) {
          if (i + 1 < cards.length) {
            rows.add(
              Row(
                children: [
                  Expanded(child: cards[i]),
                  const HGapSm(),
                  Expanded(child: cards[i + 1]),
                ],
              ),
            );
          } else {
            rows.add(
              Row(
                children: [
                  Expanded(child: cards[i]),
                ],
              ),
            );
          }
          if (i + 2 < cards.length) {
            rows.add(const VGapSm());
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions'.toUpperCase(),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const VGapSm(),
              ...rows,
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required String emoji,
    required String subtitle,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.01),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: accentColor.withValues(alpha: 0.1),
            highlightColor: accentColor.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 6,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const VGapMd(),
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

