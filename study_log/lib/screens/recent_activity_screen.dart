import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/study_log.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/service_locator.dart';
import '../controllers/progress_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';

/// Represents daily aggregate activity for a single calendar day.
class DayActivityItem {
  final DateTime date;
  final int topicsFinished;
  final int revisionsDone;
  final int studyMinutes;

  const DayActivityItem({
    required this.date,
    required this.topicsFinished,
    required this.revisionsDone,
    this.studyMinutes = 0,
  });

  bool get hasActivity => topicsFinished > 0 || revisionsDone > 0 || studyMinutes > 0;
}

/// Recent Activity Screen featuring:
/// - Top glassmorphism App Bar with back navigation and refresh
/// - Horizontal calendar date strip below app bar to select dates
/// - Summary card displaying topics finished, revisions done, and hours spent on selected date
/// - Detailed list of study log entries specifically for the selected date
/// - Adheres strictly to [optimize.md] and [aa-rules.md]
class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  late final ProgressController _progressController;
  late final ScrollController _dateStripController;
  late DateTime _selectedDate;
  List<StudyLog> _allLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _dateStripController = ScrollController();
    _progressController = getIt<ProgressController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _dateStripController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!_isLoading && mounted) {
      setState(() => _isLoading = true);
    }
    await _progressController.refresh();
    final logs = await _fetchAllLogs();
    if (mounted) {
      setState(() {
        _allLogs = logs;
        _isLoading = false;
      });
      _scrollToSelectedDate(false);
    }
  }

  Future<List<StudyLog>> _fetchAllLogs() async {
    final directLogs = await LocalStudyLogStorage.loadAll();
    final Map<String, StudyLog> logsById = {
      for (final l in directLogs) l.id: l,
    };

    final topicBuckets = await LocalTopicStorage.loadAllBuckets();
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;
    final courses = getIt.isRegistered<CoursesController>()
        ? getIt<CoursesController>()
        : null;

    final existingTopicIds = directLogs
        .where((l) => l.topicId != null && l.topicId!.isNotEmpty)
        .map((l) => l.topicId!)
        .toSet();

    for (final list in topicBuckets.values) {
      for (final topic in list) {
        if (topic.isCompleted && topic.completedAt != null) {
          if (!existingTopicIds.contains(topic.id)) {
            final courseTitle = courses?.getCourseById(topic.courseId)?.title ?? '';
            final moduleTitle = ongoing?.moduleTitleFor(topic.moduleId) ?? '';
            final synthLog = StudyLog(
              id: 'synth_${topic.id}',
              type: StudyLogType.topicCompleted,
              courseId: topic.courseId,
              courseTitle: courseTitle,
              moduleId: topic.moduleId,
              moduleTitle: moduleTitle,
              topicId: topic.id,
              topicTitle: topic.title,
              timestamp: topic.completedAt!,
              createdAt: topic.completedAt!,
            );
            logsById[synthLog.id] = synthLog;
          }
        }
      }
    }

    // Synthesize completed modules if all topics are completed and no log exists yet
    final existingModuleLogs = directLogs
        .where((l) => l.isModuleCompleted)
        .map((l) => l.moduleId)
        .toSet();

    for (final entry in topicBuckets.entries) {
      final moduleId = entry.key;
      final list = entry.value;
      if (list.isNotEmpty && list.every((t) => t.isCompleted)) {
        if (!existingModuleLogs.contains(moduleId)) {
          final first = list.first;
          final courseTitle =
              courses?.getCourseById(first.courseId)?.title ?? '';
          final moduleTitle = ongoing?.moduleTitleFor(moduleId) ?? '';
          final latestCompletedAt = list
                  .map((t) => t.completedAt)
                  .whereType<DateTime>()
                  .fold<DateTime?>(
                      null,
                      (prev, curr) => prev == null || curr.isAfter(prev)
                          ? curr
                          : prev) ??
              DateTime.now();

          final synthModLog = StudyLog(
            id: 'synth_mod_$moduleId',
            type: StudyLogType.moduleCompleted,
            courseId: first.courseId,
            courseTitle: courseTitle,
            moduleId: moduleId,
            moduleTitle: moduleTitle.isNotEmpty ? moduleTitle : first.title,
            timestamp: latestCompletedAt,
            createdAt: latestCompletedAt,
          );
          logsById[synthModLog.id] = synthModLog;
        }
      }
    }

    final revisions = await LocalRevisionStorage.loadAll();
    final existingRevisionKeys = directLogs
        .where((l) => l.isRevisionModuleCompleted)
        .map((l) =>
            '${l.moduleId}_${l.timestamp.year}_${l.timestamp.month}_${l.timestamp.day}')
        .toSet();

    for (final r in revisions) {
      final revDate = r.lastRevisionAt ?? r.updatedAt;
      final key =
          '${r.moduleId}_${revDate.year}_${revDate.month}_${revDate.day}';
      if (!existingRevisionKeys.contains(key) &&
          (r.currentLevel > 1 || r.isFinished)) {
        final courseTitle = courses?.getCourseById(r.courseId)?.title ?? '';
        final moduleTitle = ongoing?.moduleTitleFor(r.moduleId) ?? '';
        final synthRevLog = StudyLog(
          id: 'synth_rev_${r.id}_${revDate.millisecondsSinceEpoch}',
          type: StudyLogType.revisionModuleCompleted,
          courseId: r.courseId,
          courseTitle: courseTitle,
          moduleId: r.moduleId,
          moduleTitle: moduleTitle,
          revisionLevel: r.currentLevel,
          timestamp: revDate,
          createdAt: revDate,
        );
        logsById[synthRevLog.id] = synthRevLog;
      }
    }

    // Map study session durations to specific completed topics/revisions on the same day
    final Map<String, int> sessionMinutesByTopic = {};
    final Map<String, int> sessionMinutesByTitle = {};
    for (final l in directLogs) {
      if (l.type == StudyLogType.studySession &&
          l.durationMinutes != null &&
          l.durationMinutes! > 0) {
        final dayKey =
            '${l.timestamp.year}_${l.timestamp.month}_${l.timestamp.day}';
        if (l.topicId != null && l.topicId!.isNotEmpty) {
          final tKey = '${l.topicId}_$dayKey';
          sessionMinutesByTopic[tKey] =
              (sessionMinutesByTopic[tKey] ?? 0) + l.durationMinutes!;
        }
        if (l.topicTitle != null && l.topicTitle!.isNotEmpty) {
          final titleKey = '${l.topicTitle!.trim().toLowerCase()}_$dayKey';
          sessionMinutesByTitle[titleKey] =
              (sessionMinutesByTitle[titleKey] ?? 0) + l.durationMinutes!;
        }
      }
    }

    for (final entry in logsById.entries) {
      final l = entry.value;
      if ((l.isTopicCompleted || l.isRevisionTopicCompleted) &&
          (l.durationMinutes == null || l.durationMinutes == 0)) {
        final dayKey =
            '${l.timestamp.year}_${l.timestamp.month}_${l.timestamp.day}';
        int? matchedMinutes;
        if (l.topicId != null && l.topicId!.isNotEmpty) {
          matchedMinutes = sessionMinutesByTopic['${l.topicId}_$dayKey'];
        }
        if (matchedMinutes == null &&
            l.topicTitle != null &&
            l.topicTitle!.isNotEmpty) {
          matchedMinutes =
              sessionMinutesByTitle['${l.topicTitle!.trim().toLowerCase()}_$dayKey'];
        }
        if (matchedMinutes != null && matchedMinutes > 0) {
          logsById[entry.key] = l.copyWith(durationMinutes: matchedMinutes);
        }
      }
    }

    final merged = logsById.values.toList();
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged;
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _onDateSelected(DateTime date) {
    if (_isSameDay(_selectedDate, date)) return;
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
    _scrollToSelectedDate(true);
  }

  void _onSelectToday() {
    final now = DateTime.now();
    _onDateSelected(DateTime(now.year, now.month, now.day));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.surface(context),
              onSurface: AppTheme.textPrimaryColor(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _onDateSelected(picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToSelectedDate([bool animate = true]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dateStripController.hasClients) return;
      final days = _getCalendarDays();
      final index = days.indexWhere((d) => _isSameDay(d, _selectedDate));
      if (index == -1) return;

      final targetOffset = (index * 60.0) - (MediaQuery.sizeOf(context).width / 2) + 30.0;
      final clampedOffset = targetOffset.clamp(
        0.0,
        _dateStripController.position.maxScrollExtent,
      );

      if (animate) {
        _dateStripController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _dateStripController.jumpTo(clampedOffset);
      }
    });
  }

  List<DateTime> _getCalendarDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime start = today.subtract(const Duration(days: 30));
    if (_selectedDate.isBefore(start)) {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
    }
    final int count = today.difference(start).inDays + 1;
    return List<DateTime>.generate(count, (i) => start.add(Duration(days: i)));
  }

  Set<DateTime> _getActiveDates() {
    final Set<DateTime> dates = {};
    for (final a in _progressController.activitiesInRange) {
      if (a.hasActivity) {
        dates.add(DateTime(a.date.year, a.date.month, a.date.day));
      }
    }
    for (final l in _allLogs) {
      dates.add(DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day));
    }
    return dates;
  }

  List<StudyLog> _getLogsForSelectedDate() {
    return _allLogs.where((log) {
      return log.timestamp.year == _selectedDate.year &&
          log.timestamp.month == _selectedDate.month &&
          log.timestamp.day == _selectedDate.day;
    }).toList();
  }

  DayActivityItem _getActivityForSelectedDate() {
    final norm = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    DailyProgressActivity? act;
    for (final a in _progressController.activitiesInRange) {
      if (a.date.year == norm.year && a.date.month == norm.month && a.date.day == norm.day) {
        act = a;
        break;
      }
    }

    int topics = act?.topicsFinished ?? 0;
    int revisions = act?.revisionsDone ?? 0;
    int minutes = act?.studyMinutes ?? 0;

    // Cross-verify with logs on the selected date to ensure instant accuracy
    // Note: Strictly count unique topics and revision topics only (not module completions).
    final Set<String> topicIdsForDate = <String>{};
    final Set<String> revTopicIdsForDate = <String>{};
    int logMinutes = 0;
    for (final l in _allLogs) {
      final lNorm = DateTime(l.timestamp.year, l.timestamp.month, l.timestamp.day);
      if (lNorm == norm) {
        if (l.isTopicCompleted && l.topicId != null && l.topicId!.isNotEmpty) {
          topicIdsForDate.add(l.topicId!);
        }
        if (l.isRevisionTopicCompleted && l.topicId != null && l.topicId!.isNotEmpty) {
          revTopicIdsForDate.add(l.topicId!);
        }
        if (l.durationMinutes != null && l.durationMinutes! > 0) {
          logMinutes += l.durationMinutes!;
        }
      }
    }
    if (topicIdsForDate.length > topics) topics = topicIdsForDate.length;
    if (revTopicIdsForDate.length > revisions) revisions = revTopicIdsForDate.length;
    if (logMinutes > minutes) minutes = logMinutes;

    return DayActivityItem(
      date: norm,
      topicsFinished: topics,
      revisionsDone: revisions,
      studyMinutes: minutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final calendarDays = _getCalendarDays();
    final activeDates = _getActiveDates();
    final selectedLogs = _getLogsForSelectedDate();
    final selectedActivity = _getActivityForSelectedDate();

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Recent Activity',
              onBack: _handleBack,
            ),
            const VGapXs(),
            _CalendarDateStrip(
              scrollController: _dateStripController,
              days: calendarDays,
              selectedDate: _selectedDate,
              activeDates: activeDates,
              onSelectDate: _onDateSelected,
              onPickDate: _pickDate,
              onSelectToday: _onSelectToday,
            ),
            const VGapSm(),
            Expanded(
              child: _RecentActivityBody(
                isLoading: _isLoading,
                onRefresh: _loadData,
                selectedDate: _selectedDate,
                activity: selectedActivity,
                logs: selectedLogs,
                bottomPadding: bottomSafe + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// =============================================================================
// Calendar Date Strip
// =============================================================================
class _CalendarDateStrip extends StatelessWidget {
  final ScrollController scrollController;
  final List<DateTime> days;
  final DateTime selectedDate;
  final Set<DateTime> activeDates;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onPickDate;
  final VoidCallback onSelectToday;

  const _CalendarDateStrip({
    required this.scrollController,
    required this.days,
    required this.selectedDate,
    required this.activeDates,
    required this.onSelectDate,
    required this.onPickDate,
    required this.onSelectToday,
  });

  static final DateFormat _monthFormat = DateFormat('MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSelectedToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _monthFormat.format(selectedDate),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!isSelectedToday) ...[
                    const HGapSm(),
                    InkWell(
                      onTap: onSelectToday,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.pastelIndigo(context),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.pastelIndigoText(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Material(
                color: AppTheme.surface(context),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onPickDate,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VGapXs(),
        SizedBox(
          height: 68,
          child: ListView.separated(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            separatorBuilder: (_, __) => const HGapSm(),
            itemBuilder: (context, index) {
              final date = days[index];
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final isDateToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final hasActivity = activeDates.contains(date);

              return _DateStripPill(
                key: ValueKey(date.millisecondsSinceEpoch),
                date: date,
                isSelected: isSelected,
                isToday: isDateToday,
                hasActivity: hasActivity,
                onTap: () => onSelectDate(date),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateStripPill extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasActivity;
  final VoidCallback onTap;

  const _DateStripPill({
    super.key,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasActivity,
    required this.onTap,
  });

  static final DateFormat _weekdayFormat = DateFormat('EEE');

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? AppTheme.primaryColor
        : AppTheme.surface(context);
    final borderColor = isSelected
        ? Colors.transparent
        : (isToday
            ? AppTheme.primaryColor.withValues(alpha: 0.6)
            : AppTheme.borderColor(context));
    final textColor = isSelected
        ? Colors.white
        : (isToday ? AppTheme.primaryColor : AppTheme.textPrimaryColor(context));
    final subColor = isSelected
        ? Colors.white.withValues(alpha: 0.85)
        : AppTheme.textSecondaryColor(context);

    return RepaintBoundary(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isToday && !isSelected ? 1.5 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _weekdayFormat.format(date),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date.day.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              if (hasActivity)
                Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 4.5, width: 4.5),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Activity Body: Selected Date Summary & Logs List
// =============================================================================
class _RecentActivityBody extends StatelessWidget {
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final DateTime selectedDate;
  final DayActivityItem activity;
  final List<StudyLog> logs;
  final double bottomPadding;

  const _RecentActivityBody({
    required this.isLoading,
    required this.onRefresh,
    required this.selectedDate,
    required this.activity,
    required this.logs,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && logs.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        children: [
          _SelectedDateSummaryCard(
            date: selectedDate,
            activity: activity,
            logCount: logs.length,
          ),
          const VGapMd(),
          _LogsSectionHeader(
            selectedDate: selectedDate,
            logCount: logs.length,
          ),
          const VGapSm(),
          if (logs.isEmpty)
            _EmptyLogsPlaceholder(selectedDate: selectedDate)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: logs.length,
              separatorBuilder: (_, __) => const VGapSm(),
              itemBuilder: (context, index) {
                final log = logs[index];
                return _StudyLogListItem(
                  key: ValueKey(log.id),
                  log: log,
                );
              },
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Selected Date Summary Card
// =============================================================================
class _SelectedDateSummaryCard extends StatelessWidget {
  final DateTime date;
  final DayActivityItem activity;
  final int logCount;

  const _SelectedDateSummaryCard({
    required this.date,
    required this.activity,
    required this.logCount,
  });

  static final DateFormat _dateFormat = DateFormat('EEEE, d MMMM yyyy');

  static String _formatDurationDetailed(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Today' : _dateFormat.format(date),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isToday ? AppTheme.primaryColor : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  if (isToday)
                    Text(
                      _dateFormat.format(date),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${activity.topicsFinished} ${activity.topicsFinished == 1 ? 'topic' : 'topics'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const VGapSm(),
          Row(
            children: [
              _SummaryStatBadge(
                icon: Icons.menu_book_rounded,
                count: '${activity.topicsFinished}',
                label: 'Topics',
                bgColor: AppTheme.pastelGreen(context),
                iconColor: AppTheme.pastelGreenText(context),
              ),
              const HGapSm(),
              _SummaryStatBadge(
                icon: Icons.sync_rounded,
                count: '${activity.revisionsDone}',
                label: 'Revisions',
                bgColor: AppTheme.pastelPurple(context),
                iconColor: AppTheme.pastelPurpleText(context),
              ),
              const HGapSm(),
              _SummaryStatBadge(
                icon: Icons.schedule_rounded,
                count: _formatDurationDetailed(activity.studyMinutes),
                label: 'Time Spent',
                bgColor: AppTheme.pastelOrange(context),
                iconColor: AppTheme.pastelOrangeText(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStatBadge extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;
  final Color bgColor;
  final Color iconColor;

  const _SummaryStatBadge({
    required this.icon,
    required this.count,
    required this.label,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const HGapXs(),
                Flexible(
                  child: Text(
                    count,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: iconColor.withValues(alpha: 0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Logs Section Header
// =============================================================================
class _LogsSectionHeader extends StatelessWidget {
  final DateTime selectedDate;
  final int logCount;

  const _LogsSectionHeader({
    required this.selectedDate,
    required this.logCount,
  });

  static final DateFormat _shortDateFormat = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isToday ? 'Today\'s Study Logs' : 'Logs for ${_shortDateFormat.format(selectedDate)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        Text(
          '$logCount ${logCount == 1 ? 'entry' : 'entries'}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Empty Logs Placeholder
// =============================================================================
class _EmptyLogsPlaceholder extends StatelessWidget {
  final DateTime selectedDate;

  const _EmptyLogsPlaceholder({required this.selectedDate});

  static final DateFormat _shortDateFormat = DateFormat('d MMMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.pastelIndigo(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.pastelIndigoBorder(context)),
            ),
            child: Icon(
              Icons.event_note_rounded,
              size: 30,
              color: AppTheme.pastelIndigoText(context),
            ),
          ),
          const VGapMd(),
          Text(
            isToday ? 'No logs recorded today yet' : 'No study logs on ${_shortDateFormat.format(selectedDate)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapXs(),
          Text(
            'Complete topics or revisions to build your study trail.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Single Study Log List Item
// =============================================================================
class _StudyLogListItem extends StatelessWidget {
  final StudyLog log;

  const _StudyLogListItem({
    super.key,
    required this.log,
  });

  static final DateFormat _timeFormat = DateFormat('h:mm a');

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final bool isRevModule = log.isRevisionModuleCompleted;
    final bool isRevTopic = log.isRevisionTopicCompleted;
    final bool isModComplete = log.isModuleCompleted;
    final bool isSession = log.isStudySession;

    final String title;
    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    final String badgeLabel;
    final String breadcrumb;

    if (isModComplete) {
      title = log.moduleTitle.isNotEmpty ? log.moduleTitle : 'Module Completed';
      icon = Icons.layers_rounded;
      iconColor = AppTheme.pastelIndigoText(context);
      iconBg = AppTheme.pastelIndigo(context);
      badgeLabel = 'Module Done';
      breadcrumb = log.courseTitle.isNotEmpty
          ? '${log.courseTitle} • Module Completed'
          : 'Module Completed';
    } else if (isRevModule) {
      title = log.moduleTitle.isNotEmpty ? log.moduleTitle : 'Revision Module';
      icon = Icons.workspace_premium_rounded;
      iconColor = AppTheme.pastelPurpleText(context);
      iconBg = AppTheme.pastelPurple(context);
      badgeLabel = log.revisionLevel != null
          ? 'R${log.revisionLevel} Cleared'
          : 'Revision Cleared';
      breadcrumb = log.courseTitle.isNotEmpty
          ? '${log.courseTitle} • Revision Module'
          : 'Revision Cleared';
    } else if (isRevTopic) {
      title = (log.topicTitle != null && log.topicTitle!.isNotEmpty)
          ? log.topicTitle!
          : (log.moduleTitle.isNotEmpty ? log.moduleTitle : 'Revision Topic');
      icon = Icons.sync_rounded;
      iconColor = AppTheme.pastelPurpleText(context);
      iconBg = AppTheme.pastelPurple(context);
      badgeLabel = log.revisionLevel != null ? 'R${log.revisionLevel}' : 'Revision';
      breadcrumb = [log.courseTitle, log.moduleTitle]
          .where((s) => s.isNotEmpty)
          .join(' › ');
    } else if (isSession) {
      title = (log.topicTitle != null && log.topicTitle!.isNotEmpty)
          ? log.topicTitle!
          : (log.moduleTitle.isNotEmpty ? log.moduleTitle : 'Study Session');
      icon = Icons.timer_outlined;
      iconColor = AppTheme.pastelOrangeText(context);
      iconBg = AppTheme.pastelOrange(context);
      badgeLabel = 'Session';
      breadcrumb = [log.courseTitle, log.moduleTitle]
          .where((s) => s.isNotEmpty)
          .join(' › ');
    } else {
      // Individual topic completed
      title = (log.topicTitle != null && log.topicTitle!.isNotEmpty)
          ? log.topicTitle!
          : (log.moduleTitle.isNotEmpty ? log.moduleTitle : 'Topic Completed');
      icon = Icons.menu_book_rounded;
      iconColor = AppTheme.pastelGreenText(context);
      iconBg = AppTheme.pastelGreen(context);
      badgeLabel = 'Completed';
      breadcrumb = [log.courseTitle, log.moduleTitle]
          .where((s) => s.isNotEmpty)
          .join(' › ');
    }

    final int? minutes = (log.durationMinutes != null && log.durationMinutes! > 0)
        ? log.durationMinutes
        : null;
    final durationLabel = (minutes != null && minutes > 0) ? _formatDuration(minutes) : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (breadcrumb.isNotEmpty)
                  Text(
                    breadcrumb,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const HGapSm(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _timeFormat.format(log.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (minutes != null && minutes > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.pastelOrange(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: AppTheme.pastelOrangeText(context),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDuration(minutes),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.pastelOrangeText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const HGapXs(),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
