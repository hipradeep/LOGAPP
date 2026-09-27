import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../services/local_module_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';

enum ModuleStudyStatus {
  running,
  upcoming,
  completed,
}

/// Represents an ongoing or upcoming module for study.
/// Guarantees that only valid Module entities are represented (never Course).
class OngoingModuleItem {
  final Course course;
  final Module module;
  final String title;
  final String breadcrumb;
  final String progressRatio;
  final double progress;
  final ModuleStudyStatus status;

  const OngoingModuleItem({
    required this.course,
    required this.module,
    required this.title,
    required this.breadcrumb,
    required this.progressRatio,
    required this.progress,
    required this.status,
  });

  bool get isRunning => status == ModuleStudyStatus.running;
  bool get isUpcoming => status == ModuleStudyStatus.upcoming;
}

/// Rollup of a course's modules, derived from real topic completion.
class CourseModuleProgress {
  final String courseId;
  final int completedModules;
  final int totalModules;
  final bool isCourseMarkedComplete;

  const CourseModuleProgress({
    required this.courseId,
    required this.completedModules,
    required this.totalModules,
    this.isCourseMarkedComplete = false,
  });

  bool get hasModules => totalModules > 0;

  /// A course counts as complete when marked complete OR when it has modules and all are done.
  bool get isComplete =>
      isCourseMarkedComplete || (hasModules && completedModules >= totalModules);

  double get ratio {
    if (isComplete) return 1.0;
    return hasModules ? (completedModules / totalModules).clamp(0.0, 1.0) : 0.0;
  }
}

/// Controller responsible for fetching and managing running and upcoming modules dynamically.
/// Completely free of static/hardcoded modules or topics.
class OngoingModulesController extends ChangeNotifier {
  final CoursesController _coursesController;
  final FirestoreService _firestoreService;

  List<OngoingModuleItem> _ongoingItems = [];
  final Map<String, int> _topicCounts = {};
  final Map<String, int> _completedTopicCounts = {};
  final Set<String> _completedModuleIds = {};
  final Map<String, CourseModuleProgress> _courseProgress =
      <String, CourseModuleProgress>{};
  int _totalTopicCount = 0;
  int _completedTopicCount = 0;
  int _completedTodayCount = 0;
  int _dayStreak = 0;
  bool _isLoading = false;

