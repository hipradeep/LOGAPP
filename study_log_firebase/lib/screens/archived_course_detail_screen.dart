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
import 'archived_topic_detail_sheet.dart';

/// Detail page for a single archived course: completion summary, restore/delete
/// actions and the nested module → topic tree.
///
/// Module lists start collapsed so the completion summary reads first; the
/// section header toggle expands or collapses all of them at once.
class ArchivedCourseDetailScreen extends StatefulWidget {
  final String courseId;

  const ArchivedCourseDetailScreen({super.key, required this.courseId});

  @override
  State<ArchivedCourseDetailScreen> createState() =>
      _ArchivedCourseDetailScreenState();
}

class _ArchivedCourseDetailScreenState
    extends State<ArchivedCourseDetailScreen> {
  /// Resolved once so a rename or unarchive doesn't swap the course mid-view.
  late final String _courseId = widget.courseId;

  bool _isLoadingDetails = false;
  List<Module> _modules = [];
  Map<String, List<Topic>> _moduleTopics = {};
  int _completedTopicsCount = 0;
  int _totalTopicsCount = 0;
  int _completedModulesCount = 0;

  @override
  void initState() {
    super.initState();
    _isLoadingDetails = true;
    _loadCourseDetails();
  }

  Course? get _course => getIt<CoursesController>().getCourseById(_courseId);

  Future<void> _loadCourseDetails() async {
    try {
      // 1. Load modules for this course (local first, fallback to Firestore)
      var loadedModules = await LocalModuleStorage.loadModules(_courseId);
      final firestoreService = getIt<FirestoreService>();
      if (loadedModules.isEmpty && firestoreService.isAvailable) {
        try {
          final remote = await firestoreService.getModules(courseId: _courseId);
          if (remote.isNotEmpty) {
            loadedModules = remote;
            await LocalModuleStorage.saveModulesForCourse(_courseId, remote);
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

        if (topics.isEmpty &&
            firestoreService.isAvailable &&
            module.id.isNotEmpty) {
          try {
            final remoteTopics = await firestoreService.getTopics(
              moduleId: module.id,
            );
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

        final isModuleDone =
            (topics.isNotEmpty && moduleCompletedTopics >= topics.length) ||
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

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final course = _course;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: course == null
            ? Column(
                children: [
                  _DetailTopBar(
                    title: 'Archive',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: _ArchivedEmptyDetail(bottomPadding: bottomSafe + 24),
                  ),
                ],
              )
            : ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 32),
                children: [
                  _DetailTopBar(
                    title: 'Archive',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  const VGapMd(),
                  _ArchivedCourseCompletionHeader(
                    course: course,
                    completedModules: _completedModulesCount,
                    totalModules: _modules.length,
                    completedTopics: _completedTopicsCount,
                    totalTopics: _totalTopicsCount,
                  ),
                  const VGapLg(),
                  if (_isLoadingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else if (_modules.isEmpty)
                    const _ArchivedNoModulesCard()
                  else
                    _ArchivedModulesSection(
                      modules: _modules,
                      moduleTopics: _moduleTopics,
                    ),
                ],
              ),
      ),
    );
  }
}

/// Owns the expand/collapse state for every module so the header toggle can
/// drive them all from one place.
class _ArchivedModulesSection extends StatefulWidget {
  final List<Module> modules;
  final Map<String, List<Topic>> moduleTopics;

  const _ArchivedModulesSection({
    required this.modules,
    required this.moduleTopics,
  });

  @override
  State<_ArchivedModulesSection> createState() =>
      _ArchivedModulesSectionState();
}

class _ArchivedModulesSectionState extends State<_ArchivedModulesSection> {
  /// Module ids the user has expanded. Starts empty, so every module list is
  /// collapsed until the user expands one or hits the toggle.
  final Set<String> _expanded = {};

  void collapseAll() {
    if (!mounted) return;
    setState(() {
      _expanded.clear();
    });
  }

  void expandAll() {
    if (!mounted) return;
    setState(() {
      _expanded
        ..clear()
        ..addAll(widget.modules.map((m) => m.id));
    });
  }

  void _toggle(String moduleId) {
    if (!mounted) return;
    setState(() {
      if (!_expanded.remove(moduleId)) {
        _expanded.add(moduleId);
      }
    });
  }

  bool get _allExpanded =>
      _expanded.length == widget.modules.length && widget.modules.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            _CollapseAllToggle(
              isAllExpanded: _allExpanded,
              onToggle: _allExpanded ? collapseAll : expandAll,
            ),
          ],
        ),
        const VGapSm(),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: widget.modules.length,
          separatorBuilder: (_, _) => const VGapMd(),
          itemBuilder: (context, index) {
            final module = widget.modules[index];
            return _ArchivedModuleCard(
              module: module,
              topics: widget.moduleTopics[module.id] ?? [],
              orderIndex: index + 1,
              isExpanded: _expanded.contains(module.id),
              onToggle: () => _toggle(module.id),
            );
          },
        ),
      ],
    );
  }
}

