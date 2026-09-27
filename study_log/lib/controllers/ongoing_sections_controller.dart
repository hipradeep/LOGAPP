import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/course.dart';
import '../models/section.dart';
import '../services/local_section_storage.dart';
import '../services/local_subsection_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../screens/section_detail_screen.dart';
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

/// Controller responsible for fetching and managing running and upcoming sections dynamically.
/// Completely free of static/hardcoded sections or subsections.
class OngoingSectionsController extends ChangeNotifier {
  final CoursesController _coursesController;
  final FirestoreService _firestoreService;

  List<OngoingSectionItem> _ongoingItems = [];
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

      final List<OngoingSectionItem> runningItems = [];
      final List<OngoingSectionItem> upcomingItems = [];

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
          final subsections = await LocalSubsectionStorage.loadSubsections(section.title);
          final int completedCount;
          final int totalCount;
          final double progress;
          final SectionStudyStatus studyStatus;

          if (subsections.isNotEmpty) {
            completedCount = subsections.where((s) => s.status == SubsectionStatus.completed).length;
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
      }

      // Sort: Running sections first, then upcoming sections
      runningItems.sort((a, b) => a.section.orderIndex.compareTo(b.section.orderIndex));
      upcomingItems.sort((a, b) => a.section.orderIndex.compareTo(b.section.orderIndex));

      _ongoingItems = [...runningItems, ...upcomingItems];
    } catch (e) {
      debugPrint('Error fetching ongoing sections: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
