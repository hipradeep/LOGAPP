import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../models/study_log.dart';
import '../models/topic.dart';
import '../models/topic_revision.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../theme/revision_level_palette.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/entity_detail_header.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/study_text_fields.dart';
import '../widgets/topic_options_sheet.dart';
import '../widgets/topic_revision_badge.dart';
import 'add_topic_screen.dart';
import 'session_setup_screen.dart';

/// Screen displaying comprehensive details, revision ladder, and notes
/// for a single [Topic].
class TopicDetailScreen extends StatefulWidget {
  final Topic topic;
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;
  final bool isFromModuleRevision;

  const TopicDetailScreen({
    super.key,
    required this.topic,
    required this.moduleTitle,
    this.courseTitle = '',
    this.courseId = '',
    this.moduleId = '',
    this.isFromModuleRevision = false,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  late Topic _topic;
  List<StudyLog> _topicLogs = [];
  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    _loadTopicData();
  }

  @override
  void dispose() {
    _activeTab.dispose();
    super.dispose();
  }

  void _handleTabSelected(int index) {
    if (_activeTab.value != index) {
      _activeTab.value = index;
    }
  }

  Future<void> _loadTopicData() async {
    // 1. Refresh topic entity directly from DatabaseService
    if (_topic.id.isNotEmpty) {
      try {
        final match = await DatabaseService.instance.getTopicById(_topic.id);
        if (match != null && mounted) {
          setState(() {
            _topic = match;
          });
        }
      } catch (_) {}
    }

    // 2. Load study logs for this specific topic
    try {
      final allLogs = await DatabaseService.instance.getStudyLogs();
      final filtered = allLogs
          .where((l) => l.topicId == _topic.id)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _topicLogs = filtered;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleStatusChanged(TopicStatus newStatus) async {
    if (newStatus == _topic.status) return;

    final resolvedCourseId =
        _topic.courseId.isNotEmpty ? _topic.courseId : widget.courseId;
    final resolvedModuleId =
        _topic.moduleId.isNotEmpty ? _topic.moduleId : widget.moduleId;

    final updated = _topic.copyWith(
      courseId: resolvedCourseId,
      moduleId: resolvedModuleId,
      status: newStatus,
      completedAt: newStatus == TopicStatus.completed ? DateTime.now() : null,
      clearCompletedAt: newStatus != TopicStatus.completed,
    );

    setState(() {
      _topic = updated;
    });

    try {
      // 1. Direct SQLite database upsert & real-time stream notification
      await DatabaseService.instance.updateTopic(updated);

      // 2. Log completion if newly completed
      if (updated.isCompleted) {
        final studyLog = StudyLog(
          id: '${updated.id}_${DateTime.now().millisecondsSinceEpoch}',
          type: StudyLogType.topicCompleted,
          courseId: resolvedCourseId,
          courseTitle: widget.courseTitle,
          moduleId: resolvedModuleId,
          moduleTitle: widget.moduleTitle,
          topicId: updated.id,
          topicTitle: updated.title,
          timestamp: updated.completedAt ?? DateTime.now(),
          createdAt: DateTime.now(),
        );
        await DatabaseService.instance.addStudyLog(studyLog);
      }

      // 4. Refresh global reactive controllers
      if (getIt.isRegistered<OngoingModulesController>()) {
        unawaited(getIt<OngoingModulesController>().refresh());
      }
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
      if (getIt.isRegistered<RevisionController>()) {
        unawaited(getIt<RevisionController>().reconcile());
      }
      if (getIt.isRegistered<TopicRevisionController>()) {
        unawaited(getIt<TopicRevisionController>().refresh());
      }

      unawaited(_loadTopicData());
    } catch (e) {
      debugPrint('Error updating topic status: $e');
    }
  }

  void _handleStartStudy({bool isRevision = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSetupScreen(
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          moduleTitle: widget.moduleTitle,
          moduleId: widget.moduleId,
          topics: [_topic],
          isRevision: isRevision,
        ),
      ),
    );
    _loadTopicData();
  }


  void _handleOpenOptions() {
    TopicOptionsSheet.show(
      context,
      topic: _topic,
      moduleTitle: widget.moduleTitle,
      courseTitle: widget.courseTitle,
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      onEdit: _handleEditFullTopic,
      onDelete: _handleDeleteTopic,
    );
  }

  void _handleEditFullTopic() async {
    final result = await Navigator.push<Topic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTopicScreen(
          moduleTitle: widget.moduleTitle,
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicToEdit: _topic,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _topic = result);
      unawaited(_loadTopicData());
    }
  }

  void _handleDeleteTopic() async {
    final confirmed = await StudyConfirmationDialog.showDeleteTopic(
      context,
      topicTitle: _topic.title,
    );

    if (confirmed && mounted) {
      if (_topic.id.isNotEmpty) {
        await DatabaseService.instance.deleteTopic(_topic.id);
      }
      if (getIt.isRegistered<TopicRevisionController>() && _topic.id.isNotEmpty) {
        unawaited(getIt<TopicRevisionController>().deleteByTopicId(_topic.id));
      }
      if (getIt.isRegistered<OngoingModulesController>()) {
        unawaited(getIt<OngoingModulesController>().refresh());
      }
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }

      Navigator.pop(context, null);
    }
  }