  OngoingModulesController({
    CoursesController? coursesController,
    FirestoreService? firestoreService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _coursesController.addListener(_onCoursesChanged);
    refresh();
  }

  List<OngoingModuleItem> get ongoingItems => List.unmodifiable(_ongoingItems);
  bool get isLoading => _isLoading;

  /// Real number of topics stored for a module, keyed by module id.
  int topicCountForModule(String moduleId) => _topicCounts[moduleId] ?? 0;

  /// Number of completed topics for a module, keyed by module id.
  int completedTopicCountForModule(String moduleId) =>
      _completedTopicCounts[moduleId] ?? 0;

  /// True when the module has at least one topic and every one is completed,
  /// or when it was marked complete.
  bool isModuleComplete(String moduleId) {
    if (_completedModuleIds.contains(moduleId)) return true;
    final total = _topicCounts[moduleId] ?? 0;
    if (total <= 0) return false;
    return (_completedTopicCounts[moduleId] ?? 0) >= total;
  }

  /// Module-level rollup for a course, or null when the course has no modules.
  CourseModuleProgress? progressForCourse(String courseId) => _courseProgress[courseId];

  /// Topics completed today across all active courses.
  int get completedTodayCount => _completedTodayCount;

  /// Topics still awaiting completion (candidates for revision).
  int get pendingTopicCount {
    final pending = _totalTopicCount - _completedTopicCount;
    return pending < 0 ? 0 : pending;
  }

  /// Topics completed across all active courses.
  int get completedTopicCount => _completedTopicCount;

  /// Total topics across all active courses.
  int get totalTopicCount => _totalTopicCount;

  /// Consecutive days (ending today or yesterday) with at least one completion.
  int get dayStreakCount => _dayStreak;

  /// Overall completion ratio across all active courses, 0.0 - 1.0.
  double get goalProgress =>
      _totalTopicCount > 0 ? _completedTopicCount / _totalTopicCount : 0.0;

  void _onCoursesChanged() {
    refresh();
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final courses = _coursesController.courses;
      // Filter out archived courses; completed courses are still tracked for
      // overall course completion, progress rollups, and statistics.
      final nonArchivedCourses = courses.where((c) {
        final st = c.status.toLowerCase();
        return st != 'archived';
      }).toList();

      // Read the topic cache once per refresh instead of once per module.
      final topicBuckets = await LocalTopicStorage.loadAllBuckets();

      final List<OngoingModuleItem> runningItems = [];
      final List<OngoingModuleItem> upcomingItems = [];
      final Map<String, int> topicCounts = <String, int>{};
      final Map<String, int> completedTopicCounts = <String, int>{};
      final Set<String> completedModuleIds = <String>{};
      final Map<String, CourseModuleProgress> courseProgress =
          <String, CourseModuleProgress>{};
      final Set<DateTime> completionDays = <DateTime>{};
      int totalTopics = 0;
      int completedTopics = 0;
      int completedToday = 0;

      for (final course in nonArchivedCourses) {
        int courseTotalModules = 0;
        int courseCompletedModules = 0;
        final bool isCourseMarkedComplete =
            course.status.toLowerCase() == 'completed';

        // 1. Fetch cached modules from local disk
        List<Module> modules = await LocalModuleStorage.loadModules(course.id);

        // 2. Fallback to Firestore if local cache is empty
        if (modules.isEmpty && _firestoreService.isAvailable) {
          try {
            modules = await _firestoreService
                .streamModules(courseId: course.id)
                .first
                .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
            if (modules.isNotEmpty) {
              await LocalModuleStorage.saveModulesForCourse(course.id, modules);
            }
          } catch (_) {
            modules = [];
          }
        }

        // 3. For each real module, compute its progress and status from actual topics
        for (final module in modules) {
          final topics = LocalTopicStorage.resolveForModule(
            topicBuckets,
            moduleId: module.id,
            fallbackTitle: module.title,
          );
          topicCounts[module.id] = topics.length;
          int moduleCompleted = 0;
          totalTopics += topics.length;
          for (final sub in topics) {
            if (!sub.isCompleted) continue;
            moduleCompleted++;
            completedTopics++;
            final doneAt = sub.completedAt;
            if (doneAt == null) continue;
            completionDays.add(_dayOnly(doneAt));
            if (_isSameDay(doneAt, DateTime.now())) completedToday++;
          }
          final int completedCount;
          final int totalCount;
          final double progress;
          final ModuleStudyStatus studyStatus;

          if (topics.isNotEmpty) {
            completedTopicCounts[module.id] = moduleCompleted;
            completedCount = moduleCompleted;
            totalCount = topics.length;
            progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

            if (completedCount == totalCount && totalCount > 0) {
              studyStatus = ModuleStudyStatus.completed;
            } else if (completedCount > 0) {
              studyStatus = ModuleStudyStatus.running;
            } else {
              studyStatus = ModuleStudyStatus.upcoming;
            }
          } else {
            // Real module with no topics added yet
            completedCount = 0;
            totalCount = 0;
            progress = 0.0;
            final st = module.status.toLowerCase();
            if (st == 'completed') {
              studyStatus = ModuleStudyStatus.completed;
            } else if (st == 'in_progress' || st == 'active') {
              studyStatus = ModuleStudyStatus.running;
            } else {
              studyStatus = ModuleStudyStatus.upcoming;
            }
          }

          if (studyStatus == ModuleStudyStatus.completed) {
            completedModuleIds.add(module.id);
          }

          // Course-level rollup must happen before completed modules are skipped
          // below, otherwise a course whose modules are all done would report 0.
          courseTotalModules++;
          if (studyStatus == ModuleStudyStatus.completed) {
            courseCompletedModules++;
          }

          // Exclude completed courses and completed modules from ongoing study items
          if (isCourseMarkedComplete || studyStatus == ModuleStudyStatus.completed) {
            continue;
          }

          final isRunning = studyStatus == ModuleStudyStatus.running;
          final progressRatio = totalCount > 0
              ? '$completedCount / $totalCount topics'
              : '0 topics';

          final item = OngoingModuleItem(
            course: course,
            module: module,
            title: module.title,
            breadcrumb: '${course.title} • ${isRunning ? 'Running' : 'Upcoming'}',
            progressRatio: progressRatio,
            progress: progress,
            status: studyStatus,
          );

          if (isRunning) {
            runningItems.add(item);
          } else {
            upcomingItems.add(item);
          }
        }

        courseProgress[course.id] = CourseModuleProgress(
          courseId: course.id,
          completedModules: courseCompletedModules,
          totalModules: courseTotalModules,
          isCourseMarkedComplete: isCourseMarkedComplete,
        );
      }

      // Sort: Running modules first, then upcoming modules
      runningItems.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));
      upcomingItems.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));

      _ongoingItems = [...runningItems, ...upcomingItems];
      _topicCounts
        ..clear()
        ..addAll(topicCounts);
      _completedTopicCounts
        ..clear()
        ..addAll(completedTopicCounts);
      _completedModuleIds
        ..clear()
        ..addAll(completedModuleIds);
      _courseProgress
        ..clear()
        ..addAll(courseProgress);
      _totalTopicCount = totalTopics;
      _completedTopicCount = completedTopics;
      _completedTodayCount = completedToday;
      _dayStreak = _computeStreak(completionDays);
    } catch (e) {
      debugPrint('Error fetching ongoing modules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Subtracts exactly one calendar day, DST-safe (Dart normalises out-of-range days).
  static DateTime _previousDay(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Counts consecutive active days, allowing the streak to still be alive
  /// if the last completion was yesterday.
  static int _computeStreak(Set<DateTime> activeDays) {
    if (activeDays.isEmpty) return 0;

    final today = _dayOnly(DateTime.now());
    final sorted = activeDays.toList()..sort((a, b) => b.compareTo(a));

    var cursor = sorted.first;
    if (cursor != today && cursor != _previousDay(today)) {
      return 0;
    }

    var streak = 1;
    for (final day in sorted.skip(1)) {
      final expected = _previousDay(cursor);
      if (day == expected) {
        streak++;
        cursor = day;
      } else if (day.isAfter(expected)) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Deletes a module permanently from both local storage and Firestore.
  Future<void> deleteModule(OngoingModuleItem item) async {
    try {
      // 1. Remove from local modules for this course
      final cached = await LocalModuleStorage.loadModules(item.course.id);
      final updated = cached.where((s) => s.id != item.module.id && s.title != item.module.title).toList();
      await LocalModuleStorage.saveModulesForCourse(item.course.id, updated);

      // 2. Remove from Firestore if available
      if (_firestoreService.isAvailable && item.module.id.isNotEmpty) {
        try {
          await _firestoreService.deleteModule(item.module.id);
        } catch (e) {
          debugPrint('Error deleting module from firestore: $e');
        }
      }

      // 3. Remove locally from _ongoingItems immediately for instant feedback
      _ongoingItems.removeWhere((i) => i.module.id == item.module.id && i.module.title == item.module.title);
      notifyListeners();

      // 4. Trigger full refresh
      await refresh();
    } catch (e) {
      debugPrint('Error deleting ongoing module: $e');
    }
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesChanged);
    super.dispose();
  }
}
