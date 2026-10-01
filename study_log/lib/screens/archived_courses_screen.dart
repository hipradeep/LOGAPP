import 'package:flutter/material.dart';
import '../controllers/courses_controller.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/topic.dart';
import '../services/firestore_service.dart';
import '../services/local_module_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/study_confirmation_dialog.dart';

/// Screen displaying archived courses with:
/// - Horizontal course selector when multiple archived courses exist
/// - Custom header below app bar showing course completion details (progress, ratio, stats)
/// - Single page showing nested list of modules and their child topics
/// - Restore / Unarchive and Delete actions
class ArchivedCoursesScreen extends StatefulWidget {
  final String? initialCourseId;

  const ArchivedCoursesScreen({super.key, this.initialCourseId});

  @override
  State<ArchivedCoursesScreen> createState() => _ArchivedCoursesScreenState();
}

class _ArchivedCoursesScreenState extends State<ArchivedCoursesScreen> {
  final CoursesController _coursesController = getIt<CoursesController>();
  String? _selectedCourseId;

  bool _isLoadingDetails = false;
  List<Module> _modules = [];
  Map<String, List<Topic>> _moduleTopics = {};
  int _completedTopicsCount = 0;
  int _totalTopicsCount = 0;
  int _completedModulesCount = 0;

  @override
  void initState() {
    super.initState();
    _coursesController.addListener(_onCoursesUpdated);
    _initSelection();
  }

  @override
  void dispose() {
    _coursesController.removeListener(_onCoursesUpdated);
    super.dispose();
  }

  void _onCoursesUpdated() {
    if (!mounted) return;
    final archived = _coursesController.archivedCourses;
    if (archived.isEmpty) {
      setState(() {
        _selectedCourseId = null;
        _modules = [];
        _moduleTopics = {};
      });
      return;
    }

    if (_selectedCourseId == null ||
        !archived.any((c) => c.id == _selectedCourseId)) {
      _selectCourse(archived.first.id);
    } else {
      _loadCourseDetails(_selectedCourseId!);
    }
  }

  void _initSelection() {
    final archived = _coursesController.archivedCourses;
    if (archived.isEmpty) return;

    if (widget.initialCourseId != null &&
        archived.any((c) => c.id == widget.initialCourseId)) {
      _selectedCourseId = widget.initialCourseId;
    } else {
      _selectedCourseId = archived.first.id;
    }
    _loadCourseDetails(_selectedCourseId!);
  }

  void _selectCourse(String courseId) {
    if (_selectedCourseId == courseId && _modules.isNotEmpty) return;
    setState(() {
      _selectedCourseId = courseId;
    });
    _loadCourseDetails(courseId);
  }

  Future<void> _loadCourseDetails(String courseId) async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      // 1. Load modules for this course (local first, fallback to Firestore)
      var loadedModules = await LocalModuleStorage.loadModules(courseId);
      final firestoreService = getIt<FirestoreService>();
      if (loadedModules.isEmpty && firestoreService.isAvailable) {
        try {
          final remote = await firestoreService.getModules(courseId: courseId);
          if (remote.isNotEmpty) {
            loadedModules = remote;
            await LocalModuleStorage.saveModulesForCourse(courseId, remote);
          }
        } catch (_) {}
      }

      // 2. Load all topic buckets to resolve topics per module
      final topicBuckets = await LocalTopicStorage.loadAllBuckets();
      final Map<String, List<Topic>> moduleTopicsMap = {};
      int totalTopics = 0;
      int completedTopics = 0;
      int completedModules = 0;

      for (final module in loadedModules) {
        var topics = LocalTopicStorage.resolveForModule(
          topicBuckets,
          moduleId: module.id,
          fallbackTitle: module.title,
        );

        if (topics.isEmpty && firestoreService.isAvailable && module.id.isNotEmpty) {
          try {
            final remoteTopics = await firestoreService.getTopics(moduleId: module.id);
            if (remoteTopics.isNotEmpty) {
              topics = remoteTopics;
              await LocalTopicStorage.saveTopics(module.id, remoteTopics);
            }
          } catch (_) {}
        }

        moduleTopicsMap[module.id] = topics;
        totalTopics += topics.length;

        int moduleCompletedTopics = 0;
        for (final t in topics) {
          if (t.isCompleted) {
            completedTopics++;
            moduleCompletedTopics++;
          }
        }

        final isModuleDone = (topics.isNotEmpty && moduleCompletedTopics >= topics.length) ||
            module.status.toLowerCase() == 'completed';
        if (isModuleDone) {
          completedModules++;
        }
      }

