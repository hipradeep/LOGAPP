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

/// Revision screen — a tracking list for the R1 -> R5 spaced repetition ladder.
///
/// Clean visual design with:
/// - Horizontal level tabs showing intervals and count badges, plus a Finished chip
/// - Section header showing active category with count and sort dropdown
/// - Modern white item cards with tech icon glyphs, level pill tags, and due status
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
  int? _levelFilter;
  RevisionScope _scope = RevisionScope.all;
  RevisionSortMode _sortMode = RevisionSortMode.dueDate;

  @override
  void initState() {
    super.initState();
    widget.revisionController.reconcile();
  }

  void _handleRevisionLongPress(Revision revision) {
    RevisionOptionsSheet.show(
      context,
      revision: revision,
      revisionController: widget.revisionController,
      onOpenRevision: widget.onOpenRevision,
    );
  }

  /// Filters, scopes and orders the records for the single list.
  List<Revision> _visibleRevisions(DateTime now) {
    final items = widget.revisionController.revisions;
    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;

    final filtered = items.where((r) {
      if (ongoing != null && r.moduleId.isNotEmpty) {
        final total = ongoing.topicCountForModule(r.moduleId);
        final done = ongoing.completedTopicCountForModule(r.moduleId);
        if (total > 0 && done < total) return false;
      }

      if (_levelFilter == null) {
        // Finished items will not show in "all" section
        if (r.isFinished) return false;
      } else if (_levelFilter == 6) {
        // Finished tab selected
        if (!r.isFinished) return false;
      } else {
        // R1..R5 tab selected
        if (r.isFinished || r.currentLevel != _levelFilter) return false;
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
          final titleA = ongoing?.moduleTitleFor(a.moduleId) ?? '';
          final titleB = ongoing?.moduleTitleFor(b.moduleId) ?? '';
          return titleA.toLowerCase().compareTo(titleB.toLowerCase());
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
            TabHeader(
              title: 'Revision',
              subtitle: 'Review due & upcoming topics',
              onBack: widget.onBack,
              padding: EdgeInsets.fromLTRB(
                widget.onBack != null ? 12.0 : 20.0,
                16.0,
                20.0,
                8.0,
              ),
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
              listenable: widget.revisionController,
              builder: (context, _) {
                final now = DateTime.now();
                final revisions = _visibleRevisions(now);

                final String sectionTitle;
                final int sectionCount;

                if (_levelFilter == 6) {
                  sectionTitle = 'Finished Revisions';
                  sectionCount = revisions.length;
                } else if (_levelFilter != null) {
                  sectionTitle = 'R$_levelFilter Revisions';
                  sectionCount = revisions.length;
                } else if (_scope == RevisionScope.dueToday) {
                  sectionTitle = 'Due Today';
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
                listenable: widget.revisionController,
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
                          showCard: false,
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
                      separatorBuilder: (_, _) => const VGapSm(),
                      itemBuilder: (context, index) {
                        final revision = revisions[index];
                        return _RevisionItemCard(
                          key: ValueKey(revision.id),
                          revision: revision,
                          onTap: () => widget.onOpenRevision(revision),
                          onLongPress: () => _handleRevisionLongPress(revision),
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
    if (_levelFilter == 6) return 'No finished revisions';
    if (_levelFilter != null) return 'No R$_levelFilter revisions';
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
    if (_levelFilter == 6) {
      return 'Complete the R5 level of a ladder to see it here.';
    }
    if (_levelFilter != null) {
      return 'Revisions appear here when they reach level R$_levelFilter.';
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
                dense: true,
                visualDensity: VisualDensity.compact,
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


/// Horizontal category filter row: All (12), R1 (Purple), R2 (Blue), R3 (Teal), R4 (Orange), R5 (Coral), Finished (Green)
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
    int activeTotalCount = 0;
    int finishedTotalCount = 0;
    final levelCounts = <int, int>{};

    final ongoing = getIt.isRegistered<OngoingModulesController>()
        ? getIt<OngoingModulesController>()
        : null;

    for (final r in revisions) {
      if (ongoing != null && r.moduleId.isNotEmpty) {
        final total = ongoing.topicCountForModule(r.moduleId);
        final done = ongoing.completedTopicCountForModule(r.moduleId);
        if (total > 0 && done < total) continue;
      }

      if (r.isFinished) {
        finishedTotalCount++;
      } else {
        activeTotalCount++;
        levelCounts[r.currentLevel] = (levelCounts[r.currentLevel] ?? 0) + 1;
      }
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
              style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondaryColor(context),
                  size: 20,
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

/// Item card for a revision:
/// - Rounded rectangular card
/// - Tech icon / glyph container
/// - Title with R-level pill tag
/// - Subtitle (course & description)
/// - Red clock with due status
class _RevisionItemCard extends StatelessWidget {
  final Revision revision;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RevisionItemCard({
    super.key,
    required this.revision,
    required this.onTap,
    this.onLongPress,
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
      title: _moduleTitleFor(revision),
      titleBadge: _RevisionLevelPill(
        level: revision.currentLevel,
        isFinished: revision.isFinished,
      ),
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
      onLongPress: onLongPress,
    );
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
      return AppTheme.errorColor;
    }
    return AppTheme.textSecondaryColor(context);
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
