import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../models/revision_module.dart';
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
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/study_text_fields.dart';
import '../widgets/underline_tab_item.dart';
import '../widgets/topic_options_sheet.dart';
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

final DateFormat _dayMonthFormat = DateFormat('d MMM');
final DateFormat _dayMonthYearFormat = DateFormat('d MMM, yyyy');

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  late Topic _topic;
  int _totalMinutesExpended = 0;
  DateTime? _lastUpdatedAt;
  final ValueNotifier<int> _activeTab = ValueNotifier<int>(0);
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _topic = widget.topic;
    if (widget.isFromModuleRevision) {
      _activeTab.value = 1;
    }
    _pageController = PageController(initialPage: _activeTab.value);
    _loadTopicData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _activeTab.dispose();
    super.dispose();
  }

  void _handleTabSelected(int index) {
    if (_activeTab.value != index) {
      _activeTab.value = index;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
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

    // 2. Load study logs for this specific topic and precompute metrics
    try {
      final filtered =
          await DatabaseService.instance.getStudyLogsByTopic(_topic.id);

      int minutes = 0;
      for (final l in filtered) {
        if (l.durationMinutes != null && l.durationMinutes! > 0) {
          minutes += l.durationMinutes!;
        }
      }

      final DateTime lastDate;
      if (getIt.isRegistered<TopicRevisionController>()) {
        final rev = getIt<TopicRevisionController>().topicRevisionFor(_topic.id);
        if (rev != null) {
          lastDate = rev.lastRevisionAt ?? rev.updatedAt;
        } else if (_topic.completedAt != null) {
          lastDate = _topic.completedAt!;
        } else if (filtered.isNotEmpty) {
          lastDate = filtered.first.timestamp;
        } else {
          lastDate = DateTime.now();
        }
      } else if (_topic.completedAt != null) {
        lastDate = _topic.completedAt!;
      } else if (filtered.isNotEmpty) {
        lastDate = filtered.first.timestamp;
      } else {
        lastDate = DateTime.now();
      }

      if (mounted) {
        setState(() {
          _totalMinutesExpended = minutes;
          _lastUpdatedAt = lastDate;
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

        // Prompt to move into revision schedule if not yet enrolled
        final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
            ? getIt<TopicRevisionController>()
            : null;
        if (mounted && topicRevCtrl != null && !topicRevCtrl.isTopicEnrolled(updated.id)) {
          final shouldMove = await StudyConfirmationDialog.showMoveToRevision(
            context,
            topicTitle: updated.title,
            courseTitle: widget.courseTitle,
            moduleTitle: widget.moduleTitle,
          );
          if (shouldMove && mounted) {
            await topicRevCtrl.enrollTopicInRevision(
              courseId: resolvedCourseId,
              moduleId: resolvedModuleId,
              topicId: updated.id,
              title: updated.title,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${updated.title}" added to revision schedule (R1)'),
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          }
        }
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

  Future<void> _handleRevisionStatusChanged(TopicStatus newStatus) async {
    final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
        ? getIt<TopicRevisionController>()
        : null;
    if (topicRevCtrl == null) return;
    final rev = topicRevCtrl.topicRevisionFor(_topic.id);
    if (rev == null) return;

    await topicRevCtrl.setLevelStatus(rev.id, newStatus);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleStartStudy([bool isRevision = false]) async {
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


  void _handleOpenOptions() async {
    await TopicOptionsSheet.show(
      context,
      topic: _topic,
      moduleTitle: widget.moduleTitle,
      courseTitle: widget.courseTitle,
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      onEdit: _handleEditFullTopic,
      onDelete: _handleDeleteTopic,
    );
    if (mounted) {
      _loadTopicData();
    }
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
      if (!mounted) return;
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

  String get _resolvedAppBarTitle {
    if (widget.moduleTitle.isNotEmpty) return widget.moduleTitle;
    if (widget.courseTitle.isNotEmpty) return widget.courseTitle;
    return 'Topic';
  }

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;
    Navigator.pop(context, _topic);
  }

  void _handleAppBarBack() {
    Navigator.pop(context, _topic);
  }

  void _handlePageChanged(int idx) {
    _activeTab.value = idx;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = widget.isFromModuleRevision ? (bottomSafe + 24) : (bottomSafe + 84);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        floatingActionButton: widget.isFromModuleRevision
            ? null
            : _TopicFloatingActionButton(
                topic: _topic,
                onStartStudy: _handleStartStudy,
              ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomAppBar(
                title: _resolvedAppBarTitle,
                onBack: _handleAppBarBack,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: _handleOpenOptions,
                    tooltip: 'Options',
                  ),
                ],
              ),
              _TopicHeaderSection(
                topic: _topic,
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
                lastUpdatedAt: _lastUpdatedAt,
                totalMinutesExpended: _totalMinutesExpended,
                onStatusChanged: _handleStatusChanged,
                onRevisionStatusChanged: _handleRevisionStatusChanged,
              ),
              _TopicTabsSection(
                topicId: _topic.id,
                activeTab: _activeTab,
                onTabSelected: _handleTabSelected,
              ),
              const VGapSm(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: _handlePageChanged,
                  children: [
                    _TopicNotesTabView(
                      description: _topic.description,
                      bottomPadding: bottomPadding,
                      onDoubleTap: _handleEditFullTopic,
                    ),
                    _TopicRevisionTabView(
                      topic: _topic,
                      courseId: widget.courseId,
                      moduleId: widget.moduleId,
                      courseTitle: widget.courseTitle,
                      moduleTitle: widget.moduleTitle,
                      bottomPadding: bottomPadding,
                      onRevisionUpdated: _loadTopicData,
                      onStatusChanged: _handleStatusChanged,
                    ),
                  ],
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
// SUBSECTION: EXTRACTED TAB VIEWS & SECTIONS (VIEW GRAVITY CHECK COMPLIANT)
// =============================================================================

class _TopicFloatingActionButton extends StatelessWidget {
  final Topic topic;
  final ValueChanged<bool> onStartStudy;

  const _TopicFloatingActionButton({
    required this.topic,
    required this.onStartStudy,
  });

  @override
  Widget build(BuildContext context) {
    if (getIt.isRegistered<TopicRevisionController>()) {
      return ListenableBuilder(
        listenable: getIt<TopicRevisionController>(),
        builder: (context, _) {
          final revCtrl = getIt<TopicRevisionController>();
          final revision = revCtrl.topicRevisionFor(topic.id);
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
            switch (topic.status) {
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
            onPressed: () => onStartStudy(isRevision),
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
      onPressed: () => onStartStudy(topic.isCompleted),
      backgroundColor:
          topic.isCompleted ? AppTheme.successColor : AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      tooltip:
          topic.isCompleted ? 'Start Revision Session' : 'Start Study Session',
      child: const Icon(Icons.play_arrow_rounded, size: 28),
    );
  }
}

class _TopicHeaderSection extends StatelessWidget {
  final Topic topic;
  final String courseId;
  final String courseTitle;
  final DateTime? lastUpdatedAt;
  final int totalMinutesExpended;
  final ValueChanged<TopicStatus> onStatusChanged;
  final ValueChanged<TopicStatus>? onRevisionStatusChanged;

  const _TopicHeaderSection({
    required this.topic,
    required this.courseId,
    required this.courseTitle,
    required this.lastUpdatedAt,
    required this.totalMinutesExpended,
    required this.onStatusChanged,
    this.onRevisionStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (getIt.isRegistered<TopicRevisionController>()) {
      return ListenableBuilder(
        listenable: getIt<TopicRevisionController>(),
        builder: (context, _) {
          final rev = getIt<TopicRevisionController>().topicRevisionFor(topic.id);
          return _CompactTopicHeader(
            topicTitle: topic.title,
            courseId: courseId,
            courseTitle: courseTitle,
            status: topic.status,
            topicRevision: rev,
            lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
            totalMinutesExpended: totalMinutesExpended,
            onStatusChanged: onStatusChanged,
            onRevisionStatusChanged: onRevisionStatusChanged,
          );
        },
      );
    }

    return _CompactTopicHeader(
      topicTitle: topic.title,
      courseId: courseId,
      courseTitle: courseTitle,
      status: topic.status,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      totalMinutesExpended: totalMinutesExpended,
      onStatusChanged: onStatusChanged,
    );
  }
}

class _TopicTabsSection extends StatelessWidget {
  final String topicId;
  final ValueNotifier<int> activeTab;
  final ValueChanged<int> onTabSelected;

  const _TopicTabsSection({
    required this.topicId,
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
        ? getIt<TopicRevisionController>()
        : null;

    if (topicRevCtrl != null) {
      return ListenableBuilder(
        listenable: topicRevCtrl,
        builder: (context, _) {
          final revision = topicRevCtrl.topicRevisionFor(topicId);
          final String progressLabel;
          if (revision != null) {
            final levelLabel = revision.isFinished ? 'Done' : 'R${revision.currentLevel}';
            progressLabel = 'Progress ($levelLabel)';
          } else {
            progressLabel = 'Progress';
          }
          return ValueListenableBuilder<int>(
            valueListenable: activeTab,
            builder: (context, activeIdx, _) {
              return _TopicTabsRow(
                activeIndex: activeIdx,
                progressLabel: progressLabel,
                onTabSelected: onTabSelected,
              );
            },
          );
        },
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: activeTab,
      builder: (context, activeIdx, _) {
        return _TopicTabsRow(
          activeIndex: activeIdx,
          progressLabel: 'Progress',
          onTabSelected: onTabSelected,
        );
      },
    );
  }
}

class _TopicNotesTabView extends StatelessWidget {
  final String description;
  final double bottomPadding;
  final VoidCallback onDoubleTap;

  const _TopicNotesTabView({
    required this.description,
    required this.bottomPadding,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return _KeepAlivePage(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.0, 4.0, 16.0, bottomPadding),
        child: _TopicNotesCard(
          description: description,
          onDoubleTap: onDoubleTap,
        ),
      ),
    );
  }
}

class _TopicRevisionTabView extends StatelessWidget {
  final Topic topic;
  final String courseId;
  final String moduleId;
  final String courseTitle;
  final String moduleTitle;
  final double bottomPadding;
  final VoidCallback onRevisionUpdated;
  final ValueChanged<TopicStatus> onStatusChanged;

  const _TopicRevisionTabView({
    required this.topic,
    required this.courseId,
    required this.moduleId,
    required this.courseTitle,
    required this.moduleTitle,
    required this.bottomPadding,
    required this.onRevisionUpdated,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _KeepAlivePage(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.0, 4.0, 16.0, bottomPadding),
        child: _TopicRevisionLadderCard(
          topic: topic,
          courseId: courseId,
          moduleId: moduleId,
          courseTitle: courseTitle,
          moduleTitle: moduleTitle,
          onRevisionUpdated: onRevisionUpdated,
          onStatusChanged: onStatusChanged,
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
  final TopicRevision? topicRevision;
  final DateTime lastUpdatedAt;
  final int totalMinutesExpended;
  final ValueChanged<TopicStatus> onStatusChanged;
  final ValueChanged<TopicStatus>? onRevisionStatusChanged;

  const _CompactTopicHeader({
    required this.topicTitle,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    this.topicRevision,
    required this.lastUpdatedAt,
    required this.totalMinutesExpended,
    required this.onStatusChanged,
    this.onRevisionStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = EntityDetailHeader.formatDate(lastUpdatedAt);
    final hoursStr = EntityDetailHeader.formatDuration(totalMinutesExpended);

    final Color statusBg;
    final Color statusBorder;
    final Color statusColor;
    final String statusLabel;

    final effectiveStatus = topicRevision?.levelStatus ?? status;

    if (topicRevision != null) {
      if (topicRevision!.isFinished) {
        statusBg = AppTheme.successColor.withValues(alpha: 0.12);
        statusBorder = AppTheme.successColor.withValues(alpha: 0.25);
        statusColor = AppTheme.successColor;
        statusLabel = 'Mastered';
      } else {
        final level = topicRevision!.currentLevel;
        switch (topicRevision!.levelStatus) {
          case TopicStatus.completed:
            final now = DateTime.now();
            final isEarly = !topicRevision!.isDueAt(now);
            if (isEarly) {
              statusBg = AppTheme.pastelBlue(context);
              statusBorder = AppTheme.pastelBlueBorder(context);
              statusColor = AppTheme.pastelBlueText(context);
              statusLabel = 'R$level: Completed';
            } else {
              statusBg = AppTheme.successColor.withValues(alpha: 0.12);
              statusBorder = AppTheme.successColor.withValues(alpha: 0.25);
              statusColor = AppTheme.successColor;
              statusLabel = 'R$level: Completed';
            }
            break;
          case TopicStatus.inProgress:
            statusBg = AppTheme.pastelPurple(context);
            statusBorder = AppTheme.pastelPurpleBorder(context);
            statusColor = AppTheme.pastelPurpleText(context);
            statusLabel = 'R$level: In Progress';
            break;
          case TopicStatus.notStarted:
            statusBg = AppTheme.surfaceVariant(context);
            statusBorder = AppTheme.borderColor(context);
            statusColor = AppTheme.textSecondaryColor(context);
            statusLabel = 'R$level: Not Started';
            break;
        }
      }
    } else {
      final isComplete = status == TopicStatus.completed;
      final inProgress = status == TopicStatus.inProgress;

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
        onSelected: (newStatus) {
          if (topicRevision != null && onRevisionStatusChanged != null) {
            onRevisionStatusChanged!(newStatus);
          } else {
            onStatusChanged(newStatus);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppTheme.surface(context),
        elevation: 4,
        itemBuilder: (_) => [
          _buildPopupItem(context, TopicStatus.notStarted, 'Not Started', Icons.radio_button_unchecked_rounded, effectiveStatus),
          _buildPopupItem(context, TopicStatus.inProgress, 'In Progress', Icons.timelapse_rounded, effectiveStatus),
          _buildPopupItem(context, TopicStatus.completed, 'Completed', Icons.check_circle_rounded, effectiveStatus),
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
    TopicStatus currentStatus,
  ) {
    final isSelected = currentStatus == itemStatus;
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
            UnderlineTabItem(
              label: 'Notes',
              isActive: activeIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            const HGapLg(),
            UnderlineTabItem(
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

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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

  void _handleEnroll(BuildContext context, TopicRevisionController controller) async {
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

  void _handleAdvanceOrComplete(
    BuildContext context,
    TopicRevisionController controller,
    TopicRevision revision,
  ) async {
    final now = DateTime.now();
    if (!revision.isDueAt(now)) {
      return;
    }
    if (revision.levelStatus == TopicStatus.notStarted) {
      await controller.setLevelStatus(revision.id, TopicStatus.inProgress);
      return;
    }

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
            if (revision == null)
              _StudyPhaseStatusHeader(status: topic.status)
            else if (!revision.isFinished)
              _RevisionStatusHeader(revision: revision, now: now, isDue: isDue)
            else
              const _MasteredStatusHeader(),

            // Vertical Repetition Pipeline: Study Phase -> R1 -> R2 -> R3 -> R4 -> R5
            _VerticalPipeline(
              topic: topic,
              topicStatus: topic.status,
              revision: revision,
              onToggleCurrentLevelStatus: revision != null && !revision.isFinished
                  ? () => topicRevCtrl.toggleLevelStatus(revision.id)
                  : null,
              onEnrollRevision: revision == null && topic.status == TopicStatus.completed
                  ? () => _handleEnroll(context, topicRevCtrl)
                  : null,
              onToggleStudyStatus: onStatusChanged != null && (revision == null || topic.status != TopicStatus.completed)
                  ? () {
                      final next = topic.status == TopicStatus.notStarted
                          ? TopicStatus.inProgress
                          : (topic.status == TopicStatus.inProgress
                              ? TopicStatus.completed
                              : TopicStatus.notStarted);
                      onStatusChanged!(next);
                    }
                  : null,
            ),

            // Bottom Actions Row
            _RevisionBottomActions(
              topic: topic,
              revision: revision,
              isDue: isDue,
              now: now,
              onEnroll: () => _handleEnroll(context, topicRevCtrl),
              onAdvanceOrComplete: revision != null
                  ? () => _handleAdvanceOrComplete(context, topicRevCtrl, revision)
                  : () {},
            ),
          ],
        );
      },
    );
  }
}

class _RevisionBottomActions extends StatelessWidget {
  final Topic topic;
  final TopicRevision? revision;
  final bool isDue;
  final DateTime now;
  final VoidCallback onEnroll;
  final VoidCallback onAdvanceOrComplete;

  const _RevisionBottomActions({
    required this.topic,
    required this.revision,
    required this.isDue,
    required this.now,
    required this.onEnroll,
    required this.onAdvanceOrComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (revision == null) {
      if (topic.status == TopicStatus.completed) {
        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onEnroll,
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
        );
      }
      return const SizedBox.shrink();
    }

    if (!revision!.isFinished) {
      if (isDue) {
        final isCompleted = revision!.levelStatus == TopicStatus.completed;
        final isInProgress = revision!.levelStatus == TopicStatus.inProgress;
        final isNotStarted = revision!.levelStatus == TopicStatus.notStarted;

        final Color btnBg = isCompleted
            ? AppTheme.pastelGreen(context)
            : (isInProgress
                ? AppTheme.successColor.withValues(alpha: 0.12)
                : AppTheme.pastelPurple(context));

        final Color btnFg = isCompleted
            ? AppTheme.pastelGreenText(context)
            : (isInProgress
                ? AppTheme.successColor
                : AppTheme.pastelPurpleText(context));

        final Color btnBorder = isCompleted
            ? AppTheme.pastelGreenBorder(context)
            : (isInProgress
                ? AppTheme.successColor.withValues(alpha: 0.35)
                : AppTheme.pastelPurpleBorder(context));

        final IconData btnIcon = isCompleted
            ? Icons.check_circle_rounded
            : (isInProgress
                ? Icons.check_circle_outline_rounded
                : Icons.play_arrow_rounded);

        final String btnLabel = isNotStarted
            ? 'Start R${revision!.currentLevel} (In Progress)'
            : (isInProgress
                ? 'Complete R${revision!.currentLevel}'
                : 'Advance to R${revision!.currentLevel + 1}');

        return Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdvanceOrComplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: btnBg,
                foregroundColor: btnFg,
                elevation: 0,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: btnBorder,
                    width: 1.0,
                  ),
                ),
              ),
              icon: Icon(btnIcon, size: 18, color: btnFg),
              label: Text(
                btnLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: btnFg,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        );
      }

      // Not due yet: strictly locked from advancing until scheduled due date
      final days = revision!.daysUntilDue(now);
      final nextLevelNum = revision!.levelStatus == TopicStatus.completed
          ? revision!.currentLevel + 1
          : revision!.currentLevel;
      final dateStr = _dayMonthFormat.format(revision!.nextRevisionAt);
      final unlockText = days <= 1
          ? 'R$nextLevelNum unlocks tomorrow ($dateStr)'
          : 'R$nextLevelNum unlocks in $days days ($dateStr)';

      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Container(
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
                  unlockText,
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
      );
    }

    // Mastered banner
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.stars_rounded, size: 20, color: AppTheme.successColor),
            HGapSm(),
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
    );
  }
}

class _RevisionStatusHeader extends StatelessWidget {
  final TopicRevision revision;
  final DateTime now;
  final bool isDue;

  const _RevisionStatusHeader({
    required this.revision,
    required this.now,
    required this.isDue,
  });

  @override
  Widget build(BuildContext context) {
    final int currentLevel = revision.currentLevel;
    final int days = revision.daysUntilDue(now);
    final String dateStr = _dayMonthFormat.format(revision.nextRevisionAt);

    final IconData statusIcon;
    final Color statusColor;
    final String statusText;

    switch (revision.levelStatus) {
      case TopicStatus.completed:
        final isEarly = !isDue;
        statusIcon = Icons.check_circle_rounded;
        statusColor = isEarly ? AppTheme.pastelBlueText(context) : AppTheme.successColor;
        statusText = 'R$currentLevel completed for this interval';
        break;

      case TopicStatus.inProgress:
        statusIcon = Icons.timelapse_rounded;
        statusColor = AppTheme.pastelPurpleText(context);
        statusText = 'R$currentLevel in progress';
        break;

      case TopicStatus.notStarted:
        if (isDue) {
          statusIcon = Icons.schedule_rounded;
          statusColor = AppTheme.errorColor;
          statusText = 'R$currentLevel due today';
        } else {
          statusIcon = Icons.schedule_rounded;
          statusColor = AppTheme.textSecondaryColor(context);
          statusText = days <= 1
              ? 'R$currentLevel unlocks tomorrow ($dateStr)'
              : 'R$currentLevel unlocks in $days days ($dateStr)';
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const HGapSm(),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyPhaseStatusHeader extends StatelessWidget {
  final TopicStatus status;

  const _StudyPhaseStatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    final IconData statusIcon;
    final Color statusColor;
    final String statusText;

    switch (status) {
      case TopicStatus.completed:
        statusIcon = Icons.check_circle_rounded;
        statusColor = AppTheme.successColor;
        statusText = 'Study phase completed';
        break;
      case TopicStatus.inProgress:
        statusIcon = Icons.timelapse_rounded;
        statusColor = AppTheme.pastelPurpleText(context);
        statusText = 'Study phase in progress';
        break;
      case TopicStatus.notStarted:
        statusIcon = Icons.radio_button_unchecked_rounded;
        statusColor = AppTheme.textSecondaryColor(context);
        statusText = 'Study phase not started';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const HGapSm(),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteredStatusHeader extends StatelessWidget {
  const _MasteredStatusHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(Icons.stars_rounded, size: 16, color: AppTheme.successColor),
          HGapSm(),
          Text(
            'Topic mastered (All 5 revisions completed)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.successColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalPipeline extends StatelessWidget {
  final Topic topic;
  final TopicStatus topicStatus;
  final TopicRevision? revision;
  final VoidCallback? onToggleCurrentLevelStatus;
  final VoidCallback? onEnrollRevision;
  final VoidCallback? onToggleStudyStatus;

  const _VerticalPipeline({
    required this.topic,
    required this.topicStatus,
    required this.revision,
    this.onToggleCurrentLevelStatus,
    this.onEnrollRevision,
    this.onToggleStudyStatus,
  });

  DateTime _dateForLevel(int level) {
    final now = DateTime.now();
    if (revision == null) {
      DateTime cursor = topic.completedAt ?? now;
      for (int l = 1; l <= level; l++) {
        cursor = cursor.add(RevisionSchedule.intervalFor(l));
      }
      return cursor;
    }

    final rev = revision!;
    if (rev.isFinished) {
      if (level == 5 && rev.completedAt != null) {
        return rev.completedAt!;
      }
      if (level == 1) {
        return rev.createdAt;
      }
      DateTime cursor = rev.createdAt;
      for (int l = 1; l < level; l++) {
        cursor = cursor.add(RevisionSchedule.intervalFor(l));
      }
      return cursor;
    }

    if (level == rev.currentLevel) {
      return rev.nextRevisionAt;
    } else if (level < rev.currentLevel) {
      if (level == 1) {
        return rev.createdAt;
      }
      DateTime cursor = rev.createdAt;
      for (int l = 1; l < level; l++) {
        cursor = cursor.add(RevisionSchedule.intervalFor(l));
      }
      return cursor;
    } else {
      DateTime cursor = rev.nextRevisionAt;
      for (int l = rev.currentLevel + 1; l <= level; l++) {
        cursor = cursor.add(RevisionSchedule.intervalFor(l));
      }
      return cursor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStudyDone = topicStatus == TopicStatus.completed || revision != null;

    return Column(
      children: [
        _StudyStatusNode(
          topic: topic,
          topicStatus: topicStatus,
          revision: revision,
          isStudyDone: isStudyDone,
          onToggleStudyStatus: onToggleStudyStatus,
        ),
        for (var level = 1; level <= 5; level++)
          _RevisionLevelNode(
            level: level,
            revision: revision,
            isLast: level == 5,
            targetDate: _dateForLevel(level),
            onToggleCurrentLevelStatus: onToggleCurrentLevelStatus,
            onEnrollRevision: onEnrollRevision,
          ),
      ],
    );
  }
}

class _StudyStatusNode extends StatelessWidget {
  final Topic topic;
  final TopicStatus topicStatus;
  final TopicRevision? revision;
  final bool isStudyDone;
  final VoidCallback? onToggleStudyStatus;

  const _StudyStatusNode({
    required this.topic,
    required this.topicStatus,
    required this.revision,
    required this.isStudyDone,
    this.onToggleStudyStatus,
  });

  @override
  Widget build(BuildContext context) {
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
      final doneDate = topic.completedAt ?? revision?.createdAt ?? DateTime.now();
      subtitle = 'Completed on ${_dayMonthYearFormat.format(doneDate)}';
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

    final rowContent = Stack(
      children: [
        Positioned(
          top: 22,
          bottom: 0,
          left: 12,
          child: Container(
            width: 2,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: lineColor,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
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
      ],
    );

    if (onToggleStudyStatus != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleStudyStatus,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.08),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.04),
          child: rowContent,
        ),
      );
    }

    return rowContent;
  }
}

class _RevisionLevelNode extends StatelessWidget {
  final int level;
  final TopicRevision? revision;
  final bool isLast;
  final DateTime targetDate;
  final VoidCallback? onToggleCurrentLevelStatus;
  final VoidCallback? onEnrollRevision;

  const _RevisionLevelNode({
    required this.level,
    required this.revision,
    required this.isLast,
    required this.targetDate,
    this.onToggleCurrentLevelStatus,
    this.onEnrollRevision,
  });

  @override
  Widget build(BuildContext context) {
    final isCleared = revision != null && (revision!.isFinished || level < revision!.currentLevel);
    final isCurrent = revision != null && !revision!.isFinished && level == revision!.currentLevel;
    final now = DateTime.now();
    final isDue = isCurrent && revision!.isDueAt(now);

    final lineColor = isCleared
        ? AppTheme.successColor.withValues(alpha: 0.35)
        : (isCurrent && revision!.levelStatus == TopicStatus.inProgress)
            ? AppTheme.primaryColor.withValues(alpha: 0.30)
            : (isCurrent && revision!.levelStatus == TopicStatus.completed)
                ? (isDue
                    ? AppTheme.successColor.withValues(alpha: 0.35)
                    : AppTheme.pastelBlueBorder(context))
                : AppTheme.borderColor(context);

    Widget indicator;
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
      switch (revision!.levelStatus) {
        case TopicStatus.completed:
          final isEarly = !isDue;
          final color = isEarly ? AppTheme.pastelBlueText(context) : AppTheme.successColor;
          statusLabel = 'Completed';
          badgeBg = isEarly ? AppTheme.pastelBlue(context) : AppTheme.pastelGreen(context);
          badgeBorder = isEarly ? AppTheme.pastelBlueBorder(context) : AppTheme.pastelGreenBorder(context);
          badgeText = isEarly ? AppTheme.pastelBlueText(context) : AppTheme.pastelGreenText(context);
          indicator = Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.35),
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
          break;
        case TopicStatus.inProgress:
          statusLabel = 'In Progress';
          badgeBg = AppTheme.pastelPurple(context);
          badgeBorder = AppTheme.pastelPurpleBorder(context);
          badgeText = AppTheme.pastelPurpleText(context);
          indicator = const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: 0.72,
              strokeWidth: 2.5,
              color: AppTheme.primaryColor,
              backgroundColor: Color(0xFFE8E5FF),
            ),
          );
          break;
        case TopicStatus.notStarted:
          statusLabel = isDue ? 'Due' : 'Not Started';
          badgeBg = isDue
              ? AppTheme.errorColor.withValues(alpha: 0.12)
              : AppTheme.surfaceVariant(context);
          badgeBorder = isDue
              ? AppTheme.errorColor.withValues(alpha: 0.35)
              : AppTheme.borderColor(context);
          badgeText = isDue ? AppTheme.errorColor : AppTheme.textSecondaryColor(context);
          indicator = Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDue ? AppTheme.errorColor : const Color(0xFFCBD5E1),
                width: 2.0,
              ),
            ),
          );
          break;
      }
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

    final dateLabel = _dayMonthYearFormat.format(targetDate);

    final VoidCallback? rowTap;
    if (isCurrent && onToggleCurrentLevelStatus != null) {
      rowTap = onToggleCurrentLevelStatus;
    } else if (revision == null && level == 1 && onEnrollRevision != null) {
      rowTap = onEnrollRevision;
    } else {
      rowTap = null;
    }

    final rowContent = Stack(
      children: [
        if (!isLast)
          Positioned(
            top: 22,
            bottom: 0,
            left: 12,
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: lineColor,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Align(
                alignment: Alignment.topCenter,
                child: indicator,
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
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCurrent
                            ? (isDue ? AppTheme.errorColor : AppTheme.primaryColor)
                            : AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (rowTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: rowTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: (isCurrent && revision != null && !isDue && revision!.levelStatus == TopicStatus.completed)
              ? AppTheme.pastelBlueText(context).withValues(alpha: 0.12)
              : AppTheme.primaryColor.withValues(alpha: 0.08),
          highlightColor: AppTheme.primaryColor.withValues(alpha: 0.04),
          child: rowContent,
        ),
      );
    }

    return rowContent;
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

