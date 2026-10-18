import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
import '../widgets/tab_header.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/compact_list_item.dart';
import '../widgets/revision_options_sheet.dart';
import '../widgets/revision_interval_sheet.dart';
import '../widgets/topic_revision_card.dart';
import '../widgets/topic_options_sheet.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../controllers/revision_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';
import '../services/database_service.dart';
import 'session_setup_screen.dart';
import 'topic_detail_screen.dart';

/// Type filter in the revision stream: individual topics or topics grouped by module.
enum RevisionTypeFilter {
  topics('Topics'),
  modules('Modules');

  const RevisionTypeFilter(this.label);
  final String label;
}

/// How the continuous revision list is ordered.
enum RevisionSortMode {
  dueDate('Due Date'),
  level('Level'),
  name('Name');

  const RevisionSortMode(this.label);
  final String label;
}

/// Extra narrowing applied on top of the R1-R5 level chips.
enum RevisionScope {
  all('All'),
  dueToday('Due today'),
  upcoming('Upcoming'),
  finished('Finished');

  const RevisionScope(this.label);
  final String label;
}

/// Revision screen — tracking spaced repetition for individual Topics and whole Modules in a unified stream.
///
/// Features:
/// - Unified single stream: All due topic & module revisions appear together in chronological order
/// - Combined horizontal level ladder (All, R1..R5, Finished) with aggregated count badges
/// - Lightweight segmented type filter: [ All (N) ] [ Topics (N) ] [ Modules (N) ]
/// - Section header showing active category with count, sort dropdown (Due Date, Level, Name), and filter action
/// - Scope filter modal bottom sheet: [ All, Due today, Upcoming, Finished ] accessed via the tune filter button
/// - Stream group headers distinguishing Today's Revisions from Upcoming items
/// - Dedicated [TopicRevisionCard] and [_RevisionItemCard] with type badges and quick actions
class RevisionScreen extends StatefulWidget {
  final RevisionController revisionController;
  final TopicRevisionController? topicRevisionController;
  final VoidCallback? onBack;
  final void Function(Revision revision) onOpenRevision;

  const RevisionScreen({
    super.key,
    required this.revisionController,
    this.topicRevisionController,
    this.onBack,
    required this.onOpenRevision,
  });

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  RevisionTypeFilter _typeFilter = RevisionTypeFilter.topics;
  int? _levelFilter;
  RevisionScope _scope = RevisionScope.all;
  RevisionSortMode _sortMode = RevisionSortMode.dueDate;

  TopicRevisionController? get _topicRevisionController =>
      widget.topicRevisionController ??
      (getIt.isRegistered<TopicRevisionController>()
          ? getIt<TopicRevisionController>()
          : null);

  @override
  void initState() {
    super.initState();
    widget.revisionController.reconcile();
    _topicRevisionController?.refresh();
  }

  void _handleRevisionLongPress(Revision revision) {
    RevisionOptionsSheet.show(
      context,
      revision: revision,
      revisionController: widget.revisionController,
      onOpenRevision: widget.onOpenRevision,
    );
  }

  Future<void> _handleQuickCompleteModule(Revision moduleRev) async {
    final success =
        await widget.revisionController.completeCurrentLevel(moduleRev.id);
    if (success && mounted) {
      final next = moduleRev.currentLevel + 1;
      final msg = next > 5
          ? 'Module revision completed!'
          : 'Module moved to revision level R$next!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    }
  }

  Future<void> _handleOpenTopicDetail(TopicRevision topicRev) async {
    final courseTitle = TopicRevisionCard.courseTitleFor(topicRev);
    final moduleTitle = TopicRevisionCard.moduleTitleFor(topicRev);

    Topic? topic;
    try {
      final db = getIt.isRegistered<DatabaseService>()
          ? getIt<DatabaseService>()
          : DatabaseService.instance;
      final topics = await db.getTopics(moduleId: topicRev.moduleId);
      topic = topics.where((t) => t.id == topicRev.topicId).firstOrNull;
    } catch (_) {}

    topic ??= Topic(
      id: topicRev.topicId,
      courseId: topicRev.courseId,
      moduleId: topicRev.moduleId,
      title: topicRev.title,
      status: TopicStatus.inProgress,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TopicDetailScreen(
          topic: topic!,
          moduleTitle: moduleTitle,
          courseTitle: courseTitle,
          courseId: topicRev.courseId,
          moduleId: topicRev.moduleId,
        ),
      ),
    );
  }

