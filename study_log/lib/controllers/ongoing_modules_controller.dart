import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/section.dart';
import '../services/local_section_storage.dart';
import '../services/local_subsection_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import 'courses_controller.dart';

enum SectionStudyStatus {
  running,
  upcoming,
  completed,
}

/// Represents an ongoing or upcoming section for study.
/// Guarantees that only valid Section entities are represented (never Course).
class OngoingSectionItem {
  final Course course;
  final Section section;
  final String title;
  final String breadcrumb;
  final String progressRatio;
  final double progress;
  final SectionStudyStatus status;

  const OngoingSectionItem({
    required this.course,
    required this.section,
    required this.title,
    required this.breadcrumb,
    required this.progressRatio,
    required this.progress,
    required this.status,
  });

  bool get isRunning => status == SectionStudyStatus.running;
  bool get isUpcoming => status == SectionStudyStatus.upcoming;
}

/// Rollup of a course's modules, derived from real topic completion.
class CourseModuleProgress {
  final String courseId;
  final int completedModules;
  final int totalModules;

  const CourseModuleProgress({
    required this.courseId,
    required this.completedModules,
    required this.totalModules,
  });

  bool get hasModules => totalModules > 0;

  /// A course counts as complete only when it has modules and all are done.
  bool get isComplete => hasModules && completedModules >= totalModules;

  double get ratio =>
      hasModules ? (completedModules / totalModules).clamp(0.0, 1.0) : 0.0;
}

/// Controller responsible for fetching and managing running and upcoming sections dynamically.
/// Completely free of static/hardcoded sections or subsections.
class OngoingSectionsController extends ChangeNotifier {
  final CoursesController _coursesController;
  final FirestoreService _firestoreService;

  List<OngoingSectionItem> _ongoingItems = [];
  final Map<String, int> _topicCounts = {};
  final Map<String, int> _completedTopicCounts = {};
  final Map<String, CourseModuleProgress> _courseProgress =
      <String, CourseModuleProgress>{};
  int _totalTopicCount = 0;
  int _completedTopicCount = 0;
  int _completedTodayCount = 0;
  int _dayStreak = 0;
  bool _isLoading = false;

  OngoingSectionsController({
    CoursesController? coursesController,
    FirestoreService? firestoreService,
  })  : _coursesController = coursesController ?? getIt<CoursesController>(),
        _firestoreService = firestoreService ?? getIt<FirestoreService>() {
    _coursesController.addListener(_onCoursesChanged);
    refresh();
  }

  List<OngoingSectionItem> get ongoingItems => List.unmodifiable(_ongoingItems);
  bool get isLoading => _isLoading;

  /// Real number of topics stored for a section, keyed by section id.
  int topicCountForSection(String sectionId) => _topicCounts[sectionId] ?? 0;

  /// Number of completed topics for a section, keyed by section id.
  int completedTopicCountForSection(String sectionId) =>
      _completedTopicCounts[sectionId] ?? 0;