  DateTime _resolveLastDate() {
    if (getIt.isRegistered<TopicRevisionController>()) {
      final rev = getIt<TopicRevisionController>().topicRevisionFor(_topic.id);
      if (rev != null) {
        return rev.lastRevisionAt ?? rev.updatedAt;
      }
    }
    if (_topic.completedAt != null) {
      return _topic.completedAt!;
    }
    if (_topicLogs.isNotEmpty) {
      return _topicLogs.first.timestamp;
    }
    return DateTime.now();
  }

  int _resolveTotalMinutes() {
    int minutes = 0;
    for (final l in _topicLogs) {
      if (l.durationMinutes != null && l.durationMinutes! > 0) {
        minutes += l.durationMinutes!;
      }
    }
    return minutes;
  }

  Widget? _buildFab() {
    if (widget.isFromModuleRevision) return null;

    if (getIt.isRegistered<TopicRevisionController>()) {
      return ListenableBuilder(
        listenable: getIt<TopicRevisionController>(),
        builder: (context, _) {
          final revCtrl = getIt<TopicRevisionController>();
          final revision = revCtrl.topicRevisionFor(_topic.id);
          final now = DateTime.now();
          final isDue = revision != null && revision.isDueAt(now);

          final Color fabColor;
          final String tooltip;
          final bool isRevision;

          if (revision != null) {
            isRevision = true;
            if (revision.isFinished) {
              fabColor = AppTheme.successColor;
              tooltip = 'Mastered (Start Revision)';
            } else {
              final colors = RevisionLevelPalette.of(context, revision.currentLevel);
              fabColor = colors.foreground;
              tooltip = isDue
                  ? 'Start R${revision.currentLevel} (Due Today)'
                  : 'Start R${revision.currentLevel} Revision';
            }
          } else {
            switch (_topic.status) {
              case TopicStatus.completed:
                fabColor = AppTheme.successColor;
                tooltip = 'Topic Completed (Start Revision)';
                isRevision = true;
                break;
              case TopicStatus.inProgress:
                fabColor = const Color(0xFF6366F1);
                tooltip = 'Continue Study Session';
                isRevision = false;
                break;
              case TopicStatus.notStarted:
                fabColor = AppTheme.primaryColor;
                tooltip = 'Start Study Session';
                isRevision = false;
                break;
            }
          }

          return FloatingActionButton(
            onPressed: () => _handleStartStudy(isRevision: isRevision),
            backgroundColor: fabColor,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: tooltip,
            child: const Icon(Icons.play_arrow_rounded, size: 28),
          );
        },
      );
    }

    return FloatingActionButton(
      onPressed: () => _handleStartStudy(isRevision: _topic.isCompleted),
      backgroundColor:
          _topic.isCompleted ? AppTheme.successColor : AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      tooltip:
          _topic.isCompleted ? 'Start Revision Session' : 'Start Study Session',
      child: const Icon(Icons.play_arrow_rounded, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _topic);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        floatingActionButton: _buildFab(),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomAppBar(
                title: widget.moduleTitle.isNotEmpty
                    ? widget.moduleTitle
                    : (widget.courseTitle.isNotEmpty ? widget.courseTitle : 'Topic'),
                onBack: () => Navigator.pop(context, _topic),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: _handleOpenOptions,
                    tooltip: 'Options',
                  ),
                ],
              ),
              _CompactTopicHeader(
                topicTitle: _topic.title,
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
                status: _topic.status,
                lastUpdatedAt: _resolveLastDate(),
                totalMinutesExpended: _resolveTotalMinutes(),
                onStatusChanged: _handleStatusChanged,
              ),
              _buildTabsRow(context),
              const VGapSm(),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _activeTab,
                  builder: (context, activeIdx, _) {
                    if (activeIdx == 1) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16.0,
                          4.0,
                          16.0,
                          widget.isFromModuleRevision ? (bottomSafe + 24) : (bottomSafe + 84),
                        ),
                        child: _TopicRevisionLadderCard(
                          topic: _topic,
                          courseId: widget.courseId,
                          moduleId: widget.moduleId,
                          courseTitle: widget.courseTitle,
                          moduleTitle: widget.moduleTitle,
                          onRevisionUpdated: _loadTopicData,
                          onStatusChanged: _handleStatusChanged,
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16.0,
                        4.0,
                        16.0,
                        widget.isFromModuleRevision ? (bottomSafe + 24) : (bottomSafe + 84),
                      ),
                      child: _TopicNotesCard(
                        description: _topic.description,
                        onDoubleTap: _handleEditFullTopic,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabsRow(BuildContext context) {
    final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
        ? getIt<TopicRevisionController>()
        : null;

    if (topicRevCtrl != null) {
      return ListenableBuilder(
        listenable: topicRevCtrl,
        builder: (context, _) {
          final revision = topicRevCtrl.topicRevisionFor(_topic.id);
          final String progressLabel;
          if (revision != null) {
            final levelLabel = revision.isFinished ? 'Done' : 'R${revision.currentLevel}';
            progressLabel = 'Progress ($levelLabel)';
          } else {
            progressLabel = 'Progress';
          }
          return ValueListenableBuilder<int>(
            valueListenable: _activeTab,
            builder: (context, activeIdx, _) {
              return _TopicTabsRow(
                activeIndex: activeIdx,
                progressLabel: progressLabel,
                onTabSelected: _handleTabSelected,
              );
            },
          );
        },
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _activeTab,
      builder: (context, activeIdx, _) {
        return _TopicTabsRow(
          activeIndex: activeIdx,
          progressLabel: 'Progress',
          onTabSelected: _handleTabSelected,
        );
      },
    );
  }
}

// =============================================================================
// SUBSECTION: COMPACT HEADER (MODULE CONTEXT, DATE, HOURS, STATUS)
// =============================================================================

class _CompactTopicHeader extends StatelessWidget {
  final String topicTitle;
  final String courseId;
  final String courseTitle;
  final TopicStatus status;
  final DateTime lastUpdatedAt;
  final int totalMinutesExpended;
  final ValueChanged<TopicStatus> onStatusChanged;

  const _CompactTopicHeader({
    required this.topicTitle,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    required this.lastUpdatedAt,
    required this.totalMinutesExpended,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = EntityDetailHeader.formatDate(lastUpdatedAt);
    final hoursStr = EntityDetailHeader.formatDuration(totalMinutesExpended);

    final isComplete = status == TopicStatus.completed;
    final inProgress = status == TopicStatus.inProgress;

    final Color statusBg;
    final Color statusBorder;
    final Color statusColor;
    final String statusLabel;

    if (isComplete) {
      statusBg = AppTheme.successColor.withValues(alpha: 0.12);
      statusBorder = AppTheme.successColor.withValues(alpha: 0.25);
      statusColor = AppTheme.successColor;
      statusLabel = 'Completed';
    } else if (inProgress) {
      statusBg = AppTheme.pastelPurple(context);
      statusBorder = AppTheme.pastelPurpleBorder(context);
      statusColor = AppTheme.pastelPurpleText(context);
      statusLabel = 'In Progress';
    } else {
      statusBg = AppTheme.surfaceVariant(context);
      statusBorder = AppTheme.borderColor(context);
      statusColor = AppTheme.textSecondaryColor(context);
      statusLabel = 'Not Started';
    }

    final displayTitle = topicTitle.isNotEmpty ? topicTitle : 'Topic';

    return EntityDetailHeader(
      title: displayTitle,
      courseId: courseId,
      courseTitle: courseTitle,
      horizontalPadding: 16.0,
      dateText: dateStr,
      durationText: hoursStr,
      statusWidget: PopupMenuButton<TopicStatus>(
        onSelected: onStatusChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppTheme.surface(context),
        elevation: 4,
        itemBuilder: (_) => [
          _buildPopupItem(context, TopicStatus.notStarted, 'Not Started', Icons.radio_button_unchecked_rounded),
          _buildPopupItem(context, TopicStatus.inProgress, 'In Progress', Icons.timelapse_rounded),
          _buildPopupItem(context, TopicStatus.completed, 'Completed', Icons.check_circle_rounded),
        ],
        child: DetailStatusBadge(
          label: statusLabel,
          backgroundColor: statusBg,
          borderColor: statusBorder,
          textColor: statusColor,
          trailing: Icon(Icons.arrow_drop_down_rounded, size: 12, color: statusColor),
        ),
      ),
    );
  }

  PopupMenuItem<TopicStatus> _buildPopupItem(
    BuildContext context,
    TopicStatus itemStatus,
    String text,
    IconData icon,
  ) {
    final isSelected = status == itemStatus;
    return PopupMenuItem(
      value: itemStatus,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondaryColor(context),
          ),
          const HGapSm(),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicTabsRow extends StatelessWidget {
  final int activeIndex;
  final String progressLabel;
  final ValueChanged<int> onTabSelected;

  const _TopicTabsRow({
    required this.activeIndex,
    required this.progressLabel,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor(context), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            _TabItem(
              label: 'Notes',
              isActive: activeIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            const HGapLg(),
            _TabItem(
              label: progressLabel,
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

// =============================================================================
// SUBSECTION: SPACED REPETITION LADDER CARD
// =============================================================================

class _TopicRevisionLadderCard extends StatelessWidget {
  final Topic topic;
  final String courseId;
  final String moduleId;
  final String courseTitle;
  final String moduleTitle;
  final VoidCallback? onRevisionUpdated;
  final ValueChanged<TopicStatus>? onStatusChanged;

  const _TopicRevisionLadderCard({
    required this.topic,
    required this.courseId,
    required this.moduleId,
    required this.courseTitle,
    required this.moduleTitle,
    this.onRevisionUpdated,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<TopicRevisionController>()) {
      return const SizedBox.shrink();
    }

    final topicRevCtrl = getIt<TopicRevisionController>();

    return ListenableBuilder(
      listenable: topicRevCtrl,
      builder: (context, _) {
        final revision = topicRevCtrl.topicRevisionFor(topic.id);
        final now = DateTime.now();
        final isDue = revision != null && revision.isDueAt(now);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Outer Section Header Row (Label without icon + Status Badge)
            Row(
              children: [
                Text(
                  'Repetition',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                if (revision != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: revision.isFinished
                          ? AppTheme.successColor.withValues(alpha: 0.12)
                          : (isDue
                              ? AppTheme.errorColor.withValues(alpha: 0.12)
                              : AppTheme.pastelIndigo(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      revision.isFinished
                          ? 'Mastered'
                          : (isDue ? 'R${revision.currentLevel} Due' : 'R${revision.currentLevel} Active'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: revision.isFinished
                            ? AppTheme.successColor
                            : (isDue ? AppTheme.errorColor : AppTheme.pastelIndigoText(context)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const VGapSm(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDue
                      ? AppTheme.errorColor.withValues(alpha: 0.35)
                      : AppTheme.borderColor(context),
                  width: isDue ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical Repetition Pipeline: Study Phase -> R1 -> R2 -> R3 -> R4 -> R5
                  _VerticalPipeline(
                    topicStatus: topic.status,
                    revision: revision,
                  ),

              // Bottom Actions Row
              if (revision == null) ...[
                if (topic.status == TopicStatus.completed) ...[
                  const VGapMd(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _enrollTopic(context, topicRevCtrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.pastelIndigo(context),
                        foregroundColor: AppTheme.pastelIndigoText(context),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppTheme.pastelIndigoBorder(context),
                            width: 1.0,
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppTheme.pastelIndigoText(context),
                      ),
                      label: Text(
                        'Add to Revision (R1)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.pastelIndigoText(context),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const VGapMd(),
                if (!revision.isFinished) ...[
                  if (topic.status == TopicStatus.completed && isDue) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _completeCurrentLevel(context, topicRevCtrl, revision),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.successColor,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppTheme.successColor.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppTheme.successColor,
                        ),
                        label: Text(
                          'Complete R${revision.currentLevel}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ] else if (topic.status != TopicStatus.completed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          const HGapXs(),
                          Flexible(
                            child: Text(
                              'Mark topic as completed to continue revision',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                          const HGapXs(),
                          Flexible(
                            child: Text(
                              revision.daysUntilDue(now) == 1
                                  ? 'R${revision.currentLevel} unlocks tomorrow (${DateFormat('d MMM').format(revision.nextRevisionAt)})'
                                  : 'R${revision.currentLevel} unlocks in ${revision.daysUntilDue(now)} days (${DateFormat('d MMM').format(revision.nextRevisionAt)})',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, size: 20, color: AppTheme.successColor),
                        const HGapSm(),
                        Expanded(
                          child: Text(
                            'Topic mastered! All 5 revision stages completed.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  },
);
  }

  void _enrollTopic(BuildContext context, TopicRevisionController controller) async {
    try {
      await controller.enrollTopicInRevision(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topic.id,
        title: topic.title,
      );
      onRevisionUpdated?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${topic.title}" added to revision schedule (R1)'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error enrolling topic: $e');
    }
  }

  void _completeCurrentLevel(
    BuildContext context,
    TopicRevisionController controller,
    TopicRevision revision,
  ) async {
    final nextLevel = revision.currentLevel + 1;
    final success = await controller.completeCurrentLevel(revision.id);
    if (success && context.mounted) {
      onRevisionUpdated?.call();
      final msg = nextLevel > 5
          ? '🎉 Topic mastered! All revisions complete.'
          : 'Advanced to R$nextLevel';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _VerticalPipeline extends StatelessWidget {
  final TopicStatus topicStatus;
  final TopicRevision? revision;

  const _VerticalPipeline({
    required this.topicStatus,
    required this.revision,
  });

  static const List<int> _intervals = [1, 3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final isStudyDone = topicStatus == TopicStatus.completed;

    return Column(
      children: [
        // 0. Initial Study Status Node
        _buildStudyStatusRow(context, isStudyDone),
        // 1 to 5: R1 through R5
        for (var level = 1; level <= 5; level++)
          _buildRevisionRow(
            context,
            level: level,
            intervalDays: _intervals[level - 1],
            revision: revision,
            isLast: level == 5,
          ),
      ],
    );
  }

  Widget _buildStudyStatusRow(BuildContext context, bool isStudyDone) {
    final inProg = topicStatus == TopicStatus.inProgress;

    final Color indicatorBg;
    final Color indicatorBorder;
    final Color iconColor;
    final IconData iconData;
    final String label;
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeText;
    final String subtitle;

    if (isStudyDone) {
      indicatorBg = AppTheme.successColor;
      indicatorBorder = AppTheme.successColor.withValues(alpha: 0.35);
      iconColor = AppTheme.textOnDark;
      iconData = Icons.check_rounded;
      label = 'Learned';
      badgeBg = AppTheme.pastelGreen(context);
      badgeBorder = AppTheme.pastelGreenBorder(context);
      badgeText = AppTheme.pastelGreenText(context);
      subtitle = 'Topic completed • Ready for repetition';
    } else if (inProg) {
      indicatorBg = AppTheme.pastelPurple(context);
      indicatorBorder = AppTheme.pastelPurpleBorder(context);
      iconColor = AppTheme.pastelPurpleText(context);
      iconData = Icons.timelapse_rounded;
      label = 'In Progress';
      badgeBg = AppTheme.pastelPurple(context);
      badgeBorder = AppTheme.pastelPurpleBorder(context);
      badgeText = AppTheme.pastelPurpleText(context);
      subtitle = 'Topic currently being studied';
    } else {
      indicatorBg = AppTheme.surface(context);
      indicatorBorder = AppTheme.borderColor(context);
      iconColor = AppTheme.textMutedColor(context);
      iconData = Icons.radio_button_unchecked_rounded;
      label = 'Not Started';
      badgeBg = AppTheme.surfaceVariant(context);
      badgeBorder = AppTheme.borderColor(context);
      badgeText = AppTheme.textSecondaryColor(context);
      subtitle = 'Study session not started yet';
    }

    final lineColor = isStudyDone
        ? AppTheme.successColor.withValues(alpha: 0.35)
        : AppTheme.borderColor(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: indicatorBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: indicatorBorder,
                      width: isStudyDone ? 4 : 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconData, size: 11, color: iconColor),
                ),
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
              padding: const EdgeInsets.only(top: 2, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Study Phase',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const HGapXs(),
                      DetailStatusBadge(
                        label: label,
                        backgroundColor: badgeBg,
                        borderColor: badgeBorder,
                        textColor: badgeText,
                      ),
                    ],
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionRow(
    BuildContext context, {
    required int level,
    required int intervalDays,
    required TopicRevision? revision,
    required bool isLast,
  }) {
    final isCleared = revision != null && (revision.isFinished || level < revision.currentLevel);
    final isCurrent = revision != null && !revision.isFinished && level == revision.currentLevel;
    final now = DateTime.now();
    final isDue = isCurrent && revision.isDueAt(now);

    final lineColor = isCleared
        ? AppTheme.successColor.withValues(alpha: 0.35)
        : isCurrent
            ? AppTheme.primaryColor.withValues(alpha: 0.30)
            : AppTheme.borderColor(context);

    final Widget indicator;
    final String statusLabel;
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeText;

    if (isCleared) {
      statusLabel = 'Cleared';
      badgeBg = AppTheme.pastelGreen(context);
      badgeBorder = AppTheme.pastelGreenBorder(context);
      badgeText = AppTheme.pastelGreenText(context);
      indicator = Container(
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
        child: const Icon(
          Icons.check_rounded,
          color: AppTheme.textOnDark,
          size: 11,
        ),
      );
    } else if (isCurrent) {
      statusLabel = isDue ? 'Due Today' : 'Pending';
      badgeBg = isDue
          ? AppTheme.errorColor.withValues(alpha: 0.12)
          : AppTheme.pastelPurple(context);
      badgeBorder = isDue
          ? AppTheme.errorColor.withValues(alpha: 0.35)
          : AppTheme.pastelPurpleBorder(context);
      badgeText = isDue ? AppTheme.errorColor : AppTheme.pastelPurpleText(context);
      indicator = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: isDue ? AppTheme.errorColor : AppTheme.primaryColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: (isDue ? AppTheme.errorColor : AppTheme.primaryColor)
                .withValues(alpha: 0.30),
            width: 4,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppTheme.textOnDark,
            shape: BoxShape.circle,
          ),
        ),
      );
    } else {
      statusLabel = 'Upcoming';
      badgeBg = AppTheme.surfaceVariant(context);
      badgeBorder = AppTheme.borderColor(context);
      badgeText = AppTheme.textSecondaryColor(context);
      indicator = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 2,
          ),
        ),
      );
    }

    String? dateDetail;
    if (isCurrent && revision != null) {
      dateDetail = DateFormat('d MMM, yyyy').format(revision.nextRevisionAt);
    } else if (isCleared && level == 1 && revision != null) {
      dateDetail = DateFormat('d MMM, yyyy').format(revision.createdAt);
    } else if (isCleared && level == 5 && revision?.completedAt != null) {
      dateDetail = DateFormat('d MMM, yyyy').format(revision!.completedAt!);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                indicator,
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
              padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 16),
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
                              ? (isDue ? AppTheme.errorColor : AppTheme.primaryColor)
                              : AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const HGapXs(),
                      DetailStatusBadge(
                        label: statusLabel,
                        backgroundColor: badgeBg,
                        borderColor: badgeBorder,
                        textColor: badgeText,
                      ),
                    ],
                  ),
                  const VGapXs(),
                  Row(
                    children: [
                      Text(
                        '+${intervalDays}d interval',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? (isDue ? AppTheme.errorColor : AppTheme.primaryColor)
                              : AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      if (dateDetail != null) ...[
                        const HGapXs(),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textMutedColor(context).withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const HGapXs(),
                        Text(
                          dateDetail,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
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

// =============================================================================
// SUBSECTION: NOTES & DESCRIPTION CARD
// =============================================================================

class _TopicNotesCard extends StatelessWidget {
  final String description;
  final VoidCallback? onDoubleTap;

  const _TopicNotesCard({
    required this.description,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = description.trim();
    final hasNotes = trimmed.isNotEmpty;
    final urls = UrlHighlightEditingController.extractUrls(trimmed);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          'Notes/Description',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        hasNotes
            ? Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  children: UrlHighlightEditingController.buildUrlSpans(
                    text: trimmed,
                    defaultStyle: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    urlStyle: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF2196F3),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF2196F3),
                    ),
                    onUrlTap: (u) => UrlLauncherHelper.openUrl(u, context: context),
                  ),
                ),
              )
            : Text(
                'No notes added yet.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
        if (urls.isNotEmpty) ...[
          const VGapSm(),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final u in urls)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => UrlLauncherHelper.openUrl(u, context: context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 15,
                            color: Color(0xFF2196F3),
                          ),
                          const HGapXs(),
                          Flexible(
                            child: Text(
                              u,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const HGapXs(),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: Color(0xFF2196F3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
    );
  }
}

