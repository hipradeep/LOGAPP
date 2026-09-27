import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

enum SubsectionStatus {
  completed,
  inProgress,
  notStarted,
}

class SubsectionItem {
  final String id;
  final String title;
  final SubsectionStatus status;

  const SubsectionItem({
    required this.id,
    required this.title,
    required this.status,
  });

  SubsectionItem copyWith({
    String? id,
    String? title,
    SubsectionStatus? status,
  }) {
    return SubsectionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
    );
  }
}

/// Redesigned Section Detail (Subsections) screen matching the reference design:
/// - Top bar with Back button, section title (e.g. "Arrays"), and 3-dots menu
/// - Top Progress banner: "3 / 8 subsections", "38%", and purple linear progress bar
/// - Interactive list of subsections:
///   - Completed: Green check circle badge & "Completed" green label
///   - In Progress: Purple circular progress ring & "In Progress" label
///   - Not started: Empty circle outline & "Not started" label
///   - Trailing chevrons and clean dividers
/// - Tap to cycle status (Not started -> In Progress -> Completed) with live progress updates
class SectionDetailScreen extends StatefulWidget {
  final String sectionTitle;
  final String courseTitle;

  const SectionDetailScreen({
    super.key,
    required this.sectionTitle,
    this.courseTitle = 'DSA',
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  late List<SubsectionItem> _subsections;

  @override
  void initState() {
    super.initState();
    _subsections = [
      const SubsectionItem(
        id: '1',
        title: 'Introduction',
        status: SubsectionStatus.completed,
      ),
      const SubsectionItem(
        id: '2',
        title: 'Traversing an Array',
        status: SubsectionStatus.completed,
      ),
      const SubsectionItem(
        id: '3',
        title: 'Basic Problems',
        status: SubsectionStatus.inProgress,
      ),
      const SubsectionItem(
        id: '4',
        title: 'Two Pointer',
        status: SubsectionStatus.notStarted,
      ),
      const SubsectionItem(
        id: '5',
        title: 'Sliding Window',
        status: SubsectionStatus.notStarted,
      ),
      const SubsectionItem(
        id: '6',
        title: 'Prefix Sum',
        status: SubsectionStatus.notStarted,
      ),
      const SubsectionItem(
        id: '7',
        title: 'Sorting in Arrays',
        status: SubsectionStatus.notStarted,
      ),
      const SubsectionItem(
        id: '8',
        title: 'Binary Search',
        status: SubsectionStatus.notStarted,
      ),
    ];
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  void _toggleSubsectionStatus(int index) {
    setState(() {
      final current = _subsections[index];
      final SubsectionStatus next;
      switch (current.status) {
        case SubsectionStatus.notStarted:
          next = SubsectionStatus.inProgress;
          break;
        case SubsectionStatus.inProgress:
          next = SubsectionStatus.completed;
          break;
        case SubsectionStatus.completed:
          next = SubsectionStatus.notStarted;
          break;
      }
      _subsections[index] = current.copyWith(status: next);
    });
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
                  leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
                  title: const Text('Mark All as Completed'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    setState(() {
                      _subsections = _subsections
                          .map((s) => s.copyWith(status: SubsectionStatus.completed))
                          .toList();
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: AppTheme.primaryColor),
                  title: const Text('Reset Section Progress'),
                  onTap: () {
                    Navigator.pop(modalCtx);
                    setState(() {
                      _subsections = _subsections
                          .map((s) => s.copyWith(status: SubsectionStatus.notStarted))
                          .toList();
                    });
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
    final completedCount = _subsections.where((s) => s.status == SubsectionStatus.completed).length;
    final totalCount = _subsections.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _SectionDetailTopBar(
              title: widget.sectionTitle,
              onBack: _handleBack,
              onOptions: _openOptionsMenu,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: _SubsectionsProgressHeader(
                completedCount: completedCount,
                totalCount: totalCount,
                progress: progress,
              ),
            ),
            const VGapSm(),
            Expanded(
              child: _SubsectionsListView(
                subsections: _subsections,
                onToggle: _toggleSubsectionStatus,
                bottomPadding: bottomSafe + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === Subcomponents (Rule 2 & 23: Pure, extracted StatelessWidget classes) ===

class _SectionDetailTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onOptions;

  const _SectionDetailTopBar({
    required this.title,
    required this.onBack,
    required this.onOptions,
  });

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
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _SubsectionsProgressHeader extends StatelessWidget {
  final int completedCount;
  final int totalCount;
  final double progress;

  const _SubsectionsProgressHeader({
    required this.completedCount,
    required this.totalCount,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completedCount / $totalCount subsections',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '$percent%',
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
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}

class _SubsectionsListView extends StatelessWidget {
  final List<SubsectionItem> subsections;
  final ValueChanged<int> onToggle;
  final double bottomPadding;

  const _SubsectionsListView({
    required this.subsections,
    required this.onToggle,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: subsections.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 64,
        endIndent: 20,
        color: Color(0xFFF3F4F6),
      ),
      itemBuilder: (context, index) {
        final item = subsections[index];
        return _SubsectionListItem(
          item: item,
          onTap: () => onToggle(index),
        );
      },
    );
  }
}

class _SubsectionListItem extends StatelessWidget {
  final SubsectionItem item;
  final VoidCallback onTap;

  const _SubsectionListItem({
    required this.item,
    required this.onTap,
  });

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
                _StatusBadgeIcon(status: item.status),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      _StatusLabel(status: item.status),
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

class _StatusBadgeIcon extends StatelessWidget {
  final SubsectionStatus status;

  const _StatusBadgeIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SubsectionStatus.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 18,
          ),
        );
      case SubsectionStatus.inProgress:
        return const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            value: 0.72,
            strokeWidth: 2.8,
            color: AppTheme.primaryColor,
            backgroundColor: Color(0xFFE8E5FF),
          ),
        );
      case SubsectionStatus.notStarted:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 2.0,
            ),
          ),
        );
    }
  }
}

class _StatusLabel extends StatelessWidget {
  final SubsectionStatus status;

  const _StatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SubsectionStatus.completed:
        return const Text(
          'Completed',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF10B981),
          ),
        );
      case SubsectionStatus.inProgress:
        return const Text(
          'In Progress',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        );
      case SubsectionStatus.notStarted:
        return const Text(
          'Not started',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        );
    }
  }
}