  /// True when the section has at least one topic and every one is completed.
  bool isSectionComplete(String sectionId) {
    final total = _topicCounts[sectionId] ?? 0;
    if (total <= 0) return false;
    return (_completedTopicCounts[sectionId] ?? 0) >= total;
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
      // Filter out completed and archived courses
      final activeCourses = courses.where((c) {
        final st = c.status.toLowerCase();
        return st != 'completed' && st != 'archived';
      }).toList();

      // Read the topic cache once per refresh instead of once per section.
      final topicBuckets = await LocalSubsectionStorage.loadAllBuckets();

      final List<OngoingSectionItem> runningItems = [];
      final List<OngoingSectionItem> upcomingItems = [];
      final Map<String, int> topicCounts = <String, int>{};
      final Map<String, int> completedTopicCounts = <String, int>{};
      final Map<String, CourseModuleProgress> courseProgress =
          <String, CourseModuleProgress>{};
      final Set<DateTime> completionDays = <DateTime>{};
      int totalTopics = 0;
      int completedTopics = 0;
      int completedToday = 0;
      int courseTotalModules = 0;
      int courseCompletedModules = 0;

      for (final course in activeCourses) {
        // 1. Fetch cached sections from local disk
        List<Section> sections = await LocalSectionStorage.loadSections(course.id);

        // 2. Fallback to Firestore if local cache is empty
        if (sections.isEmpty && _firestoreService.isAvailable) {
          try {
            sections = await _firestoreService
                .streamSections(courseId: course.id)
                .first
                .timeout(const Duration(milliseconds: 1500), onTimeout: () => []);
          } catch (_) {
            sections = [];
          }
        }

        // 3. For each real section, compute its progress and status from actual subsections
        for (final section in sections) {
          final subsections = LocalSubsectionStorage.resolveForSection(
            topicBuckets,
            sectionId: section.id,
            fallbackTitle: section.title,
          );
          topicCounts[section.id] = subsections.length;
          int sectionCompleted = 0;
          totalTopics += subsections.length;
          for (final sub in subsections) {
            if (!sub.isCompleted) continue;
            sectionCompleted++;
            completedTopics++;
            final doneAt = sub.completedAt;
            if (doneAt == null) continue;
            completionDays.add(_dayOnly(doneAt));
            if (_isSameDay(doneAt, DateTime.now())) completedToday++;
          }
          final int completedCount;
          final int totalCount;
          final double progress;
          final SectionStudyStatus studyStatus;

          if (subsections.isNotEmpty) {
            completedTopicCounts[section.id] = sectionCompleted;
            completedCount = sectionCompleted;
            totalCount = subsections.length;
            progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

            if (completedCount == totalCount && totalCount > 0) {
              studyStatus = SectionStudyStatus.completed;
            } else if (completedCount > 0) {
              studyStatus = SectionStudyStatus.running;
            } else {
              studyStatus = SectionStudyStatus.upcoming;
            }
          } else {
            // Real section with no subsections added yet
            completedCount = 0;
            totalCount = 0;
            progress = 0.0;
            final st = section.status.toLowerCase();
            if (st == 'completed') {
              studyStatus = SectionStudyStatus.completed;
            } else if (st == 'in_progress' || st == 'active') {
              studyStatus = SectionStudyStatus.running;
            } else {
              studyStatus = SectionStudyStatus.upcoming;
            }
          }

          // Course-level rollup must happen before completed modules are skipped
          // below, otherwise a course whose modules are all done would report 0.
          courseTotalModules++;
          if (studyStatus == SectionStudyStatus.completed) {
            courseCompletedModules++;
          }

          // Exclude completed sections so user only sees running or upcoming sections
          if (studyStatus == SectionStudyStatus.completed) {
            continue;
          }

          final isRunning = studyStatus == SectionStudyStatus.running;
          final progressRatio = totalCount > 0
              ? '$completedCount / $totalCount subsections'
              : '0 subsections';

          final item = OngoingSectionItem(
            course: course,
            section: section,
            title: section.title,
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
        );
      }

      // Sort: Running sections first, then upcoming sections
      runningItems.sort((a, b) => a.section.orderIndex.compareTo(b.section.orderIndex));
      upcomingItems.sort((a, b) => a.section.orderIndex.compareTo(b.section.orderIndex));

      _ongoingItems = [...runningItems, ...upcomingItems];
      _topicCounts
        ..clear()
        ..addAll(topicCounts);
      _completedTopicCounts
        ..clear()
        ..addAll(completedTopicCounts);
      _courseProgress
        ..clear()
        ..addAll(courseProgress);
      _totalTopicCount = totalTopics;
      _completedTopicCount = completedTopics;
      _completedTodayCount = completedToday;
      _dayStreak = _computeStreak(completionDays);
    } catch (e) {
      debugPrint('Error fetching ongoing sections: $e');
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

  /// Deletes a section permanently from both local storage and Firestore.
  Future<void> deleteSection(OngoingSectionItem item) async {
    try {
      // 1. Remove from local sections for this course
      final cached = await LocalSectionStorage.loadSections(item.course.id);
      final updated = cached.where((s) => s.id != item.section.id && s.title != item.section.title).toList();
      await LocalSectionStorage.saveSectionsForCourse(item.course.id, updated);

      // 2. Remove from Firestore if available
      if (_firestoreService.isAvailable && item.section.id.isNotEmpty) {
        try {
          await _firestoreService.deleteSection(item.section.id);
        } catch (e) {
          debugPrint('Error deleting section from firestore: $e');
        }
      }

      // 3. Remove locally from _ongoingItems immediately for instant feedback
      _ongoingItems.removeWhere((i) => i.section.id == item.section.id && i.section.title == item.section.title);
      notifyListeners();

      // 4. Trigger full refresh
      await refresh();
    } catch (e) {
      debugPrint('Error deleting ongoing section: $e');
    }
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesChanged);
    super.dispose();
  }
}
