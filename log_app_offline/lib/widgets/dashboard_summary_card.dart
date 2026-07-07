import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../models/task.dart';
import 'app_spacers.dart';
import 'app_tooltip.dart';
import '../services/milestone_service.dart';
import '../services/service_locator.dart';

class DashboardSummaryCard extends StatefulWidget {
  final List<Activity> activities;
  final List<CheckIn> checkIns;
  final List<Task> subTasks;
  final MilestoneService milestoneService;

  DashboardSummaryCard({
    super.key,
    required this.activities,
    required this.checkIns,
    required this.subTasks,
    MilestoneService? milestoneService,
  }) : milestoneService = milestoneService ?? getIt<MilestoneService>();

  @override
  State<DashboardSummaryCard> createState() => _DashboardSummaryCardState();
}

class _DashboardSummaryCardState extends State<DashboardSummaryCard> {
  bool _isExpanded = false;
  int? _selectedDayIndex;

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    if (widget.activities.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface(context).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.playlist_add_check_rounded, color: AppTheme.textSecondary, size: 28),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No active activities selected.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Go to Settings > Track Activities to choose.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    double totalWeight = 0.0;
    double weightedCompletionSum = 0.0;
    int fullyCompletedCount = 0;
    int visibleCount = 0;
    double todayStars = 0.0;
    double maxStars = 0.0;
    final now = DateTime.now();

    final todayCheckIns = widget.checkIns.where((c) => _isToday(c.timestamp) && c.checked).toList();

    for (var activity in widget.activities) {
      final double activityProgress;
      if (activity.trackingType == 'milestone') {
        final milestoneProgress = widget.milestoneService.getMilestoneDailyCompletion(activity, widget.subTasks, now);
        if (milestoneProgress == -1.0) {
          continue; // Exclude from calculations for today
        }
        activityProgress = milestoneProgress;
      } else {
        if (activity.trackingType == 'multiple') {
          final todayTask = widget.subTasks.firstWhere(
            (s) => s.activityId == activity.id && _isToday(s.timestamp),
            orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: now, checked: false),
          );
          final totalSub = todayTask.subTasks.length;
          final checkedSub = todayTask.subTasks.where((st) => st.checked).length;
          activityProgress = totalSub > 0 ? checkedSub / totalSub : 0.0;
        } else {
          final todayCount = todayCheckIns.where((c) => c.activityId == activity.id).length;
          activityProgress = activity.targetCount > 0
              ? (todayCount / activity.targetCount).clamp(0.0, 1.0)
              : 0.0;
        }
      }
      
