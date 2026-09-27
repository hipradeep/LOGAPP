import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../models/revision.dart';
import '../models/subsection_item.dart';
import '../services/local_subsection_storage.dart';
import '../services/service_locator.dart';
import '../controllers/revision_controller.dart';
import 'section_detail_screen.dart';

/// Revision detail screen — mirrors the Course Detail layout:
///
/// - Same top bar (back, "REVISION" eyebrow, overflow menu)
/// - Same hero block (44px pastel rounded square + 24px module title)
/// - Same progress banner, but tracking the R1 -> R5 ladder instead of modules
/// - "Topics (n)" tab replaces the module list
/// - "Progress" tab replaces "Overview" and shows the ladder vertically
///
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
  List<SubsectionItem> _topics = const [];
  bool _isLoadingTopics = true;

  RevisionController get _controller => getIt<RevisionController>();

  /// Always prefers the live record so the ladder reflects auto-progression.
  Revision get _revision =>
      _controller.revisionForSection(widget.revision.sectionId) ??
      widget.revision;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _activeTab.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final revision = widget.revision;
    final topics = await LocalSubsectionStorage.loadSubsectionsForSection(
      sectionId: revision.sectionId,
      fallbackTitle: revision.sectionTitle,
    );
    if (!mounted) return;
    setState(() {
      _topics = topics;
      _isLoadingTopics = false;
    });
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _openModule() {
    final revision = _revision;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionDetailScreen(
          sectionTitle: revision.sectionTitle,
          courseTitle: revision.courseTitle,
          courseId: revision.courseId,
          sectionId: revision.sectionId,
        ),
      ),
    );
  }

  void _openOptionsMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  leading: const Icon(
                    Icons.open_in_new_rounded,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text(
                    'Open Module',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    _openModule();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.restart_alt_rounded,
                    color: AppTheme.textPrimary,
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
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'Remove from revision',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    await _controller.deleteRevision(_revision.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final revision = _revision;
            return Column(
              children: [
                _RevisionDetailTopBar(
                  onBack: _handleBack,
                  onOptions: _openOptionsMenu,
                ),
                _HeroBlock(
                  icon: Icons.sync_rounded,
                  title: revision.sectionTitle,
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: _RevisionLadderHeader(revision: revision),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _activeTab,
                  builder: (context, activeIdx, _) {
                    return _RevisionTabsRow(
                      activeIndex: activeIdx,
                      topicsCount: _topics.length,
                      onTabSelected: (index) {
                        if (_activeTab.value == index) return;
                        _activeTab.value = index;
                      },
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
                          onStartRevision: () =>
                              _startCurrentLevel(revision),
                          bottomPadding: bottomSafe + 24,
                        );
                      }
                      return _RevisionTopicsView(
                        topics: _topics,
                        isLoading: _isLoadingTopics,
                        onTopicTap: _openModule,
                        bottomPadding: bottomSafe + 24,
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

// === Subcomponents ===

class _RevisionDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOptions;

  const _RevisionDetailTopBar({
    required this.onBack,
    required this.onOptions,
  });

  static const String _eyebrow = 'Revision';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
          Expanded(
            child: Text(
              _eyebrow.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppTheme.textPrimary,
              size: 24,
            ),
            onPressed: onOptions,
            tooltip: 'Options',
          ),
        ],
      ),
    );
  }
}

/// Same hero block the course page uses: 44px pastel square + 24px title.
class _HeroBlock extends StatelessWidget {
  final IconData icon;
  final String title;

  const _HeroBlock({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.pastelPurple,
              borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
              border: Border.all(color: AppTheme.pastelPurpleBorder),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppTheme.pastelPurpleText, size: 22),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionLadderHeader extends StatelessWidget {
  final Revision revision;

  const _RevisionLadderHeader({required this.revision});

  @override
  Widget build(BuildContext context) {
    final cleared = revision.isFinished
        ? RevisionSchedule.maxLevel
        : revision.currentLevel - 1;
    final total = RevisionSchedule.maxLevel;
    final progress = cleared / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$cleared / $total levels cleared',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const VGapSm(),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: const Color(0xFFECEEF6),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
            ),
          ),
        ),
      ],
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
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFEEF0F5), width: 1.5),
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
            color: isActive ? AppTheme.primaryColor : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

/// Replaces the course page's module list with this module's topics.
class _RevisionTopicsView extends StatelessWidget {
  final List<SubsectionItem> topics;
  final bool isLoading;
  final VoidCallback onTopicTap;
  final double bottomPadding;

  const _RevisionTopicsView({
    required this.topics,
    required this.isLoading,
    required this.onTopicTap,
    required this.bottomPadding,
  });

  static const List<Color> _badgeColorCycle = [
    Color(0xFF10B981),
    Color(0xFF38BDF8),
    Color(0xFFFB923C),
    Color(0xFF818CF8),
  ];

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
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.playlist_add_rounded,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const VGapMd(),
              const Text(
                'No topics yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const VGapXs(),
              const Text(
                'Add topics to this module to start tracking its revision ladder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: bottomPadding),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final topic = topics[index];
        final color = _badgeColorCycle[index % _badgeColorCycle.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TopicListItem(
            icon: topic.iconCodePoint != null
                ? IconData(topic.iconCodePoint!, fontFamily: 'MaterialIcons')
                : Icons.menu_book_rounded,
            iconColor: color,
            title: topic.title,
            subtitle: topic.description,
            isCompleted: topic.isCompleted,
            completedAt: topic.completedAt,
            onTap: onTopicTap,
          ),
        );
      },
    );
  }
}

class _TopicListItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final DateTime? completedAt;
  final VoidCallback onTap;

  const _TopicListItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.completedAt,
    required this.onTap,
  });

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
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
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppTheme.smallBorderRadius,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
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
                        isCompleted && completedAt != null
                            ? 'Completed ${_formatDate(completedAt!)}'
                            : (subtitle.isNotEmpty
                                ? subtitle
                                : 'Not started'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCompleted
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCompleted
                              ? AppTheme.successColor
                              : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const HGapSm(),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                    size: 20,
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]}';
}

/// Replaces "Overview" with a compact "Revision Progress" card: a vertical
/// R1 -> R5 timeline plus a single full-width action button.
class _RevisionLadderView extends StatelessWidget {
  final Revision revision;
  final VoidCallback onStartRevision;
  final double bottomPadding;

  const _RevisionLadderView({
    required this.revision,
    required this.onStartRevision,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Revision Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const VGapMd(),
              for (var level = 1; level <= maxLevel; level++)
                _TimelineRow(
                  level: level,
                  revision: revision,
                  isLast: level == maxLevel,
                ),
              if (!revision.isFinished) ...[
                const VGapMd(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onStartRevision,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(
                      'Start R${revision.currentLevel} Revision',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ],
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
            : const Color(0xFFEEF0F5);

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
                              : AppTheme.textPrimary,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
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
                              : AppTheme.textSecondary,
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
            color: AppTheme.surfaceColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.borderColor, width: 2),
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
        bg = AppTheme.pastelGreen;
        fg = AppTheme.pastelGreenText;
        break;
      case _StepState.current:
        label = 'Pending';
        bg = AppTheme.pastelPurple;
        fg = AppTheme.pastelPurpleText;
        break;
      case _StepState.upcoming:
        label = 'Upcoming';
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
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