  void _handleOpenTopicSession(TopicRevision topicRev) {
    final courseTitle = TopicRevisionCard.courseTitleFor(topicRev);
    final moduleTitle = TopicRevisionCard.moduleTitleFor(topicRev);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSetupScreen(
          courseTitle: courseTitle,
          courseId: topicRev.courseId,
          moduleTitle: moduleTitle,
          moduleId: topicRev.moduleId,
          topics: [
            Topic(
              id: topicRev.topicId,
              courseId: topicRev.courseId,
              moduleId: topicRev.moduleId,
              title: topicRev.title,
              status: TopicStatus.completed,
            ),
          ],
          isRevision: true,
          revisionId: topicRev.id,
        ),
      ),
    );
  }

  Future<void> _handleQuickCompleteTopic(TopicRevision topicRev) async {
    final topicCtrl = _topicRevisionController;
    if (topicCtrl == null) return;
    final success = await topicCtrl.completeCurrentLevel(topicRev.id);
    if (success && mounted) {
      final next = topicRev.currentLevel + 1;
      final msg = next > 5
          ? '"${topicRev.title}" marked mastered!'
          : '"${topicRev.title}" moved to revision level R$next!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    }
  }

  void _handleTopicLongPress(TopicRevision topicRev) {
    final courseTitle = TopicRevisionCard.courseTitleFor(topicRev);
    final moduleTitle = TopicRevisionCard.moduleTitleFor(topicRev);

    TopicOptionsSheet.show(
      context,
      topic: Topic(
        id: topicRev.topicId,
        courseId: topicRev.courseId,
        moduleId: topicRev.moduleId,
        title: topicRev.title,
        status: TopicStatus.completed,
      ),
      moduleTitle: moduleTitle,
      courseTitle: courseTitle,
      courseId: topicRev.courseId,
      moduleId: topicRev.moduleId,
    );
  }

  void _handleTypeFilterChanged(RevisionTypeFilter filter) {
    if (_typeFilter != filter) {
      setState(() => _typeFilter = filter);
    }
  }

  void _handleLevelSelected(int? level) {
    setState(() {
      if (_levelFilter == level) {
        _levelFilter = null;
      } else {
        _levelFilter = level;
      }
    });
  }

  void _handleScopeChanged(RevisionScope scope) {
    if (_scope != scope) {
      setState(() => _scope = scope);
    }
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<RevisionScope>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RevisionFilterSheet(
        currentScope: _scope,
        onSelectScope: (scope) => Navigator.pop(ctx, scope),
      ),
    );
    if (result == null || !mounted) return;
    _handleScopeChanged(result);
  }

  void _handleSortChanged(RevisionSortMode mode) {
    setState(() => _sortMode = mode);
  }

  /// Single-pass ingestion, filtering, and metric calculation for the revision stream.
  _RevisionStreamState _computeStreamState(DateTime now) {
    final topicCtrl = _topicRevisionController;
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;

    final List<UnifiedRevisionItem> allItems = [];

    // 1. Ingest Topic Revisions
    int activeTopicsCount = 0;
    int finishedTopicsCount = 0;
    final topicLevelCounts = <int, int>{};
    if (topicCtrl != null) {
      for (final tr in topicCtrl.scheduledTopics) {
        if (tr.isFinished) {
          finishedTopicsCount++;
        } else {
          activeTopicsCount++;
          topicLevelCounts[tr.currentLevel] =
              (topicLevelCounts[tr.currentLevel] ?? 0) + 1;
        }
        if (_typeFilter == RevisionTypeFilter.topics) {
          allItems.add(UnifiedTopicRevisionItem(tr));
        }
      }
    }

    // 2. Ingest Modules (topics grouped by module roll-up)
    int activeModulesCount = 0;
    int finishedModulesCount = 0;
    final moduleLevelCounts = <int, int>{};
    for (final r in widget.revisionController.revisions) {
      if (r.isFinished) {
        finishedModulesCount++;
      } else {
        activeModulesCount++;
        moduleLevelCounts[r.currentLevel] =
            (moduleLevelCounts[r.currentLevel] ?? 0) + 1;
      }
      if (_typeFilter == RevisionTypeFilter.modules) {
        final title = ongoing?.moduleTitleFor(r.moduleId) ?? '';
        final topicCount = ongoing?.topicCountForModule(r.moduleId) ?? 0;
        allItems.add(UnifiedModuleRevisionItem(
          r,
          resolvedTitle: title,
          topicCount: topicCount,
        ));
      }
    }

    // 3. Level Counts based on active type filter (Topics or Modules)
    final int activeTotal;
    final int finishedTotal;
    final Map<int, int> aggregatedLevelCounts = {};

    if (_typeFilter == RevisionTypeFilter.topics) {
      activeTotal = activeTopicsCount;
      finishedTotal = finishedTopicsCount;
      aggregatedLevelCounts.addAll(topicLevelCounts);
    } else {
      activeTotal = activeModulesCount;
      finishedTotal = finishedModulesCount;
      aggregatedLevelCounts.addAll(moduleLevelCounts);
    }

    // 4. Compute scope counts based on current type and level filters
    int dueTodayCount = 0;
    int upcomingCount = 0;
    for (final item in allItems) {
      if (_levelFilter != null) {
        if (_levelFilter == 6 && !item.isFinished) continue;
        if (_levelFilter != 6 &&
            (item.isFinished || item.currentLevel != _levelFilter)) {
          continue;
        }
      } else {
        if (item.isFinished) continue;
      }

      if (item.isDueAt(now)) {
        dueTodayCount++;
      } else {
        upcomingCount++;
      }
    }

    // 5. Filter by level and scope
    final filtered = allItems.where((item) {
      if (_levelFilter == 6 || _scope == RevisionScope.finished) {
        if (!item.isFinished) return false;
      } else if (_levelFilter != null) {
        if (item.isFinished || item.currentLevel != _levelFilter) return false;
      } else {
        if (item.isFinished && _scope != RevisionScope.finished) return false;
      }

      switch (_scope) {
        case RevisionScope.all:
          return true;
        case RevisionScope.dueToday:
          return item.isDueAt(now);
        case RevisionScope.upcoming:
          return !item.isFinished && !item.isDueAt(now);
        case RevisionScope.finished:
          return item.isFinished;
      }
    }).toList();

    // 6. Sort
    switch (_sortMode) {
      case RevisionSortMode.dueDate:
        filtered.sort((a, b) {
          if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
          return a.nextRevisionAt.compareTo(b.nextRevisionAt);
        });
        break;
      case RevisionSortMode.level:
        filtered.sort((a, b) {
          if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
          final byLevel = a.currentLevel.compareTo(b.currentLevel);
          if (byLevel != 0) return byLevel;
          return a.nextRevisionAt.compareTo(b.nextRevisionAt);
        });
        break;
      case RevisionSortMode.name:
        filtered.sort((a, b) {
          if (a.isFinished != b.isFinished) return a.isFinished ? 1 : -1;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }

    return _RevisionStreamState(
      visibleItems: filtered,
      activeTopicsCount: activeTopicsCount,
      finishedTopicsCount: finishedTopicsCount,
      activeModulesCount: activeModulesCount,
      finishedModulesCount: finishedModulesCount,
      dueTodayCount: dueTodayCount,
      upcomingCount: upcomingCount,
      aggregatedLevelCounts: aggregatedLevelCounts,
      activeTotal: activeTotal,
      finishedTotal: finishedTotal,
    );
  }

  /// Converts a filtered list of items into row entries with optional group headers.
  List<_StreamRowEntry> _buildRowEntries(
    List<UnifiedRevisionItem> items,
    DateTime now,
  ) {
    if (items.isEmpty) return const [];

    if (_scope == RevisionScope.all &&
        _sortMode == RevisionSortMode.dueDate &&
        _levelFilter != 6) {
      final dueItems = <UnifiedRevisionItem>[];
      final upcomingItems = <UnifiedRevisionItem>[];

      for (final item in items) {
        if (item.isDueAt(now)) {
          dueItems.add(item);
        } else {
          upcomingItems.add(item);
        }
      }

      if (dueItems.isNotEmpty && upcomingItems.isNotEmpty) {
        final entries = <_StreamRowEntry>[];
        entries.add(_HeaderRowEntry(
          title: "Today's Revisions",
          count: dueItems.length,
          icon: Icons.today_rounded,
          color: AppTheme.errorColor,
        ));
        for (final item in dueItems) {
          entries.add(_ItemRowEntry(item));
        }
        entries.add(_HeaderRowEntry(
          title: 'Upcoming',
          count: upcomingItems.length,
          icon: Icons.schedule_rounded,
        ));
        for (final item in upcomingItems) {
          entries.add(_ItemRowEntry(item));
        }
        return entries;
      }
    }

    return items.map((item) => _ItemRowEntry(item)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topicCtrl = _topicRevisionController;
    final Listenable mergedListenable = topicCtrl != null
        ? Listenable.merge([widget.revisionController, topicCtrl])
        : widget.revisionController;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const _RevisionTabHeader(),
            Expanded(
              child: ListenableBuilder(
                listenable: mergedListenable,
                builder: (context, _) => _buildStreamBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamBody(BuildContext context) {
    final now = DateTime.now();
    final state = _computeStreamState(now);
    final topicCtrl = _topicRevisionController;

    final String typeLabel = switch (_typeFilter) {
      RevisionTypeFilter.topics => 'Topics',
      RevisionTypeFilter.modules => 'Modules',
    };

    final String sectionTitle;
    if (_levelFilter == 6) {
      sectionTitle = 'Finished $typeLabel';
    } else if (_levelFilter != null) {
      sectionTitle = 'R$_levelFilter $typeLabel';
    } else if (_scope == RevisionScope.dueToday) {
      sectionTitle = 'Due Today ($typeLabel)';
    } else if (_scope == RevisionScope.upcoming) {
      sectionTitle = 'Upcoming $typeLabel';
    } else if (_scope == RevisionScope.finished) {
      sectionTitle = 'Finished $typeLabel';
    } else {
      sectionTitle = typeLabel;
    }

    final bool isInitialLoading =
        (topicCtrl != null &&
            topicCtrl.isLoading &&
            topicCtrl.scheduledTopics.isEmpty) ||
        (widget.revisionController.isLoading &&
            widget.revisionController.revisions.isEmpty);

    final entries = _buildRowEntries(state.visibleItems, now);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        _RevisionLevelFilterRow(
          selectedLevel: _levelFilter,
          activeTotalCount: state.activeTotal,
          finishedTotalCount: state.finishedTotal,
          levelCounts: state.aggregatedLevelCounts,
          onSelected: _handleLevelSelected,
        ),
        const VGapXs(),
        _RevisionSectionHeader(
          typeFilter: _typeFilter,
          title: sectionTitle,
          count: state.visibleItems.length,
          topicsCount: state.activeTopicsCount,
          modulesCount: state.activeModulesCount,
          sortMode: _sortMode,
          scope: _scope,
          onTypeChanged: _handleTypeFilterChanged,
          onSortChanged: _handleSortChanged,
          onFilterPressed: _openFilterSheet,
        ),
        Expanded(
          child: isInitialLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : state.visibleItems.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: AppEmptyState(
                          icon: Icons.sync_rounded,
                          title: _emptyTitleFor(),
                          description: _emptyDescriptionFor(),
                          showCard: false,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: AppTheme.primaryColor,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          2,
                          16,
                          bottomSafe + 100,
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, index) {
                          final next = entries[index + 1];
                          if (next is _HeaderRowEntry) {
                            return const VGapMd();
                          }
                          return const VGapSm();
                        },
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          switch (entry) {
                            case _HeaderRowEntry():
                              return _RevisionGroupHeader(
                                title: entry.title,
                                count: entry.count,
                                icon: entry.icon,
                                color: entry.color,
                              );
                            case _ItemRowEntry(:final item):
                              if (item is UnifiedTopicRevisionItem) {
                                final topicRev = item.topicRevision;
                                return TopicRevisionCard(
                                  key: ValueKey('topic_${topicRev.id}'),
                                  revision: topicRev,
                                  onTap: () => _handleOpenTopicDetail(topicRev),
                                  onRevise: () =>
                                      _handleOpenTopicSession(topicRev),
                                  onQuickComplete: () =>
                                      _handleQuickCompleteTopic(topicRev),
                                  onLongPress: () =>
                                      _handleTopicLongPress(topicRev),
                                  onOptionsTap: () =>
                                      _handleTopicLongPress(topicRev),
                                );
                              } else if (item is UnifiedModuleRevisionItem) {
                                final moduleRev = item.moduleRevision;
                                return _RevisionItemCard(
                                  key: ValueKey('module_${moduleRev.id}'),
                                  revision: moduleRev,
                                  topicCount: item.topicCount,
                                  onTap: () => widget.onOpenRevision(moduleRev),
                                  onQuickComplete: () =>
                                      _handleQuickCompleteModule(moduleRev),
                                  onLongPress: () =>
                                      _handleRevisionLongPress(moduleRev),
                                );
                              }
                              return const SizedBox.shrink();
                          }
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Future<void> _handleRefresh() async {
    final futures = <Future>[];
    final topicCtrl = _topicRevisionController;
    if (topicCtrl != null) futures.add(topicCtrl.refresh());
    futures.add(widget.revisionController.reconcile());
    await Future.wait(futures);
  }

  String _emptyTitleFor() {
    final type = _typeFilter == RevisionTypeFilter.topics
        ? 'topic revisions'
        : 'module revisions';
    if (_levelFilter == 6) return 'No finished $type';
    if (_levelFilter != null) return 'No R$_levelFilter $type';
    switch (_scope) {
      case RevisionScope.all:
        return 'No $type scheduled';
      case RevisionScope.dueToday:
        return 'Nothing due today';
      case RevisionScope.upcoming:
        return 'Nothing upcoming';
      case RevisionScope.finished:
        return 'No finished $type';
    }
  }

  String _emptyDescriptionFor() {
    final type = _typeFilter == RevisionTypeFilter.topics
        ? 'topics'
        : 'modules';
    if (_levelFilter == 6) {
      return 'Complete the R5 level of any $type to see them here.';
    }
    if (_levelFilter != null) {
      return 'Revisions appear here when they reach level R$_levelFilter.';
    }
    switch (_scope) {
      case RevisionScope.all:
        return _typeFilter == RevisionTypeFilter.topics
            ? 'Add topics to Revision to start spaced repetition.'
            : 'Add modules with topics to Revision to start spaced repetition.';
      case RevisionScope.dueToday:
        return 'You are all caught up! Revisions appear here once their scheduled date arrives.';
      case RevisionScope.upcoming:
        return 'No revisions are currently counting down.';
      case RevisionScope.finished:
        return 'Complete the R5 level of any $type to see them here.';
    }
  }
}



/// Horizontal category filter row: All (12), R1 (Purple), R2 (Blue), R3 (Teal), R4 (Orange), R5 (Coral), Finished (Green)
class _RevisionLevelFilterRow extends StatelessWidget {
  final int? selectedLevel;
  final int activeTotalCount;
  final int finishedTotalCount;
  final Map<int, int> levelCounts;
  final ValueChanged<int?> onSelected;

  const _RevisionLevelFilterRow({
    required this.selectedLevel,
    required this.activeTotalCount,
    required this.finishedTotalCount,
    required this.levelCounts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        children: [
          _AllPillTab(
            isSelected: selectedLevel == null,
            count: activeTotalCount,
            onTap: () => onSelected(null),
          ),
          for (final level in RevisionLevelPalette.levels)
            _LevelTabCard(
              level: level,
              count: levelCounts[level] ?? 0,
              isSelected: selectedLevel == level,
              onTap: () => onSelected(level),
            ),
          _FinishedTabCard(
            count: finishedTotalCount,
            isSelected: selectedLevel == 6,
            onTap: () => onSelected(6),
          ),
        ],
      ),
    );
  }
}

class _AllPillTab extends StatelessWidget {
  final bool isSelected;
  final int count;
  final VoidCallback onTap;

  const _AllPillTab({
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.pastelIndigo(context)
                : AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.pastelIndigoBorder(context)
                  : AppTheme.borderColor(context),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            'All $count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppTheme.pastelIndigoText(context)
                  : AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTabCard extends StatelessWidget {
  final int level;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelTabCard({
    required this.level,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = RevisionLevelPalette.of(context, level);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.background
                : colors.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.foreground : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'R$level',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  height: 16,
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors.foreground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDark ? const Color(0xFF0F0F14) : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedTabCard extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FinishedTabCard({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = RevisionLevelPalette.completed(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.background
                : colors.background.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colors.foreground : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Finished',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  height: 16,
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors.foreground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.isDark ? const Color(0xFF0F0F14) : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header row: Left type dropdown (All / Topics / Modules) + count badge, Right sort dropdown + filter icon
class _RevisionSectionHeader extends StatelessWidget {
  final RevisionTypeFilter typeFilter;
  final String title;
  final int count;
  final int topicsCount;
  final int modulesCount;
  final RevisionSortMode sortMode;
  final RevisionScope scope;
  final ValueChanged<RevisionTypeFilter> onTypeChanged;
  final ValueChanged<RevisionSortMode> onSortChanged;
  final VoidCallback onFilterPressed;

  const _RevisionSectionHeader({
    required this.typeFilter,
    required this.title,
    required this.count,
    required this.topicsCount,
    required this.modulesCount,
    required this.sortMode,
    required this.scope,
    required this.onTypeChanged,
    required this.onSortChanged,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          PopupMenuButton<RevisionTypeFilter>(
            initialValue: typeFilter,
            onSelected: onTypeChanged,
            position: PopupMenuPosition.under,
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: RevisionTypeFilter.topics,
                child: _TypeMenuItem(
                  icon: Icons.topic_outlined,
                  title: 'Topics',
                  count: topicsCount,
                  isSelected: typeFilter == RevisionTypeFilter.topics,
                ),
              ),
              PopupMenuItem(
                value: RevisionTypeFilter.modules,
                child: _TypeMenuItem(
                  icon: Icons.folder_outlined,
                  title: 'Modules',
                  count: modulesCount,
                  isSelected: typeFilter == RevisionTypeFilter.modules,
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const HGapXs(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 20,
                ),
              ],
            ),
          ),
          const HGapSm(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.pastelIndigo(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.pastelIndigoText(context),
              ),
            ),
          ),
          const Spacer(),
          PopupMenuButton<RevisionSortMode>(
            initialValue: sortMode,
            onSelected: onSortChanged,
            position: PopupMenuPosition.under,
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: AppTheme.shadowColor(context),
            itemBuilder: (ctx) => [
              for (final mode in RevisionSortMode.values)
                PopupMenuItem<RevisionSortMode>(
                  value: mode,
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          mode == sortMode ? FontWeight.bold : FontWeight.w500,
                      color: mode == sortMode
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sortMode.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const HGapXs(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondaryColor(context),
                  size: 18,
                ),
              ],
            ),
          ),
          const HGapSm(),
          Material(
            color: scope != RevisionScope.all
                ? AppTheme.pastelIndigo(context)
                : AppTheme.surfaceVariant(context),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onFilterPressed,
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scope != RevisionScope.all
                        ? AppTheme.pastelIndigoBorder(context)
                        : AppTheme.borderColor(context),
                    width: 0.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.tune_rounded,
                  color: scope != RevisionScope.all
                      ? AppTheme.pastelIndigoText(context)
                      : AppTheme.textSecondaryColor(context),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final bool isSelected;

  const _TypeMenuItem({
    required this.icon,
    required this.title,
    required this.count,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.textSecondaryColor(context),
        ),
        const HGapSm(),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.pastelIndigo(context)
                : AppTheme.surfaceVariant(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? AppTheme.pastelIndigoText(context)
                  : AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
        if (isSelected) ...[
          const HGapSm(),
          const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );
  }
}

/// Modal bottom sheet for filtering revisions by scope (All, Due today, Upcoming, Finished).
class _RevisionFilterSheet extends StatelessWidget {
  final RevisionScope currentScope;
  final ValueChanged<RevisionScope> onSelectScope;

  const _RevisionFilterSheet({
    required this.currentScope,
    required this.onSelectScope,
  });

  static IconData scopeIconFor(RevisionScope scope) {
    switch (scope) {
      case RevisionScope.all:
        return Icons.table_chart_outlined;
      case RevisionScope.dueToday:
        return Icons.today_rounded;
      case RevisionScope.upcoming:
        return Icons.schedule_rounded;
      case RevisionScope.finished:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VGapSm(),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const VGapMd(),
          Text(
            'Filter revisions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const VGapSm(),
          for (final scope in RevisionScope.values)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () => onSelectScope(scope),
              leading: Icon(
                scopeIconFor(scope),
                color: scope == currentScope
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor(context),
                size: 20,
              ),
              title: Text(
                scope.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      scope == currentScope ? FontWeight.bold : FontWeight.w500,
                  color: scope == currentScope
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimaryColor(context),
                ),
              ),
              trailing: scope == currentScope
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppTheme.primaryColor,
                      size: 18,
                    )
                  : null,
            ),
          const VGapSm(),
        ],
      ),
    );
  }
}

/// Static tab header for the Revision Screen.
class _RevisionTabHeader extends StatelessWidget {
  const _RevisionTabHeader();

  @override
  Widget build(BuildContext context) {
    return TabHeader(
      title: 'Revision',
      subtitle: 'Review due & upcoming topics',
      actions: [
        IconButton(
          icon: Icon(
            Icons.info_outline_rounded,
            color: AppTheme.textSecondaryColor(context),
            size: 22,
          ),
          onPressed: () => RevisionIntervalSheet.show(context),
          tooltip: 'Revision Intervals',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }
}

/// Visual group header separating due today revisions and upcoming revisions.
class _RevisionGroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color? color;

  const _RevisionGroupHeader({
    required this.title,
    required this.count,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textSecondaryColor(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const HGapXs(),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: effectiveColor,
            ),
          ),
          const HGapXs(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: effectiveColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Holds metrics and visible items for the revision stream.
class _RevisionStreamState {
  final List<UnifiedRevisionItem> visibleItems;
  final int activeTopicsCount;
  final int finishedTopicsCount;
  final int activeModulesCount;
  final int finishedModulesCount;
  final int dueTodayCount;
  final int upcomingCount;
  final Map<int, int> aggregatedLevelCounts;
  final int activeTotal;
  final int finishedTotal;

  const _RevisionStreamState({
    required this.visibleItems,
    required this.activeTopicsCount,
    required this.finishedTopicsCount,
    required this.activeModulesCount,
    required this.finishedModulesCount,
    required this.dueTodayCount,
    required this.upcomingCount,
    required this.aggregatedLevelCounts,
    required this.activeTotal,
    required this.finishedTotal,
  });
}

sealed class _StreamRowEntry {
  const _StreamRowEntry();
}

class _HeaderRowEntry extends _StreamRowEntry {
  final String title;
  final int count;
  final IconData icon;
  final Color? color;

  const _HeaderRowEntry({
    required this.title,
    required this.count,
    required this.icon,
    this.color,
  });
}

class _ItemRowEntry extends _StreamRowEntry {
  final UnifiedRevisionItem item;

  const _ItemRowEntry(this.item);
}

/// Item card for a module revision:
/// - Leading course icon chip
/// - Title with [Module] type pill and [R-level] pill
/// - Course name and topic count breadcrumb
/// - Red clock with due status
/// - Primary "Open" action button and quick "Complete" checkmark when due
class _RevisionItemCard extends StatelessWidget {
  final Revision revision;
  final int topicCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onQuickComplete;

  const _RevisionItemCard({
    super.key,
    required this.revision,
    this.topicCount = 0,
    required this.onTap,
    this.onLongPress,
    this.onQuickComplete,
  });

  @override
  Widget build(BuildContext context) {
    final (completedCount, totalCount) = _resolveCounts(revision, topicCount);
    final isAllCompleted =
        revision.isFinished || (totalCount > 0 && completedCount == totalCount);
    final progressLabel = totalCount == 1
        ? '$completedCount/$totalCount topic'
        : '$completedCount/$totalCount topics';

    return CompactListItem(
      margin: EdgeInsets.zero,
      leading: CourseIconChip(
        courseId: revision.courseId,
        size: 38,
        radius: 10,
      ),
      title: _moduleTitleFor(revision),
      courseName: _courseFor(revision),
      bottom: Row(
        children: [
          Icon(
            isAllCompleted
                ? Icons.check_circle_rounded
                : Icons.checklist_rounded,
            size: 13,
            color: isAllCompleted
                ? AppTheme.successColor
                : AppTheme.textSecondaryColor(context),
          ),
          const HGapXs(),
          Expanded(
            child: Text(
              progressLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isAllCompleted
                    ? AppTheme.successColor
                    : AppTheme.textSecondaryColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _RevisionLevelPill(
            level: revision.currentLevel,
            isFinished: revision.isFinished,
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  static (int, int) _resolveCounts(Revision revision, int fallbackTotal) {
    if (getIt.isRegistered<TopicRevisionController>()) {
      final topics = getIt<TopicRevisionController>()
          .topicRevisions
          .where((tr) => tr.moduleId == revision.moduleId)
          .toList();
      if (topics.isNotEmpty) {
        final completed = topics
            .where(
                (t) => t.levelStatus == TopicStatus.completed || t.isFinished)
            .length;
        return (completed, topics.length);
      }
    }
    final total = fallbackTotal > 0
        ? fallbackTotal
        : (revision.totalTopicsCount > 0
            ? revision.totalTopicsCount
            : (getIt.isRegistered<OngoingModulesController>()
                ? getIt<OngoingModulesController>()
                    .topicCountForModule(revision.moduleId)
                : 0));
    final completed = revision.isFinished ? total : 0;
    return (completed, total);
  }

  static String _moduleTitleFor(Revision revision) {
    if (getIt.isRegistered<OngoingModulesController>()) {
      return getIt<OngoingModulesController>().moduleTitleFor(revision.moduleId);
    }
    return '';
  }

  static String _courseFor(Revision revision) {
    if (getIt.isRegistered<CoursesController>()) {
      final course = getIt<CoursesController>().getCourseById(revision.courseId);
      if (course != null && course.title.isNotEmpty) return course.title;
    }
    return '';
  }
}

/// Pill badge showing R1, R2, etc. next to the title with distinct color coding
class _RevisionLevelPill extends StatelessWidget {
  final int level;
  final bool isFinished;

  const _RevisionLevelPill({
    required this.level,
    this.isFinished = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = isFinished
        ? RevisionLevelPalette.completed(context)
        : RevisionLevelPalette.of(context, level);

    final label = isFinished ? 'Completed' : 'R$level';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border, width: 0.8),
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
