import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_spacers.dart';
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

/// Revision screen — a tracking list for the R1 -> R5 spaced repetition ladder.
///
/// Deliberately a single continuous list ordered by due date: no "due in N
/// days" groupings and no per-card action button. Tapping a card opens the
/// module it tracks; progression itself is automatic.
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
        final matches = r.sectionTitle.toLowerCase().contains(query) ||
            r.sectionDescription.toLowerCase().contains(query);
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
        // Most urgent first. Ties keep finished records at the bottom.
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
          return a.sectionTitle.toLowerCase().compareTo(
                b.sectionTitle.toLowerCase(),
              );
        });
        break;
    }
    return filtered;
  }

  Future<void> _handleOverflow(String action, Revision revision) async {
    switch (action) {
      case 'open':
        widget.onOpenRevision(revision);
        break;
      case 'reset':
        await widget.revisionController.resetRevision(revision.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${revision.sectionTitle}" reset to R1'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        break;
      case 'remove':
        await widget.revisionController.deleteRevision(revision.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${revision.sectionTitle}" removed from revision'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _RevisionSearchBar(controller: _searchController),
              ),
            _RevisionLevelFilterRow(
              selectedLevel: _levelFilter,
              onSelected: (level) => setState(() => _levelFilter = level),
            ),
            _RevisionSortRow(
              sortMode: _sortMode,
              scope: _scope,
              onSortChanged: (mode) => setState(() => _sortMode = mode),
              onFilterPressed: _openFilterSheet,
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
                        palette: _cardPalettes[index % _cardPalettes.length],
                        onTap: () => widget.onOpenRevision(revision),
                        onOverflow: (action) =>
                            _handleOverflow(action, revision),
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
      backgroundColor: AppTheme.surfaceColor,
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
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const VGapMd(),
            const Text(
              'Filter revisions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
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
                      : AppTheme.textSecondary,
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
                        : AppTheme.textPrimary,
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

// === Palette cycle ===

class _CardPalette {
  final Color bg;
  final Color border;
  final Color accent;
  const _CardPalette(this.bg, this.border, this.accent);
}

const List<_CardPalette> _cardPalettes = [
  _CardPalette(
    AppTheme.pastelPurple,
    AppTheme.pastelPurpleBorder,
    AppTheme.pastelPurpleText,
  ),
  _CardPalette(
    AppTheme.pastelGreen,
    AppTheme.pastelGreenBorder,
    AppTheme.pastelGreenText,
  ),
  _CardPalette(
    AppTheme.pastelOrange,
    AppTheme.pastelOrangeBorder,
    AppTheme.pastelOrangeText,
  ),
  _CardPalette(Color(0xFFE0F2FE), Color(0xFFBAE6FD), Color(0xFF0284C7)),
];

const List<IconData> _topicIcons = [
  Icons.menu_book_rounded,
  Icons.article_rounded,
  Icons.lightbulb_rounded,
  Icons.psychology_rounded,
  Icons.terminal_rounded,
  Icons.functions_rounded,
  Icons.storage_rounded,
  Icons.cloud_rounded,
  Icons.security_rounded,
  Icons.schema_rounded,
];

// === Subcomponents ===

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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.textPrimary,
              size: 28,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const HGapXs(),
          const Text(
            'Revision',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              isSearchActive
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
              color: isSearchActive
                  ? AppTheme.primaryColor
                  : AppTheme.textPrimary,
              size: 24,
            ),
            onPressed: onSearchTap,
            tooltip: 'Search',
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 6,
            onSelected: onMenuAction,
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(
                value: 'showFinished',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF1E293B),
                      size: 20,
                    ),
                    HGapMd(),
                    Text(
                      'Toggle finished',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
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
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF9CA3AF),
            size: 20,
          ),
          const HGapSm(),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search revisions...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
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

/// Horizontal R-level chips: All, R1, R2, R3, R4, R5.
class _RevisionLevelFilterRow extends StatelessWidget {
  final int? selectedLevel;
  final ValueChanged<int?> onSelected;

  const _RevisionLevelFilterRow({
    required this.selectedLevel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _LevelChip(
            label: 'All',
            isSelected: selectedLevel == null,
            onTap: () => onSelected(null),
          ),
          for (var level = 1; level <= RevisionSchedule.maxLevel; level++)
            _LevelChip(
              label: 'R$level',
              isSelected: selectedLevel == level,
              onTap: () => onSelected(level),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sort selector ("Due Date") plus the filter icon.
class _RevisionSortRow extends StatelessWidget {
  final RevisionSortMode sortMode;
  final RevisionScope scope;
  final ValueChanged<RevisionSortMode> onSortChanged;
  final VoidCallback onFilterPressed;

  const _RevisionSortRow({
    required this.sortMode,
    required this.scope,
    required this.onSortChanged,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
      child: Row(
        children: [
          const Icon(
            Icons.swap_vert_rounded,
            color: Color(0xFF9CA3AF),
            size: 18,
          ),
          const HGapXs(),
          PopupMenuButton<RevisionSortMode>(
            initialValue: sortMode,
            onSelected: onSortChanged,
            position: PopupMenuPosition.under,
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
                      fontWeight: mode == sortMode
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: mode == sortMode
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sortMode.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (scope != RevisionScope.all)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.pastelPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  scope.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.pastelPurpleText,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: onFilterPressed,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }
}

class _RevisionItemCard extends StatelessWidget {
  final Revision revision;
  final _CardPalette palette;
  final VoidCallback onTap;
  final ValueChanged<String> onOverflow;

  const _RevisionItemCard({
    required this.revision,
    required this.palette,
    required this.onTap,
    required this.onOverflow,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = revision.daysUntilDue(now);
    final isDue = revision.isDueAt(now);
    final icon =
        _topicIcons[revision.id.hashCode.abs() % _topicIcons.length];

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.bg,
                    borderRadius: BorderRadius.circular(
                      AppTheme.smallBorderRadius,
                    ),
                    border: Border.all(color: palette.border, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: palette.accent, size: 22),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        revision.sectionTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Text(
                        revision.sectionDescription.isEmpty
                            ? 'Revision ${revision.levelLabel}'
                            : revision.sectionDescription,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapSm(),
                      Row(
                        children: [
                          _LevelBadge(
                            label: revision.levelLabel,
                            isDue: isDue,
                            isFinished: revision.isFinished,
                          ),
                          const HGapSm(),
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  revision.isFinished
                                      ? Icons.check_circle_rounded
                                      : Icons.event_rounded,
                                  size: 13,
                                  color: _dueColor(days, isDue, revision),
                                ),
                                const HGapXs(),
                                Flexible(
                                  child: Text(
                                    _dueLabel(days, isDue),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _dueColor(
                                        days,
                                        isDue,
                                        revision,
                                      ),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _RevisionOverflowMenu(
                  revision: revision,
                  onSelected: onOverflow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dueLabel(int days, bool isDue) {
    if (isDue) return days <= 0 ? 'Today' : 'Overdue ${days.abs()}d';
    if (days == 1) return 'Tomorrow';
    return 'In ${days}d';
  }

  static Color _dueColor(int days, bool isDue, Revision revision) {
    if (revision.isFinished) return AppTheme.successColor;
    if (isDue) return AppTheme.primaryColor;
    if (days <= 2) return AppTheme.errorColor;
    return AppTheme.textSecondary;
  }
}

class _LevelBadge extends StatelessWidget {
  final String label;
  final bool isDue;
  final bool isFinished;

  const _LevelBadge({
    required this.label,
    required this.isDue,
    required this.isFinished,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isFinished
        ? AppTheme.successColor
        : isDue
            ? AppTheme.primaryColor
            : AppTheme.pastelPurple;
    final fg =
        isFinished || isDue ? Colors.white : AppTheme.pastelPurpleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _RevisionOverflowMenu extends StatelessWidget {
  final Revision revision;
  final ValueChanged<String> onSelected;

  const _RevisionOverflowMenu({
    required this.revision,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF9CA3AF),
        size: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 6,
      onSelected: onSelected,
      itemBuilder: (ctx) => [
        const PopupMenuItem<String>(
          value: 'open',
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: Color(0xFF1E293B),
                size: 18,
              ),
              HGapMd(),
              Text(
                'Open details',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Resetting is pointless once a record is already at R1.
        if (revision.currentLevel > 1)
          const PopupMenuItem<String>(
            value: 'reset',
            child: Row(
              children: [
                Icon(
                  Icons.restart_alt_rounded,
                  color: Color(0xFF1E293B),
                  size: 18,
                ),
                HGapMd(),
                Text(
                  'Reset to R1',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 18,
              ),
              HGapMd(),
              Text(
                'Remove from revision',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
