import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/compact_list_item.dart';
import '../models/revision.dart';
import '../controllers/revision_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../services/service_locator.dart';

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

class _RevisionLevelConfig {
  final int level;
  final String label;
  final String interval;
  final RevisionLevelColors colors;

  const _RevisionLevelConfig({
    required this.level,
    required this.label,
    required this.interval,
    required this.colors,
  });
}

const List<({int level, String label, String interval})> _kLevelMeta = [
  (level: 1, label: 'R1', interval: '1 day'),
  (level: 2, label: 'R2', interval: '3 days'),
  (level: 3, label: 'R3', interval: '7 days'),
  (level: 4, label: 'R4', interval: '14 days'),
  (level: 5, label: 'R5', interval: '30 days'),
];

/// Level metadata joined with the shared theme-aware level colours.
List<_RevisionLevelConfig> _revisionLevelConfigs(BuildContext context) {
  return [
    for (final meta in _kLevelMeta)
      _RevisionLevelConfig(
        level: meta.level,
        label: meta.label,
        interval: meta.interval,
        colors: RevisionLevelPalette.of(context, meta.level),
      ),
  ];
}

/// Revision screen — a tracking list for the R1 -> R5 spaced repetition ladder.
///
/// Clean visual design with:
/// - Circular action buttons in top bar
/// - Horizontal level tabs showing intervals and count badges
/// - Section header showing active category with count and sort dropdown
/// - Modern white item cards with tech icon glyphs, level pill tags, and due status
/// - Play revision button and three-dot list item menu removed as requested.
class RevisionScreen extends StatefulWidget {
  final RevisionController revisionController;
  final VoidCallback? onBack;
  final void Function(Revision revision) onOpenRevision;

  const RevisionScreen({
    super.key,
    required this.revisionController,
    this.onBack,
    required this.onOpenRevision,
  });

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');

