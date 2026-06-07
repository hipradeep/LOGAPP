import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/sub_task.dart';
import 'app_spacers.dart';

class MilestonesTab extends StatefulWidget {
  final List<Activity> milestoneActivities;
  final Activity? selectedActivity;
  final List<SubTask> subTasks;
  final Function(Activity?) onActivitySelected;
  final Function(SubTask, bool) onToggleSubTask;
  final bool isLoadingSubTasks;

  const MilestonesTab({
    super.key,
    required this.milestoneActivities,
    required this.selectedActivity,
    required this.subTasks,
    required this.onActivitySelected,
    required this.onToggleSubTask,
    this.isLoadingSubTasks = false,
  });

  @override
  State<MilestonesTab> createState() => _MilestonesTabState();
}

class _MilestonesTabState extends State<MilestonesTab> {
  late DateTime _currentEndDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentEndDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void didUpdateWidget(covariant MilestonesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedActivity?.id != widget.selectedActivity?.id) {
      final now = DateTime.now();
      _currentEndDate = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _currentEndDate.subtract(const Duration(days: 6));
    final end = _currentEndDate;
    final DateFormat formatter = DateFormat('MMM d');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFutureWeek = _currentEndDate.isAfter(today);

    String rangeText;
    if (isFutureWeek) {
      rangeText = '${formatter.format(start)} to ${formatter.format(end)}';
    } else {
      final endDay = DateTime(end.year, end.month, end.day);
      if (endDay == today) {
        rangeText = 'Today to ${formatter.format(start)}';
      } else {
        rangeText = '${formatter.format(end)} to ${formatter.format(start)}';
      }
    }

    // Generate rangeDays conditionally:
    // Ascending for future weeks, Descending for current/past weeks.

    final List<DateTime> rangeDays = [];
    if (isFutureWeek) {
      // Ascending (earliest to latest): e.g. Jun 8 to Jun 14
      for (int i = 6; i >= 0; i--) {
        final day = _currentEndDate.subtract(Duration(days: i));
        rangeDays.add(DateTime(day.year, day.month, day.day));
      }
    } else {
      // Descending (latest to earliest): e.g. Today to Jun 1
      for (int i = 0; i < 7; i++) {
        final day = _currentEndDate.subtract(Duration(days: i));
        rangeDays.add(DateTime(day.year, day.month, day.day));
      }
    }

    final filteredSubTasks = widget.subTasks.where((st) {
      final stDate = DateTime(st.timestamp.year, st.timestamp.month, st.timestamp.day);
      return rangeDays.contains(stDate);
    }).toList();

    filteredSubTasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group subtasks by day date (Y-M-D)
    final Map<DateTime, List<SubTask>> grouped = {};
    for (var dayKey in rangeDays) {
      grouped[dayKey] = [];
    }

    for (var st in filteredSubTasks) {
      final dateKey = DateTime(st.timestamp.year, st.timestamp.month, st.timestamp.day);
      if (grouped.containsKey(dateKey)) {
        grouped[dateKey]!.add(st);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown to select a milestone activity
        Row(
          children: [
            SizedBox(
              width: 180,
              child: _buildActivityDropdown(context),
            ),
            const HGapSm(),
            _buildCalendarButton(context),
            const HGapSm(),
            _buildProgressButton(context),
            const Spacer(),
          ],
        ),
        const VGapMd(),
        
        // Date range pagination header
        if (widget.selectedActivity != null) ...[
          _buildTasksHeaderRow(rangeText),
          const VGapSm(),
        ],

        // Subtasks list for the selected activity
        if (widget.selectedActivity == null)
          _buildEmptyState('Select a milestone activity above.')
        else if (widget.isLoadingSubTasks)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rangeDays.length,
            itemBuilder: (context, dateIndex) {
              final dateKey = rangeDays[dateIndex];
              final daySubTasks = grouped[dateKey]!;
              final dayName = _getDayName(dateKey);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
                    child: Text(
                      dayName,
                      style: TextStyle(
                        color: AppTheme.primaryLight.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (daySubTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        'No subtasks',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.4),
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...daySubTasks.map((st) {
                      final hasSchedule = st.subTaskName.contains('|');
                      final nameToShow = hasSchedule ? st.subTaskName.split('|').first : st.subTaskName;
                      final scheduleTimeStr = hasSchedule ? st.subTaskName.split('|').last : null;

                      return GestureDetector(
                        onTap: () => widget.onToggleSubTask(st, !st.checked),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: st.checked
                                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.02),
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
                                        nameToShow,
                                        style: TextStyle(
                                          color: st.checked ? AppTheme.textSecondary : Colors.white,
                                          decoration: st.checked ? TextDecoration.lineThrough : null,
                                          decorationColor: AppTheme.textSecondary.withValues(alpha: 0.7),
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasSchedule) ...[
                                      const HGapSm(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: st.checked
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
                                              color: st.checked
                                                  ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                                  : AppTheme.primaryLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTimeString(scheduleTimeStr!),
                                              style: TextStyle(
                                                color: st.checked
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
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: st.checked ? AppTheme.primaryColor : Colors.transparent,
                                  border: Border.all(
                                    color: st.checked 
                                        ? AppTheme.primaryColor 
                                        : AppTheme.textSecondary.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: st.checked
                                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildTasksHeaderRow(String rangeText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Tasks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rangeText,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const HGapSm(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentEndDate = _currentEndDate.subtract(const Duration(days: 7));
                      });
                    },
                    child: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Container(width: 1, height: 12, color: Colors.white12),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentEndDate = _currentEndDate.add(const Duration(days: 7));
                      });
                    },
                    child: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getDayName(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Today';
    } else if (compareDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM d').format(date);
    }
  }


  Widget _buildCalendarButton(BuildContext context) {
    final activity = widget.selectedActivity;
    final hasDates = activity != null && (activity.startDate != null || activity.endDate != null);

    return Tooltip(
      message: hasDates ? 'View Milestone Dates' : 'No Dates Set',
      child: GestureDetector(
        onTap: () {
          if (activity == null) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(activity.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activity.description?.isNotEmpty == true) ...[
                    Text(
                      activity.description!,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const VGapMd(),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded, color: AppTheme.primaryLight, size: 18),
                      const HGapSm(),
                      Text(
                        activity.startDate != null
                            ? 'Start: ${DateFormat('MMM d, yyyy').format(activity.startDate!)}'
                            : 'Start: Not set',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  const VGapSm(),
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, color: AppTheme.successColor, size: 18),
                      const HGapSm(),
                      Text(
                        activity.endDate != null
                            ? 'End: ${DateFormat('MMM d, yyyy').format(activity.endDate!)}'
                            : 'End: Not set',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: hasDates
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : AppTheme.surfaceColor.withValues(alpha: 0.25),
            shape: BoxShape.circle,
            border: Border.all(
              color: hasDates
                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: hasDates ? AppTheme.primaryLight : AppTheme.textSecondary.withValues(alpha: 0.5),
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressButton(BuildContext context) {
    final total = widget.subTasks.length;
    final completed = widget.subTasks.where((st) => st.checked).length;
    final percent = total > 0 ? completed / total : 0.0;

    return Tooltip(
      message: 'Progress: $completed/$total completed (${(percent * 100).toStringAsFixed(0)}%)',
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Milestone Progress: $completed of $total subtasks completed (${(percent * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: AppTheme.surfaceColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 2.5,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.successColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityDropdown(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: AppTheme.surfaceColor,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.7), size: 20),
          value: widget.selectedActivity?.id,
          hint: Text(
            widget.milestoneActivities.isEmpty ? 'No milestone activities' : 'Select a milestone activity',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          items: widget.milestoneActivities.map((activity) {
            return DropdownMenuItem<String>(
              value: activity.id,
              child: Text(
                activity.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              final activity = widget.milestoneActivities.firstWhere((a) => a.id == id);
              widget.onActivitySelected(activity);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
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
}
