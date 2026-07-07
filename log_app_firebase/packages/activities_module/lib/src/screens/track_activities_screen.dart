import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'add_activity_screen.dart';
import 'activity_details_screen.dart';
import '../controllers/track_activities_controller.dart';

class TrackActivitiesScreen extends StatefulWidget {
  const TrackActivitiesScreen({super.key});

  @override
  State<TrackActivitiesScreen> createState() => _TrackActivitiesScreenState();
}

class _TrackActivitiesScreenState extends State<TrackActivitiesScreen> {
  late final TrackActivitiesController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = TrackActivitiesController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return AppProvider<TrackActivitiesController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<TrackActivitiesController>(context);
          return FullScreenPage(
            showScaffold: true,
            isScrollable: false,
            title: 'Track Activities',
            showBackButton: true,
            padding: EdgeInsets.zero,
            actions: [
              GestureDetector(
                onTap: _navigateToAddActivity,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: AppTheme.textPrimaryColor(context),
                    size: 20,
                  ),
                ),
              ),
            ],

            children: [
              Expanded(
                child: controller.isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      )
                    : (controller.errorMessage != null
                        ? Center(
                            child: Text(
                              controller.errorMessage!,
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          )
                        : (controller.activities.isEmpty
                            ? _buildEmptyState()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.paddingOf(context).bottom + 32,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const VGapMd(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Select activities to show on homepage'.toUpperCase(),
                                                style: AppTheme.bodySmall.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const VGapSm(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24),
                                        child: _buildList(controller.activities, controller.checkIns, controller.tasks),
                                      ),
                                    ],
                                  ),
                                ),
                              ))),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildList(List<Activity> activities, List<CheckIn> checkIns, List<Task> tasks) {
    final active = activities.where((a) => a.isActive).toList();
    final inactive = activities.where((a) => !a.isActive).toList();

    bool isExpired(Activity activity) {
      if (activity.endDate != null) {
        final today = DateTime.now();
        final endMidnight = DateTime(activity.endDate!.year, activity.endDate!.month, activity.endDate!.day);
        final todayMidnight = DateTime(today.year, today.month, today.day);
        return todayMidnight.isAfter(endMidnight);
      }
      return false;
    }

    bool isToday(DateTime date) {
      final now = DateTime.now();
      return date.day == now.day && date.month == now.month && date.year == now.year;
    }

    String? getSortingTime(Activity activity) {
      if (activity.trackingType == 'multiple') {
        final todayTask = tasks.firstWhere(
          (s) => s.activityId == activity.id && isToday(s.timestamp) && s.subTasks.isNotEmpty,
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

    int compareActive(Activity a, Activity b) {
      final aExpired = isExpired(a);
      final bExpired = isExpired(b);
      if (aExpired != bExpired) {
        return aExpired ? 1 : -1;
      }
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

    int compareInactive(Activity a, Activity b) {
      final aExpired = isExpired(a);
      final bExpired = isExpired(b);
      if (aExpired != bExpired) {
        return aExpired ? 1 : -1;
      }
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
      return b.timestamp.compareTo(a.timestamp);
    }

    active.sort(compareActive);
    inactive.sort(compareInactive);

    if (active.isEmpty && inactive.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('Active Activities (${active.length})', AppTheme.primaryColor),
          const VGapSm(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: active.length,
            itemBuilder: (context, index) {
              final a = active[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8), // Compact: reduced bottom card padding
                child: ActivityCard(
                  key: ValueKey(a.id),
                  activity: a,
                  onTap: () => _navigateToActivityDetails(a),
                ),
              );
            },
          ),
          const VGapSm(), // Compact: reduced spacer
        ],
        if (inactive.isNotEmpty) ...[
          _buildSectionHeader('Inactive Activities (${inactive.length})', AppTheme.successColor),
          const VGapSm(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: inactive.length,
            itemBuilder: (context, index) {
              final a = inactive[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8), // Compact: reduced bottom card padding
                child: ActivityCard(
                  key: ValueKey(a.id),
                  activity: a,
                  onTap: () => _navigateToActivityDetails(a),
                ),
              );
            },
          ),
          const VGapSm(), // Compact: reduced spacer
        ],
        const VGapLg(), // Compact: reduced bottom layout padding
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const HGapSm(),
          Text(
            title.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: accentColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.playlist_add_rounded,
      title: 'No Activities Tracked',
      description: 'Create daily check-in habits, recurring tasks, or milestone activities.',
      actionLabel: 'Add Activity',
      onActionPressed: _navigateToAddActivity,
    );
  }

  void _navigateToAddActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddActivityScreen(
          onAdd: (name, trackingType, targetCount, {
            List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
            String? scheduledTime,
            DateTime? startDate,
            DateTime? endDate,
            List<String> subTaskTemplates = const [],
            String? description,
            bool skippable = false,
            bool reminderEnabled = true,
            double weight = 1.0,
            int points = 10,
            int focusDuration = 25,
            bool isPomodoroFocusEnabled = false,
          }) {
            _addActivity(
              name, trackingType, targetCount,
              repeatDays: repeatDays,
              scheduledTime: scheduledTime,
              startDate: startDate,
              endDate: endDate,
              subTaskTemplates: subTaskTemplates,
              description: description,
              skippable: skippable,
              reminderEnabled: reminderEnabled,
              weight: weight,
              points: points,
              focusDuration: focusDuration,
              isPomodoroFocusEnabled: isPomodoroFocusEnabled,
            );
          },
        ),
      ),
    );
  }

  void _navigateToActivityDetails(Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetailsScreen(
          activityId: activity.id,
        ),
      ),
    );
  }

  void _addActivity(
    String name, String trackingType, int targetCount, {
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String? description,
    bool skippable = false,
    bool reminderEnabled = true,
    double weight = 1.0,
    int points = 10,
    int focusDuration = 25,
    bool isPomodoroFocusEnabled = false,
  }) async {
    try {
      await _controller.createActivity(
        name, trackingType, targetCount,
        repeatDays: repeatDays,
        scheduledTime: scheduledTime,
        startDate: startDate,
        endDate: endDate,
        subTaskTemplates: subTaskTemplates,
        description: description,
        skippable: skippable,
        reminderEnabled: reminderEnabled,
        weight: weight,
        points: points,
        focusDuration: focusDuration,
        isPomodoroFocusEnabled: isPomodoroFocusEnabled,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  static const _dayLabelsShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _getRepeatDaysLabel(List<int> days) {
    if (days.length == 7) return 'Every day';
    return days.map((d) => _dayLabelsShort[d - 1][0]).join(', ');
  }

  String _formatScheduledTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final t = TimeOfDay(hour: hour, minute: minute);
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  ({IconData icon, String label, Color color}) _getTypeBadge(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return (icon: Icons.repeat_rounded, label: 'Multiple', color: AppTheme.secondaryColor);
      case 'milestone':
        return (icon: Icons.flag_rounded, label: 'Milestone', color: AppTheme.warningColor);
      case 'single':
      default:
        return (icon: Icons.bolt_rounded, label: 'Single', color: AppTheme.primaryColor);
    }
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityProgressIcon(Activity activity) {
    final isActive = activity.isActive;
    final accentColor = isActive ? AppTheme.primaryColor : AppTheme.successColor;
    
    IconData typeIcon;
    switch (activity.trackingType) {
      case 'multiple':
        typeIcon = Icons.repeat_rounded;
        break;
      case 'milestone':
        typeIcon = Icons.flag_rounded;
        break;
      case 'single':
      default:
        typeIcon = Icons.bolt_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: Icon(typeIcon, size: 14, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    final isActive = activity.isActive;
    final accentColor = isActive ? AppTheme.primaryColor : AppTheme.successColor;
    final typeBadge = _getTypeBadge(activity.trackingType);

    // Calculate progress percentage of the date range (start date to end date)
    double progressPercent = 0.0;
    final start = activity.startDate;
    final end = activity.endDate;
    if (start != null && end != null) {
      final today = DateTime.now();
      final startMidnight = DateTime(start.year, start.month, start.day);
      final endMidnight = DateTime(end.year, end.month, end.day);
      final todayMidnight = DateTime(today.year, today.month, today.day);

      final totalDays = endMidnight.difference(startMidnight).inDays + 1;
      int elapsedDays = todayMidnight.difference(startMidnight).inDays + 1;
      if (todayMidnight.isBefore(startMidnight)) {
        elapsedDays = 0;
      } else if (todayMidnight.isAfter(endMidnight)) {
        elapsedDays = totalDays;
      }
      progressPercent = totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : AppTheme.successColor.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Stack(
            children: [
              // Whole card background progress bar (light color)
              if (isActive && start != null && end != null && progressPercent > 0) // Completed/Inactive: hide progress background bar
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressPercent,
                    child: Container(
                      color: typeBadge.color.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isActive) // Completed/Inactive: hide left colored accent bar
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: typeBadge.color.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppTheme.defaultBorderRadius),
                            bottomLeft: Radius.circular(AppTheme.defaultBorderRadius),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Compact: reduced padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildActivityProgressIcon(activity),
                                const HGapSm(), // Compact: reduced gap between icon and text
                                Expanded(
                                  child: Text(
                                    activity.name,
                                    style: AppTheme.bodyMedium.copyWith( // Compact: stepped down text style
                                      color: isActive ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isActive && activity.skippable) ...[ // Completed/Inactive: hide skippable arrow
                                  const HGapSm(),
                                  Icon(
                                    Icons.double_arrow_rounded,
                                    size: 16, // Compact: reduced icon size
                                    color: AppTheme.warningColor.withValues(alpha: 0.8),
                                  ),
                                ],
                              ],
                            ),
                            if (isActive) ...[ // Completed/Inactive: hide all metadata chips
                              const VGapXs(), // Compact: reduced spacer
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: 4, // Compact: reduced tag wrap margins
                                      runSpacing: 4,
                                      children: [
                                        if (activity.targetCount > 1)
                                          _buildMetaChip(
                                            icon: Icons.repeat_rounded,
                                            label: '${activity.targetCount}x/day',
                                            color: AppTheme.secondaryColor,
                                          ),
                                        if (activity.scheduledTime != null)
                                          _buildMetaChip(
                                            icon: Icons.access_time_rounded,
                                            label: _formatScheduledTime(activity.scheduledTime!),
                                            color: AppTheme.primaryAccentColor(context),
                                          ),
                                        _buildMetaChip(
                                          icon: Icons.calendar_view_week_rounded,
                                          label: _getRepeatDaysLabel(activity.repeatDays),
                                          color: AppTheme.textSecondaryColor(context),
                                        ),
                                      ],
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
