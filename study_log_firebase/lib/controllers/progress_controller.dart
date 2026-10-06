import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../models/study_log.dart';
import '../models/user_profile.dart';
import '../services/local_revision_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_user_profile_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';

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
  final int studyMinutes;

  const DailyProgressActivity({
    required this.date,
    required this.topicsFinished,
    required this.revisionsDone,
    this.studyMinutes = 0,
  });

  int get totalActivity => topicsFinished + revisionsDone;
  bool get hasActivity => totalActivity > 0 || studyMinutes > 0;

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
  int _totalActiveDays = 0;
  int _totalStudyMinutes = 0;
  UserProfile? _userProfile;

  final Map<DateTime, int> _dailyTopicsFinished = {};
  final Map<DateTime, int> _dailyRevisions = {};
  final Map<DateTime, int> _dailyStudyMinutes = {};

  List<DailyProgressActivity> _activitiesInRange = [];
  List<DailyProgressActivity> _recentActivities = [];

  bool get isLoading => _isLoading;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalActiveDays => _totalActiveDays;
  int get totalStudyMinutes => _totalStudyMinutes;
  double get totalStudyHours => _totalStudyMinutes / 60.0;
  DateTime? get mostActiveDay => _mostActiveDay;
  int get mostActiveDayCount => _mostActiveDayCount;
  int get totalTopicsFinished => _totalTopicsFinished;
  int get totalTopicRevisions => _totalTopicRevisions;
  UserProfile? get userProfile => _userProfile;
  String get userName => _userProfile?.name ?? 'Pradeep Maurya';
  String get userHeadline => _userProfile?.headline ?? 'Software Developer';
  String get userInitial => _userProfile?.initial ?? 'P';

  /// Compact study hours string (e.g. "0h", "1.5h", "12h").
  String get formattedStudyHours {
    if (_totalStudyMinutes <= 0) return '0h';
    final hours = _totalStudyMinutes / 60.0;
    if (hours < 1.0) {
      return '${_totalStudyMinutes}m';
    }
    if (hours == hours.truncateToDouble()) {
      return '${hours.toInt()}h';
    }
    return '${hours.toStringAsFixed(1)}h';
  }

  /// Detailed duration string (e.g. "45m", "2h", "2h 30m").
  String get formattedStudyDuration {
    if (_totalStudyMinutes <= 0) return '0h';
    final hours = _totalStudyMinutes ~/ 60;
    final mins = _totalStudyMinutes % 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  List<DailyProgressActivity> get activitiesInRange => List.unmodifiable(_activitiesInRange);
  List<DailyProgressActivity> get recentActivities => List.unmodifiable(_recentActivities);

  StreamSubscription<UserProfile?>? _profileSub;

  ProgressController() {
    _initProfileStream();
    load();
  }

  void _initProfileStream() {
    if (getIt.isRegistered<FirestoreService>()) {
      final fs = getIt<FirestoreService>();
      if (fs.isAvailable) {
        _profileSub = fs.streamUserProfile().listen((profile) {
          if (profile != null) {
            _userProfile = profile;
            if (_totalStudyMinutes == 0 && profile.totalStudyMinutes > 0) {
              _totalStudyMinutes = profile.totalStudyMinutes;
            }
            if (_currentStreak == 0 && profile.currentStreak > 0) {
              _currentStreak = profile.currentStreak;
            }
            if (_longestStreak == 0 && profile.longestStreak > 0) {
              _longestStreak = profile.longestStreak;
            }
            if (_totalActiveDays == 0 && profile.totalActiveDays > 0) {
              _totalActiveDays = profile.totalActiveDays;
            }
            notifyListeners();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  static DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> refresh() => load();

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 0. Fast local hydration: display cached user profile stats immediately without waiting
      final cachedProfile = await LocalUserProfileStorage.loadProfile();
      if (cachedProfile != null) {
        _userProfile = cachedProfile;
        if (_totalStudyMinutes == 0) _totalStudyMinutes = cachedProfile.totalStudyMinutes;
        if (_currentStreak == 0) _currentStreak = cachedProfile.currentStreak;
        if (_longestStreak == 0) _longestStreak = cachedProfile.longestStreak;
        if (_totalActiveDays == 0) _totalActiveDays = cachedProfile.totalActiveDays;
        notifyListeners();
      }

      final now = DateTime.now();
      final today = normalizeDate(now);
      final cutoffDate = today.subtract(const Duration(days: threeMonthsDays - 1));

      _dailyTopicsFinished.clear();
      _dailyRevisions.clear();
      _dailyStudyMinutes.clear();

      // Load all historical completion events for accurate all-time total active days and max streak
      final results = await Future.wait([
        LocalTopicStorage.loadCompletedTopicDatesSince(DateTime(2000)),
        LocalRevisionStorage.loadRevisionEventsSince(DateTime(2000)),
        LocalStudyLogStorage.loadAll(),
      ]);

      final completedTopicDates = results[0] as List<DateTime>;
      final recordedEvents = results[1] as List<DateTime>;
      final studyLogs = results[2] as List<StudyLog>;

      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable) {
          unawaited(firestore.syncAllLocalStudyLogsToFirestore());
        }
      }

      final Set<DateTime> allActiveDates = <DateTime>{};

      int finishedTopicsCount = 0;
      for (final date in completedTopicDates) {
        final norm = normalizeDate(date);
        if (!norm.isAfter(today)) {
          allActiveDates.add(norm);
          if (!norm.isBefore(cutoffDate)) {
            finishedTopicsCount++;
            _dailyTopicsFinished[norm] = (_dailyTopicsFinished[norm] ?? 0) + 1;
          }
        }
      }

      int revisionsCount = 0;
      for (final eventTime in recordedEvents) {
        final norm = normalizeDate(eventTime);
        if (!norm.isAfter(today)) {
          allActiveDates.add(norm);
          if (!norm.isBefore(cutoffDate)) {
            _dailyRevisions[norm] = (_dailyRevisions[norm] ?? 0) + 1;
            revisionsCount++;
          }
        }
      }

      // Also ensure all StudyLog entries are accounted for and sum session minutes
      int totalMinutes = 0;
      for (final log in studyLogs) {
        if (log.durationMinutes != null && log.durationMinutes! > 0) {
          totalMinutes += log.durationMinutes!;
        }
        final norm = normalizeDate(log.timestamp);
        if (norm.isAfter(today)) continue;
        allActiveDates.add(norm);
        if (!norm.isBefore(cutoffDate)) {
          if (log.durationMinutes != null && log.durationMinutes! > 0) {
            _dailyStudyMinutes[norm] = (_dailyStudyMinutes[norm] ?? 0) + log.durationMinutes!;
          }
          if (log.type == StudyLogType.revisionCompleted && recordedEvents.isEmpty) {
            _dailyRevisions[norm] = (_dailyRevisions[norm] ?? 0) + 1;
            revisionsCount++;
          } else if (log.type == StudyLogType.studySession) {
            _dailyTopicsFinished[norm] = (_dailyTopicsFinished[norm] ?? 0) + 1;
            finishedTopicsCount++;
          }
        }
      }
      _totalStudyMinutes = totalMinutes;

      // Fallback: If no dedicated revision event logs exist, inspect cached revisions lazily
      if (revisionsCount == 0) {
        final revisions = await LocalRevisionStorage.loadAll();
        for (final r in revisions) {
          final timesRevised = r.isFinished ? RevisionSchedule.maxLevel : (r.currentLevel - 1);
          if (timesRevised > 0) {
            final d = normalizeDate(r.lastRevisionAt ?? r.updatedAt);
            if (!d.isAfter(today)) {
              allActiveDates.add(d);
              if (!d.isBefore(cutoffDate)) {
                revisionsCount += timesRevised;
                _dailyRevisions[d] = (_dailyRevisions[d] ?? 0) + timesRevised;
              }
            }
          }
        }
      }
      _totalTopicsFinished = finishedTopicsCount;
      _totalTopicRevisions = revisionsCount;
      _totalActiveDays = allActiveDates.length;

      // Compute streaks and highlights across all active dates
      _computeStreaksAndHighlights(today, allActiveDates);

      // Sync or restore UserProfile document (profile details, streaks, total session hours)
      var profile = await LocalUserProfileStorage.loadProfile();
      if (profile == null && getIt.isRegistered<FirestoreService>()) {
        final fs = getIt<FirestoreService>();
        if (fs.isAvailable) {
          profile = await fs.getUserProfile();
        }
      }

      if (allActiveDates.isEmpty && _totalStudyMinutes == 0 && profile != null) {
        // Fresh install / data cleared: restore stats from cloud profile
        _currentStreak = profile.currentStreak;
        _longestStreak = profile.longestStreak;
        _totalActiveDays = profile.totalActiveDays;
        _totalStudyMinutes = profile.totalStudyMinutes;
        _totalTopicsFinished = profile.totalTopicsFinished;
        _totalTopicRevisions = profile.totalTopicRevisions;
        _userProfile = profile;
        unawaited(LocalUserProfileStorage.saveProfile(profile));
      } else {
        DateTime? lastActive;
        if (allActiveDates.isNotEmpty) {
          final sorted = allActiveDates.toList()..sort();
          lastActive = sorted.last;
        }

        final nowTime = DateTime.now();
        final updatedProfile = (profile ?? UserProfile(createdAt: nowTime, updatedAt: nowTime)).copyWith(
          currentStreak: _currentStreak,
          longestStreak: _longestStreak,
          totalActiveDays: _totalActiveDays,
          totalStudyMinutes: _totalStudyMinutes,
          totalTopicsFinished: _totalTopicsFinished,
          totalTopicRevisions: _totalTopicRevisions,
          lastActiveDate: lastActive,
          updatedAt: nowTime,
        );
        _userProfile = updatedProfile;

        unawaited(LocalUserProfileStorage.saveProfile(updatedProfile));
        if (getIt.isRegistered<FirestoreService>()) {
          final fs = getIt<FirestoreService>();
          if (fs.isAvailable) {
            unawaited(fs.saveUserProfile(updatedProfile));
          }
        }
      }

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
          studyMinutes: _dailyStudyMinutes[date] ?? 0,
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
      debugPrint('Error loading progress data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates user identity details (name, headline, email, avatarUrl) and saves locally & to Firestore.
  Future<void> updateProfileDetails({
    required String name,
    required String headline,
    String? email,
    String? avatarUrl,
  }) async {
    final nowTime = DateTime.now();
    final current = _userProfile ?? UserProfile(createdAt: nowTime, updatedAt: nowTime);
    final updated = current.copyWith(
      name: name,
      headline: headline,
      email: email,
      avatarUrl: avatarUrl,
      updatedAt: nowTime,
    );
    _userProfile = updated;
    notifyListeners();
    await LocalUserProfileStorage.saveProfile(updated);
    if (getIt.isRegistered<FirestoreService>()) {
      final fs = getIt<FirestoreService>();
      if (fs.isAvailable) {
        await fs.saveUserProfile(updated);
      }
    }
  }

  void _computeStreaksAndHighlights(DateTime today, Set<DateTime> allDates) {
    if (allDates.isEmpty) {
      _currentStreak = 0;
      _longestStreak = 0;
      _mostActiveDay = today;
      _mostActiveDayCount = 0;
      return;
    }

    // Most active day calculation (within recent range)
    DateTime? bestDay;
    int maxActivity = 0;

    final recentDates = _dailyTopicsFinished.keys.toSet()..addAll(_dailyRevisions.keys);
    for (final date in recentDates) {
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

    if (!allDates.contains(today)) {
      checkDate = today.subtract(const Duration(days: 1));
    }

    while (allDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    _currentStreak = streak;

    // Longest streak calculation across all historical active dates
    final sortedActiveDays = allDates.toList()..sort();

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