class _CollapseAllToggle extends StatelessWidget {
  final bool isAllExpanded;
  final VoidCallback onToggle;

  const _CollapseAllToggle({
    required this.isAllExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAllExpanded ? 'Collapse all' : 'Expand all',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const HGapXs(),
            Icon(
              isAllExpanded
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
              size: 15,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _DetailTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 10.0, 16.0, 0),
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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
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

  const _ArchivedCourseCompletionHeader({
    required this.course,
    required this.completedModules,
    required this.totalModules,
    required this.completedTopics,
    required this.totalTopics,
  });

  @override
  Widget build(BuildContext context) {
    final double moduleProgress = totalModules > 0
        ? (completedModules / totalModules)
        : 0.0;
    final double topicProgress = totalTopics > 0
        ? (completedTopics / totalTopics)
        : 0.0;
    final int percent =
        ((totalTopics > 0 ? topicProgress : moduleProgress) * 100).toInt();

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
              CourseIconChip(courseId: course.id, size: 44, radius: 12),
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
              value: (totalTopics > 0 ? topicProgress : moduleProgress).clamp(
                0.0,
                1.0,
              ),
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

class _ArchivedModuleCard extends StatelessWidget {
  final Module module;
  final List<Topic> topics;
  final int orderIndex;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ArchivedModuleCard({
    required this.module,
    required this.topics,
    required this.orderIndex,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = topics.where((t) => t.isCompleted).length;
    final totalCount = topics.length;
    final isDone =
        (totalCount > 0 && completedCount >= totalCount) ||
        module.status.toLowerCase() == 'completed';

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
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 12.0,
              ),
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
                        '$orderIndex',
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
                    child: Text(
                      module.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
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
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.borderColor(context),
            ),
            if (topics.isEmpty)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                itemCount: topics.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.borderColor(context),
                ),
                itemBuilder: (context, tIndex) {
                  final topic = topics[tIndex];
                  return _ArchivedTopicRow(
                    topic: topic,
                    moduleTitle: module.title,
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// Name-only topic row. Tapping opens [ArchivedTopicDetailSheet] to read the
/// description, keeping the collapsed list compact.
class _ArchivedTopicRow extends StatelessWidget {
  final Topic topic;
  final String moduleTitle;

  const _ArchivedTopicRow({required this.topic, required this.moduleTitle});

  @override
  Widget build(BuildContext context) {
    final bool isDone = topic.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ArchivedTopicDetailSheet.show(
          context,
          topic: topic,
          moduleTitle: moduleTitle,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
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
                child: Text(
                  topic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isDone
                        ? AppTheme.textSecondaryColor(context)
                        : AppTheme.textPrimaryColor(context),
                    decoration: isDone
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              const HGapXs(),
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: AppTheme.textMutedColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchivedNoModulesCard extends StatelessWidget {
  const _ArchivedNoModulesCard();

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

class _ArchivedEmptyDetail extends StatelessWidget {
  final double bottomPadding;

  const _ArchivedEmptyDetail({required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24, 72, 24, bottomPadding),
      children: [
        Center(
          child: Icon(
            Icons.search_off_rounded,
            size: 44,
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const VGapMd(),
        Text(
          'Course unavailable',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapXs(),
        Text(
          'This course may have been restored or deleted.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
      ],
    );
  }
}
