import 'package:flutter/material.dart';
import 'dart:math';
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
import '../services/note_service.dart';
import '../services/check_in_service.dart';
import '../services/milestone_service.dart';
import '../services/service_locator.dart';
import 'note_write_screen.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/app_provider.dart';
import '../widgets/focus_timer_sheet.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/add_transaction_sheet.dart';

import '../widgets/dashboard_summary_card.dart';
import '../widgets/dashboard_weekly_calendar.dart';

class DashboardScreen extends StatefulWidget {
  final CheckInService checkInService;
  final NoteService noteService;
  final MilestoneService milestoneService;

  DashboardScreen({
    super.key,
    CheckInService? checkInService,
    NoteService? noteService,
    MilestoneService? milestoneService,
  })  : checkInService = checkInService ?? getIt<CheckInService>(),
        noteService = noteService ?? getIt<NoteService>(),
        milestoneService = milestoneService ?? getIt<MilestoneService>();

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final CheckInService _checkInService;
  late final NoteService _noteService;
  
  final ValueNotifier<Set<String>> _selectedActivityIds = ValueNotifier({});
  late final DashboardController _controller;
  static final DateFormat _dateFormat = DateFormat('EEEE, MMM d');





  @override
  void initState() {
    super.initState();
    _checkInService = widget.checkInService;
    _noteService = widget.noteService;
    _controller = DashboardController(
      checkInService: widget.checkInService,
      milestoneService: widget.milestoneService,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<DashboardController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<DashboardController>(context);
          return FullScreenPage(
            showScaffold: false,
            isScrollable: true,
            title: 'LOG',
            padding: EdgeInsets.zero,
            backgroundWidgets: _buildBackgroundWidgets(context),
            children: controller.errorMessage != null
                ? [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height - 200,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Failed to load dashboard:\n${controller.errorMessage}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                        ),
                      ),
                    ),
                  ]
                : (controller.isLoading
                    ? [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height - 200,
                          child: Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          ),
                        ),
                      ]
                    : [
                        _buildHeaderDate(context),
                        const VGapMd(),
                        DashboardSummaryCard(
                          activities: controller.todayActivities,
                          checkIns: controller.checkIns,
                          subTasks: controller.tasks,
                        ),
                        const VGapSm(),
                        DashboardQuickActions(
                          onFocus: _handleFocusAction,
                          onWater: _handleWaterAction,
                          onNewJournal: _handleNewJournalAction,
                          onAddTransaction: _handleAddTransactionAction,
                        ),
                        const VGapSm(),
                        _buildActivitiesAndCalendarSection(context, controller),
                        const VGapXxl(),
                        const VGapXxl(),
                        const VGapXxl(),
                      ]),
          );
        }
      ),
    );
  }

  List<Widget> _buildBackgroundWidgets(BuildContext context) {
    return [
      GlowBlob(
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
    ];
  }

  Widget _buildHeaderDate(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _dateFormat.format(DateTime.now()).toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.primaryAccentColor(context),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesAndCalendarSection(BuildContext context, DashboardController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActiveActivitiesList(context, controller.pendingActivities, controller.todayCheckIns, controller.tasks, isCompletedList: false),
        if (controller.skippedActivities.isNotEmpty) ...[
          const VGapSm(),
          _buildActiveActivitiesList(context, controller.skippedActivities, controller.todayCheckIns, controller.tasks, isCompletedList: false, isSkippedList: true),
        ],
        if (controller.completedActivities.isNotEmpty) ...[
          const VGapSm(),
          _buildActiveActivitiesList(context, controller.completedActivities, controller.todayCheckIns, controller.tasks, isCompletedList: true),
        ],
        const VGapSm(),
           
        DashboardWeeklyCalendar(
          activities: controller.activeActivities,
          checkIns: controller.checkIns,
          subTasks: controller.tasks,
        ),
        const VGapSm(),
      ],
    );
  }

  Widget _buildActiveActivitiesList(
    BuildContext context,
    List<Activity> activities,
    List<CheckIn> todayCheckIns,
    List<Task> allTasks, {
    required bool isCompletedList,
    bool isSkippedList = false,
  }) {
    if (activities.isEmpty) return const SizedBox.shrink();

    return ValueListenableBuilder<Set<String>>(
      valueListenable: _selectedActivityIds,
      builder: (context, selectedIds, child) {
        final hasSelection = activities.any((activity) => selectedIds.contains(activity.id));

        return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSkippedList
            ? AppTheme.warningColor.withValues(alpha: 0.04)
            : (isCompletedList 
                ? AppTheme.successColor.withValues(alpha: 0.04)
                : AppTheme.surface(context).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isSkippedList
              ? AppTheme.warningColor.withValues(alpha: 0.15)
              : (isCompletedList
                  ? AppTheme.successColor.withValues(alpha: 0.15)
                  : AppTheme.borderColor(context)),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: Row(
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
                            : (isCompletedList
                                ? AppTheme.successColor
                                : AppTheme.textPrimaryColor(context)),
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
        ),
        const VGapSm(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((activity) {
              final int count;
              int? targetCountOverride;
              bool? isCompletedOverride;

              if (activity.trackingType == 'multiple') {
                final todayTask = allTasks.firstWhere(
                  (s) => s.activityId == activity.id && _isToday(s.timestamp) && s.subTasks.isNotEmpty,
                  orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: DateTime.now(), checked: false),
                );
                count = todayTask.subTasks.where((st) => st.checked).length;
              } else if (activity.trackingType == 'milestone') {
                final todayTasks = allTasks.where((s) => s.activityId == activity.id && _isToday(s.timestamp)).toList();
                count = todayTasks.where((s) => s.checked).length;
                targetCountOverride = todayTasks.length;
                isCompletedOverride = widget.milestoneService.isMilestoneCompletedToday(activity, allTasks) && !isSkippedList;
              } else {
                count = todayCheckIns.where((c) => c.activityId == activity.id).length;
              }

              return ActivityChip(
                key: ValueKey(activity.id),
                activity: activity,
                todayCount: count,
                targetCountOverride: targetCountOverride,
                isCompletedOverride: isCompletedOverride,
                isSkipped: isSkippedList,
                isSelected: selectedIds.contains(activity.id),
                onTap: () {
                  // In multi-select mode: tap toggles selection (not for completed section)
                  if (_selectedActivityIds.value.isNotEmpty && !isCompletedList) {
                    final newSet = Set<String>.from(_selectedActivityIds.value);
                    if (newSet.contains(activity.id)) {
                      newSet.remove(activity.id);
                    } else {
                      newSet.add(activity.id);
                    }
                    _selectedActivityIds.value = newSet;
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
                  final newSet = Set<String>.from(_selectedActivityIds.value);
                  if (newSet.contains(activity.id)) {
                    newSet.remove(activity.id);
                  } else {
                    newSet.add(activity.id);
                  }
                  _selectedActivityIds.value = newSet;
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
    });
  }





  void _handleSkipSelected(BuildContext context, List<Activity> sectionActivities) {
    final selectedIds = _selectedActivityIds.value;
    final selected = sectionActivities.where((a) => selectedIds.contains(a.id)).toList();
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
      _selectedActivityIds.value = {};
      return;
    }

    for (var activity in toSkip) {
      _executeSkipActivity(context, activity);
    }
    _selectedActivityIds.value = {};
  }

  void _handleActivateSelected(BuildContext context, List<Activity> activities) {
    final selectedIds = _selectedActivityIds.value;
    final toActivate = activities.where((activity) => selectedIds.contains(activity.id)).toList();
    if (toActivate.isEmpty) return;
    for (var activity in toActivate) {
      _executeActivateActivity(context, activity);
    }
    _selectedActivityIds.value = {};
  }

  void _executeActivateActivity(BuildContext context, Activity activity) async {
    try {
      AppToast.show(
        context: context,
        message: '"${activity.name}" activated',
        backgroundColor: AppTheme.successColor,
      );
      await _checkInService.deleteSkippedCheckInForToday(activity.id);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context: context,
        message: 'Failed to activate: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _executeSkipActivity(BuildContext context, Activity activity) async {
    try {
      AppToast.show(
        context: context,
        message: '"${activity.name}" marked as skipped',
        backgroundColor: AppTheme.warningColor,
        actionLabel: 'UNDO',
        onActionPressed: () async {
          try {
            AppToast.show(
              context: context,
              message: 'Skip undone successfully',
              backgroundColor: AppTheme.successColor,
            );
            await _checkInService.deleteSkippedCheckInForToday(activity.id);
          } catch (e) {
            if (!context.mounted) return;
            AppToast.show(
              context: context,
              message: 'Failed to undo: $e',
              backgroundColor: AppTheme.errorColor,
            );
          }
        },
      );
      await _checkInService.createCheckIn(activity.id, DateTime.now(), false, skipped: true);
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context: context,
        message: 'Failed to skip: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }





  // QUICK ACTIONS NAMED HANDLERS
  void _handleFocusAction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FocusTimerSheet(),
    );
  }


  void _handleWaterAction() async {
    try {
      await _controller.logWater();
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: 'Drank 250ml water logged! 💧',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context: context,
        message: 'Failed to log: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _handleNewJournalAction() async {
    int dayNum = 1;
    try {
      dayNum = await _noteService.getNextDayNumber();
    } catch (e) {
      // fallback to 1
    }

    if (!mounted) return;

    String tagName = 'Daily';
    if (_controller.activeActivities.isNotEmpty) {
      final random = Random();
      tagName = _controller.activeActivities[random.nextInt(_controller.activeActivities.length)].name;
    }
    final defaultTitle = 'Day $dayNum | "$tagName Feeling"';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteWriteScreen(initialTitle: defaultTitle),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      final title = result['title'] as String;
      final content = result['content'] as String;
      final mood = result['mood'] as String;
      final tags = result['tags'] as List<String>;
      try {
        await _noteService.createEntry(title, content, mood, tags);
        if (!mounted) return;
        AppToast.show(
          context: context,
          message: 'Journal entry saved! 📝',
          backgroundColor: AppTheme.successColor,
        );
      } catch (e) {
        if (!mounted) return;
        AppToast.show(
          context: context,
          message: 'Failed to save: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  void _handleAddTransactionAction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTransactionSheet(),
    );
  }
}
