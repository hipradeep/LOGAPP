import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';
import 'add_activity_screen.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final String activityId;

  const ActivityDetailsScreen({
    super.key,
    required this.activityId,
  });

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();

  late Stream<Activity?> _activityStream;
  late Stream<List<CheckIn>> _checkInsStream;
  late Stream<List<Task>> _subTasksStream;

  @override
  void initState() {
    super.initState();
    _activityStream = _activityService.getActivityStream(widget.activityId);
    _checkInsStream = _checkInService.getCheckInsStreamForLast7Days(widget.activityId);
    _subTasksStream = _activityService.getSubTasksForActivityStream(widget.activityId);
  }

  String _getRepeatDaysLabel(List<int> days) {
    const dayLabelsShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekends';
    return days.map((d) => dayLabelsShort[d - 1]).join(', ');
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
    return StreamBuilder<Activity?>(
      stream: _activityStream,
      builder: (context, activitySnapshot) {
        if (activitySnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error loading activity: ${activitySnapshot.error}',
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
          );
        }
        if (activitySnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }
        final activity = activitySnapshot.data;
        if (activity == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Activity not found', style: TextStyle(color: Colors.white)),
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

        return StreamBuilder<List<CheckIn>>(
          stream: _checkInsStream,
          builder: (context, checkInsSnapshot) {
            final checkIns = checkInsSnapshot.data ?? [];
            return StreamBuilder<List<Task>>(
              stream: _subTasksStream,
              builder: (context, subTasksSnapshot) {
                final subTasks = subTasksSnapshot.data ?? [];
                return _buildDetailsScreen(activity, checkIns, subTasks);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsScreen(Activity activity, List<CheckIn> checkIns, List<Task> subTasks) {
    final typeColor = _getTrackingTypeColor(activity.trackingType);
    final typeIcon = _getTrackingTypeIcon(activity.trackingType);

    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Activity Details',
      showBackButton: true,
      actions: [
        GestureDetector(
          onTap: () => _navigateToEditActivity(activity),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
      backgroundWidgets: const [
        GlowBlob(
          top: -40,
          left: -40,
          size: 240,
          color: AppTheme.primaryColor,
          opacity: 0.1,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 280,
          color: AppTheme.secondaryColor,
          opacity: 0.05,
        ),
      ],
      children: [
        // 1. Header Card (Name, Category, Description)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.04),
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
                    width: 56,
                    height: 56,
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
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(typeIcon, color: Colors.white, size: 26),
                  ),
                  const HGapMd(),
                  // Name and Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: AppTheme.headingMedium.copyWith(fontSize: 22),
                        ),
                        const VGapXs(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getTrackingTypeLabel(activity.trackingType).toUpperCase(),
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
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
                const VGapMd(),
                const Divider(color: Colors.white10, height: 1),
                const VGapMd(),
                Text(
                  'Description',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const VGapXs(),
                Text(
                  activity.description!,
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const VGapLg(),

        // 2. Schedule Card Details
        _buildScheduleDetailsCard(activity),
        const VGapLg(),

        // 3. Analytics Section Placeholder
        _buildAnalyticsPlaceholder(),
        const VGapLg(),

        // 4. Timeline Section
        _buildHistoryTimeline(activity, checkIns, subTasks),
        const VGapXxl(),
      ],
    );
  }

  Widget _buildScheduleDetailsCard(Activity activity) {
    final start = activity.startDate;
    final end = activity.endDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.03),
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
          const VGapMd(),
          _buildDetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Repeat Days',
            value: _getRepeatDaysLabel(activity.repeatDays),
          ),
          if (activity.scheduledTime != null) ...[
            const VGapSm(),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              label: 'Reminder Time',
              value: _formatScheduledTime(activity.scheduledTime!),
            ),
          ],
          if (start != null || end != null) ...[
            const VGapSm(),
            _buildDetailRow(
              icon: Icons.date_range_rounded,
              label: 'Tracking Period',
              value: '${start != null ? DateFormat('MMM d, yyyy').format(start) : 'Start'} to ${end != null ? DateFormat('MMM d, yyyy').format(end) : 'Ongoing'}',
            ),
          ],
          const VGapSm(),
          _buildDetailRow(
            icon: Icons.settings_rounded,
            label: 'Type Settings',
            value: activity.trackingType == 'multiple'
                ? '${activity.subTaskTemplates.length} custom checklist tasks'
                : (activity.trackingType == 'milestone'
                    ? 'Flexible tasks checklist'
                    : 'Simple checklist item'),
          ),
          if (activity.skippable) ...[
            const VGapSm(),
            _buildDetailRow(
              icon: Icons.double_arrow_rounded,
              label: 'Skippable',
              value: 'Yes (allows skipping daily without breaking streaks)',
            ),
          ],
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
        Icon(icon, size: 16, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
        const HGapSm(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
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

  Widget _buildAnalyticsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.12),
            AppTheme.secondaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppTheme.secondaryColor,
                  size: 20,
                ),
              ),
              const HGapMd(),
              Text(
                'Analytics & Performance',
                style: AppTheme.headingSmall.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const VGapLg(),
          SizedBox(
            height: 100,
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) => Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.04),
                  )),
                ),
                CustomPaint(
                  size: const Size(double.infinity, 100),
                  painter: MockGraphPainter(),
                ),
              ],
            ),
          ),
          const VGapMd(),
          Center(
            child: Text(
              'Weekly performance graphs and insights coming soon!',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTimeline(Activity activity, List<CheckIn> checkIns, List<Task> subTasks) {
    final List<DateTime> last7Days = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: index));
      return DateTime(date.year, date.month, date.day);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const IconSm(Icons.history_rounded, color: AppTheme.textSecondary),
            const HGapSm(),
            Text(
              '1-Week History Timeline'.toUpperCase(),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const VGapMd(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasActivity
                              ? AppTheme.successColor.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: hasActivity
                                ? AppTheme.successColor
                                : Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                        ),
                        child: hasActivity
                            ? const Icon(Icons.check, size: 12, color: AppTheme.successColor)
                            : null,
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.white.withValues(alpha: 0.08),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                    ],
                  ),
                  const HGapMd(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: hasActivity
                              ? AppTheme.successColor.withValues(alpha: 0.03)
                              : AppTheme.surfaceColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasActivity
                                ? AppTheme.successColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
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
                                    color: hasActivity ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: hasActivity ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                if (hasActivity)
                                  Text(
                                    activity.trackingType == 'multiple' || activity.trackingType == 'milestone'
                                        ? '${dayCheckIns.length} task(s) logged'
                                        : 'Completed',
                                    style: TextStyle(
                                      color: hasActivity ? AppTheme.successColor : AppTheme.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            if (hasActivity && (activity.trackingType == 'multiple' || activity.trackingType == 'milestone')) ...[
                              const VGapSm(),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: dayCheckIns.map((c) {
                                  final name = c.subTaskName ?? 'Task';
                                  final cleanName = name.contains('|') ? name.split('|').first : name;
                                  final timeStr = _getTaskScheduledTime(cleanName, day, subTasks, activity);
                                  final formattedTime = timeStr != null ? _formatScheduledTime(timeStr) : null;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          cleanName,
                                          style: const TextStyle(
                                            color: AppTheme.primaryLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (formattedTime != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              formattedTime,
                                              style: TextStyle(
                                                color: AppTheme.primaryLight.withValues(alpha: 0.8),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        GestureDetector(
                                          onTap: () => _deleteCheckInItem(c, subTasks, activity),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 12,
                                            color: AppTheme.errorColor.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else if (hasActivity && activity.trackingType == 'single') ...[
                              const VGapSm(),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: dayCheckIns.map((c) {
                                  final timeStr = DateFormat('h:mm a').format(c.timestamp);
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.successColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppTheme.successColor.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          'Checked at $timeStr',
                                          style: const TextStyle(
                                            color: AppTheme.successColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _deleteCheckInItem(c, subTasks, activity),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 12,
                                            color: AppTheme.errorColor.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              const VGapXs(),
                              Text(
                                'No activity logged',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                                  fontSize: 12,
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

  String? _getTaskScheduledTime(String taskTitle, DateTime day, List<Task> subTasks, Activity activity) {
    if (activity.trackingType == 'multiple') {
      final containerTask = subTasks.firstWhere(
        (s) => s.timestamp.year == day.year &&
               s.timestamp.month == day.month &&
               s.timestamp.day == day.day &&
               s.subTasks.isNotEmpty,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
      );
      if (containerTask.id.isNotEmpty) {
        final matching = containerTask.subTasks.firstWhere(
          (st) => st.title == taskTitle,
          orElse: () => SubTask(id: '', title: '', checked: false),
        );
        if (matching.id.isNotEmpty && matching.scheduledTime != null) {
          return matching.scheduledTime;
        }
      }
      for (var template in activity.subTaskTemplates) {
        final parts = template.split('|');
        if (parts.first == taskTitle && parts.length > 1) {
          return parts.last;
        }
      }
    } else if (activity.trackingType == 'milestone') {
      final matching = subTasks.firstWhere(
        (s) => s.timestamp.year == day.year &&
               s.timestamp.month == day.month &&
               s.timestamp.day == day.day &&
               s.taskName == taskTitle,
        orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
      );
      if (matching.id.isNotEmpty) {
        return matching.scheduledTime;
      }
    }
    return null;
  }

  void _deleteCheckInItem(CheckIn checkIn, List<Task> subTasks, Activity activity) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _checkInService.deleteCheckIn(checkIn.id);

      if (activity.trackingType == 'multiple') {
        // Find the corresponding container Task in loaded subTasks
        final taskForDay = subTasks.firstWhere(
          (s) => _isSameDay(s.timestamp, checkIn.timestamp) && s.subTasks.isNotEmpty,
          orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: checkIn.timestamp, checked: false),
        );
        if (taskForDay.id.isNotEmpty) {
          final List<SubTask> updatedSubTasks = List<SubTask>.from(taskForDay.subTasks);
          final index = updatedSubTasks.indexWhere((st) {
            final cleanTitle = st.title.contains('|') ? st.title.split('|').first : st.title;
            return cleanTitle == checkIn.subTaskName;
          });
          if (index != -1) {
            updatedSubTasks[index] = updatedSubTasks[index].copyWith(checked: false);

            final allChecked = updatedSubTasks.isNotEmpty && updatedSubTasks.every((st) => st.checked);
            final updatedTask = taskForDay.copyWith(subTasks: updatedSubTasks, checked: allChecked);
            await _activityService.updateSubTask(updatedTask);
          }
        }
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Log entry removed.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete history item: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
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
          onToggleComplete: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            try {
              await _activityService.toggleActivity(activity.id, !activity.checked);
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
        backgroundColor: AppTheme.surfaceColor,
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

class MockGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final paintShadow = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.2, size.height * 0.8,
      size.width * 0.35, size.height * 0.2,
      size.width * 0.5, size.height * 0.4,
    );
    path.cubicTo(
      size.width * 0.65, size.height * 0.6,
      size.width * 0.8, size.height * 0.1,
      size.width, size.height * 0.3,
    );

    canvas.drawPath(path, paintShadow);
    canvas.drawPath(path, paintLine);

    // Draw glowing data points
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pointOuterPaint = Paint()
      ..color = AppTheme.secondaryColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 6, pointOuterPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 3, pointPaint);

    canvas.drawCircle(Offset(size.width, size.height * 0.3), 6, pointOuterPaint);
    canvas.drawCircle(Offset(size.width, size.height * 0.3), 3, pointPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
