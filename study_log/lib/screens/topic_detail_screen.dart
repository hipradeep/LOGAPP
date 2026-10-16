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
import '../services/local_study_log_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/study_confirmation_dialog.dart';
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

  const TopicDetailScreen({
    super.key,
    required this.topic,
    required this.moduleTitle,
    this.courseTitle = '',
    this.courseId = '',
    this.moduleId = '',
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  late Topic _topic;
  List<StudyLog> _topicLogs = [];

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    _loadTopicData();
  }

  Future<void> _loadTopicData() async {
    // 1. Refresh topic entity from database/cache
    try {
      final topics = await LocalTopicStorage.loadTopicsForModule(
        moduleId: widget.moduleId,
        fallbackTitle: widget.moduleTitle,
      );
      final match = topics.where((t) => t.id == _topic.id).firstOrNull;
      if (match != null && mounted) {
        _topic = match;
      }
    } catch (_) {}

    // 2. Load study logs for this specific topic
    try {
      final allLogs = await LocalStudyLogStorage.loadAll();
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

    final updated = _topic.copyWith(
      status: newStatus,
      completedAt: newStatus == TopicStatus.completed ? DateTime.now() : null,
      clearCompletedAt: newStatus != TopicStatus.completed,
    );

    setState(() {
      _topic = updated;
    });

    final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
    try {
      final currentTopics = await LocalTopicStorage.loadTopicsForModule(
        moduleId: widget.moduleId,
        fallbackTitle: widget.moduleTitle,
      );
      final index = currentTopics.indexWhere((t) => t.id == updated.id);
      if (index != -1) {
        currentTopics[index] = updated;
        await LocalTopicStorage.saveTopics(key, currentTopics);
      }

      if (getIt.isRegistered<DatabaseService>()) {
        await getIt<DatabaseService>().updateTopic(updated);
      }

      if (updated.isCompleted) {
        final studyLog = StudyLog(
          id: '${updated.id}_${DateTime.now().millisecondsSinceEpoch}',
          type: StudyLogType.topicCompleted,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          topicId: updated.id,
          topicTitle: updated.title,
          timestamp: updated.completedAt ?? DateTime.now(),
          createdAt: DateTime.now(),
        );
        await LocalStudyLogStorage.addLog(studyLog);
      }

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
      final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
      final currentTopics = await LocalTopicStorage.loadTopicsForModule(
        moduleId: widget.moduleId,
        fallbackTitle: widget.moduleTitle,
      );
      currentTopics.removeWhere((t) => t.id == _topic.id);
      await LocalTopicStorage.saveTopics(key, currentTopics);

      if (getIt.isRegistered<DatabaseService>() && _topic.id.isNotEmpty) {
        unawaited(getIt<DatabaseService>().deleteTopic(_topic.id));
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

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
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
              const VGapXs(),
              Divider(
                height: 12,
                thickness: 1.0,
                color: AppTheme.borderColor(context),
              ),
              const VGapXs(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.0, 4.0, 16.0, bottomSafe + 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopicNotesCard(
                        description: _topic.description,
                      ),
                      const VGapMd(),
                      _TopicRevisionLadderCard(
                        topic: _topic,
                        courseId: widget.courseId,
                        moduleId: widget.moduleId,
                        courseTitle: widget.courseTitle,
                        moduleTitle: widget.moduleTitle,
                        onRevisionUpdated: _loadTopicData,
                        onStatusChanged: _handleStatusChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  static final DateFormat _dateFormat = DateFormat('d MMM, yyyy');

  const _CompactTopicHeader({
    required this.topicTitle,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    required this.lastUpdatedAt,
    required this.totalMinutesExpended,
    required this.onStatusChanged,
  });

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '0h';
    final hours = minutes / 60.0;
    if (minutes % 60 == 0) {
      return '${hours.toInt()}h';
    } else if (hours < 1.0) {
      return '${minutes}m';
    } else {
      return '${hours.toStringAsFixed(1).replaceAll('.0', '')}h';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _dateFormat.format(lastUpdatedAt);
    final hoursStr = _formatDuration(totalMinutesExpended);

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModuleContextPill(
            moduleTitle: displayTitle,
            courseId: courseId,
            courseTitle: courseTitle,
          ),
          const VGapXs(),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: AppTheme.textMutedColor(context),
                  ),
                  const HGapXs(),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppTheme.textMutedColor(context),
                  ),
                  const HGapXs(),
                  Text(
                    hoursStr,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<TopicStatus>(
                onSelected: onStatusChanged,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: AppTheme.surface(context),
                elevation: 4,
                itemBuilder: (_) => [
                  _buildPopupItem(context, TopicStatus.notStarted, 'Not Started', Icons.radio_button_unchecked_rounded),
                  _buildPopupItem(context, TopicStatus.inProgress, 'In Progress', Icons.timelapse_rounded),
                  _buildPopupItem(context, TopicStatus.completed, 'Completed', Icons.check_circle_rounded),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down_rounded, size: 12, color: statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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

        return Container(
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
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.pastelIndigo(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 16,
                      color: AppTheme.pastelIndigoText(context),
                    ),
                  ),
                  const HGapSm(),
                  Text(
                    'Repetition',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const Spacer(),
                  if (revision != null) ...[
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
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Text(
                        topic.status == TopicStatus.completed ? 'Ready for R1' : 'Study Phase',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const VGapMd(),

              // Direct Horizontal Ladder: (Study Status) -> R1 -> R2 -> R3 -> R4 -> R5
              _HorizontalPipeline(
                topicStatus: topic.status,
                revision: revision,
                onStatusChanged: onStatusChanged,
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
                          Text(
                            'Mark topic as completed to continue revision',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondaryColor(context),
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
                          Text(
                            revision.daysUntilDue(now) == 1
                                ? 'R${revision.currentLevel} unlocks tomorrow (${DateFormat('d MMM').format(revision.nextRevisionAt)})'
                                : 'R${revision.currentLevel} unlocks in ${revision.daysUntilDue(now)} days (${DateFormat('d MMM').format(revision.nextRevisionAt)})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondaryColor(context),
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

class _HorizontalPipeline extends StatelessWidget {
  final TopicStatus topicStatus;
  final TopicRevision? revision;
  final ValueChanged<TopicStatus>? onStatusChanged;

  const _HorizontalPipeline({
    required this.topicStatus,
    required this.revision,
    this.onStatusChanged,
  });

  static const List<int> _intervals = [1, 3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final isStudyDone = topicStatus == TopicStatus.completed;

    // Connecting lines states
    final line0Active = isStudyDone;
    final line1Active = revision != null && (revision!.isFinished || revision!.currentLevel >= 2);
    final line2Active = revision != null && (revision!.isFinished || revision!.currentLevel >= 3);
    final line3Active = revision != null && (revision!.isFinished || revision!.currentLevel >= 4);
    final line4Active = revision != null && (revision!.isFinished || revision!.currentLevel >= 5);

    final line0Color = revision != null ? AppTheme.primaryColor : AppTheme.successColor;

    return Row(
      children: [
        _buildStudyStatusNode(context, topicStatus),
        _buildConnectingLine(context, line0Active, customColor: line0Color),
        _buildRevisionNode(context, 1, _intervals[0], revision),
        _buildConnectingLine(context, line1Active),
        _buildRevisionNode(context, 2, _intervals[1], revision),
        _buildConnectingLine(context, line2Active),
        _buildRevisionNode(context, 3, _intervals[2], revision),
        _buildConnectingLine(context, line3Active),
        _buildRevisionNode(context, 4, _intervals[3], revision),
        _buildConnectingLine(context, line4Active),
        _buildRevisionNode(context, 5, _intervals[4], revision),
      ],
    );
  }

  Widget _buildStudyStatusNode(BuildContext context, TopicStatus status) {
    final isDone = status == TopicStatus.completed;
    final inProg = status == TopicStatus.inProgress;

    final Color bg;
    final Color border;
    final Color iconColor;
    final IconData icon;
    final String label;

    if (isDone) {
      bg = AppTheme.successColor;
      border = AppTheme.successColor;
      iconColor = Colors.white;
      icon = Icons.check_rounded;
      label = 'Learned';
    } else if (inProg) {
      bg = AppTheme.pastelPurple(context);
      border = AppTheme.pastelPurpleBorder(context);
      iconColor = AppTheme.pastelPurpleText(context);
      icon = Icons.timelapse_rounded;
      label = 'In Prog';
    } else {
      bg = AppTheme.surfaceVariant(context);
      border = AppTheme.borderColor(context);
      iconColor = AppTheme.textMutedColor(context);
      icon = Icons.radio_button_unchecked_rounded;
      label = 'Study';
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onStatusChanged == null
            ? null
            : () {
                final TopicStatus next;
                switch (status) {
                  case TopicStatus.notStarted:
                    next = TopicStatus.inProgress;
                    break;
                  case TopicStatus.inProgress:
                    next = TopicStatus.completed;
                    break;
                  case TopicStatus.completed:
                    next = TopicStatus.notStarted;
                    break;
                }
                onStatusChanged!(next);
              },
        borderRadius: BorderRadius.circular(10),
        child: Tooltip(
          message: 'Tap to change status ($label)',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                    border: Border.all(color: border, width: inProg ? 2.0 : 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const VGapXs(),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isDone || inProg ? FontWeight.bold : FontWeight.w500,
                    color: isDone
                        ? AppTheme.successColor
                        : (inProg ? AppTheme.pastelPurpleText(context) : AppTheme.textMutedColor(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevisionNode(
    BuildContext context,
    int level,
    int intervalDays,
    TopicRevision? revision,
  ) {
    final isCompleted = revision != null && (revision.isFinished || level < revision.currentLevel);
    final isCurrent = revision != null && !revision.isFinished && level == revision.currentLevel;

    final Color bg;
    final Color border;
    final Color textColor;
    final double borderWidth;

    if (isCompleted) {
      bg = AppTheme.successColor;
      border = AppTheme.successColor;
      textColor = Colors.white;
      borderWidth = 1.5;
    } else if (isCurrent) {
      bg = AppTheme.primaryColor;
      border = AppTheme.primaryColor;
      textColor = Colors.white;
      borderWidth = 2.5;
    } else {
      bg = AppTheme.surfaceVariant(context);
      border = AppTheme.borderColor(context);
      textColor = AppTheme.textSecondaryColor(context);
      borderWidth = 1.5;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: borderWidth),
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text(
                  'R$level',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
        ),
        const VGapXs(),
        Text(
          '+${intervalDays}d',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent
                ? AppTheme.primaryColor
                : (isCompleted ? AppTheme.successColor : AppTheme.textMutedColor(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingLine(BuildContext context, bool isActive, {Color? customColor}) {
    final lineColor = isActive
        ? (customColor ?? AppTheme.primaryColor)
        : AppTheme.borderColor(context);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 2.5,
            color: lineColor,
          ),
          const VGapXs(),
          const SizedBox(height: 12),
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

  const _TopicNotesCard({
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = description.trim();
    final hasNotes = trimmed.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
              const HGapSm(),
              Text(
                'Notes/Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ],
          ),
          const VGapSm(),
          Text(
            hasNotes ? trimmed : 'No notes added yet.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
              color: hasNotes
                  ? AppTheme.textSecondaryColor(context)
                  : AppTheme.textMutedColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

