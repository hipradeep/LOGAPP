import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_fab.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/entity_detail_header.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/topic_list_item.dart';
import '../models/topic.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../widgets/topic_options_sheet.dart';
import 'add_topic_screen.dart';
import 'session_setup_screen.dart';
import 'topic_detail_screen.dart';

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
  StreamSubscription<List<Topic>>? _topicsSubscription;
  DateTime? _lastUpdatedAt;
  int _totalMinutesExpended = 0;
  final _togglingTopicIndices = <int>{};
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
    _loadModuleStats();
  }

  @override
  void dispose() {
    _topicsSubscription?.cancel();
    super.dispose();
  }

  void _handleBack() {
    if (_isReordering) {
      setState(() => _isReordering = false);
      return;
    }
    Navigator.of(context).pop();
  }

  void _toggleReordering() {
    setState(() => _isReordering = !_isReordering);
  }

  void _handleReorderTopics(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _topics.length) return;
    if (newIndex < 0 || newIndex > _topics.length) return;
    if (oldIndex == newIndex) return;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _topics.removeAt(oldIndex);
      _topics.insert(newIndex, item);
    });

    final updatedList = <Topic>[];
    for (int i = 0; i < _topics.length; i++) {
      final updated = _topics[i].copyWith(orderIndex: i);
      _topics[i] = updated;
      updatedList.add(updated);
    }

    try {
      await DatabaseService.instance.updateTopicOrders(updatedList);
    } catch (e) {
      debugPrint('Database updateTopicOrders error: $e');
    }
  }

  List<Topic> _deduplicateTopics(List<Topic> topics) {
    final seenIds = <String>{};
    final seenTitles = <String>{};
    final result = <Topic>[];

    for (final topic in topics) {
      final id = topic.id.trim();
      final title = topic.title.trim().toLowerCase();

      final idSeen = id.isNotEmpty && seenIds.contains(id);
      final titleSeen = title.isNotEmpty && seenTitles.contains(title);

      if (idSeen || titleSeen) {
        continue;
      }

      if (id.isNotEmpty) seenIds.add(id);
      if (title.isNotEmpty) seenTitles.add(title);
      result.add(topic);
    }
    return result;
  }

  List<Topic> _mergeTopics(List<Topic> current, List<Topic> incoming) {
    final map = <String, Topic>{};
    final titleToKey = <String, String>{};

    for (final t in current) {
      final key = t.id.isNotEmpty ? t.id : t.title.trim().toLowerCase();
      map[key] = t;
      if (t.title.trim().isNotEmpty) {
        titleToKey[t.title.trim().toLowerCase()] = key;
      }
    }

    for (final t in incoming) {
      final titleKey = t.title.trim().toLowerCase();
      if (titleKey.isNotEmpty && titleToKey.containsKey(titleKey)) {
        final existingKey = titleToKey[titleKey]!;
        map[existingKey] = t;
      } else {
        final key = t.id.isNotEmpty ? t.id : titleKey;
        map[key] = t;
        if (titleKey.isNotEmpty) {
          titleToKey[titleKey] = key;
        }
      }
    }

    final list = map.values.toList();
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return list;
  }

  Future<void> _loadTopics() async {
    // 1. Immediately render topics directly from SQLite DatabaseService
    final cached = widget.moduleId.isNotEmpty
        ? await DatabaseService.instance.getTopics(moduleId: widget.moduleId)
        : (widget.moduleTitle.isNotEmpty
            ? (await DatabaseService.instance.getAllTopics())
                .where((t) => t.moduleId == widget.moduleTitle)
                .toList()
            : <Topic>[]);
    if (!mounted) return;
    if (cached.isNotEmpty) {
      final clean = _deduplicateTopics(cached);
      setState(() => _topics = clean);
      unawaited(_loadModuleStats());
      if (clean.every((t) => t.isCompleted)) {
        unawaited(_syncModuleCompletion());
      }
    }

    // 2. Real-time stream subscription from DatabaseService
    if (widget.moduleId.isNotEmpty && getIt.isRegistered<DatabaseService>()) {
      final dbService = getIt<DatabaseService>();
      _topicsSubscription?.cancel();
      _topicsSubscription = dbService
          .streamTopics(moduleId: widget.moduleId)
          .listen((remoteTopics) {
        if (!mounted) return;
        if (_isReordering) return;
        if (remoteTopics.isNotEmpty) {
          final merged = _mergeTopics(_topics, remoteTopics);
          setState(() => _topics = merged);
          unawaited(_loadModuleStats());
          if (merged.every((t) => t.isCompleted)) {
            unawaited(_syncModuleCompletion());
          }
        }
      }, onError: (e) {
        debugPrint('Error streaming topics from database: $e');
      });
    }
  }

  Future<void> _loadModuleStats() async {
    try {
      DateTime? latestDate;
      int totalMinutes = 0;

      final topicIds = _topics.map((t) => t.id).toSet();
      final topicTitles = _topics.map((t) => t.title.toLowerCase().trim()).toSet();

      final logs = await DatabaseService.instance.getStudyLogs();
      for (final log in logs) {
        final matches = (widget.moduleId.isNotEmpty && log.moduleId == widget.moduleId) ||
            (widget.moduleTitle.isNotEmpty &&
                log.moduleTitle.toLowerCase() == widget.moduleTitle.toLowerCase());
        if (matches) {
          final isTopicSession = log.type == StudyLogType.studySession &&
              log.revisionLevel == null &&
              (_topics.isEmpty ||
                  (log.topicId != null && topicIds.contains(log.topicId)) ||
                  (log.topicTitle != null && topicTitles.contains(log.topicTitle!.toLowerCase().trim())) ||
                  log.topicId == null);

          if (isTopicSession && log.durationMinutes != null && log.durationMinutes! > 0) {
            totalMinutes += log.durationMinutes!;
          }

          final logDate = log.timestamp;
          if (latestDate == null || logDate.isAfter(latestDate)) {
            latestDate = logDate;
          }
        }
      }

      for (final t in _topics) {
        if (t.completedAt != null) {
          if (latestDate == null || t.completedAt!.isAfter(latestDate)) {
            latestDate = t.completedAt;
          }
        }
      }

      if (latestDate == null) {
        final allModules = await DatabaseService.instance.getAllModules();
        final match = allModules.firstWhere(
          (m) =>
              (widget.moduleId.isNotEmpty && m.id == widget.moduleId) ||
              (widget.moduleTitle.isNotEmpty &&
                  m.title.toLowerCase() == widget.moduleTitle.toLowerCase()),
          orElse: () => Module(
            id: '',
            courseId: '',
            title: '',
            description: '',
            orderIndex: 0,
            status: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (match.id.isNotEmpty) {
          latestDate = match.updatedAt;
        }
      }

      if (mounted) {
        setState(() {
          _lastUpdatedAt = latestDate ?? DateTime.now();
          _totalMinutesExpended = totalMinutes;
        });
      }
    } catch (e) {
      debugPrint('Error loading module stats: $e');
    }
  }

  Future<void> _recordModuleCompletionLog({DateTime? timestamp}) async {
    final now = timestamp ?? DateTime.now();

    // 1. Resolve moduleId
    String resolvedModuleId = widget.moduleId;
    if (resolvedModuleId.isEmpty && _topics.isNotEmpty) {
      resolvedModuleId = _topics
          .firstWhere((t) => t.moduleId.isNotEmpty, orElse: () => _topics.first)
          .moduleId;
    }
    if (resolvedModuleId.isEmpty) {
      resolvedModuleId = widget.moduleTitle;
    }

    // 2. Resolve moduleTitle
    String resolvedModuleTitle = widget.moduleTitle;
    if (resolvedModuleTitle.isEmpty && getIt.isRegistered<OngoingModulesController>()) {
      resolvedModuleTitle =
          getIt<OngoingModulesController>().moduleTitleFor(resolvedModuleId);
    }
    if (resolvedModuleTitle.isEmpty && _topics.isNotEmpty) {
      resolvedModuleTitle = _topics.first.title;
    }

    // 3. Resolve courseId
    String resolvedCourseId = widget.courseId;
    if (resolvedCourseId.isEmpty && _topics.isNotEmpty) {
      resolvedCourseId = _topics
          .firstWhere((t) => t.courseId.isNotEmpty, orElse: () => _topics.first)
          .courseId;
    }

    // 4. Resolve courseTitle
    String resolvedCourseTitle = widget.courseTitle;
    if (resolvedCourseTitle.isEmpty &&
        resolvedCourseId.isNotEmpty &&
        getIt.isRegistered<CoursesController>()) {
      resolvedCourseTitle =
          getIt<CoursesController>().getCourseById(resolvedCourseId)?.title ?? '';
    }

    // Avoid duplicate module completion logs on the same calendar day
    final existingLogs = await DatabaseService.instance.getStudyLogs();
    final alreadyLoggedToday = existingLogs.any((l) {
      if (!l.isModuleCompleted) return false;
      final sameModule = (resolvedModuleId.isNotEmpty && l.moduleId == resolvedModuleId) ||
          (resolvedModuleTitle.isNotEmpty &&
              l.moduleTitle.toLowerCase() == resolvedModuleTitle.toLowerCase());
      final sameDay = l.timestamp.year == now.year &&
          l.timestamp.month == now.month &&
          l.timestamp.day == now.day;
      return sameModule && sameDay;
    });

    if (!alreadyLoggedToday) {
      final modLog = StudyLog(
        id: 'mod_complete_${resolvedModuleId.isNotEmpty ? resolvedModuleId : now.millisecondsSinceEpoch}_${now.millisecondsSinceEpoch}',
        type: StudyLogType.moduleCompleted,
        courseId: resolvedCourseId,
        courseTitle: resolvedCourseTitle,
        moduleId: resolvedModuleId,
        moduleTitle: resolvedModuleTitle,
        timestamp: now,
        createdAt: now,
      );
      await DatabaseService.instance.addStudyLog(modLog);
    }
  }

  Future<void> _removeModuleCompletionLog() async {
    String resolvedModuleId = widget.moduleId;
    if (resolvedModuleId.isEmpty && _topics.isNotEmpty) {
      resolvedModuleId = _topics
          .firstWhere((t) => t.moduleId.isNotEmpty, orElse: () => _topics.first)
          .moduleId;
    }
    if (resolvedModuleId.isNotEmpty) {
      await DatabaseService.instance.deleteStudyLogForModule(
        moduleId: resolvedModuleId,
        type: StudyLogType.moduleCompleted.value,
      );
    }
    if (widget.moduleId.isNotEmpty && widget.moduleId != resolvedModuleId) {
      await DatabaseService.instance.deleteStudyLogForModule(
        moduleId: widget.moduleId,
        type: StudyLogType.moduleCompleted.value,
      );
    }
    if (widget.moduleTitle.isNotEmpty) {
      await DatabaseService.instance.deleteStudyLogForModule(
        moduleId: widget.moduleTitle,
        type: StudyLogType.moduleCompleted.value,
      );
    }
  }

  Future<void> _syncModuleCompletion() async {
    String courseId = widget.courseId;
    String moduleId = widget.moduleId;

    // Resolve courseId and moduleId from topics or disk cache if either is empty
    if (courseId.isEmpty && _topics.isNotEmpty) {
      courseId = _topics
          .firstWhere((t) => t.courseId.isNotEmpty, orElse: () => _topics.first)
          .courseId;
    }
    if (moduleId.isEmpty && _topics.isNotEmpty) {
      moduleId = _topics
          .firstWhere((t) => t.moduleId.isNotEmpty, orElse: () => _topics.first)
          .moduleId;
    }

    if (courseId.isEmpty || moduleId.isEmpty) {
      final all = await DatabaseService.instance.getAllModules();
      final match = all.firstWhere(
        (m) => (moduleId.isNotEmpty && m.id == moduleId) ||
               (widget.moduleTitle.isNotEmpty && m.title.toLowerCase() == widget.moduleTitle.toLowerCase()),
        orElse: () => Module(id: '', courseId: '', title: '', description: '', orderIndex: 0, status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      if (match.id.isNotEmpty) {
        if (courseId.isEmpty) courseId = match.courseId;
        if (moduleId.isEmpty) moduleId = match.id;
      }
    }

    final allDone = _topics.isNotEmpty && _topics.every((t) => t.isCompleted);
    final newStatus = allDone ? 'completed' : 'active';
    final now = DateTime.now();

    if (allDone) {
      await _recordModuleCompletionLog(timestamp: now);
    } else {
      await _removeModuleCompletionLog();
    }

    if (courseId.isEmpty) return;
    try {
      final modules = await DatabaseService.instance.getModules(courseId: courseId);
      final idx = modules.indexWhere(
        (m) => (moduleId.isNotEmpty && m.id == moduleId) ||
               (widget.moduleTitle.isNotEmpty && m.title.toLowerCase() == widget.moduleTitle.toLowerCase()),
      );

      final Module targetModule;
      if (idx != -1) {
        final prevStatus = modules[idx].status.toLowerCase();
        if (prevStatus != newStatus) {
          targetModule = modules[idx].copyWith(
            status: newStatus,
            updatedAt: now,
          );
          modules[idx] = targetModule;
          await DatabaseService.instance.saveModules(courseId, modules);
        }
      } else {
        // Module not cached yet for this course — create and store it
        targetModule = Module(
          id: moduleId.isNotEmpty ? moduleId : 'module_${now.millisecondsSinceEpoch}',
          courseId: courseId,
          title: widget.moduleTitle,
          description: '',
          status: newStatus,
          orderIndex: widget.moduleOrderIndex,
          createdAt: now,
          updatedAt: now,
        );
        modules.add(targetModule);
        await DatabaseService.instance.saveModules(courseId, modules);
      }

      // If all modules in this course are now completed, also update course to completed
      if (modules.isNotEmpty && modules.every((m) => m.status.toLowerCase() == 'completed')) {
        if (getIt.isRegistered<CoursesController>()) {
          final coursesCtrl = getIt<CoursesController>();
          final course = coursesCtrl.courses.firstWhere(
            (c) => c.id == courseId,
            orElse: () => Course(id: '', title: '', description: '', status: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
          );
          if (course.id.isNotEmpty && course.status.toLowerCase() != 'completed') {
            await coursesCtrl.updateCourse(course.copyWith(status: 'completed'));
          }
        }
      }

      // Reconcile revision ladder so any pending state is updated
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
    } catch (e) {
      debugPrint('Error syncing module completion: $e');
    }
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
      final merged = _mergeTopics(_topics, [result]);
      setState(() {
        _topics = merged;
      });
      await _syncModuleCompletion();
      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
    }
  }

  Future<void> _toggleTopicStatus(int index) async {
    if (index < 0 || index >= _topics.length) return;
    if (_togglingTopicIndices.contains(index)) return;
    _togglingTopicIndices.add(index);

    try {
      final current = _topics[index];
      final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
          ? getIt<TopicRevisionController>()
          : null;
      final topicRev = topicRevCtrl?.topicRevisionFor(current.id);

      // If already enrolled in spaced repetition, toggle its revision level status
      if (topicRev != null) {
        await topicRevCtrl!.toggleLevelStatus(topicRev.id);
        return;
      }

      // First-time study: manage topic.status (notStarted -> inProgress -> completed -> notStarted)
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
      final topicId = current.id.isNotEmpty
          ? current.id
          : 'topic_${widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle.toLowerCase().replaceAll(' ', '_')}_$index';
      final courseId =
          current.courseId.isNotEmpty ? current.courseId : widget.courseId;
      final moduleId =
          current.moduleId.isNotEmpty ? current.moduleId : widget.moduleId;

      final updated = next == TopicStatus.completed
          ? current.copyWith(
              id: topicId,
              courseId: courseId,
              moduleId: moduleId,
              status: next,
              completedAt: DateTime.now(),
            )
          : current.copyWith(
              id: topicId,
              courseId: courseId,
              moduleId: moduleId,
              status: next,
              clearCompletedAt: true,
            );

      setState(() {
        _topics[index] = updated;
      });

      await DatabaseService.instance.updateTopic(updated);
      await _syncModuleCompletion();

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
        await DatabaseService.instance.addStudyLog(studyLog);
        if (getIt.isRegistered<ProgressController>()) {
          unawaited(getIt<ProgressController>().refresh());
        }

        // Show dialog asking to move into revision schedule
        if (mounted && topicRevCtrl != null && !topicRevCtrl.isTopicEnrolled(updated.id)) {
          final shouldMove = await StudyConfirmationDialog.showMoveToRevision(
            context,
            topicTitle: updated.title,
            courseTitle: widget.courseTitle,
            moduleTitle: widget.moduleTitle,
          );
          if (shouldMove && mounted) {
            await topicRevCtrl.enrollTopicInRevision(
              courseId: courseId,
              moduleId: moduleId,
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
      } else {
        if (getIt.isRegistered<ProgressController>()) {
          unawaited(getIt<ProgressController>().refresh());
        }
      }

      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
      unawaited(_loadModuleStats());
    } finally {
      _togglingTopicIndices.remove(index);
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
      if (sub.id.isNotEmpty) {
        await DatabaseService.instance.deleteTopic(sub.id);
      }
      await _syncModuleCompletion();
      unawaited(_loadModuleStats());

      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
      }
      if (getIt.isRegistered<TopicRevisionController>() && sub.id.isNotEmpty) {
        unawaited(getIt<TopicRevisionController>().deleteByTopicId(sub.id));
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

  Future<void> _handleEditTopic(int index) async {
    final topic = _topics[index];
    final result = await Navigator.push<Topic>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTopicScreen(
          moduleTitle: widget.moduleTitle,
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicToEdit: topic,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _topics[index] = result;
      });
      await _syncModuleCompletion();
      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
    }
  }

  Future<void> _handleOpenTopicDetail(int index) async {
    final topic = _topics[index];
    final updatedTopic = await Navigator.push<Topic?>(
      context,
      MaterialPageRoute(
        builder: (_) => TopicDetailScreen(
          topic: topic,
          moduleTitle: widget.moduleTitle,
          courseTitle: widget.courseTitle,
          courseId: widget.courseId,
          moduleId: widget.moduleId,
        ),
      ),
    );

    if (updatedTopic != null && mounted) {
      setState(() {
        _topics[index] = updatedTopic;
      });
    }

    // Refresh topics from storage in case status, notes, or full topic was modified/deleted
    await _loadTopics();
    await _syncModuleCompletion();
    unawaited(_loadModuleStats());
    if (getIt.isRegistered<TopicRevisionController>()) {
      unawaited(getIt<TopicRevisionController>().refresh());
    }
  }

  Future<void> _handleDuplicateTopic(int index) async {
    final original = _topics[index];
    final newId = 'topic_${DateTime.now().millisecondsSinceEpoch}';
    final duplicated = original.copyWith(
      id: newId,
      title: '${original.title} (Copy)',
      orderIndex: original.orderIndex + 1,
    );

    setState(() {
      _topics.insert(index + 1, duplicated);
    });

    await DatabaseService.instance.addTopic(duplicated);
    await _syncModuleCompletion();

    if (getIt.isRegistered<OngoingModulesController>()) {
      await getIt<OngoingModulesController>().refresh();
    }
    if (getIt.isRegistered<RevisionController>()) {
      await getIt<RevisionController>().reconcile();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Topic "${original.title}" duplicated'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
    }
  }

  void _showModuleCompletedDialog({bool isInRevision = false}) {
    if (!mounted) return;
    final revisionCtrl = getIt.isRegistered<RevisionController>()
        ? getIt<RevisionController>()
        : null;

    final inRevision = isInRevision || (revisionCtrl != null &&
        revisionCtrl.revisionForModule(widget.moduleId, moduleTitle: widget.moduleTitle) != null);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.surface(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.textMutedColor(ctx),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen(ctx),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.pastelGreenBorder(ctx), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.pastelGreenText(ctx),
                    size: 30,
                  ),
                ),
                const VGapMd(),
                Text(
                  'Successfully completed this module!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(ctx),
                  ),
                  textAlign: TextAlign.center,
                ),
                const VGapXs(),
                Text(
                  widget.moduleTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapSm(),
                Text(
                  inRevision
                      ? 'All topics completed. Move this module forward in your revision schedule.'
                      : 'All topics have been completed! Add this module to revision to retain what you learned.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryColor(ctx),
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const VGapLg(),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      if (inRevision) {
                        final rev = revisionCtrl?.revisionForModule(widget.moduleId, moduleTitle: widget.moduleTitle);
                        if (rev != null && revisionCtrl != null) {
                          final now = DateTime.now();
                          final isDue = rev.isDueAt(now);
                          if (isDue) {
                            await revisionCtrl.completeCurrentLevel(rev.id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Moved "${widget.moduleTitle}" to next revision level (R${rev.currentLevel + 1})!'),
                                  backgroundColor: AppTheme.successColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${widget.moduleTitle}" revised! Level remains R${rev.currentLevel} until scheduled due date.'),
                                  backgroundColor: AppTheme.primaryColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          }
                        }
                      } else {
                        if (revisionCtrl != null) {
                          final rev = await revisionCtrl.createOrEnsureRevision(
                            courseId: widget.courseId,
                            moduleId: widget.moduleId,
                            courseTitle: widget.courseTitle,
                            moduleTitle: widget.moduleTitle,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${widget.moduleTitle}" added to revision schedule (Level R${rev.currentLevel})!'),
                                backgroundColor: AppTheme.successColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      }
                      await _loadTopics();
                      await _loadModuleStats();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      inRevision ? 'Next Revision Level' : 'Add to Revise',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
    final completedCount = _topics.where((s) => s.status == TopicStatus.completed).length;
    final totalCount = _topics.length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return PopScope(
      canPop: !_isReordering,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isReordering) {
          setState(() => _isReordering = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        floatingActionButton: (_topics.isNotEmpty && !_isReordering)
            ? AppFab(
                onPressed: () async {
                  final result = await Navigator.push<dynamic>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionSetupScreen(
                        courseTitle: widget.courseTitle,
                        courseId: widget.courseId,
                        moduleTitle: widget.moduleTitle,
                        moduleId: widget.moduleId,
                        topics: _topics,
                        isRevision: progress >= 1.0,
                      ),
                    ),
                  );
                  await _loadTopics();
                  await _loadModuleStats();
                  final allDone = (result == true) ||
                      (result is Map && result['allCompleted'] == true) ||
                      (_topics.isNotEmpty && _topics.every((t) => t.isCompleted));
                  if (allDone) {
                    await _recordModuleCompletionLog();
                    await _syncModuleCompletion();
                    if (getIt.isRegistered<OngoingModulesController>()) {
                      await getIt<OngoingModulesController>().refresh();
                    }
                    if (getIt.isRegistered<ProgressController>()) {
                      unawaited(getIt<ProgressController>().refresh());
                    }
                    if (mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showModuleCompletedDialog(isInRevision: result is Map && result['isRevision'] == true);
                        }
                      });
                    }
                  }
                },
                
                tooltip: progress >= 1.0 ? 'Start Revision Session' : 'Start Study Session',
                icon: Icons.play_arrow_rounded,
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomAppBar(
                title: _isReordering ? 'REORDER TOPICS' : null,
                onBack: _handleBack,
                actions: [
                  if (_isReordering)
                    AddPillButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      onPressed: _toggleReordering,
                    )
                  else
                    AddPillButton(
                      label: 'Add Topic',
                      onPressed: _openAddTopicScreen,
                    ),
                ],
              ),
              _CompactModuleHeader(
                moduleTitle: widget.moduleTitle,
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
                completedCount: completedCount,
                totalCount: totalCount,
                progress: progress,
                lastUpdatedAt: _lastUpdatedAt ?? DateTime.now(),
                totalMinutesExpended: _totalMinutesExpended,
              ),
              const VGapXs(),
              Divider(
                height: 12,
                thickness: 1.0,
                color: AppTheme.borderColor(context),
              ),
              const VGapXs(),
              Expanded(
                child: _TopicsListView(
                  topics: _topics,
                  moduleTitle: widget.moduleTitle,
                  courseTitle: widget.courseTitle,
                  courseId: widget.courseId,
                  moduleId: widget.moduleId,
                  isReordering: _isReordering,
                  onReorderTopics: _handleReorderTopics,
                  onOrderTopic: _toggleReordering,
                  onToggle: _toggleTopicStatus,
                  onOpenDetail: _handleOpenTopicDetail,
                  onEdit: _handleEditTopic,
                  onDuplicate: _handleDuplicateTopic,
                  onDelete: _handleDeleteTopic,
                  onRefresh: () {
                    unawaited(_loadTopics());
                    unawaited(_loadModuleStats());
                  },
                  bottomPadding: bottomSafe + 84,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CompactModuleHeader extends StatelessWidget {
  final String moduleTitle;
  final String courseId;
  final String courseTitle;
  final int completedCount;
  final int totalCount;
  final double progress;
  final DateTime lastUpdatedAt;
  final int totalMinutesExpended;

  const _CompactModuleHeader({
    required this.moduleTitle,
    required this.courseId,
    required this.courseTitle,
    required this.completedCount,
    required this.totalCount,
    required this.progress,
    required this.lastUpdatedAt,
    required this.totalMinutesExpended,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = totalCount > 0 && completedCount >= totalCount;
    final dateStr = EntityDetailHeader.formatDate(lastUpdatedAt);
    final hoursStr = EntityDetailHeader.formatDuration(totalMinutesExpended);
    final countStr = totalCount > 0 ? '$completedCount/$totalCount topics' : null;

    final statusBg = isComplete
        ? AppTheme.successColor.withValues(alpha: 0.12)
        : AppTheme.pastelPurple(context);
    final statusBorder = isComplete
        ? AppTheme.successColor.withValues(alpha: 0.25)
        : AppTheme.pastelPurpleBorder(context);
    final statusColor = isComplete
        ? AppTheme.successColor
        : AppTheme.pastelPurpleText(context);
    final statusLabel = isComplete ? 'Completed' : 'In Progress';

    String resolvedCourse = courseTitle;
    if (resolvedCourse.isEmpty && courseId.isNotEmpty && getIt.isRegistered<CoursesController>()) {
      try {
        final c = getIt<CoursesController>().courses.firstWhere((c) => c.id == courseId);
        resolvedCourse = c.title;
      } catch (_) {}
    }

    return EntityDetailHeader(
      title: moduleTitle,
      courseId: courseId,
      courseTitle: resolvedCourse,
      horizontalPadding: 16.0,
      countText: countStr,
      dateText: dateStr,
      durationText: hoursStr,
      statusWidget: DetailStatusBadge(
        label: statusLabel,
        backgroundColor: statusBg,
        borderColor: statusBorder,
        textColor: statusColor,
      ),
    );
  }
}

class _TopicsListView extends StatelessWidget {
  final List<Topic> topics;
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;
  final bool isReordering;
  final void Function(int, int)? onReorderTopics;
  final VoidCallback? onOrderTopic;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onOpenDetail;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDelete;
  final VoidCallback? onRefresh;
  final double bottomPadding;

  const _TopicsListView({
    required this.topics,
    required this.moduleTitle,
    required this.courseTitle,
    required this.courseId,
    required this.moduleId,
    this.isReordering = false,
    this.onReorderTopics,
    this.onOrderTopic,
    required this.onToggle,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.onRefresh,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const AppEmptyState(
        icon: Icons.format_list_bulleted_rounded,
        title: 'No topics yet',
        description: 'Add a topic from the top bar to start learning.',
        showCard: false,
      );
    }
    final topicRevCtrl = getIt.isRegistered<TopicRevisionController>()
        ? getIt<TopicRevisionController>()
        : null;

    Widget buildList(BuildContext context) {
      if (isReordering) {
        return ReorderableListView.builder(
          buildDefaultDragHandles: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
          itemCount: topics.length,
          onReorder: onReorderTopics ?? (_, _) {},
          itemBuilder: (context, index) {
            final item = topics[index];
            final topicRev = topicRevCtrl?.topicRevisionFor(item.id);

            return Column(
              key: ValueKey(item.id.isNotEmpty ? item.id : 'topic_$index'),
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: TopicListItem(
                    topic: item,
                    topicRevision: topicRev,
                    subtitle: 'Drag to reorder',
                    trailing: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: Icon(
                          Icons.reorder_rounded,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                    showTrailing: false,
                    onCheckboxTap: null,
                    onTap: null,
                    onLongPress: null,
                    onOptionsTap: null,
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.6,
                  indent: 52,
                  endIndent: 16,
                  color: AppTheme.borderColor(context),
                ),
              ],
            );
          },
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
        itemCount: topics.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 0.6,
          indent: 52,
          endIndent: 16,
          color: AppTheme.borderColor(context),
        ),
        itemBuilder: (context, index) {
          final item = topics[index];
          final topicRev = topicRevCtrl?.topicRevisionFor(item.id);

          void openOptions() {
            TopicOptionsSheet.show(
              context,
              topic: item,
              moduleTitle: moduleTitle,
              courseTitle: courseTitle,
              courseId: courseId,
              moduleId: moduleId,
              showRemoveFromRevision: false,
              onRevisionChanged: onRefresh,
              onOrderTopic: onOrderTopic,
              onEdit: () => onEdit(index),
              onDuplicate: () => onDuplicate(index),
              onDelete: () => onDelete(index),
            );
          }

          return TopicListItem(
            topic: item,
            topicRevision: topicRev,
            onCheckboxTap: () => onToggle(index),
            onTap: () => onOpenDetail(index),
            onLongPress: openOptions,
            onOptionsTap: openOptions,
          );
        },
      );
    }

    if (topicRevCtrl != null) {
      return ListenableBuilder(
        listenable: topicRevCtrl,
        builder: (context, _) => buildList(context),
      );
    }

    return buildList(context);
  }
}
