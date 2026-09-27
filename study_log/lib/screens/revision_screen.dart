import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_icon_chip.dart';
import '../models/revision.dart';
import '../controllers/revision_controller.dart';

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
  final VoidCallback onBack;
  final void Function(Revision revision) onOpenRevision;

  const RevisionScreen({
    super.key,
    required this.revisionController,
    required this.onBack,
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

    final filtered = items.where((r) {
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
            _RevisionTopBar(
              onBack: widget.onBack,
              isSearchActive: _isSearchVisible,
              onSearchTap: _toggleSearch,
              onMenuAction: _handleTopMenuAction,
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
                final dueCount = revisions.where((r) => r.isDueAt(now)).length;

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
                  if (dueCount > 0) {
                    sectionTitle = 'Due Today';
                    sectionCount = dueCount;
                  } else {
                    sectionTitle = 'All Revisions';
                    sectionCount = revisions.length;
                  }
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
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: AppEmptyState(
                        icon: Icons.sync_rounded,
                        title: _emptyTitleFor(),
                        description: _emptyDescriptionFor(),
                      ),
                    );
                  }

                  return ListView.separated(
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
        return 'Finish every topic in a module and its revision ladder '
            'starts automatically at R1.';
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

/// Top header matching the reference design:
/// Circular back button, bold title, circular search, circular overflow menu.
class _RevisionTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSearchTap;
  final bool isSearchActive;
  final ValueChanged<String> onMenuAction;

  const _RevisionTopBar({
    required this.onBack,
    required this.onSearchTap,
    required this.isSearchActive,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 26,
                ),
              ),
            ),
          ),
          const HGapMd(),
          Text(
            'Revision',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Material(
            color: isSearchActive
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSearchTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSearchActive
                        ? AppTheme.primaryColor
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isSearchActive
                      ? Icons.close_rounded
                      : Icons.search_rounded,
                  color: isSearchActive
                      ? AppTheme.primaryColor
                      : const Color(0xFF334155),
                  size: 20,
                ),
              ),
            ),
          ),
          const HGapSm(),
          PopupMenuButton<String>(
            onSelected: onMenuAction,
            color: AppTheme.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
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
                    HGapMd(),
                    Text(
                      'Toggle finished',
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
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF334155),
                size: 20,
              ),
            ),
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
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: isSelected ? AppTheme.pastelIndigo(context) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFC7D2FE)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 1.4 : 1.0,
              ),
            ),
            child: Text(
              'All ($count)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppTheme.pastelIndigoText(context)
                    : const Color(0xFF64748B),
              ),
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
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: config.colors.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? config.colors.foreground : config.colors.border,
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      config.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: config.colors.foreground,
                      ),
                    ),
                    const HGapXs(),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: config.colors.foreground,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const VGapXs(),
                Text(
                  config.interval,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
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

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor(context),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RevisionIconBox(
                  courseId: revision.courseId,
                  moduleTitle: revision.moduleTitle,
                  courseTitle: revision.courseTitle,
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              revision.moduleTitle,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor(context),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const HGapSm(),
                          _RevisionLevelPill(level: revision.currentLevel),
                        ],
                      ),
                      const VGapXs(),
                      Text(
                        _subtitleFor(revision),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondaryColor(context),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
                        children: [
                          Icon(
                            revision.isFinished
                                ? Icons.check_circle_rounded
                                : Icons.access_time_rounded,
                            size: 15,
                            color: isDue ?  AppTheme.errorColor : dueColor,
                          ),
                          const HGapXs(),
                          Flexible(
                            child: Text(
                              _dueLabel(days, isDue, revision),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDue ?  AppTheme.errorColor : dueColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitleFor(Revision revision) {
    final description = revision.moduleDescription.trim();
    if (description.isNotEmpty) return description;
    return revision.courseTitle.trim();
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

/// Rounded icon box for a module/course with tech-specific glyphs
class _RevisionIconBox extends StatelessWidget {
  final String courseId;
  final String moduleTitle;
  final String courseTitle;

  const _RevisionIconBox({
    required this.courseId,
    required this.moduleTitle,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final lower = '${moduleTitle.toLowerCase()} ${courseTitle.toLowerCase()}';

    if (lower.contains('java') || lower.contains('spring')) {
      return _buildBox(
        icon: Icons.coffee_rounded,
        bg: const Color(0xFFFFF1F2),
        fg:  AppTheme.errorColor,
        border: const Color(0xFFFEE2E2),
      );
    }
    if (lower.contains('docker') ||
        lower.contains('container') ||
        lower.contains('k8s') ||
        lower.contains('kubernetes')) {
      return _buildBox(
        icon: Icons.directions_boat_rounded,
        bg: const Color(0xFFEFF6FF),
        fg: const Color(0xFF2563EB),
        border: const Color(0xFFDBEAFE),
      );
    }
    if (lower.contains('python')) {
      return _buildBox(
        icon: Icons.terminal_rounded,
        bg: const Color(0xFFFEF9C3),
        fg: const Color(0xFFCA8A04),
        border: const Color(0xFFFEF08A),
      );
    }
    if (lower.contains('flutter') ||
        lower.contains('dart') ||
        lower.contains('android') ||
        lower.contains('ios')) {
      return _buildBox(
        icon: Icons.flutter_dash_rounded,
        bg: AppTheme.pastelSky(context),
        fg: AppTheme.pastelSkyText(context),
        border: AppTheme.pastelSkyBorder(context),
      );
    }
    if (lower.contains('database') ||
        lower.contains('sql') ||
        lower.contains('mongo') ||
        lower.contains('postgres')) {
      return _buildBox(
        icon: Icons.dns_rounded,
        bg: const Color(0xFFECFDF5),
        fg: const Color(0xFF059669),
        border: const Color(0xFFA7F3D0),
      );
    }
    if (lower.contains('git')) {
      return _buildBox(
        icon: Icons.call_split_rounded,
        bg: const Color(0xFFFFF7ED),
        fg: const Color(0xFFEA580C),
        border: const Color(0xFFFFEDD5),
      );
    }
    if (lower.contains('dsa') ||
        lower.contains('algo') ||
        lower.contains('tree') ||
        lower.contains('graph')) {
      return _buildBox(
        icon: Icons.account_tree_rounded,
        bg: const Color(0xFFF5F3FF),
        fg: const Color(0xFF6366F1),
        border: const Color(0xFFDDD6FE),
      );
    }
    if (lower.contains('react') ||
        lower.contains('javascript') ||
        lower.contains('js') ||
        lower.contains('frontend') ||
        lower.contains('web')) {
      return _buildBox(
        icon: Icons.code_rounded,
        bg: const Color(0xFFFAF5FF),
        fg: const Color(0xFF7C3AED),
        border: const Color(0xFFF3E8FF),
      );
    }

    return CourseIconChip(
      courseId: courseId,
      size: 52,
      radius: 16,
    );
  }

  Widget _buildBox({
    required IconData icon,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: fg,
        size: 26,
      ),
    );
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
