import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_text_action_button.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../controllers/activity_details_controller.dart';
import '../widgets/app_provider.dart';
import '../services/activity_service.dart';
import '../services/service_locator.dart';
import '../widgets/activity_graph.dart';
import 'add_activity_screen.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;
  final bool showEditIcon;

  const ActivityDetailsScreen({
    super.key,
    required this.activityId,
    this.showEditIcon = true,
  });

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final ActivityService _activityService = getIt<ActivityService>();
  late final ActivityDetailsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ActivityDetailsController(activityId: widget.activityId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRepeatDaysLabel(List<int> days) {
    const dayLabelsShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    return days.map((d) => dayLabelsShort[d - 1][0]).join(', ');
  }

  String _formatScheduledTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final t = TimeOfDay(hour: hour, minute: minute);
      final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
      final m = t.minute.toString().padLeft(2, '0');
      final period = t.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    } catch (_) {
      return timeStr;
    }
  }

  String _getTrackingTypeLabel(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return 'Multiple Tasks';
      case 'milestone':
        return 'Milestone Progress';
      case 'single':
      default:
        return 'Single Habit';
    }
  }

  IconData _getTrackingTypeIcon(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return Icons.repeat_rounded;
      case 'milestone':
        return Icons.flag_rounded;
      case 'single':
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _getTrackingTypeColor(String trackingType) {
    switch (trackingType) {
      case 'multiple':
        return AppTheme.secondaryColor;
      case 'milestone':
        return AppTheme.warningColor;
      case 'single':
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // CRITICAL: Registers this component to rebuild on theme switch
    return AppProvider<ActivityDetailsController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<ActivityDetailsController>(context);
          if (controller.isLoading) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            );
          }
          if (controller.errorMessage != null) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Error loading activity: ${controller.errorMessage}',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            );
          }
          final activity = controller.activity;
          if (activity == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Activity not found',
                      style: TextStyle(color: AppTheme.textPrimaryColor(context)),
                    ),
                    const VGapMd(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildDetailsScreen(activity, controller.checkIns, controller.tasks);
        },
      ),
    );
  }

  Widget _buildDetailsScreen(Activity activity, List<CheckIn> checkIns, List<Task> tasks) {
    final typeColor = _getTrackingTypeColor(activity.trackingType);
    final typeIcon = _getTrackingTypeIcon(activity.trackingType);

    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Activity Details',
      showBackButton: true,
      actions: widget.showEditIcon
          ? [
              AppTextActionButton(
                label: 'Edit',
                onPressed: () => _navigateToEditActivity(activity),
              ),
            ]
          : null,

      children: [
        // 1. Header Card (Name, Category, Description)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12), // Compact: reduced padding
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16), // Compact: matched standard border radius
            border: Border.all(
              color: AppTheme.borderColor(context),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 44, // Compact: reduced icon container size
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [typeColor, typeColor.withValues(alpha: 0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.3),
                          blurRadius: 8, // Compact: reduced shadow blur
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(typeIcon, color: Colors.white, size: 20), // Compact: reduced icon size
                  ),
                  const HGapMd(),
                  // Name and Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: AppTheme.headingSmall.copyWith(fontSize: 18), // Compact: stepped down typography
                        ),
                        const VGapXs(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // Compact: tighter tag padding
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6), // Compact: matched tag border radius
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getTrackingTypeLabel(activity.trackingType).toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 9, // Compact: micro text size
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (activity.description != null && activity.description!.isNotEmpty) ...[
                const VGapSm(), // Compact: reduced spacer
                Divider(color: AppTheme.borderColor(context), height: 1),
                const VGapSm(), // Compact: reduced spacer
                Text(
                  'Description',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const VGapXs(),
                Text(
                  activity.description!,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondaryColor(context),
                    fontSize: 13, // Compact: slightly smaller body font size
                  ),
                ),
              ],
            ],
          ),
        ),
        const VGapSm(), // Compact: reduced space between cards

        // 2. Schedule Card Details
        _buildScheduleDetailsCard(activity),
        const VGapSm(), // Compact: reduced space between cards

        // 3. Tasks Checklist Section
        if (activity.hasSubTasks) ...[
          _buildTaskListSection(activity, tasks),
          const VGapSm(), // Compact: reduced space between cards
        ],

        // 4. Analytics Section
        ActivityGraphCard(
          activity: activity,
          checkIns: checkIns,
          tasks: tasks,
        ),
        const VGapSm(), // Compact: reduced space between cards

        // 4. Timeline Section
        _buildHistoryTimeline(activity, checkIns, tasks),
        const VGapLg(), // Compact: reduced bottom safe area gap
      ],
    );
  }

  Widget _buildScheduleDetailsCard(Activity activity) {
    final start = activity.startDate;
    final end = activity.endDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // Compact: reduced padding
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16), // Compact: matched standard border radius
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule & Settings'.toUpperCase(),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const VGapSm(), // Compact: reduced gap
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Repeat Days',
            value: _getRepeatDaysLabel(activity.repeatDays),
          ),
          if (activity.scheduledTime != null) ...[
            const VGapXs(), // Compact: reduced gap
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Reminder Time',
              value: _formatScheduledTime(activity.scheduledTime!),
            ),
          ],
          if (start != null || end != null) ...[
            const VGapXs(), // Compact: reduced gap
            _buildDetailRow(
              icon: Icons.date_range_rounded,
              label: 'Tracking Period',
              value: '${start != null ? DateFormat('MMM d, yyyy').format(start) : 'Start'} to ${end != null ? DateFormat('MMM d, yyyy').format(end) : 'Ongoing'}',
            ),
          ],
          const VGapXs(), // Compact: reduced gap
          _buildDetailRow(
            icon: Icons.settings_rounded,
            label: 'Type',
            value: activity.trackingType == 'multiple'
                ? 'Multiple'
                : (activity.trackingType == 'milestone'
                    ? 'Milestone'
                    : 'Single'),
          ),
          const VGapXs(), // Compact: reduced gap
          _buildDetailRow(
            icon: Icons.double_arrow_rounded,
            label: 'Skippable',
            value: activity.skippable ? 'Yes' : 'No',
          ),
        ],
      ),
    );
  }

  Widget _buildTaskListSection(Activity activity, List<Task> tasks) {
    List<Widget> taskWidgets = [];

    if (activity.trackingType == 'multiple') {
      for (var template in activity.subTaskTemplates) {
        final parts = template.split('|');
        final title = parts.first;
        final timeStr = parts.length > 1 ? parts.last : null;
        final formattedTime = timeStr != null ? _formatScheduledTime(timeStr) : null;

        taskWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4), // Compact: reduced vertical padding
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 6, // Compact: reduced icon dot size
                  color: AppTheme.secondaryColor.withValues(alpha: 0.6),
                ),
                const HGapSm(), // Compact: reduced horizontal gap
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 13, // Compact: stepped down size
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (formattedTime != null) ...[
                  const HGapSm(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 10,
                          color: AppTheme.primaryAccentColor(context), // Contrast: primaryAccentColor instead of primaryLight
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: AppTheme.primaryAccentColor(context), // Contrast: primaryAccentColor instead of primaryLight
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
        );
      }
    } else if (activity.trackingType == 'milestone') {
      final activeTasks = tasks.where((t) => !t.checked).toList();
      for (var t in activeTasks) {
        final totalCount = t.subTasks.length;
        final completedCount = t.subTasks.where((st) => st.checked).length;

        taskWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4), // Compact: reduced vertical padding
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 6, // Compact: reduced icon dot size
                  color: AppTheme.warningColor.withValues(alpha: 0.6),
                ),
                const HGapSm(), // Compact: reduced horizontal gap
                Expanded(
                  child: Text(
                    t.taskName,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 13, // Compact: stepped down size
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (totalCount > 0) ...[
                  const HGapSm(),
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
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    if (taskWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12), // Compact: reduced padding
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16), // Compact: matched standard border radius
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.playlist_add_check_rounded,
                color: AppTheme.primaryAccentColor(context), // Contrast: primaryAccentColor instead of primaryLight
                size: 16,
              ),
              const HGapSm(),
              Text(
                'Tasks List'.toUpperCase(),
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryAccentColor(context), // Contrast: primaryAccentColor instead of primaryLight
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const VGapSm(), // Compact: reduced gap
          ...taskWidgets,
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6)),
        const HGapSm(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondaryColor(context),
                  fontSize: 13,
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildHistoryTimeline(Activity activity, List<CheckIn> checkIns, List<Task> tasks) {
    final List<DateTime> last7Days = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: index));
      return DateTime(date.year, date.month, date.day);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconSm(Icons.history_rounded, color: AppTheme.textSecondaryColor(context)),
            const HGapSm(),
            Text(
              '1-Week History Timeline'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondaryColor(context),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const VGapSm(), // Compact: reduced from VGapMd
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: last7Days.length,
          itemBuilder: (context, index) {
            final day = last7Days[index];
            final isLast = index == last7Days.length - 1;

            final dayCheckIns = checkIns.where((c) {
              return c.timestamp.year == day.year &&
                  c.timestamp.month == day.month &&
                  c.timestamp.day == day.day &&
                  c.checked;
            }).toList();

            final bool hasActivity = dayCheckIns.isNotEmpty;

            String dayLabel;
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));

            if (day == today) {
              dayLabel = 'Today';
            } else if (day == yesterday) {
              dayLabel = 'Yesterday';
            } else {
              dayLabel = DateFormat('EEEE, MMM d').format(day);
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 18, // Compact: reduced timeline dot size from 20
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasActivity
                              ? AppTheme.successColor.withValues(alpha: 0.15)
                              : AppTheme.subtleFillColor(context),
                          border: Border.all(
                            color: hasActivity
                                ? AppTheme.successColor
                                : AppTheme.borderColor(context),
                            width: 2,
                          ),
                        ),
                        child: hasActivity
                            ? const Icon(Icons.check, size: 10, color: AppTheme.successColor) // Compact: reduced icon size
                            : null,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppTheme.borderColor(context),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const HGapMd(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10), // Compact: reduced from 16
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Compact: reduced from 14
                        decoration: BoxDecoration(
                          color: hasActivity
                              ? AppTheme.successColor.withValues(alpha: 0.03)
                              : AppTheme.surface(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12), // Compact: matched standard border radius
                          border: Border.all(
                            color: hasActivity
                                ? AppTheme.successColor.withValues(alpha: 0.15)
                                : AppTheme.borderColor(context),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: hasActivity ? AppTheme.textPrimaryColor(context) : AppTheme.textSecondaryColor(context),
                                    fontWeight: hasActivity ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13, // Compact: stepped down size
                                  ),
                                ),
                                if (hasActivity)
                                  Text(
                                    activity.trackingType == 'multiple' || activity.trackingType == 'milestone'
                                        ? '${dayCheckIns.length} task(s) logged'
                                        : 'Completed',
                                    style: TextStyle(
                                      color: hasActivity ? AppTheme.successColor : AppTheme.textSecondaryColor(context),
                                      fontSize: 10, // Compact: micro scale
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            if (hasActivity && (activity.trackingType == 'multiple' || activity.trackingType == 'milestone')) ...[
                              const VGapSm(),
                              Wrap(
                                spacing: 4, // Compact: reduced spacing
                                runSpacing: 4,
                                children: dayCheckIns.map((c) {
                                  final name = c.subTaskName ?? 'Task';
                                  final cleanName = name.contains('|') ? name.split('|').first : name;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Compact: tighter tag padding
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6), // Compact: matched border radius
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      cleanName,
                                      style: TextStyle(
                                        color: AppTheme.primaryAccentColor(context), // Contrast: primaryAccentColor instead of primaryLight
                                        fontSize: 10, // Compact: stepped down size
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else if (hasActivity && activity.trackingType == 'single') ...[
                              const VGapSm(),
                              Wrap(
                                spacing: 4, // Compact: reduced spacing
                                runSpacing: 4,
                                children: dayCheckIns.map((c) {
                                  final timeStr = DateFormat('h:mm a').format(c.timestamp);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), // Compact: tighter tag padding
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6), // Compact: matched border radius
                                      border: Border.all(
                                        color: AppTheme.successColor.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'Checked at $timeStr',
                                      style: const TextStyle(
                                        color: AppTheme.successColor,
                                        fontSize: 10, // Compact: stepped down size
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              const VGapXs(),
                              Text(
                                'No activity logged',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.4),
                                  fontSize: 11, // Compact: stepped down size
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }






  void _navigateToEditActivity(Activity activity) {
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
          }) {},
          initialActivity: activity,
          onEdit: (name, trackingType, targetCount, {
            List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
            String? scheduledTime,
            DateTime? startDate,
            DateTime? endDate,
            List<String> subTaskTemplates = const [],
            String? description,
            bool skippable = false,
            bool reminderEnabled = true,
          }) async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _activityService.updateActivity(
                activity.id, name, trackingType, targetCount,
                repeatDays: repeatDays,
                scheduledTime: scheduledTime,
                startDate: startDate,
                endDate: endDate,
                subTaskTemplates: subTaskTemplates,
                description: description,
                skippable: skippable,
                reminderEnabled: reminderEnabled,
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Activity updated in Firestore.')),
              );
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          },
          onDelete: () async {
            final navigator = Navigator.of(context);
            final deleted = await _confirmDeleteActivity(activity);
            if (deleted) {
              // Pop the AddActivityScreen first
              navigator.pop();
              // Pop the ActivityDetailsScreen since the activity is deleted
              navigator.pop();
            }
          },
          onToggleActive: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _activityService.toggleActivity(activity.id, !activity.isActive);
              navigator.pop(); // close AddActivityScreen
            } catch (e) {
              messenger.showSnackBar(
                SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
              );
            }
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteActivity(Activity activity) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        title: Text('Delete "${activity.name}"?', style: AppTheme.headingSmall),
        content: const Text('Are you sure you want to delete this activity? All associated daily progress will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _activityService.deleteActivity(activity.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Activity deleted from Firestore.')),
        );
        return true;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to delete activity: $e'), backgroundColor: AppTheme.errorColor),
        );
        return false;
      }
    }
    return false;
  }
}


