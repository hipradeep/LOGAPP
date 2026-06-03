import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/app_spacers.dart';
import '../widgets/app_icons.dart';
import '../widgets/glow_blob.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/activity_check_in_sheet.dart';

import '../models/log_entry.dart';
import '../models/activity.dart';
import '../models/check_in.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _useMockData = false;
  
  late Stream<List<Activity>> _checkedActivitiesStream;
  late Stream<List<CheckIn>> _checkInsStream;

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
    _useMockData = Firebase.apps.isEmpty;
    _initStreams();
  }

  void _initStreams() {
    _checkedActivitiesStream = _firebaseService.getCheckedActivitiesStream();
    _checkInsStream = _firebaseService.getCheckedActivitiesCheckInsStream();
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
          // Subheader indicating date and connection status
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
                GestureDetector(
                  onTap: () {
                    if (Firebase.apps.isNotEmpty) {
                      setState(() {
                        _useMockData = !_useMockData;
                        _initStreams();
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_useMockData 
                              ? 'Switched to local offline simulator mode.' 
                              : 'Switched to Firebase live stream mode.'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Firebase is not initialized. Locked in offline simulator mode.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _useMockData 
                          ? AppTheme.warningColor.withOpacity(0.15) 
                          : AppTheme.successColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _useMockData 
                            ? AppTheme.warningColor.withOpacity(0.4) 
                            : AppTheme.successColor.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const HGapSm(),
                        Text(
                          _useMockData ? 'OFFLINE' : 'LIVE',
                          style: TextStyle(
                            color: _useMockData ? AppTheme.warningColor : AppTheme.successColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
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
                  
                  // Classify activities into pending and completed today
                  final List<Activity> pendingActivities = [];
                  final List<Activity> completedActivities = [];
                  
                  for (var activity in checkedActivities) {
                    final activityCheckIns = checkIns
                        .where((c) => c.activityId == activity.id && _isToday(c.timestamp) && c.checked)
                        .toList();
                    final todayCount = activityCheckIns.length;
                    final target = activity.targetCount;
                    final bool isCompleted = activity.trackingType == 'multiple'
                        ? todayCount >= target
                        : todayCount >= 1;
                        
                    if (isCompleted) {
                      completedActivities.add(activity);
                    } else {
                      pendingActivities.add(activity);
                    }
                  }
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCheckedActivitiesList(pendingActivities, isCompletedList: false),
                      if (completedActivities.isNotEmpty) ...[
                        const VGapSm(),
                        _buildCheckedActivitiesList(completedActivities, isCompletedList: true),
                      ],
                      const VGapSm(),
                      _buildDailySummaryCard(checkedActivities, checkIns),
                      const VGapSm(),
                      _buildWeeklyCalendarCard(checkedActivities, checkIns),
                    ],
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

  Widget _buildCheckedActivitiesList(List<Activity> activities, {required bool isCompletedList}) {
    if (activities.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompletedList 
            ? AppTheme.successColor.withOpacity(0.04)
            : AppTheme.surfaceColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isCompletedList
              ? AppTheme.successColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.02),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompletedList ? Icons.check_circle_rounded : Icons.star_rounded, 
                color: isCompletedList ? AppTheme.successColor : Colors.amber, 
                size: 16,
              ),
              const HGapSm(),
              Text(
                (isCompletedList ? 'Completed Today' : 'Active Activities').toUpperCase(),
                style: AppTheme.bodySmall.copyWith(
                  color: isCompletedList ? AppTheme.successColor : AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const VGapSm(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activities.map((activity) {
              return _DashboardActivityChip(
                activity: activity,
                useMockData: _useMockData,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ActivityCheckInSheet(
                      activity: activity,
                      useMockData: _useMockData,
                    ),
                  ).then((_) {
                    // Refresh dashboard state when bottom sheet is dismissed
                    setState(() {});
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
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
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
                        color: AppTheme.surfaceColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
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

  // QUICK MOOD LOGGING ACTION
  void _handleQuickMood(String emoji, String label) async {
    if (_useMockData) {
      setState(() {
        FirebaseService.mockEntries.insert(
          0,
          LogEntry(
            id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
            title: 'Feeling $label',
            content: 'Logged a quick check-in.',
            timestamp: DateTime.now(),
            mood: emoji,
            tags: ['QuickCheck'],
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quick check-in logged locally: Feeling $label $emoji'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      FirebaseService.notifyLogsChanged();
    } else {
      try {
        await _firebaseService.createEntry(
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
  }

  Widget _buildDailySummaryCard(List<Activity> activities, List<CheckIn> checkIns) {
    if (activities.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
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
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    int completedHabits = 0;
    final totalHabits = activities.length;

    for (var activity in activities) {
      final activityCheckIns = checkIns
          .where((c) => c.activityId == activity.id && _isToday(c.timestamp) && c.checked)
          .toList();
      final todayCount = activityCheckIns.length;
      final target = activity.targetCount;
      if (activity.trackingType == 'multiple') {
        if (todayCount >= target) {
          completedHabits++;
        }
      } else {
        if (todayCount >= 1) {
          completedHabits++;
        }
      }
    }

    final double completionRate = totalHabits > 0 ? completedHabits / totalHabits : 0.0;
    
    String motivationalMessage = 'Start your day by checking in to an activity!';
    if (completionRate > 0 && completionRate < 0.5) {
      motivationalMessage = 'Off to a good start! Keep it going!';
    } else if (completionRate >= 0.5 && completionRate < 1.0) {
      motivationalMessage = 'More than halfway there! Almost done!';
    } else if (completionRate == 1.0) {
      motivationalMessage = 'Perfect day! You\'ve completed all active habits! 🎉';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
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
                  '$completedHabits of $totalHabits Completed',
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
                  backgroundColor: Colors.white.withOpacity(0.05),
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

  Widget _buildWeeklyCalendarCard(List<Activity> activities, List<CheckIn> checkIns) {
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
        color: AppTheme.surfaceColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
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
                final activityCheckIns = checkIns
                    .where((c) =>
                        c.activityId == activity.id &&
                        _isSameDay(c.timestamp, day) &&
                        c.checked)
                    .toList();
                final todayCount = activityCheckIns.length;
                final target = activity.targetCount;
                final bool isDone = activity.trackingType == 'multiple'
                    ? todayCount >= target
                    : todayCount >= 1;
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
        : (progress > 0 ? AppTheme.primaryColor : Colors.white.withOpacity(0.1));

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
                      color: AppTheme.primaryColor.withOpacity(0.35),
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
                      ? Colors.white.withOpacity(0.03)
                      : Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              Text(
                date,
                style: AppTheme.bodySmall.copyWith(
                  color: isToday
                      ? Colors.white
                      : (isFuture
                          ? AppTheme.textSecondary.withOpacity(0.4)
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
                      color: AppTheme.primaryColor.withOpacity(0.5),
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

class _DashboardActivityChip extends StatefulWidget {
  final Activity activity;
  final bool useMockData;
  final VoidCallback onTap;

  const _DashboardActivityChip({
    Key? key,
    required this.activity,
    required this.useMockData,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_DashboardActivityChip> createState() => _DashboardActivityChipState();
}

class _DashboardActivityChipState extends State<_DashboardActivityChip> {
  final FirebaseService _firebaseService = FirebaseService();
  late Stream<List<CheckIn>> _checkInsStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant _DashboardActivityChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id || oldWidget.useMockData != widget.useMockData) {
      _initStream();
    }
  }

  void _initStream() {
    _checkInsStream = _firebaseService.getCheckInsStream(widget.activity.id);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMockData) {
      final checkIns = FirebaseService.mockCheckIns
          .where((c) => c.activityId == widget.activity.id && _isToday(c.timestamp) && c.checked)
          .toList();
      return _buildChip(checkIns.length);
    } else {
      return StreamBuilder<List<CheckIn>>(
        stream: _checkInsStream,
        builder: (context, snapshot) {
          final checkIns = snapshot.data ?? [];
          final todayCount = checkIns.where((c) => _isToday(c.timestamp) && c.checked).length;
          return _buildChip(todayCount);
        },
      );
    }
  }

  Widget _buildChip(int todayCount) {
    final targetCount = widget.activity.targetCount;
    final isMultiple = widget.activity.trackingType == 'multiple';
    final isCompleted = isMultiple ? todayCount >= targetCount : todayCount >= 1;
    final double progress = isMultiple
        ? (targetCount > 0 ? (todayCount / targetCount).clamp(0.0, 1.0) : 0.0)
        : (todayCount >= 1 ? 1.0 : 0.0);

    final Color accentColor = isCompleted ? AppTheme.successColor : AppTheme.primaryColor;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withOpacity(isCompleted ? 0.3 : 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(isCompleted ? 0.15 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini circular progress ring
            SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                  if (isCompleted)
                    Icon(
                      Icons.check_rounded,
                      color: accentColor,
                      size: 12,
                    )
                  else
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Activity name
            Text(
              widget.activity.name,
              style: AppTheme.bodySmall.copyWith(
                color: isCompleted
                    ? AppTheme.successColor.withOpacity(0.9)
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            // Count badge for multi-target activities
            if (isMultiple) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$todayCount/$targetCount',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
