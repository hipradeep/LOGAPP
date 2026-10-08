import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/topic_list_item.dart';
import '../widgets/revision_completion_dialog.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../models/revision_topic.dart';
import '../models/module.dart';
import '../models/study_log.dart';
import '../services/local_revision_topic_storage.dart';
import '../services/local_revision_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_module_storage.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/progress_controller.dart';
import 'session_setup_screen.dart';

/// Read-only by design: the ladder advances on its own, so there is no action
/// button here — tapping a topic simply opens the module it belongs to.
class RevisionDetailScreen extends StatefulWidget {
  final Revision revision;

  const RevisionDetailScreen({super.key, required this.revision});

  @override
  State<RevisionDetailScreen> createState() => _RevisionDetailScreenState();
}

class _RevisionDetailScreenState extends State<RevisionDetailScreen> {
  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);
  List<RevisionTopic> _revisionTopics = const [];
  Map<String, Topic> _baseTopicsById = const {};
  StreamSubscription<List<RevisionTopic>>? _topicsSubscription;
  bool _isLoadingTopics = true;

  String _resolvedModuleId = '';
  String _cachedCourseTitle = '';
  String _cachedModuleTitle = '';

  RevisionController get _controller => getIt<RevisionController>();

  /// Course title looked up dynamically from CoursesController
  String get _courseTitle {
    if (_cachedCourseTitle.isNotEmpty) return _cachedCourseTitle;
    if (getIt.isRegistered<CoursesController>()) {
      final t = getIt<CoursesController>().getCourseById(widget.revision.courseId)?.title;
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
    if (getIt.isRegistered<OngoingModulesController>()) {
      final t = getIt<OngoingModulesController>().moduleTitleFor(widget.revision.moduleId);
      if (t.isNotEmpty) {
        _cachedModuleTitle = t;
        return t;
      }
    }
    return '';
  }

  /// Always prefers the live record so the ladder reflects auto-progression.
  Revision get _revision =>
      _controller.revisionForModule(widget.revision.moduleId) ??
      widget.revision;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _topicsSubscription?.cancel();
    _activeTab.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final revision = widget.revision;

    // Resolve course and module titles if not yet populated
    if (_cachedCourseTitle.isEmpty && revision.courseId.isNotEmpty) {
      if (getIt.isRegistered<CoursesController>()) {
        final c = getIt<CoursesController>().getCourseById(revision.courseId);
        if (c != null && c.title.isNotEmpty) {
          _cachedCourseTitle = c.title;
        }
      }
    }
    if (_cachedModuleTitle.isEmpty && revision.moduleId.isNotEmpty) {
      final mod = await LocalModuleStorage.getModuleById(revision.moduleId);
      if (mod != null && mod.title.isNotEmpty) {
        _cachedModuleTitle = mod.title;
      }
    }

    // 1. Concurrently load cached revision topics and local base topics
    final cachedRevFuture = LocalRevisionTopicStorage.loadTopicsForRevision(revision.id);
    final localTopicsFuture = LocalTopicStorage.loadTopicsForModule(
      moduleId: revision.moduleId,
      fallbackTitle: _moduleTitle.isNotEmpty ? _moduleTitle : null,
    );

    final results = await Future.wait([cachedRevFuture, localTopicsFuture]);
    var revTopics = results[0] as List<RevisionTopic>;
    final baseTopics = results[1] as List<Topic>;

    final initialBaseMap = <String, Topic>{for (final t in baseTopics) t.id: t};

    if (mounted) {
      setState(() {
        _baseTopicsById = initialBaseMap;
        if (revTopics.isNotEmpty) {
          _revisionTopics = revTopics;
          _isLoadingTopics = false;
        }
      });
    }

    // Immediately resolve and fetch any missing topic names
    if (revTopics.isNotEmpty) {
      await _fetchTopicNames(revTopics);
    }

    // 2. Stream from SQLite database for real-time updates
    if (getIt.isRegistered<DatabaseService>() && revision.id.isNotEmpty) {
      final db = getIt<DatabaseService>();
      _topicsSubscription?.cancel();
      _topicsSubscription = db.streamRevisionTopics(revisionId: revision.id).listen(
        (updatedList) {
          if (mounted && updatedList.isNotEmpty) {
            setState(() {
              _revisionTopics = updatedList;
              _isLoadingTopics = false;
            });
            unawaited(_fetchTopicNames(updatedList));
          }
        },
        onError: (_) {},
      );
    }

    // 3. If no revision topics exist yet, auto-seed from base module topics!
    if (revTopics.isEmpty) {
      await _autoSeedTopicsFromModule();
    }
  }

  /// Fetches and resolves topic names using a cache-first hierarchy:
  /// Level 0: Denormalized title in RevisionTopic (0 reads, 0ms)
  /// Level 1: Local SQLite database (LocalTopicStorage - instant local read)
  Future<void> _fetchTopicNames(List<RevisionTopic> revTopics) async {
    if (revTopics.isEmpty) return;

    // Level 0: If all topics already have denormalized titles, NO reads needed!
    final topicsMissingTitle = revTopics.where((rt) => rt.title.isEmpty).toList();
    if (topicsMissingTitle.isEmpty) {
      return;
    }

    final moduleId = widget.revision.moduleId;
    final moduleTitle = _moduleTitle;
    final map = Map<String, Topic>.from(_baseTopicsById);

    // Level 1: Try loading module topics if base map is still empty
    if (map.isEmpty) {
      final baseTopics = await LocalTopicStorage.loadTopicsForModule(
        moduleId: moduleId,
        fallbackTitle: moduleTitle.isNotEmpty ? moduleTitle : null,
      );
      for (final t in baseTopics) {
        map[t.id] = t;
      }
    }

    // Identify which topicIds are still missing
    final missingTopicIds = topicsMissingTitle
        .map((rt) => rt.topicId)
        .where((id) => id.isNotEmpty && !map.containsKey(id))
        .toSet();

    // Check all local buckets on disk before making any remote calls
    if (missingTopicIds.isNotEmpty) {
      final allBuckets = await LocalTopicStorage.loadAllBuckets();
      for (final list in allBuckets.values) {
        for (final t in list) {
          if (missingTopicIds.contains(t.id)) {
            map[t.id] = t;
            missingTopicIds.remove(t.id);
          }
        }
      }
    }



    // Level 4: Backfill resolved titles into RevisionTopic and persist
    var backfillNeeded = false;
    final updatedRevTopics = _revisionTopics.map((rt) {
      if (rt.title.isEmpty) {
        final t = map[rt.topicId];
        if (t != null && t.title.isNotEmpty) {
          backfillNeeded = true;
          return rt.copyWith(title: t.title);
        }
      }
      return rt;
    }).toList();

    if (mounted) {
      setState(() {
        _baseTopicsById = map;
        if (backfillNeeded) {
          _revisionTopics = updatedRevTopics;
        }
      });
    }

    // Permanently save backfilled titles to SQLite database
    if (backfillNeeded) {
      await LocalRevisionTopicStorage.saveTopics(widget.revision.id, updatedRevTopics);
    }
  }

  Future<void> _autoSeedTopicsFromModule() async {
    final revision = widget.revision;
    final targetModuleId = revision.moduleId;
    _resolvedModuleId = targetModuleId;

    var baseTopics = await LocalTopicStorage.loadTopicsForModule(
      moduleId: targetModuleId,
      fallbackTitle: _moduleTitle.isNotEmpty ? _moduleTitle : null,
    );


    if (baseTopics.isNotEmpty) {
      final now = DateTime.now();
      final baseMap = {for (final t in baseTopics) t.id: t};
      final seeded = baseTopics.asMap().entries.map((entry) {
        final t = entry.value;
        return RevisionTopic.fromTopic(
          t,
          revisionId: revision.id,
          newId: 'rev_topic_${revision.id}_${entry.key}_${now.millisecondsSinceEpoch}',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _baseTopicsById = baseMap;
          _revisionTopics = seeded;
          _isLoadingTopics = false;
        });
      }
      await LocalRevisionTopicStorage.saveTopics(revision.id, seeded);
    } else if (mounted) {
      setState(() {
        _isLoadingTopics = false;
      });
    }
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  Future<void> _toggleTopicStatus(int index) async {
    if (index >= _revisionTopics.length) return;
    final current = _revisionTopics[index];
    final TopicStatus next;
    switch (current.status) {
      case TopicStatus.notStarted:
        next = TopicStatus.inProgress;
        break;
      case TopicStatus.inProgress:
        next = TopicStatus.completed;
        break;
      case TopicStatus.completed:
        next = TopicStatus.notStarted;
        break;
    }

    final updated = current.copyWith(
      status: next,
      completedAt: next == TopicStatus.completed ? DateTime.now() : null,
      clearCompletedAt: next != TopicStatus.completed,
      updatedAt: DateTime.now(),
    );

    final updatedTopics = List<RevisionTopic>.from(_revisionTopics);
    updatedTopics[index] = updated;
    setState(() {
      _revisionTopics = updatedTopics;
    });

    await LocalRevisionTopicStorage.saveTopics(widget.revision.id, updatedTopics);



    final targetTopicId = updated.topicId.isNotEmpty ? updated.topicId : updated.id;

    if (next == TopicStatus.completed) {
      final now = DateTime.now();
      final topicTitle = updated.title.isNotEmpty
          ? updated.title
          : (_baseTopicsById[updated.topicId]?.title ?? 'Revision Topic');

      final studyLog = StudyLog(
        id: 'log_rev_topic_${updated.id}_${now.millisecondsSinceEpoch}',
        type: StudyLogType.revisionCompleted,
        courseId: _revision.courseId,
        courseTitle: _courseTitle,
        moduleId: _revision.moduleId,
        moduleTitle: _moduleTitle,
        topicId: targetTopicId,
        topicTitle: topicTitle,
        revisionLevel: _revision.currentLevel,
        timestamp: now,
        createdAt: now,
      );

      await LocalStudyLogStorage.addLog(studyLog);
      await LocalRevisionStorage.recordRevisionEvent(now);

      if (getIt.isRegistered<OngoingModulesController>()) {
        unawaited(getIt<OngoingModulesController>().refresh());
      }
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    } else if (next == TopicStatus.notStarted) {
      // If user unchecks the topic, remove the revision log entry
      await LocalStudyLogStorage.deleteLogForTopic(
        topicId: targetTopicId,
        type: 'revisionCompleted',
      );
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    }

    final allTopicsCompleted = updatedTopics.isNotEmpty &&
        updatedTopics.every((t) => t.status == TopicStatus.completed);

    if (allTopicsCompleted && mounted) {
      await _showRevisionCompletionDialog(topics: updatedTopics);
    }
  }

  Future<void> _showRevisionCompletionDialog({List<RevisionTopic>? topics}) async {
    final list = topics ?? _revisionTopics;
    final allTopicsCompleted = list.isNotEmpty &&
        list.every((t) => t.status == TopicStatus.completed);

    if (!allTopicsCompleted || !mounted) return;

    final revision = _revision;
    final isDue = revision.isDueAt(DateTime.now());

    if (isDue) {
      // Scheduled revision date reached: show dialog and suggest moving to the next revision cycle.
      await RevisionCompletionDialog.show(
        context,
        topicTitle: 'All Topics Completed',
        courseTitle: _courseTitle,
        moduleTitle: _moduleTitle,
        currentLevel: revision.currentLevel,
        isFinished: revision.isFinished,
        completedAt: DateTime.now(),
        onMoveToNextRevision: () async {
          // Reset revision topics to notStarted for the new revision cycle
          final resetTopics = list.map((t) => t.copyWith(
            status: TopicStatus.notStarted,
            clearCompletedAt: true,
            updatedAt: DateTime.now(),
          )).toList();
          setState(() {
            _revisionTopics = resetTopics;
          });
          await LocalRevisionTopicStorage.saveTopics(revision.id, resetTopics);

          await _startCurrentLevel(revision, popOnComplete: true);
        },
      );
    } else {
      // Before revision date: show same dialog with button "Completed",
      // and on click it goes back to revision module with revision again action!
      await RevisionCompletionDialog.show(
        context,
        topicTitle: 'All Topics Completed',
        courseTitle: _courseTitle,
        moduleTitle: _moduleTitle,
        currentLevel: revision.currentLevel,
        isFinished: revision.isFinished,
        completedAt: DateTime.now(),
        actionButtonLabel: 'Completed',
        onMoveToNextRevision: () async {
          final now = DateTime.now();
          final log = StudyLog(
            id: 'rev_${revision.id}_${now.millisecondsSinceEpoch}',
            type: StudyLogType.revisionModuleCompleted,
            courseId: revision.courseId,
            courseTitle: _courseTitle,
            moduleId: revision.moduleId,
            moduleTitle: _moduleTitle,
            revisionLevel: revision.currentLevel,
            timestamp: now,
            createdAt: now,
          );
          await LocalStudyLogStorage.addLog(log);
          await LocalRevisionStorage.recordRevisionEvent(now);

          if (getIt.isRegistered<OngoingModulesController>()) {
            unawaited(getIt<OngoingModulesController>().refresh());
          }
          if (getIt.isRegistered<ProgressController>()) {
            unawaited(getIt<ProgressController>().refresh());
          }

          // Reset topics so they are ready for the "revise again" action
          final resetTopics = list.map((t) => t.copyWith(
            status: TopicStatus.notStarted,
            clearCompletedAt: true,
            updatedAt: DateTime.now(),
          )).toList();
          setState(() {
            _revisionTopics = resetTopics;
          });
          await LocalRevisionTopicStorage.saveTopics(revision.id, resetTopics);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'R${revision.currentLevel} completed — ready to revise again on ${_formatDate(revision.nextRevisionAt)}.',
                ),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            Navigator.of(context).pop();
          }
        },
      );
    }
  }

  Future<void> _resetTopicsForCurrentLevel({bool showFeedback = true}) async {
    final resetTopics = _revisionTopics.map((t) => t.copyWith(
      status: TopicStatus.notStarted,
      clearCompletedAt: true,
      updatedAt: DateTime.now(),
    )).toList();
    setState(() {
      _revisionTopics = resetTopics;
    });
    await LocalRevisionTopicStorage.saveTopics(widget.revision.id, resetTopics);

    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Topics reset — ready to revise again in R${_revision.currentLevel}'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  /// Explicitly completes the level the user is on and moves the ladder on.
  Future<void> _startCurrentLevel(Revision revision, {bool popOnComplete = false}) async {
    final level = revision.currentLevel;
    final advanced = await _controller.completeCurrentLevel(revision.id);
    if (!mounted || !advanced) return;

    if (getIt.isRegistered<OngoingModulesController>()) {
      unawaited(getIt<OngoingModulesController>().refresh());
    }
    if (getIt.isRegistered<ProgressController>()) {
      unawaited(getIt<ProgressController>().refresh());
    }

    final isNowFinished = _revision.isFinished;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowFinished
              ? 'R$level cleared — ladder complete'
              : 'R$level cleared — now on R${_revision.currentLevel}',
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (popOnComplete && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const VGapMd(),
                ListTile(
                  leading: Icon(
                    Icons.restart_alt_rounded,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  title: const Text('Reset to R1'),
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    await _controller.resetRevision(_revision.id);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.errorColor,
                  ),
                  title: const Text(
                    'Remove from revision',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    final confirmed = await StudyConfirmationDialog.showRemoveRevisionModule(
                      context,
                      moduleTitle: _moduleTitle,
                    );
                    if (confirmed && mounted) {
                      await _controller.deleteRevision(_revision.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleStartSession() async {
    final revision = _revision;
    // If all revision topics already completed, reset to start fresh from the first topic
    if (_revisionTopics.isNotEmpty && _revisionTopics.every((t) => t.isCompleted)) {
      await _resetTopicsForCurrentLevel(showFeedback: false);
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSetupScreen(
          courseTitle: _courseTitle,
          courseId: revision.courseId,
          moduleTitle: _moduleTitle,
          moduleId: revision.moduleId,
          topics: _revisionTopics
              .map((rt) => rt.toTopic(topic: _baseTopicsById[rt.topicId]))
              .toList(),
          revisionTopics: _revisionTopics,
          revisionId: revision.id,
          isRevision: true,
        ),
      ),
    );
    await _loadTopics();
    final allDone = (result == true) ||
        (result is Map && result['allCompleted'] == true) ||
        (_revisionTopics.isNotEmpty && _revisionTopics.every((t) => t.isCompleted));
    if (allDone && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showRevisionCompletionDialog();
        }
      });
    }
  }

  void _handleStartLevel() {
    _startCurrentLevel(_revision);
  }

  void _handleTabSelected(int index) {
    if (_activeTab.value != index) {
      _activeTab.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      floatingActionButton: _RevisionFAB(
        activeTab: _activeTab,
        hasTopics: _revisionTopics.isNotEmpty,
        onPressed: _handleStartSession,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final revision = _revision;
            return Column(
              children: [
                _RevisionHeaderSection(
                  courseTitle: _courseTitle,
                  moduleTitle: _moduleTitle,
                  revision: revision,
                  onBack: _handleBack,
                  onOptions: _openOptionsMenu,
                  onStartLevel: _handleStartLevel,
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _activeTab,
                  builder: (context, activeIdx, _) {
                    return _RevisionTabsRow(
                      activeIndex: activeIdx,
                      topicsCount: _revisionTopics.length,
                      onTabSelected: _handleTabSelected,
                    );
                  },
                ),
                const VGapSm(),
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _activeTab,
                    builder: (context, activeIdx, _) {
                      if (activeIdx == 1) {
                        return _RevisionLadderView(
                          revision: revision,
                          bottomPadding: bottomSafe + 24,
                        );
                      }
                      return _RevisionTopicsView(
                        topics: _revisionTopics,
                        baseTopicsById: _baseTopicsById,
                        revision: revision,
                        isLoading: _isLoadingTopics,
                        bottomPadding: bottomSafe + 84,
                        onToggle: _toggleTopicStatus,
                      );
                    },
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
  final ValueListenable<int> activeTab;
  final bool hasTopics;
  final VoidCallback onPressed;

  const _RevisionFAB({
    required this.activeTab,
    required this.hasTopics,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: activeTab,
      builder: (context, activeIdx, _) {
        if (activeIdx != 0 || !hasTopics) {
          return const SizedBox.shrink();
        }
        return FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const CircleBorder(),
          tooltip: 'Start Revision Session',
          child: const Icon(Icons.play_arrow_rounded, size: 28),
        );
      },
    );
  }
}

class _RevisionHeaderSection extends StatelessWidget {
  final String courseTitle;
  final String moduleTitle;
  final Revision revision;
  final VoidCallback onBack;
  final VoidCallback onOptions;
  final VoidCallback onStartLevel;

  const _RevisionHeaderSection({
    required this.courseTitle,
    required this.moduleTitle,
    required this.revision,
    required this.onBack,
    required this.onOptions,
    required this.onStartLevel,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = revision.isDueAt(DateTime.now()) && !revision.isFinished;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomAppBar(
          title: courseTitle.isNotEmpty ? courseTitle : 'REVISION',
          onBack: onBack,
          actions: [
            _RevisionLevelChip(
              currentLevel: revision.currentLevel,
              isFinished: revision.isFinished,
            ),
            const HGapXs(),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 6.0),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ModuleContextPill(
                    moduleTitle: moduleTitle,
                    courseId: revision.courseId,
                  ),
                ),
              ),
              if (isDue) ...[
                const HGapSm(),
                AddPillButton(
                  label: 'Start ${revision.levelLabel}',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onStartLevel,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: _RevisionMetaStrip(revision: revision),
        ),
      ],
    );
  }
}

class _RevisionLevelChip extends StatelessWidget {
  final int currentLevel;
  final bool isFinished;

  const _RevisionLevelChip({
    required this.currentLevel,
    required this.isFinished,
  });

  @override
  Widget build(BuildContext context) {
    final colors = isFinished
        ? RevisionLevelPalette.completed(context)
        : RevisionLevelPalette.of(context, currentLevel);
    final label = isFinished ? 'Completed' : 'R$currentLevel';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors.foreground,
        ),
      ),
    );
  }
}

/// Two-up strip under the hero: when the module was completed and when it was
/// last revised.
class _RevisionMetaStrip extends StatelessWidget {
  final Revision revision;

  const _RevisionMetaStrip({required this.revision});

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  @override
  Widget build(BuildContext context) {
    final lastRevision = revision.lastRevisionAt;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MetaItem(
            icon: Icons.task_alt_rounded,
            label: 'Completed',
            value: _formatDate(revision.createdAt),
          ),
        ),
        const _MetaDivider(),
        Expanded(
          child: _MetaItem(
            icon: Icons.history_rounded,
            label: 'Last revision',
            value: lastRevision != null ? _formatDate(lastRevision) : '-',
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? leading;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (leading != null) ...[
              leading!,
              const HGapXs(),
            ] else ...[
              Icon(icon, color: AppTheme.textSecondaryColor(context), size: 12),
              const HGapXs(),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor(context),
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const VGapXs(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppTheme.textPrimaryColor(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppTheme.borderColor(context),
    );
  }
}

class _RevisionTabsRow extends StatelessWidget {
  final int activeIndex;
  final int topicsCount;
  final ValueChanged<int> onTabSelected;

  const _RevisionTabsRow({
    required this.activeIndex,
    required this.topicsCount,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            _TabItem(
              label: 'Topics ($topicsCount)',
              isActive: activeIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            const HGapLg(),
            _TabItem(
              label: 'Progress',
              isActive: activeIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
          ),
        ),
      ),
    );
  }
}

/// Replaces the course page's module list with this module's revision topics.
///
/// Completely decoupled from course modules.
class _RevisionTopicsView extends StatelessWidget {
  final List<RevisionTopic> topics;
  final Map<String, Topic> baseTopicsById;
  final Revision revision;
  final bool isLoading;
  final double bottomPadding;
  final ValueChanged<int> onToggle;

  const _RevisionTopicsView({
    required this.topics,
    this.baseTopicsById = const {},
    required this.revision,
    required this.isLoading,
    required this.bottomPadding,
    required this.onToggle,
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

    final showEarlyBanner = !revision.isDueAt(DateTime.now()) && !revision.isFinished;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showEarlyBanner)
          RepaintBoundary(
            child: _OngoingCycleBanner(
              currentLevel: revision.currentLevel,
              nextRevisionAt: revision.nextRevisionAt,
            ),
          ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              final base = baseTopicsById[topic.topicId];
              return TopicListItem(
                key: ValueKey(topic.id),
                topic: topic.toTopic(topic: base),
                showCheckbox: true,
                showTrailing: false,
                onCheckboxTap: () => onToggle(index),
                onTap: () => onToggle(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shown on top before the topic list when revising before the scheduled revision date.
class _OngoingCycleBanner extends StatelessWidget {
  final int currentLevel;
  final DateTime nextRevisionAt;

  const _OngoingCycleBanner({
    required this.currentLevel,
    required this.nextRevisionAt,
  });

  @override
  Widget build(BuildContext context) {
    final palette = RevisionLevelPalette.of(context, currentLevel);
    final daysUntil = nextRevisionAt.difference(DateTime.now()).inDays;
    final dueText = daysUntil > 0
        ? 'in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}'
        : 'today';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.foreground.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.replay_rounded,
              size: 18,
              color: palette.foreground,
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Revise again in R$currentLevel',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: palette.foreground,
                  ),
                ),
                const VGapXs(),
                Text(
                  'Scheduled for ${_formatDate(nextRevisionAt)} ($dueText)',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';
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
              'No topics yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const VGapXs(),
            Text(
              'No topics have been added to this module yet.',
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

/// Bare R1 -> R5 timeline. No card wrapper, so it sits directly on the page
/// background. The "Start Rn" action lives in the hero, not here.
class _RevisionLadderView extends StatelessWidget {
  final Revision revision;
  final double bottomPadding;

  const _RevisionLadderView({
    required this.revision,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final maxLevel = RevisionSchedule.maxLevel;

    return ListView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: bottomPadding,
      ),
      children: [
        for (var level = 1; level <= maxLevel; level++)
          RepaintBoundary(
            key: ValueKey(level),
            child: _TimelineRow(
              level: level,
              revision: revision,
              isLast: level == maxLevel,
            ),
          ),
      ],
    );
  }
}

enum _StepState { cleared, current, upcoming }

class _TimelineRow extends StatelessWidget {
  final int level;
  final Revision revision;
  final bool isLast;

  const _TimelineRow({
    required this.level,
    required this.revision,
    required this.isLast,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  _StepState get _state {
    if (revision.isFinished) return _StepState.cleared;
    if (level < revision.currentLevel) return _StepState.cleared;
    if (level == revision.currentLevel) return _StepState.current;
    return _StepState.upcoming;
  }

  /// Every level is scheduled relative to the original completion date, not
  /// chained off the previous one.
  DateTime get _scheduledAt =>
      revision.createdAt.add(RevisionSchedule.intervalFor(level));

  static String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final isCleared = state == _StepState.cleared;
    final isCurrent = state == _StepState.current;

    final lineColor = isCleared
        ? AppTheme.successColor.withValues(alpha: 0.30)
        : isCurrent
            ? AppTheme.primaryColor.withValues(alpha: 0.25)
            : AppTheme.borderColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                _StatusIndicator(state: state),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'R$level',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCurrent
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const HGapXs(),
                      _StatusBadge(state: state),
                    ],
                  ),
                  const VGapXs(),
                  Row(
                    children: [
                      Text(
                        _formatDate(_scheduledAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Color(0xFFCBD0DB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        RevisionSchedule.intervalLabel(level),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final _StepState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _StepState.current:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _StepState.cleared:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.successColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.successColor.withValues(alpha: 0.35),
              width: 4,
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 11),
        );
      case _StepState.upcoming:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor(context), width: 2),
          ),
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final _StepState state;

  const _StatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;

    switch (state) {
      case _StepState.cleared:
        label = 'Cleared';
        bg = AppTheme.pastelGreen(context);
        fg = AppTheme.pastelGreenText(context);
        break;
      case _StepState.current:
        label = 'Pending';
        bg = AppTheme.pastelPurple(context);
        fg = AppTheme.pastelPurpleText(context);
        break;
      case _StepState.upcoming:
        label = 'Upcoming';
        bg = const Color(0xFFF3F4F6);
        fg = AppTheme.textSecondaryColor(context);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}


