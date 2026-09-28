import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../services/local_revision_storage.dart';
import '../services/local_topic_storage.dart';

/// Activity level for strike heatmap visualization.
enum StrikeActivityLevel {
  none,
  low,
  medium,
  high,
  mostActive,
}

/// Represents the daily progress activity combined from topics completed and topic revisions.
class DailyProgressActivity {
  final DateTime date;
  final int topicsFinished;
  final int revisionsDone;

  const DailyProgressActivity({
    required this.date,
    required this.topicsFinished,
    required this.revisionsDone,
  });

  int get totalActivity => topicsFinished + revisionsDone;
  bool get hasActivity => totalActivity > 0;

  StrikeActivityLevel activityLevel(int maxActivity) {
    if (totalActivity <= 0) return StrikeActivityLevel.none;
    if (totalActivity >= maxActivity && maxActivity >= 4) {
      return StrikeActivityLevel.mostActive;
    }
    if (totalActivity >= 10) return StrikeActivityLevel.mostActive;
    if (totalActivity >= 6) return StrikeActivityLevel.high;
    if (totalActivity >= 3) return StrikeActivityLevel.medium;
    return StrikeActivityLevel.low;
  }
}

/// Controller powering the My Progress screen:
/// - Strictly aggregates 3 months (90 days) of strike activity.
/// - Parallelizes disk reads across topic buckets and revision caches.
/// - Filters data within the 90-day window for maximum query speed and minimal memory footprint.
class ProgressController extends ChangeNotifier {
  static const int threeMonthsDays = 90;

  bool _isLoading = true;

  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _mostActiveDay;
  int _mostActiveDayCount = 0;

  int _totalTopicsFinished = 0;
  int _totalTopicRevisions = 0;

  final Map<DateTime, int> _dailyTopicsFinished = {};
  final Map<DateTime, int> _dailyRevisions = {};

  List<DailyProgressActivity> _activitiesInRange = [];
  List<DailyProgressActivity> _recentActivities = [];

  bool get isLoading => _isLoading;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  DateTime? get mostActiveDay => _mostActiveDay;
  int get mostActiveDayCount => _mostActiveDayCount;
  int get totalTopicsFinished => _totalTopicsFinished;
  int get totalTopicRevisions => _totalTopicRevisions;
  List<DailyProgressActivity> get activitiesInRange => List.unmodifiable(_activitiesInRange);
  List<DailyProgressActivity> get recentActivities => List.unmodifiable(_recentActivities);

  ProgressController() {
    load();
  }

  static DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> refresh() => load();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final today = normalizeDate(now);
      final cutoffDate = today.subtract(const Duration(days: threeMonthsDays - 1));

      _dailyTopicsFinished.clear();
      _dailyRevisions.clear();

      // Fast-path parallelized queries directly bounded to the 3-month window
      final results = await Future.wait([
        LocalTopicStorage.loadCompletedTopicDatesSince(cutoffDate),
        LocalRevisionStorage.loadRevisionEventsSince(cutoffDate),
      ]);

      final completedTopicDates = results[0];
      final recordedEvents = results[1];

      int finishedTopicsCount = 0;
      for (final date in completedTopicDates) {
        final norm = normalizeDate(date);
        if (!norm.isAfter(today)) {
          finishedTopicsCount++;
          _dailyTopicsFinished[norm] = (_dailyTopicsFinished[norm] ?? 0) + 1;
        }
      }
      _totalTopicsFinished = finishedTopicsCount;

      int revisionsCount = 0;
      for (final eventTime in recordedEvents) {
        final norm = normalizeDate(eventTime);
        if (!norm.isAfter(today)) {
          _dailyRevisions[norm] = (_dailyRevisions[norm] ?? 0) + 1;
          revisionsCount++;
        }
      }

      // Fallback: If no dedicated revision event logs exist, inspect cached revisions lazily
      if (revisionsCount == 0) {
        final revisions = await LocalRevisionStorage.loadAll();
        for (final r in revisions) {
          final timesRevised = r.isFinished ? RevisionSchedule.maxLevel : (r.currentLevel - 1);
          if (timesRevised > 0) {
            final d = normalizeDate(r.lastRevisionAt ?? r.updatedAt);
            if (!d.isBefore(cutoffDate) && !d.isAfter(today)) {
              revisionsCount += timesRevised;
              _dailyRevisions[d] = (_dailyRevisions[d] ?? 0) + timesRevised;
            }
          }
        }
      }
      _totalTopicRevisions = revisionsCount;

      // Compute streaks and highlights across the 3-month period
      _computeStreaksAndHighlights(today);

      // Generate 3-month daily activities (90 days exactly)
      final List<DailyProgressActivity> items = [];
      final List<DailyProgressActivity> recents = [];

      for (int i = threeMonthsDays - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final topics = _dailyTopicsFinished[date] ?? 0;
        final revisions = _dailyRevisions[date] ?? 0;

        final activity = DailyProgressActivity(
          date: date,
          topicsFinished: topics,
          revisionsDone: revisions,
        );
        items.add(activity);

        if (activity.hasActivity) {
          recents.add(activity);
        }
      }

      _activitiesInRange = items;

      // Recent activity list: newest first
      recents.sort((a, b) => b.date.compareTo(a.date));
      _recentActivities = recents;
    } catch (e) {
      debugPrint('Error loading 3-month progress data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _computeStreaksAndHighlights(DateTime today) {
    final allDates = <DateTime>{
      ..._dailyTopicsFinished.keys,
      ..._dailyRevisions.keys,
    };

    if (allDates.isEmpty) {
      _currentStreak = 0;
      _longestStreak = 0;
      _mostActiveDay = today;
      _mostActiveDayCount = 0;
      return;
    }

    // Most active day calculation
    DateTime? bestDay;
    int maxActivity = 0;

    for (final date in allDates) {
      final topics = _dailyTopicsFinished[date] ?? 0;
      final revisions = _dailyRevisions[date] ?? 0;
      final total = topics + revisions;
      if (total > maxActivity) {
        maxActivity = total;
        bestDay = date;
      }
    }

    _mostActiveDay = bestDay ?? today;
    _mostActiveDayCount = maxActivity;

    // Current streak calculation
    int streak = 0;
    DateTime checkDate = today;

    final todayActivity = (_dailyTopicsFinished[today] ?? 0) + (_dailyRevisions[today] ?? 0);
    if (todayActivity == 0) {
      checkDate = today.subtract(const Duration(days: 1));
    }

    while (true) {
      final act = (_dailyTopicsFinished[checkDate] ?? 0) + (_dailyRevisions[checkDate] ?? 0);
      if (act > 0) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    _currentStreak = streak;

    // Longest streak calculation
    final sortedActiveDays = allDates.where((d) {
      return ((_dailyTopicsFinished[d] ?? 0) + (_dailyRevisions[d] ?? 0)) > 0;
    }).toList()
      ..sort();

    int longest = 0;
    int currentRun = 0;
    DateTime? prevDate;

    for (final date in sortedActiveDays) {
      if (prevDate == null) {
        currentRun = 1;
      } else {
        final diff = date.difference(prevDate).inDays;
        if (diff == 1) {
          currentRun++;
        } else if (diff > 1) {
          currentRun = 1;
        }
      }
      if (currentRun > longest) {
        longest = currentRun;
      }
      prevDate = date;
    }

    _longestStreak = longest > _currentStreak ? longest : _currentStreak;
  }
}
