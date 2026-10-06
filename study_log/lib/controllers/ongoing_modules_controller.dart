import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../models/study_log.dart';
import '../services/local_course_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/database_service.dart';
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
  final double inProgressRatio;
  final ModuleStudyStatus status;

  const OngoingModuleItem({
    required this.course,
    required this.module,
    required this.title,
    required this.breadcrumb,
    required this.progressRatio,
    required this.progress,
    required this.inProgressRatio,
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
  final DatabaseService _dbService;

  List<OngoingModuleItem> _ongoingItems = [];
  final Map<String, int> _topicCounts = {};
  final Map<String, int> _completedTopicCounts = {};
  final Set<String> _completedModuleIds = {};
  final Map<String, CourseModuleProgress> _courseProgress =
      <String, CourseModuleProgress>{};
  final Map<String, Module> _modulesById = {};
  int _totalTopicCount = 0;
  int _completedTopicCount = 0;
  int _completedTodayCount = 0;
  int _dayStreak = 0;
  bool _isLoading = false;
  int _refreshSeq = 0;
  OngoingModulesController({
    CoursesController? coursesController,
    DatabaseService? dbService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _dbService = dbService ?? getIt<DatabaseService>() {
    _coursesController.addListener(_onCoursesChanged);
    refresh();
  }

  List<OngoingModuleItem> get ongoingItems => List.unmodifiable(_ongoingItems);
  bool get isLoading => _isLoading;

  /// Look up any cached module by its ID.
  Module? getModuleById(String moduleId) => _modulesById[moduleId];

  /// Look up module title by its ID.
  String moduleTitleFor(String moduleId) => _modulesById[moduleId]?.title ?? '';

  /// Look up module description by its ID.
  String moduleDescriptionFor(String moduleId) =>
      _modulesById[moduleId]?.description ?? '';

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
    final currentSeq = ++_refreshSeq;
    _isLoading = true;
    notifyListeners();

    try {
      List<Course> courses = _coursesController.courses;
      // Fallback: If CoursesController hasn't hydrated yet, read directly from local disk cache
      if (courses.isEmpty) {
        courses = await LocalCourseStorage.loadCourses();
      }
      // Filter out archived courses; completed courses are still tracked for
      // overall course completion, progress rollups, and statistics.
      final nonArchivedCourses = courses.where((c) {
        final st = c.status.toLowerCase();
        return st != 'archived';
      }).toList();

      // Read the topic cache once per refresh instead of once per module.
      final topicBuckets = await LocalTopicStorage.loadAllBuckets();

      // Read all cached modules in 1 pass from local disk
      final allCachedModules = await LocalModuleStorage.loadAllModules();
      final Map<String, List<Module>> modulesByCourse = {};
      _modulesById.clear();
      for (final m in allCachedModules) {
        modulesByCourse.putIfAbsent(m.courseId, () => []).add(m);
        if (m.id.isNotEmpty) _modulesById[m.id] = m;
      }

      // If any active courses are missing modules in cache, fetch them from SQLite database
      final missingCourses = nonArchivedCourses
          .where((c) => (modulesByCourse[c.id] ?? []).isEmpty)
          .toList();
      if (missingCourses.isNotEmpty) {
        await Future.wait(
          missingCourses.map((c) async {
            try {
              final fetched = await _dbService.getModules(courseId: c.id);
              if (fetched.isNotEmpty) {
                modulesByCourse[c.id] = fetched;
                for (final m in fetched) {
                  if (m.id.isNotEmpty) _modulesById[m.id] = m;
                }
                await LocalModuleStorage.saveModulesForCourse(c.id, fetched);
              }
            } catch (_) {}
          }),
        );
      }

      // Check which modules have no cached topics in local disk, and fetch from database
      final allModulesList = <Module>[];
      for (final course in nonArchivedCourses) {
        final mods = modulesByCourse[course.id] ?? [];
        allModulesList.addAll(mods);
        for (final m in mods) {
          if (m.id.isNotEmpty) _modulesById[m.id] = m;
        }
      }

      final modulesMissingTopics = allModulesList.where((m) {
        final local = LocalTopicStorage.resolveForModule(
          topicBuckets,
          moduleId: m.id,
          fallbackTitle: m.title,
        );
        return local.isEmpty && m.id.isNotEmpty;
      }).toList();

      if (modulesMissingTopics.isNotEmpty) {
        await Future.wait(
          modulesMissingTopics.map((m) async {
            try {
              final remoteTopics = await _dbService.getTopics(moduleId: m.id);
              if (remoteTopics.isNotEmpty) {
                topicBuckets[m.id] = remoteTopics;
                if (m.title.isNotEmpty) {
                  topicBuckets[m.title] = remoteTopics;
                }
                await LocalTopicStorage.saveTopics(m.id, remoteTopics);
              }
            } catch (_) {}
          }),
        );
      }

      final Set<String> revisionModuleIds = {};
      final cachedRevs = await LocalRevisionStorage.loadAll();
      for (final r in cachedRevs) {
        if (r.moduleId.isNotEmpty) revisionModuleIds.add(r.moduleId);
      }

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

        final List<Module> modules = modulesByCourse[course.id] ?? [];
        modules.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

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
          double inProgressRatio = 0.0;
          final ModuleStudyStatus studyStatus;

          if (topics.isNotEmpty) {
            completedTopicCounts[module.id] = moduleCompleted;
            completedCount = moduleCompleted;
            totalCount = topics.length;
            progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

            int moduleInProgress = 0;
            for (final sub in topics) {
              if (sub.status == TopicStatus.inProgress) moduleInProgress++;
            }
            inProgressRatio = totalCount > 0 ? (moduleInProgress / totalCount) : 0.0;

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

          final isMovedToRevision = revisionModuleIds.contains(module.id);

          // Exclude completed courses, OR completed modules (only in-progress or not-started belong here)
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
            breadcrumb: course.title,
            progressRatio: progressRatio,
            progress: progress,
            inProgressRatio: inProgressRatio,
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

      // Include study logs and revision completion events in streak tracking
      final studyLogs = await LocalStudyLogStorage.loadAll();
      for (final log in studyLogs) {
        completionDays.add(_dayOnly(log.timestamp));
        if (_isSameDay(log.timestamp, DateTime.now())) {
          completedToday++;
        }
      }

      final revisionEvents = await LocalRevisionStorage.loadRevisionEvents();
      for (final event in revisionEvents) {
        completionDays.add(_dayOnly(event));
        if (_isSameDay(event, DateTime.now())) {
          completedToday++;
        }
      }

      // Sort: Running modules first, then upcoming modules
      runningItems.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));
      upcomingItems.sort((a, b) => a.module.orderIndex.compareTo(b.module.orderIndex));

      if (currentSeq != _refreshSeq) {
        return;
      }

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
      if (currentSeq == _refreshSeq) {
        _isLoading = false;
        notifyListeners();
      }
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

  /// Deletes a module permanently from SQLite local database.
  Future<void> deleteModule(OngoingModuleItem item) async {
    try {
      // 1. Remove from local modules for this course
      final cached = await LocalModuleStorage.loadModules(item.course.id);
      final updated = cached.where((s) => s.id != item.module.id && s.title != item.module.title).toList();
      await LocalModuleStorage.saveModulesForCourse(item.course.id, updated);

      // 2. Remove from database if available
      if (item.module.id.isNotEmpty) {
        try {
          await _dbService.deleteModule(item.module.id);
        } catch (e) {
          debugPrint('Error deleting module from database: $e');
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
