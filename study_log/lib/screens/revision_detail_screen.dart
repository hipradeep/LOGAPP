import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/course_icon_chip.dart';
import '../widgets/topic_progress_header.dart';
import '../widgets/topic_status_indicator.dart';
import '../widgets/topic_status_label.dart';
import '../models/revision.dart';
import '../models/topic.dart';
import '../services/local_topic_storage.dart';
import '../services/service_locator.dart';
import '../controllers/revision_controller.dart';
import 'module_detail_screen.dart';


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
  List<Topic> _topics = const [];
  bool _isLoadingTopics = true;

  RevisionController get _controller => getIt<RevisionController>();

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
    _activeTab.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    final revision = widget.revision;
    final topics = await LocalTopicStorage.loadTopicsForModule(
      moduleId: revision.moduleId,
      fallbackTitle: revision.moduleTitle,
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

  /// Explicitly completes the level the user is on and moves the ladder on.
  Future<void> _startCurrentLevel(Revision revision) async {
    final level = revision.currentLevel;
    final advanced = await _controller.completeCurrentLevel(revision.id);
    if (!mounted || !advanced) return;

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
  }

  void _openModule() {
    final revision = _revision;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModuleDetailScreen(
          moduleTitle: revision.moduleTitle,
          courseTitle: revision.courseTitle,
          courseId: revision.courseId,
          moduleId: revision.moduleId,
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
                  title: revision.moduleTitle,
                  courseTitle: revision.courseTitle,
                  courseId: revision.courseId,
                  levelLabel: revision.levelLabel,
                  isDue: revision.isDueAt(DateTime.now()),
                  isFinished: revision.isFinished,
                  onStartRevision: () => _startCurrentLevel(revision),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: _RevisionMetaStrip(revision: revision),
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
                          bottomPadding: bottomSafe + 24,
                        );
                      }
                      return _RevisionTopicsView(
                        topics: _topics,
                        isLoading: _isLoadingTopics,
                        bottomPadding: bottomSafe + 24,
                        onTopicTap: _openModule,
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

/// Same hero block the course page uses: a 44px pastel square + 24px title,
/// with the course name tucked under it. The square shows the course icon, not
/// the module icon.
///
/// Nothing sits to the right of the module name until the current level comes
/// due, at which point the "Start Rn" button appears there.
class _HeroBlock extends StatelessWidget {
  final String title;
  final String courseTitle;
  final String courseId;
  final String levelLabel;
  final bool isDue;
  final bool isFinished;
  final VoidCallback onStartRevision;

  const _HeroBlock({
    required this.title,
    required this.courseTitle,
    required this.courseId,
    required this.levelLabel,
    required this.isDue,
    required this.isFinished,
    required this.onStartRevision,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CourseIconChip(courseId: courseId, size: 44, radius: 12),
          const HGapSm(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                const VGapXs(),
                Text(
                  courseTitle.isEmpty ? 'No course' : courseTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const HGapSm(),
          if (isDue && !isFinished)
            ElevatedButton(
              onPressed: onStartRevision,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Start $levelLabel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
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
    final lastRevision = revision.isFinished
        ? (revision.completedAt ?? revision.updatedAt)
        : revision.nextRevisionAt;

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
            value: _formatDate(lastRevision),
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
              const SizedBox(width: 6),
            ] else ...[
              Icon(icon, color: AppTheme.textSecondary, size: 12),
              const HGapXs(),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
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
            color: valueColor ?? AppTheme.textPrimary,
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
      color: AppTheme.borderColor,
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
///
/// Mirrors the module page: a pinned "N / M topics" bar above a divided list of
/// status-aware rows. Read-only here — tapping a row opens the module the topic
/// belongs to rather than changing its status.
class _RevisionTopicsView extends StatelessWidget {
  final List<Topic> topics;
  final bool isLoading;
  final double bottomPadding;
  final VoidCallback onTopicTap;

  const _RevisionTopicsView({
    required this.topics,
    required this.isLoading,
    required this.bottomPadding,
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
      return _RevisionTopicsEmptyState(onOpenModule: onTopicTap);
    }

    final completedCount = topics.where((t) => t.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 6.0),
          child: TopicProgressHeader(
            completedCount: completedCount,
            totalCount: topics.length,
            progress: completedCount / topics.length,
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemCount: topics.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              indent: 64,
              endIndent: 20,
              color: Color(0xFFF3F4F6),
            ),
            itemBuilder: (context, index) {
              final topic = topics[index];
              return _TopicListItem(
                topic: topic,
                onTap: onTopicTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RevisionTopicsEmptyState extends StatelessWidget {
  final VoidCallback onOpenModule;

  const _RevisionTopicsEmptyState({required this.onOpenModule});

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
              decoration: const BoxDecoration(
                color: AppTheme.pastelPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.playlist_add_rounded,
                size: 30,
                color: AppTheme.pastelPurpleText,
              ),
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
            const VGapMd(),
            ElevatedButton.icon(
              onPressed: onOpenModule,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open Module'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Topic row: status ring on the left, title over its status label, chevron on
/// the right to signal that tapping navigates to the module.
class _TopicListItem extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;

  const _TopicListItem({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                TopicStatusIndicator(status: topic.status),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      TopicStatusLabel(status: topic.status),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 24,
                ),
              ],
            ),
          ),
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
          _TimelineRow(
            level: level,
            revision: revision,
            isLast: level == maxLevel,
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