  int? _levelFilter;
  RevisionScope _scope = RevisionScope.all;
  RevisionSortMode _sortMode = RevisionSortMode.dueDate;
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    widget.revisionController.reconcile();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchQuery.value = _searchController.text.trim().toLowerCase();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible && _searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });
  }

  /// Filters, scopes and orders the records for the single list.
  List<Revision> _visibleRevisions(DateTime now) {
    final query = _searchQuery.value;
    final items = widget.revisionController.revisionsAtLevel(_levelFilter);
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;

    final filtered = items.where((r) {
      if (ongoing != null && r.moduleId.isNotEmpty) {
        final total = ongoing.topicCountForModule(r.moduleId);
        final done = ongoing.completedTopicCountForModule(r.moduleId);
        if (total > 0 && done < total) return false;
      }
      if (query.isNotEmpty) {
        final matches = r.moduleTitle.toLowerCase().contains(query) ||
            r.moduleDescription.toLowerCase().contains(query);
        if (!matches) return false;
      }
      switch (_scope) {
        case RevisionScope.all:
          return true;
        case RevisionScope.dueToday:
          return r.isDueAt(now);
        case RevisionScope.upcoming:
          return !r.isFinished && !r.isDueAt(now);
        case RevisionScope.finished:
          return r.isFinished;
      }
    }).toList();

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
          return a.moduleTitle.toLowerCase().compareTo(
                b.moduleTitle.toLowerCase(),
              );
        });
        break;
    }
    return filtered;
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

  void _handleSortChanged(RevisionSortMode mode) {
    setState(() => _sortMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _RevisionHeader(
              onBack: widget.onBack,
              isSearchVisible: _isSearchVisible,
              onSearchTap: _toggleSearch,
              onMenuAction: _handleTopMenuAction,
              scope: _scope,
            ),
            if (_isSearchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _RevisionSearchBar(controller: _searchController),
              ),
            ListenableBuilder(
              listenable: widget.revisionController,
              builder: (context, _) {
                return _RevisionLevelFilterRow(
                  selectedLevel: _levelFilter,
                  revisions: widget.revisionController.revisions,
                  onSelected: _handleLevelSelected,
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                widget.revisionController,
                _searchQuery,
              ]),
              builder: (context, _) {
                final now = DateTime.now();
                final revisions = _visibleRevisions(now);

                final String sectionTitle;
                final int sectionCount;

                if (_scope == RevisionScope.dueToday) {
                  sectionTitle = 'Due Today';
                  sectionCount = revisions.length;
                } else if (_levelFilter != null) {
                  sectionTitle = 'R$_levelFilter Revisions';
                  sectionCount = revisions.length;
                } else if (_scope == RevisionScope.upcoming) {
                  sectionTitle = 'Upcoming';
                  sectionCount = revisions.length;
                } else if (_scope == RevisionScope.finished) {
                  sectionTitle = 'Finished';
                  sectionCount = revisions.length;
                } else {
                  sectionTitle = 'All Revisions';
                  sectionCount = revisions.length;
                }

                return _RevisionSectionHeader(
                  title: sectionTitle,
                  count: sectionCount,
                  sortMode: _sortMode,
                  scope: _scope,
                  onSortChanged: _handleSortChanged,
                  onFilterPressed: _openFilterSheet,
                );
              },
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  widget.revisionController,
                  _searchQuery,
                ]),
                builder: (context, _) {
                  final revisions = _visibleRevisions(DateTime.now());

                  if (widget.revisionController.isLoading &&
                      widget.revisionController.revisions.isEmpty) {
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    );
                  }

                  if (revisions.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => widget.revisionController.reconcile(),
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: AppEmptyState(
                          icon: Icons.sync_rounded,
                          title: _emptyTitleFor(),
                          description: _emptyDescriptionFor(),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => widget.revisionController.reconcile(),
                    color: AppTheme.primaryColor,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        bottomSafe + 24,
                      ),
                      itemCount: revisions.length,
                      separatorBuilder: (_, __) => const VGapSm(),
                      itemBuilder: (context, index) {
                        final revision = revisions[index];
                        return _RevisionItemCard(
                          revision: revision,
                          onTap: () => widget.onOpenRevision(revision),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitleFor() {
    if (_searchQuery.value.isNotEmpty) return 'No matches found';
    switch (_scope) {
      case RevisionScope.all:
        return 'No revisions scheduled';
      case RevisionScope.dueToday:
        return 'Nothing due today';
      case RevisionScope.upcoming:
        return 'Nothing upcoming';
      case RevisionScope.finished:
        return 'No finished revisions';
    }
  }

  String _emptyDescriptionFor() {
    if (_searchQuery.value.isNotEmpty) {
      return 'Try a different search term or clear the R-level filter.';
    }
    switch (_scope) {
      case RevisionScope.all:
        return 'Finish all tasks in a module and tap "Add to Revision" '
            'to schedule spaced repetition here.';
      case RevisionScope.dueToday:
        return 'You are all caught up. Revisions appear here once their '
            'date arrives.';
      case RevisionScope.upcoming:
        return 'No revision is counting down right now.';
      case RevisionScope.finished:
        return 'Complete the R5 level of a ladder to see it here.';
    }
  }

  Future<void> _handleTopMenuAction(String action) async {
    if (action != 'showFinished') return;
    setState(() {
      _scope = _scope == RevisionScope.finished
          ? RevisionScope.all
          : RevisionScope.finished;
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<RevisionScope>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                onTap: () => Navigator.pop(ctx, scope),
                leading: Icon(
                  _scopeIconFor(scope),
                  color: scope == _scope
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor(context),
                  size: 20,
                ),
                title: Text(
                  scope.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        scope == _scope ? FontWeight.bold : FontWeight.w500,
                    color: scope == _scope
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor(context),
                  ),
                ),
                trailing: scope == _scope
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
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _scope = result);
  }

  static IconData _scopeIconFor(RevisionScope scope) {
    switch (scope) {
      case RevisionScope.all:
        return Icons.list_alt_rounded;
      case RevisionScope.dueToday:
        return Icons.today_rounded;
      case RevisionScope.upcoming:
        return Icons.schedule_rounded;
      case RevisionScope.finished:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class _RevisionHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final bool isSearchVisible;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onMenuAction;
  final RevisionScope scope;

  const _RevisionHeader({
    this.onBack,
    required this.isSearchVisible,
    required this.onSearchTap,
    required this.onMenuAction,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        onBack != null ? 8.0 : 20.0,
        16.0,
        20.0,
        8.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            AppBackButton(onPressed: onBack),
            const HGapXs(),
          ],
          Text(
            'Revision',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              isSearchVisible
                  ? Icons.close_rounded
                  : Icons.search_rounded,
              color: isSearchVisible
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimaryColor(context),
              size: 24,
            ),
            onPressed: onSearchTap,
            tooltip: isSearchVisible ? 'Close' : 'Search',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const HGapXs(),
          PopupMenuButton<String>(
            onSelected: onMenuAction,
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 24,
            ),
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'showFinished',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.textPrimaryColor(context),
                      size: 20,
                    ),
                    const HGapSm(),
                    Text(
                      scope == RevisionScope.finished
                          ? 'Show All Revisions'
                          : 'Show Finished Revisions',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevisionSearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _RevisionSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          const HGapSm(),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimaryColor(context),
              ),
              decoration: const InputDecoration(
                hintText: 'Search revisions...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal category filter row: All (12), R1 (1 day), R2 (3 days), R3 (7 days), etc.
class _RevisionLevelFilterRow extends StatelessWidget {
  final int? selectedLevel;
  final List<Revision> revisions;
  final ValueChanged<int?> onSelected;

  const _RevisionLevelFilterRow({
    required this.selectedLevel,
    required this.revisions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = revisions.length;

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        children: [
          _AllPillTab(
            isSelected: selectedLevel == null,
            count: totalCount,
            onTap: () => onSelected(null),
          ),
          for (final config in _revisionLevelConfigs(context))
            _LevelTabCard(
              config: config,
              count: revisions.where((r) => r.currentLevel == config.level).length,
              isSelected: selectedLevel == config.level,
              onTap: () => onSelected(config.level),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.pastelIndigo(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC7D2FE)
                  : AppTheme.borderColor(context),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            'All $count',
            style: TextStyle(
              fontSize: 13,
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
  final _RevisionLevelConfig config;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelTabCard({
    required this.config,
    required this.count,
    required this.isSelected,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? config.colors.background : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? config.colors.foreground : config.colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                config.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: config.colors.foreground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: config.colors.foreground,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

/// Section header row: Left title + count badge, Right sort dropdown + filter icon
class _RevisionSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final RevisionSortMode sortMode;
  final RevisionScope scope;
  final ValueChanged<RevisionSortMode> onSortChanged;
  final VoidCallback onFilterPressed;

  const _RevisionSectionHeader({
    required this.title,
    required this.count,
    required this.sortMode,
    required this.scope,
    required this.onSortChanged,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const HGapSm(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.pastelIndigo(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style:  TextStyle(
                fontSize: 13,
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
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF475569),
                  size: 20,
                ),
              ],
            ),
          ),
          const HGapSm(),
          Material(
            color: scope != RevisionScope.all
                ? AppTheme.pastelIndigo(context)
                : const Color(0xFFF1F5F9),
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
                        ? const Color(0xFFC7D2FE)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.tune_rounded,
                  color: scope != RevisionScope.all
                      ? AppTheme.pastelIndigoText(context)
                      : const Color(0xFF475569),
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

/// Item card for a revision:
/// - Rounded rectangular card
/// - Tech icon / glyph container
/// - Title with R-level pill tag
/// - Subtitle (course & description)
/// - Red clock with due status
/// - Play revision button & three-dot menu removed as requested.
class _RevisionItemCard extends StatelessWidget {
  final Revision revision;
  final VoidCallback onTap;

  const _RevisionItemCard({
    required this.revision,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = revision.daysUntilDue(now);
    final isDue = revision.isDueAt(now);
    final dueColor = _dueColor(context, days, isDue, revision);

    return CompactListItem(
      margin: EdgeInsets.zero,
      leading: CourseIconChip(
        courseId: revision.courseId,
        size: 38,
        radius: 10,
      ),
      title: revision.moduleTitle,
      titleBadge: _RevisionLevelPill(level: revision.currentLevel),
      courseName: _courseFor(revision),
      bottom: Row(
        children: [
          Icon(
            revision.isFinished
                ? Icons.check_circle_rounded
                : Icons.access_time_rounded,
            size: 13,
            color: isDue ? AppTheme.errorColor : dueColor,
          ),
          const HGapXs(),
          Flexible(
            child: Text(
              _dueLabel(days, isDue, revision),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDue ? AppTheme.errorColor : dueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  static String _courseFor(Revision revision) {
    final title = revision.courseTitle.trim();
    if (title.isNotEmpty) return title;
    if (getIt.isRegistered<CoursesController>()) {
      for (final c in getIt<CoursesController>().courses) {
        if (c.id == revision.courseId) return c.title;
      }
    }
    return '';
  }

  static String _dueLabel(int days, bool isDue, Revision revision) {
    if (revision.isFinished) return 'Completed';
    if (isDue) return days < 0 ? 'Overdue ${days.abs()}d' : 'Due today';
    if (days <= 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'In ${days}d';
  }

  static Color _dueColor(
      BuildContext context, int days, bool isDue, Revision revision) {
    if (revision.isFinished) return AppTheme.successColor;
    if (isDue) {
      return days < 0 ? const Color(0xFFDC2626) : AppTheme.errorColor;
    }
    return AppTheme.textSecondaryColor(context);
  }
}

/// Pill badge showing R1, R2, etc. next to the title
class _RevisionLevelPill extends StatelessWidget {
  final int level;

  const _RevisionLevelPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final configs = _revisionLevelConfigs(context);
    final config = configs.firstWhere(
      (c) => c.level == level,
      orElse: () => configs.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: config.colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: config.colors.border, width: 0.8),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: config.colors.foreground,
        ),
      ),
    );
  }
}
