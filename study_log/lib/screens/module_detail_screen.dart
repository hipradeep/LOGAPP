import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/topic_progress_header.dart';
import '../widgets/topic_status_indicator.dart';
import '../widgets/topic_status_label.dart';
import '../models/topic.dart';
import '../services/local_topic_storage.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_modules_controller.dart';
import 'add_topic_screen.dart';

class ModuleDetailScreen extends StatefulWidget {
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;
  final int moduleOrderIndex;

  const ModuleDetailScreen({
    super.key,
    required this.moduleTitle,
    required this.courseTitle,
    this.courseId = '',
    this.moduleId = '',
    this.moduleOrderIndex = 0,
  });

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  List<Topic> _topics = [];

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    final cached = await LocalTopicStorage.loadTopicsForModule(
      moduleId: widget.moduleId,
      fallbackTitle: widget.moduleTitle,
    );
    if (!mounted) return;
    setState(() => _topics = cached);
  }

  void _handleBack() {
    Navigator.of(context).pop();
  }

  Future<void> _openAddTopicScreen() async {
    final result = await Navigator.push<Topic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTopicScreen(
          moduleTitle: widget.moduleTitle,
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _topics.add(result);
      });
      await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
      if (getIt.isRegistered<OngoingModulesController>()) {
        getIt<OngoingModulesController>().refresh();
      }
    }
  }

  void _toggleTopicStatus(int index) {
    setState(() {
      final current = _topics[index];
      final TopicStatus next;
      switch (current.status) {
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
      _topics[index] = next == TopicStatus.completed
          ? current.copyWith(status: next, completedAt: DateTime.now())
          : current.copyWith(status: next, clearCompletedAt: true);
    });
    LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
    if (getIt.isRegistered<OngoingModulesController>()) {
      getIt<OngoingModulesController>().refresh();
    }
  }

  Future<void> _handleDeleteTopic(int index) async {
    final sub = _topics[index];
    final confirmed = await StudyConfirmationDialog.showDeleteTopic(
      context,
      topicTitle: sub.title,
    );

    if (confirmed && mounted) {
      setState(() {
        _topics.removeAt(index);
      });
      await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
      if (getIt.isRegistered<OngoingModulesController>()) {
        getIt<OngoingModulesController>().refresh();
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
    final completedCount = _topics.where((s) => s.status == TopicStatus.completed).length;
    final totalCount = _topics.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            _ModuleDetailTopBar(
              onBack: _handleBack,
              onAddTopic: _openAddTopicScreen,
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
                      color: AppTheme.pastelPurple(context),
                      borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                      border: Border.all(color: AppTheme.pastelPurpleBorder(context)),
                    ),
                    child: Text(
                      '${widget.moduleOrderIndex + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.pastelPurpleText(context),
                      ),
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: Text(
                      widget.moduleTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryColor(context),
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
              child: TopicProgressHeader(
                completedCount: completedCount,
                totalCount: totalCount,
                progress: progress,
              ),
            ),
            const VGapSm(),
            Expanded(
              child: _TopicsListView(
                topics: _topics,
                onToggle: _toggleTopicStatus,
                onDelete: _handleDeleteTopic,
                onAddTopic: _openAddTopicScreen,
                bottomPadding: bottomSafe + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAddTopic;

  const _ModuleDetailTopBar({
    required this.onBack,
    required this.onAddTopic,
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
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 28,
                ),
                onPressed: onBack,
                tooltip: 'Back',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const HGapSm(),
              Text(
                'MODULE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor(context),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          AddPillButton(
            label: 'Add Topic',
            onPressed: onAddTopic,
          ),
        ],
      ),
    );
  }
}

class _TopicsListView extends StatelessWidget {
  final List<Topic> topics;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onDelete;
  final VoidCallback onAddTopic;
  final double bottomPadding;

  const _TopicsListView({
    required this.topics,
    required this.onToggle,
    required this.onDelete,
    required this.onAddTopic,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_list_bulleted_rounded,
                size: 48,
                color: AppTheme.textSecondaryColor(context),
              ),
              const VGapMd(),
              Text(
                'No topics yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              const VGapXs(),
              Text(
                'Tap "+ Add Topic" to add your first topic.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const VGapMd(),
              ElevatedButton.icon(
                onPressed: onAddTopic,
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
      itemCount: topics.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 64,
        endIndent: 20,
        color: Color(0xFFF3F4F6),
      ),
      itemBuilder: (context, index) {
        final item = topics[index];
        return _TopicListItem(
          item: item,
          onTap: () => onToggle(index),
          onLongPress: () => onDelete(index),
        );
      },
    );
  }
}

class _TopicListItem extends StatelessWidget {
  final Topic item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TopicListItem({
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
                TopicStatusIndicator(status: item.status),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      TopicStatusLabel(status: item.status),
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
