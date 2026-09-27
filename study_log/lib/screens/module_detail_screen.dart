import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../models/subsection_item.dart';
import '../services/local_subsection_storage.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_sections_controller.dart';
import 'add_subsection_screen.dart';

class SectionDetailScreen extends StatefulWidget {
  final String sectionTitle;
  final String courseTitle;
  final String courseId;
  final String sectionId;
  final int sectionOrderIndex;

  const SectionDetailScreen({
    super.key,
    required this.sectionTitle,
    this.courseTitle = 'DSA',
    this.courseId = '',
    this.sectionId = '',
    this.sectionOrderIndex = 0,
  });

  @override
  State<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends State<SectionDetailScreen> {
  List<SubsectionItem> _subsections = [];

  @override
  void initState() {
    super.initState();
    _loadSubsections();
  }

  Future<void> _loadSubsections() async {
    final cached = await LocalSubsectionStorage.loadSubsectionsForSection(
      sectionId: widget.sectionId,
      fallbackTitle: widget.sectionTitle,
    );
    if (!mounted) return;
    setState(() => _subsections = cached);
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  Future<void> _openAddSubsectionScreen() async {
    final result = await Navigator.push<SubsectionItem>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSubsectionScreen(
          sectionTitle: widget.sectionTitle,
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          sectionId: widget.sectionId,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _subsections.add(result);
      });
      await LocalSubsectionStorage.saveSubsections(widget.sectionTitle, _subsections);
      if (getIt.isRegistered<OngoingSectionsController>()) {
        getIt<OngoingSectionsController>().refresh();
      }
    }
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
      _subsections[index] = next == SubsectionStatus.completed
          ? current.copyWith(status: next, completedAt: DateTime.now())
          : current.copyWith(status: next, clearCompletedAt: true);
    });
    LocalSubsectionStorage.saveSubsections(widget.sectionTitle, _subsections);
    if (getIt.isRegistered<OngoingSectionsController>()) {
      getIt<OngoingSectionsController>().refresh();
    }
  }

  Future<void> _handleDeleteSubsection(int index) async {
    final sub = _subsections[index];
    final confirmed = await StudyConfirmationDialog.showDeleteSubsection(
      context,
      subsectionTitle: sub.title,
    );

    if (confirmed && mounted) {
      setState(() {
        _subsections.removeAt(index);
      });
      await LocalSubsectionStorage.saveSubsections(widget.sectionTitle, _subsections);
      if (getIt.isRegistered<OngoingSectionsController>()) {
        getIt<OngoingSectionsController>().refresh();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Topic "${sub.title}" deleted'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            ),
          ),
        );
      }
    }
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
              onBack: _handleBack,
              onAddSubsection: _openAddSubsectionScreen,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 4.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.pastelPurple,
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      border: Border.all(color: AppTheme.pastelPurpleBorder),
                    ),
                    child: Text(
                      '${widget.sectionOrderIndex + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.pastelPurpleText,
                      ),
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: Text(
                      widget.sectionTitle,
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
            ),
            const VGapXs(),
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
                onDelete: _handleDeleteSubsection,
                onAddSubsection: _openAddSubsectionScreen,
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
  final VoidCallback onBack;
  final VoidCallback onAddSubsection;

  const _SectionDetailTopBar({
    required this.onBack,
    required this.onAddSubsection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.textPrimary,
                  size: 28,
                ),
                onPressed: onBack,
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const HGapSm(),
              const Text(
                'MODULE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          AddPillButton(
            label: 'Add Topic',
            onPressed: onAddSubsection,
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
              '$completedCount / $totalCount topics',
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
  final ValueChanged<int> onDelete;
  final VoidCallback onAddSubsection;
  final double bottomPadding;

  const _SubsectionsListView({
    required this.subsections,
    required this.onToggle,
    required this.onDelete,
    required this.onAddSubsection,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (subsections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
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
                'Tap "+ Add Topic" to add your first topic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const VGapMd(),
              ElevatedButton.icon(
                onPressed: onAddSubsection,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Topic'),
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
          onLongPress: () => onDelete(index),
        );
      },
    );
  }
}

class _SubsectionListItem extends StatelessWidget {
  final SubsectionItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SubsectionListItem({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
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
            color: AppTheme.primaryColor,
          ),
        );
      case SubsectionStatus.notStarted:
        return const Text(
          'Not started',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9CA3AF),
          ),
        );
    }
  }
}