      if (!mounted) return;
      setState(() {
        _modules = loadedModules;
        _moduleTopics = moduleTopicsMap;
        _totalTopicsCount = totalTopics;
        _completedTopicsCount = completedTopics;
        _completedModulesCount = completedModules;
        _isLoadingDetails = false;
      });
    } catch (e) {
      debugPrint('Error loading archived course details: $e');
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _handleRestoreCourse(Course course) async {
    final confirmed = await StudyConfirmationDialog.showRestoreCourse(
      context,
      courseTitle: course.title,
    );
    if (!confirmed || !mounted) return;

    await _coursesController.unarchiveCourse(course.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Course "${course.title}" restored to active courses'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
      ),
    );

    final remaining = _coursesController.archivedCourses;
    if (remaining.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDeleteCourse(Course course) async {
    final confirmed = await StudyConfirmationDialog.showDeleteCourse(
      context,
      courseTitle: course.title,
    );
    if (!confirmed || !mounted) return;

    await _coursesController.deleteCourse(course.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Course "${course.title}" deleted'),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        ),
      ),
    );

    final remaining = _coursesController.archivedCourses;
    if (remaining.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _coursesController,
          builder: (context, _) {
            final archivedCourses = _coursesController.archivedCourses;

            if (archivedCourses.isEmpty) {
              return Column(
                children: [
                  _ArchivedTopBar(
                    onBack: _handleBack,
                    archivedCount: 0,
                  ),
                  Expanded(
                    child: _ArchivedEmptyState(
                      bottomPadding: bottomSafe + 24,
                    ),
                  ),
                ],
              );
            }

            final currentCourse = archivedCourses.firstWhere(
              (c) => c.id == _selectedCourseId,
              orElse: () => archivedCourses.first,
            );

            return Column(
              children: [
                _ArchivedTopBar(
                  onBack: _handleBack,
                  archivedCount: archivedCourses.length,
                ),
                if (archivedCourses.length > 1)
                  _ArchivedCourseSelector(
                    courses: archivedCourses,
                    selectedCourseId: currentCourse.id,
                    onSelectCourse: _selectCourse,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ArchivedCourseCompletionHeader(
                          course: currentCourse,
                          completedModules: _completedModulesCount,
                          totalModules: _modules.length,
                          completedTopics: _completedTopicsCount,
                          totalTopics: _totalTopicsCount,
                          onRestore: () => _handleRestoreCourse(currentCourse),
                          onDelete: () => _handleDeleteCourse(currentCourse),
                        ),
                        const VGapLg(),
                        Row(
                          children: [
                            Text(
                              'COURSE MODULES & TOPICS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMutedColor(context),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_modules.length} modules',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ],
                        ),
                        const VGapSm(),
                        if (_isLoadingDetails)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else if (_modules.isEmpty)
                          _ArchivedNoModulesCard()
                        else
                          _ArchivedNestedModulesList(
                            modules: _modules,
                            moduleTopics: _moduleTopics,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArchivedTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final int archivedCount;

  const _ArchivedTopBar({
    required this.onBack,
    required this.archivedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 16.0, 10.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          Text(
            'Archived Courses',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const HGapSm(),
          if (archivedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$archivedCount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchivedCourseSelector extends StatelessWidget {
  final List<Course> courses;
  final String selectedCourseId;
  final ValueChanged<String> onSelectCourse;

  const _ArchivedCourseSelector({
    required this.courses,
    required this.selectedCourseId,
    required this.onSelectCourse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: courses.length,
        separatorBuilder: (_, __) => const HGapSm(),
        itemBuilder: (context, index) {
          final course = courses[index];
          final isSelected = course.id == selectedCourseId;

          return InkWell(
            onTap: () => onSelectCourse(course.id),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textSecondaryColor(context),
                  ),
                  const HGapXs(),
                  Text(
                    course.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArchivedCourseCompletionHeader extends StatelessWidget {
  final Course course;
  final int completedModules;
  final int totalModules;
  final int completedTopics;
  final int totalTopics;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedCourseCompletionHeader({
    required this.course,
    required this.completedModules,
    required this.totalModules,
    required this.completedTopics,
    required this.totalTopics,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final double moduleProgress =
        totalModules > 0 ? (completedModules / totalModules) : 0.0;
    final double topicProgress =
        totalTopics > 0 ? (completedTopics / totalTopics) : 0.0;
    final int percent = ((totalTopics > 0 ? topicProgress : moduleProgress) * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseIconChip(
                courseId: course.id,
                size: 44,
                radius: 12,
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor(context),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelPurple(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.pastelPurpleBorder(context),
                            ),
                          ),
                          child: Text(
                            'ARCHIVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.pastelPurpleText(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (course.description.isNotEmpty) ...[
                      const VGapXs(),
                      Text(
                        course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Course Completion',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: percent >= 100
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const VGapXs(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (totalTopics > 0 ? topicProgress : moduleProgress).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFECEEF6),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 100 ? AppTheme.successColor : AppTheme.primaryColor,
              ),
            ),
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: _ArchivedStatCard(
                  label: 'Modules Completed',
                  value: '$completedModules / $totalModules',
                  icon: Icons.folder_outlined,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: _ArchivedStatCard(
                  label: 'Topics Completed',
                  value: '$completedTopics / $totalTopics',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const VGapMd(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.unarchive_outlined, size: 18),
                  label: const Text('Restore Course'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const HGapSm(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 22),
                color: AppTheme.errorColor,
                tooltip: 'Delete permanently',
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.errorColor.withValues(alpha: 0.10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchivedStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ArchivedStatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedNestedModulesList extends StatelessWidget {
  final List<Module> modules;
  final Map<String, List<Topic>> moduleTopics;

  const _ArchivedNestedModulesList({
    required this.modules,
    required this.moduleTopics,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: modules.length,
      separatorBuilder: (_, __) => const VGapMd(),
      itemBuilder: (context, index) {
        final module = modules[index];
        final topics = moduleTopics[module.id] ?? [];
        return _ArchivedModuleCard(
          module: module,
          topics: topics,
          orderIndex: index + 1,
        );
      },
    );
  }
}

class _ArchivedModuleCard extends StatefulWidget {
  final Module module;
  final List<Topic> topics;
  final int orderIndex;

  const _ArchivedModuleCard({
    required this.module,
    required this.topics,
    required this.orderIndex,
  });

  @override
  State<_ArchivedModuleCard> createState() => _ArchivedModuleCardState();
}

class _ArchivedModuleCardState extends State<_ArchivedModuleCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final completedCount =
        widget.topics.where((t) => t.isCompleted).length;
    final totalCount = widget.topics.length;
    final isDone = (totalCount > 0 && completedCount >= totalCount) ||
        widget.module.status.toLowerCase() == 'completed';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.successColor.withValues(alpha: 0.12)
                          : AppTheme.pastelIndigo(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.orderIndex}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDone
                              ? AppTheme.successColor
                              : AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.module.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        if (widget.module.description.isNotEmpty) ...[
                          const VGapXs(),
                          Text(
                            widget.module.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const HGapSm(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppTheme.successColor.withValues(alpha: 0.12)
                          : AppTheme.background(context),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone
                            ? AppTheme.successColor.withValues(alpha: 0.3)
                            : AppTheme.borderColor(context),
                      ),
                    ),
                    child: Text(
                      isDone
                          ? 'DONE ($completedCount/$totalCount)'
                          : '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDone
                            ? AppTheme.successColor
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ),
                  const HGapXs(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.borderColor(context),
            ),
            if (widget.topics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No topics in this module',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: widget.topics.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.borderColor(context),
                ),
                itemBuilder: (context, tIndex) {
                  final topic = widget.topics[tIndex];
                  return _ArchivedTopicRow(topic: topic);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ArchivedTopicRow extends StatelessWidget {
  final Topic topic;

  const _ArchivedTopicRow({required this.topic});

  @override
  Widget build(BuildContext context) {
    final bool isDone = topic.isCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: isDone
                ? AppTheme.successColor
                : AppTheme.textMutedColor(context),
          ),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? AppTheme.textSecondaryColor(context)
                        : AppTheme.textPrimaryColor(context),
                    decoration:
                        isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                if (topic.description.isNotEmpty) ...[
                  const VGapXs(),
                  Text(
                    topic.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (topic.estimatedMinutes != null && topic.estimatedMinutes! > 0)
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Text(
                '${topic.estimatedMinutes}m',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchivedNoModulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 36,
            color: AppTheme.textMutedColor(context),
          ),
          const VGapSm(),
          Text(
            'No modules in this course',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedEmptyState extends StatelessWidget {
  final double bottomPadding;

  const _ArchivedEmptyState({required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPadding),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.pastelPurple(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
            ),
            child: Icon(
              Icons.archive_outlined,
              color: AppTheme.pastelPurpleText(context),
              size: 30,
            ),
          ),
        ),
        const VGapMd(),
        Text(
          'No archived courses',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapXs(),
        Text(
          'Courses you archive will be moved here.\nYou can view their modules and topics or restore them anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