      weightedCompletionSum += (activityProgress * activity.weight);
      totalWeight += activity.weight;
      visibleCount++;
      if (activityProgress >= 1.0) {
        fullyCompletedCount++;
      }
      todayStars += (activityProgress * activity.points);
      maxStars += activity.points;
    }

    final double completionRate = totalWeight > 0 ? weightedCompletionSum / totalWeight : 0.0;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
            if (!_isExpanded) {
              _selectedDayIndex = null;
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor(context),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DashboardSummaryRow(
                fullyCompletedCount: fullyCompletedCount,
                visibleCount: visibleCount,
                todayStars: todayStars,
                maxStars: maxStars,
                completionRate: completionRate,
                isExpanded: _isExpanded,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                clipBehavior: Clip.none,
                child: _isExpanded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const VGapMd(),
                          Divider(
                            height: 1,
                            color: AppTheme.borderColor(context).withValues(alpha: 0.3),
                          ),
                          const VGapMd(),
                          _WeeklyStarsSection(
                            activities: widget.activities,
                            checkIns: widget.checkIns,
                            subTasks: widget.subTasks,
                            milestoneService: widget.milestoneService,
                            selectedDayIndex: _selectedDayIndex,
                            onDayTapped: (index) {
                              setState(() {
                                _selectedDayIndex = index;
                              });
                            },
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSummaryRow extends StatelessWidget {
  final int fullyCompletedCount;
  final int visibleCount;
  final double todayStars;
  final double maxStars;
  final double completionRate;
  final bool isExpanded;

  const _DashboardSummaryRow({
    required this.fullyCompletedCount,
    required this.visibleCount,
    required this.todayStars,
    required this.maxStars,
    required this.completionRate,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Daily Progress'.toUpperCase(),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.primaryAccentColor(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      fontSize: 10,
                    ),
                  ),
                  const HGapXs(),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primaryAccentColor(context),
                      size: 14,
                    ),
                  ),
                ],
              ),
              const VGapXs(),
              Text(
                '$fullyCompletedCount of $visibleCount Completed',
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const VGapXs(),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const HGapXs(),
                  Text(
                    '${todayStars.toInt()}/${maxStars.toInt()}',
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.amber[300],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (completionRate >= 1.0) ...[
                    const HGapXs(),
                    Icon(
                      Icons.diamond_rounded,
                      color: AppTheme.isDarkMode(context) ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+1',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.isDarkMode(context) ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const HGapMd(),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: completionRate,
                strokeWidth: 5,
                backgroundColor: AppTheme.borderColor(context),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completionRate >= 1.0 ? AppTheme.successColor : AppTheme.primaryColor,
                ),
              ),
            ),
            Text(
              '${(completionRate * 100).toInt()}%',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodySmall?.color ?? AppTheme.textPrimaryColor(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeeklyStarsSection extends StatelessWidget {
  final List<Activity> activities;
  final List<CheckIn> checkIns;
  final List<Task> subTasks;
  final MilestoneService milestoneService;
  final int? selectedDayIndex;
  final ValueChanged<int?> onDayTapped;

  const _WeeklyStarsSection({
    required this.activities,
    required this.checkIns,
    required this.subTasks,
    required this.milestoneService,
    required this.selectedDayIndex,
    required this.onDayTapped,
  });

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final dayLabels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = weekDays[index];
        final isToday = _isSameDay(day, now);
        final isFuture = day.isAfter(DateTime(now.year, now.month, now.day));

        double dayWeightedCompletionSum = 0.0;
        double dayTotalWeight = 0.0;
        double dayStars = 0.0;
        double dayMaxStars = 0.0;

        for (var activity in activities) {
          double completionRateOfActivity = 0.0;

          if (activity.trackingType == 'milestone') {
            final milestoneProgress = milestoneService.getMilestoneDailyCompletion(activity, subTasks, day);
            if (milestoneProgress == -1.0) {
              continue;
            }
            completionRateOfActivity = milestoneProgress;
          } else {
            final double activityProgress;
            if (activity.trackingType == 'multiple') {
              final dayTask = subTasks.firstWhere(
                (s) => s.activityId == activity.id && _isSameDay(s.timestamp, day),
                orElse: () => Task(id: '', activityId: '', taskName: '', timestamp: day, checked: false),
              );
              final totalSub = dayTask.subTasks.length;
              final checkedSub = dayTask.subTasks.where((st) => st.checked).length;
              activityProgress = totalSub > 0 ? checkedSub / totalSub : 0.0;
            } else {
              final todayCount = checkIns
                  .where((c) =>
                      c.activityId == activity.id &&
                      _isSameDay(c.timestamp, day) &&
                      c.checked)
                  .length;
              activityProgress = activity.targetCount > 0
                  ? (todayCount / activity.targetCount).clamp(0.0, 1.0)
                  : 0.0;
            }
            completionRateOfActivity = activityProgress;
          }

          dayWeightedCompletionSum += (completionRateOfActivity * activity.weight);
          dayTotalWeight += activity.weight;
          dayStars += (completionRateOfActivity * activity.points);
          dayMaxStars += activity.points;
        }

        final double dayCompletionRate = dayTotalWeight > 0 ? dayWeightedCompletionSum / dayTotalWeight : 0.0;
        final bool isDayCompleted = dayCompletionRate >= 1.0;
        final isSelected = selectedDayIndex == index;

        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                onDayTapped(isSelected ? null : index);
              },
              behavior: HitTestBehavior.opaque,
              child: _DashboardDayCircle(
                label: dayLabels[index],
                date: day.day.toString(),
                stars: dayStars,
                maxStars: dayMaxStars,
                progress: dayCompletionRate,
                isToday: isToday,
                isFuture: isFuture,
                isCompleted: isDayCompleted,
              ),
            ),
            if (isSelected)
              Positioned(
                bottom: 56,
                left: -50,
                right: -50,
                child: Center(
                  child: AppTooltipStatic(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${dayStars.toInt()}/${dayMaxStars.toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _DashboardDayCircle extends StatelessWidget {
  final String label;
  final String date;
  final double stars;
  final double maxStars;
  final double progress;
  final bool isToday;
  final bool isFuture;
  final bool isCompleted;

  const _DashboardDayCircle({
    required this.label,
    required this.date,
    required this.stars,
    required this.maxStars,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final hasStars = stars > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isToday ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const VGapXs(),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : AppTheme.surface(context).withValues(alpha: 0.3),
            border: Border.all(
              color: isToday
                  ? AppTheme.primaryColor
                  : (hasStars ? Colors.amber.withValues(alpha: 0.6) : AppTheme.borderColor(context)),
              width: isToday ? 2 : 1,
            ),
            boxShadow: isToday
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : (hasStars
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.15),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : []),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!isFuture && progress > 0)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppTheme.successColor : AppTheme.primaryAccentColor(context),
                    ),
                  ),
                ),
              isCompleted && !isFuture
                  ? Icon(
                      Icons.diamond_rounded,
                      color: AppTheme.isDarkMode(context) ? const Color(0xFF22D3EE) : const Color(0xFF0891B2),
                      size: 16,
                    )
                  : Text(
                      date,
                      style: AppTheme.bodySmall.copyWith(
                        color: isToday
                            ? AppTheme.selectedChipTextColor(context)
                            : (isFuture
                                ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                                : AppTheme.textSecondaryColor(context)),
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
            ],
          ),
        ),
        const VGapXs(),
        if (!isFuture)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                color: hasStars ? Colors.amber : AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                size: 11,
              ),
              const SizedBox(width: 1),
              Text(
                '${stars.toInt()}',
                style: AppTheme.bodySmall.copyWith(
                  color: hasStars ? Colors.amber[300] : AppTheme.textSecondaryColor(context).withValues(alpha: 0.5),
                  fontWeight: hasStars ? FontWeight.bold : FontWeight.normal,
                  fontSize: 9,
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_outline_rounded,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.2),
                size: 11,
              ),
              const SizedBox(width: 1),
              Text(
                '-',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.3),
                  fontSize: 9,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// ORIGINAL PROGRESS-BASED WEEKLY CALENDAR CODE KEPT FOR REFERENCE (DON'T REMOVE)
// ============================================================================
/*
class _DashboardDayCircleOriginal extends StatelessWidget {
  final String label;
  final String date;
  final double progress;
  final bool isToday;
  final bool isFuture;
  final bool isCompleted;

  const _DashboardDayCircleOriginal({
    required this.label,
    required this.date,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    final Color progressColor = isCompleted
        ? AppTheme.successColor
        : (progress > 0 ? AppTheme.primaryAccentColor(context) : AppTheme.subtleFillColor(context));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isToday ? AppTheme.primaryAccentColor(context) : AppTheme.textSecondaryColor(context),
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
                      ? AppTheme.subtleFillColor(context).withValues(alpha: 0.3)
                      : AppTheme.subtleFillColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Text(
                date,
                style: AppTheme.bodySmall.copyWith(
                  color: isToday
                      ? AppTheme.selectedChipTextColor(context)
                      : (isFuture
                          ? AppTheme.textSecondaryColor(context).withValues(alpha: 0.4)
                          : AppTheme.textSecondaryColor(context)),
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const VGapXs(),
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
*/
