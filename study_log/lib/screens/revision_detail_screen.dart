import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/entity_detail_header.dart';
import '../widgets/topic_list_item.dart';
import '../widgets/revision_options_sheet.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/topic_revision_controller.dart';
import 'session_setup_screen.dart';
import 'topic_detail_screen.dart';

/// Screen displaying the roll-up spaced repetition status for a module and its topics.
///
/// Under the Hybrid Roll-Up Architecture:
/// - `TopicRevision` is the single source of truth for spaced repetition intervals (R1..R5).
/// - [RevisionDetailScreen] acts as a direct aggregator view showing individual topic progress,
///   module-level mastery, and provides a **Batch Session Launcher** to review all currently
///   due topics in one session.
/// - Tabs and separate module progress ladders have been removed in favor of a clean, direct
///   topic list with roll-up metrics.
class RevisionDetailScreen extends StatefulWidget {
  final String moduleId;
  final String courseId;
  final String? initialModuleTitle;
  final String? initialCourseTitle;
  final Revision? revision;

  RevisionDetailScreen({
    super.key,
    String? moduleId,
    String? courseId,
    this.initialModuleTitle,
    this.initialCourseTitle,
    this.revision,
  })  : moduleId = moduleId ?? revision?.moduleId ?? '',
        courseId = courseId ?? revision?.courseId ?? '';

  @override
  State<RevisionDetailScreen> createState() => _RevisionDetailScreenState();
}

class _RevisionDetailScreenState extends State<RevisionDetailScreen> {
  List<Topic> _baseTopics = const [];
  bool _isLoadingTopics = true;

  String _cachedCourseTitle = '';
  String _cachedModuleTitle = '';
  int _totalMinutesExpended = 0;

  RevisionController get _controller => getIt<RevisionController>();
  TopicRevisionController get _topicController => getIt<TopicRevisionController>();

  /// Course title looked up dynamically from CoursesController
  String get _courseTitle {
    if (_cachedCourseTitle.isNotEmpty) return _cachedCourseTitle;
    if (widget.initialCourseTitle != null && widget.initialCourseTitle!.isNotEmpty) {
      _cachedCourseTitle = widget.initialCourseTitle!;
      return _cachedCourseTitle;
    }
    if (getIt.isRegistered<CoursesController>()) {
      final t = getIt<CoursesController>().getCourseById(widget.courseId)?.title;
      if (t != null && t.isNotEmpty) {
        _cachedCourseTitle = t;
        return t;
      }
    }
    return '';
  }

