import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import 'add_activity_screen.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import '../services/activity_service.dart';
import '../services/check_in_service.dart';

class TrackActivitiesScreen extends StatefulWidget {
  const TrackActivitiesScreen({super.key});

  @override
  State<TrackActivitiesScreen> createState() => _TrackActivitiesScreenState();
}

class _TrackActivitiesScreenState extends State<TrackActivitiesScreen> {
  final ActivityService _activityService = ActivityService();
  final CheckInService _checkInService = CheckInService();
  
  static const _dayLabelsShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: true,
      isScrollable: true,
      title: 'Track Activities',
      showBackButton: true,
      padding: EdgeInsets.zero,
      actions: [
        GestureDetector(
          onTap: _navigateToAddActivity,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
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
        const VGapMd(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildFirestoreList(),
        ),
      ],
    );
  }

  Widget _buildFirestoreList() {
    return StreamBuilder<List<Activity>>(
      stream: _activityService.getActivitiesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading activities', style: TextStyle(color: AppTheme.errorColor)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }

        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return _buildEmptyState();
        }

        return StreamBuilder<List<CheckIn>>(
          stream: _checkInService.getCheckedActivitiesCheckInsStream(),
          builder: (context, checkinSnapshot) {
            final checkIns = checkinSnapshot.data ?? [];
            return StreamBuilder<List<Task>>(
              stream: _activityService.getSubTasksStream(),
              builder: (context, subtaskSnapshot) {
                final subTasks = subtaskSnapshot.data ?? [];
                return _buildList(activities, checkIns, subTasks);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildList(List<Activity> activities, List<CheckIn> checkIns, List<Task> subTasks) {
    final active = activities.where((a) => a.checked).toList();
    final completed = activities.where((a) => !a.checked).toList();

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

    final todaySubTasks = subTasks.where((s) => isToday(s.timestamp) && s.checked).toList();

    String? getSortingTime(Activity activity) {
      if (activity.trackingType == 'multiple') {
        for (var template in activity.subTaskTemplates) {
          final parts = template.split('|');
          if (parts.length > 1) {
            final timeStr = parts.last;
            final isCheckedIn = todaySubTasks.any((s) => s.activityId == activity.id && s.taskName == template);
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

    int compareCompleted(Activity a, Activity b) {
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
    completed.sort(compareCompleted);

    if (active.isEmpty && completed.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('Active Activities (${active.length})', AppTheme.primaryColor),
          const VGapSm(),
          ...active.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildActivityCard(a),
          )),
          const VGapMd(),
        ],
        if (completed.isNotEmpty) ...[
          _buildSectionHeader('Completed Activities (${completed.length})', AppTheme.successColor),
          const VGapSm(),
          ...completed.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildActivityCard(a),
          )),
          const VGapMd(),
        ],
        const VGapXxl(),
        const VGapXxl(),
        const VGapXxl(),
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

  String _getRepeatDaysLabel(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekends';
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

  Widget _buildActivityCard(Activity activity) {
    final isActive = activity.checked;
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
      onTap: () => _navigateToEditActivity(activity),
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
              if (start != null && end != null && progressPercent > 0)
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildActivityProgressIcon(activity),
                                const HGapMd(),
                                Expanded(
                                  child: Text(
                                    activity.name,
                                    style: AppTheme.bodyLarge.copyWith(
                                      color: isActive ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const HGapSm(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeBadge.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: typeBadge.color.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        typeBadge.icon,
                                        size: 12,
                                        color: typeBadge.color.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        typeBadge.label,
                                        style: TextStyle(
                                          color: typeBadge.color.withValues(alpha: 0.8),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const VGapSm(),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
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
                                    color: AppTheme.primaryLight,
                                  ),
                                _buildMetaChip(
                                  icon: Icons.calendar_view_week_rounded,
                                  label: _getRepeatDaysLabel(activity.repeatDays),
                                  color: AppTheme.textSecondary,
                                ),
                              ],
                            ),
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
    final isActive = activity.checked;
    final accentColor = isActive ? AppTheme.primaryColor : AppTheme.successColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor,
        border: Border.all(color: accentColor, width: 2),
      ),
      child: const Icon(Icons.check, size: 14, color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.playlist_add,
            size: 64,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const VGapMd(),
          Text(
            'No Activities Tracked',
            style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const VGapSm(),
          Text(
            'Tap the (+) button to create an activity checklist item.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium,
          ),
        ],
      ),
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
          }) {
            _addActivity(
              name, trackingType, targetCount,
              repeatDays: repeatDays,
              scheduledTime: scheduledTime,
              startDate: startDate,
              endDate: endDate,
              subTaskTemplates: subTaskTemplates,
              description: description,
            );
          },
        ),
      ),
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
          }) {},
          initialActivity: activity,
          onEdit: (name, trackingType, targetCount, {
            List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
            String? scheduledTime,
            DateTime? startDate,
            DateTime? endDate,
            List<String> subTaskTemplates = const [],
            String? description,
          }) {
            _editActivity(
              activity.id, name, trackingType, targetCount,
              repeatDays: repeatDays,
              scheduledTime: scheduledTime,
              startDate: startDate,
              endDate: endDate,
              subTaskTemplates: subTaskTemplates,
              description: description,
            );
          },
          onDelete: () async {
            final deleted = await _confirmDeleteActivity(activity);
            if (deleted && context.mounted) {
              Navigator.pop(context);
            }
          },
          onToggleComplete: () {
            _toggleActivity(activity);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
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
  }) async {
    try {
      await _activityService.createActivity(
        name,
        trackingType: trackingType,
        targetCount: targetCount,
        repeatDays: repeatDays,
        scheduledTime: scheduledTime,
        startDate: startDate,
        endDate: endDate,
        subTaskTemplates: subTaskTemplates,
        description: description ?? '',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _editActivity(
    String id, String name, String trackingType, int targetCount, {
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    String? scheduledTime,
    DateTime? startDate,
    DateTime? endDate,
    List<String> subTaskTemplates = const [],
    String? description,
  }) async {
    try {
      await _activityService.updateActivity(
        id, name, trackingType, targetCount,
        repeatDays: repeatDays,
        scheduledTime: scheduledTime,
        startDate: startDate,
        endDate: endDate,
        subTaskTemplates: subTaskTemplates,
        description: description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity updated in Firestore.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  void _toggleActivity(Activity activity) async {
    final newChecked = !activity.checked;
    try {
      await _activityService.toggleActivity(activity.id, newChecked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update activity: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<bool> _confirmDeleteActivity(Activity activity) async {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Activity deleted from Firestore.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete activity: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
        return false;
      }
      return true;
    }
    return false;
  }
}