  /// Module title looked up dynamically from OngoingModulesController
  String get _moduleTitle {
    if (_cachedModuleTitle.isNotEmpty) return _cachedModuleTitle;
    if (widget.initialModuleTitle != null && widget.initialModuleTitle!.isNotEmpty) {
      _cachedModuleTitle = widget.initialModuleTitle!;
      return _cachedModuleTitle;
    }
    if (getIt.isRegistered<OngoingModulesController>()) {
      final t = getIt<OngoingModulesController>().moduleTitleFor(widget.moduleId);
      if (t.isNotEmpty) {
        _cachedModuleTitle = t;
        return t;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadModuleStats();
    _topicController.addListener(_onTopicRevisionsUpdated);
  }

  @override
  void dispose() {
    _topicController.removeListener(_onTopicRevisionsUpdated);
    super.dispose();
  }

  void _onTopicRevisionsUpdated() {
    if (mounted) {
      _loadTopics();
    }
  }

  Future<void> _loadTopics() async {
    final courseId = widget.courseId;
    final moduleId = widget.moduleId;

    // Resolve course and module titles if not yet populated
    if (_cachedCourseTitle.isEmpty && courseId.isNotEmpty) {
      if (getIt.isRegistered<CoursesController>()) {
        final c = getIt<CoursesController>().getCourseById(courseId);
        if (c != null && c.title.isNotEmpty) {
          _cachedCourseTitle = c.title;
        }
      }
    }
    if (_cachedModuleTitle.isEmpty && moduleId.isNotEmpty) {
      final mod = await DatabaseService.instance.getModuleById(moduleId);
      if (mod != null && mod.title.isNotEmpty) {
        _cachedModuleTitle = mod.title;
      }
    }

    // Load base module topics from SQLite
    final allModuleTopics = await _loadBaseTopicsForModule(
      moduleId: moduleId,
      fallbackTitle: _moduleTitle.isNotEmpty ? _moduleTitle : null,
    );

    // Filter strictly to topics that are completed AND added for revision
    final trc = _topicController;
    final revisionTopics = allModuleTopics.where((t) {
      final isEnrolled = trc.isTopicEnrolled(t.id);
      return t.isCompleted && isEnrolled;
    }).toList();

    if (mounted) {
      setState(() {
        _baseTopics = revisionTopics;
        _isLoadingTopics = false;
      });
      unawaited(_loadModuleStats());
    }
  }

  Future<void> _loadModuleStats() async {
    try {
      final moduleId = widget.moduleId;
      final moduleTitle = _moduleTitle;

      int totalMinutes = 0;
      final logs = await DatabaseService.instance.getStudyLogs();
      for (final log in logs) {
        final matches = (moduleId.isNotEmpty && log.moduleId == moduleId) ||
            (moduleTitle.isNotEmpty &&
                log.moduleTitle.toLowerCase() == moduleTitle.toLowerCase());
        if (matches) {
          if (log.durationMinutes != null && log.durationMinutes! > 0) {
            totalMinutes += log.durationMinutes!;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalMinutesExpended = totalMinutes;
        });
      }
    } catch (_) {}
  }

  Future<List<Topic>> _loadBaseTopicsForModule({
    required String moduleId,
    String? fallbackTitle,
  }) async {
    if (moduleId.isNotEmpty) {
      final topics = await DatabaseService.instance.getTopics(moduleId: moduleId);
      if (topics.isNotEmpty) return topics;
    }
    if (fallbackTitle != null && fallbackTitle.isNotEmpty) {
      final all = await DatabaseService.instance.getAllTopics();
      final matched = all.where((t) => t.moduleId == fallbackTitle).toList();
      if (matched.isNotEmpty) return matched;
    }
    return [];
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  /// Batch Session Launcher: Launches a revision session pre-populated with all
  /// topics in this module that are currently due (or all topics if none due).
  Future<void> _handleStartSession() async {
    final trc = _topicController;
    final now = DateTime.now();

    // Find topics in this module currently due for spaced repetition
    final dueTopics = _baseTopics.where((t) {
      final tr = trc.topicRevisionFor(t.id);
      return tr != null && tr.isDueAt(now) && !tr.isFinished;
    }).toList();

    final List<Topic> sessionTopics = dueTopics.isNotEmpty ? dueTopics : _baseTopics;

    await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSetupScreen(
          courseTitle: _courseTitle,
          courseId: widget.courseId,
          moduleTitle: _moduleTitle,
          moduleId: widget.moduleId,
          topics: sessionTopics,
          isRevision: true,
        ),
      ),
    );

    if (mounted) {
      await _loadTopics();
      setState(() {});
    }
  }

  void _openOptionsMenu() {
    final rev = _controller.revisionForModule(widget.moduleId) ??
        RevisionModule(
          id: 'mod_rev_${widget.moduleId}',
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          currentLevel: 1,
          status: RevisionStatus.active,
          nextRevisionAt: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    RevisionOptionsSheet.show(
      context,
      revision: rev,
      revisionController: _controller,
      showOpenDetails: false,
      onDeleted: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  /// Tapping the status indicator / checkmark quick advances or completes the topic revision.
  Future<void> _toggleTopicStatus(Topic topic) async {
    final trc = _topicController;
    final tr = trc.topicRevisionFor(topic.id);

    if (tr == null) {
      await trc.enrollTopicInRevision(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        topicId: topic.id,
        title: topic.title,
      );
      return;
    }

    if (tr.isFinished) {
      return;
    }

    await trc.toggleLevelStatus(tr.id);
  }

  Future<void> _handleOpenTopicDetail(Topic topic) async {
    await Navigator.push<Topic?>(
      context,
      MaterialPageRoute(
        builder: (_) => TopicDetailScreen(
          topic: topic,
          moduleTitle: _moduleTitle,
          courseTitle: _courseTitle,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          isFromModuleRevision: true,
        ),
      ),
    );

    if (mounted) {
      await _loadTopics();
    }
  }

  // ── COMMENTED OUT: LEGACY MODULE-LEVEL PROGRESSION CRUD ───────────────────
  // In the Topic-First Spaced Repetition architecture:
  // - There is no independent R1..R5 state machine or progress ladder for modules.
  // - Progression is tracked strictly per-topic in TopicRevisionController.
  // - Module revision is a computed roll-up view aggregating topics.
  //
  // Future<void> _startCurrentLevel(Revision revision, {bool popOnComplete = false}) async {
  //   final level = revision.currentLevel;
  //   final advanced = await _controller.completeCurrentLevel(revision.id);
  //   if (!mounted || !advanced) return;
  //   ...
  // }
  //
  // Future<void> _showRevisionCompletionDialog({List<Topic>? topics}) async {
  //   ...
  // }
  //
  // Future<void> _resetTopicsForCurrentLevel({bool showFeedback = true}) async {
  //   ...
  // }
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      floatingActionButton: _RevisionFAB(
        hasTopics: _baseTopics.isNotEmpty,
        onPressed: _handleStartSession,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_controller, _topicController]),
          builder: (context, _) {
            final trc = _topicController;
            final now = DateTime.now();

            final totalCount = _baseTopics.length;
            final masteredCount = _baseTopics
                .where((t) => trc.topicRevisionFor(t.id)?.isFinished == true)
                .length;
            final completedCount = _baseTopics
                .where((t) {
                  final tr = trc.topicRevisionFor(t.id);
                  return tr != null && (tr.isFinished || tr.isLevelCompleted);
                })
                .length;
            final dueCount = _baseTopics
                .where((t) {
                  final tr = trc.topicRevisionFor(t.id);
                  return tr != null && tr.isDueAt(now) && !tr.isFinished;
                })
                .length;
            final inProgressCount = _baseTopics
                .where((t) {
                  final tr = trc.topicRevisionFor(t.id);
                  return tr != null && tr.levelStatus == TopicStatus.inProgress && !tr.isFinished;
                })
                .length;

            DateTime? lastTopicUpdatedAt;
            final allRevs = _baseTopics
                .map((t) => trc.topicRevisionFor(t.id))
                .where((tr) => tr != null)
                .cast<TopicRevision>()
                .toList();
            if (allRevs.isNotEmpty) {
              allRevs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              lastTopicUpdatedAt = allRevs.first.updatedAt;
            }

            return Column(
              children: [
                _RevisionHeaderSection(
                  courseTitle: _courseTitle,
                  moduleTitle: _moduleTitle,
                  courseId: widget.courseId,
                  completedTopicsCount: completedCount,
                  inProgressTopicsCount: inProgressCount,
                  masteredTopicsCount: masteredCount,
                  dueTopicsCount: dueCount,
                  totalTopicsCount: totalCount,
                  totalMinutesExpended: _totalMinutesExpended,
                  lastTopicUpdatedAt: lastTopicUpdatedAt,
                  onBack: _handleBack,
                  onOptions: _openOptionsMenu,
                ),
                const VGapSm(),
                Expanded(
                  child: _RevisionTopicsView(
                    topics: _baseTopics,
                    topicRevisionController: trc,
                    isLoading: _isLoadingTopics,
                    bottomPadding: bottomSafe + 84,
                    onToggle: _toggleTopicStatus,
                    onTopicTap: _handleOpenTopicDetail,
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

class _RevisionFAB extends StatelessWidget {
  final bool hasTopics;
  final VoidCallback onPressed;

  const _RevisionFAB({
    required this.hasTopics,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasTopics) {
      return const SizedBox.shrink();
    }
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      tooltip: 'Start Batch Revision Session',
      child: const Icon(Icons.play_arrow_rounded, size: 28),
    );
  }
}

class _RevisionHeaderSection extends StatelessWidget {
  final String courseTitle;
  final String moduleTitle;
  final String courseId;
  final int completedTopicsCount;
  final int inProgressTopicsCount;
  final int masteredTopicsCount;
  final int dueTopicsCount;
  final int totalTopicsCount;
  final int totalMinutesExpended;
  final DateTime? lastTopicUpdatedAt;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  const _RevisionHeaderSection({
    required this.courseTitle,
    required this.moduleTitle,
    required this.courseId,
    required this.completedTopicsCount,
    required this.inProgressTopicsCount,
    required this.masteredTopicsCount,
    required this.dueTopicsCount,
    required this.totalTopicsCount,
    required this.totalMinutesExpended,
    this.lastTopicUpdatedAt,
    required this.onBack,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusBg;
    final Color statusBorder;
    final Color statusColor;
    final String statusLabel;

    if (totalTopicsCount > 0 && masteredTopicsCount == totalTopicsCount) {
      statusBg = AppTheme.successColor.withValues(alpha: 0.12);
      statusBorder = AppTheme.successColor.withValues(alpha: 0.25);
      statusColor = AppTheme.successColor;
      statusLabel = 'Mastered';
    } else if (totalTopicsCount > 0 && completedTopicsCount == totalTopicsCount) {
      statusBg = AppTheme.successColor.withValues(alpha: 0.12);
      statusBorder = AppTheme.successColor.withValues(alpha: 0.25);
      statusColor = AppTheme.successColor;
      statusLabel = 'Completed';
    } else if (dueTopicsCount > 0) {
      statusBg = AppTheme.warningColor.withValues(alpha: 0.12);
      statusBorder = AppTheme.warningColor.withValues(alpha: 0.25);
      statusColor = AppTheme.warningColor;
      statusLabel = 'In Progress • $dueTopicsCount Due';
    } else if (completedTopicsCount > 0 || inProgressTopicsCount > 0) {
      statusBg = AppTheme.primaryColor.withValues(alpha: 0.12);
      statusBorder = AppTheme.primaryColor.withValues(alpha: 0.25);
      statusColor = AppTheme.primaryColor;
      statusLabel = 'In Progress';
    } else {
      statusBg = AppTheme.surface(context);
      statusBorder = AppTheme.borderColor(context);
      statusColor = AppTheme.textSecondaryColor(context);
      statusLabel = 'Not Started';
    }

    final countStr = totalTopicsCount > 0
        ? '$completedTopicsCount/$totalTopicsCount Completed'
        : null;
    final dateStr = lastTopicUpdatedAt != null
        ? EntityDetailHeader.formatDate(lastTopicUpdatedAt!)
        : null;
    final hoursStr = EntityDetailHeader.formatDuration(totalMinutesExpended);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomAppBar(
          title: courseTitle.isNotEmpty ? courseTitle : 'REVISION',
          onBack: onBack,
          actions: [
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppTheme.textPrimaryColor(context),
                size: 22,
              ),
              onPressed: onOptions,
              tooltip: 'Options',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        EntityDetailHeader(
          title: moduleTitle,
          courseId: courseId,
          horizontalPadding: 20.0,
          countText: countStr,
          dateText: dateStr,
          durationText: hoursStr,
          statusWidget: DetailStatusBadge(
            label: statusLabel,
            backgroundColor: statusBg,
            borderColor: statusBorder,
            textColor: statusColor,
          ),
          showDivider: true,
        ),
      ],
    );
  }
}

/// Renders the module's topics with their individual [TopicRevision] status and badges.
class _RevisionTopicsView extends StatelessWidget {
  final List<Topic> topics;
  final TopicRevisionController topicRevisionController;
  final bool isLoading;
  final double bottomPadding;
  final ValueChanged<Topic> onToggle;
  final ValueChanged<Topic> onTopicTap;

  const _RevisionTopicsView({
    required this.topics,
    required this.topicRevisionController,
    required this.isLoading,
    required this.bottomPadding,
    required this.onToggle,
    required this.onTopicTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (topics.isEmpty) {
      return const _RevisionTopicsEmptyState();
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        final tr = topicRevisionController.topicRevisionFor(topic.id);
        return TopicListItem(
          key: ValueKey(topic.id),
          topic: topic,
          topicRevision: tr,
          showCheckbox: true,
          showTrailing: true,
          onCheckboxTap: () => onToggle(topic),
          onTap: () => onTopicTap(topic),
        );
      },
    );
  }
}

class _RevisionTopicsEmptyState extends StatelessWidget {
  const _RevisionTopicsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.pastelPurple(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.playlist_add_rounded,
                size: 30,
                color: AppTheme.pastelPurpleText(context),
              ),
            ),
            const VGapMd(),
            Text(
              'No revision topics yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const VGapXs(),
            Text(
              'Only completed topics added to revision appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── COMMENTED OUT: MODULE-LEVEL REVISION PROGRESS LADDER & TABS ──────────────
// The R1..R5 timeline ladder and tabs at the module level have been removed in favor
// of topic-level spaced repetition tracking. Topics now directly display their
// individual R1..R5 level badges and due states in the topic list.
//
// class _RevisionLadderView extends StatelessWidget {
//   final Revision revision;
//   final List<Topic> topics;
//   final TopicRevisionController topicRevisionController;
//   final double bottomPadding;
//
//   const _RevisionLadderView({
//     required this.revision,
//     required this.topics,
//     required this.topicRevisionController,
//     required this.bottomPadding,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final maxLevel = RevisionSchedule.maxLevel;
//     return ListView(
//       children: [
//         for (var level = 1; level <= maxLevel; level++)
//           _TimelineRow(...),
//       ],
//     );
//   }
// }
//
// class _TimelineRow extends StatelessWidget { ... }
// class _StatusIndicator extends StatelessWidget { ... }
// class _StatusBadge extends StatelessWidget { ... }
// enum _StepState { cleared, current, upcoming }
//
// class _RevisionTabsRow extends StatelessWidget { ... }
// class _TabItem extends StatelessWidget { ... }
// ─────────────────────────────────────────────────────────────────────────────
