import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/add_pill_button.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/module_context_pill.dart';
import '../widgets/study_confirmation_dialog.dart';
import '../widgets/topic_list_item.dart';
import '../models/topic.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/study_log.dart';
import '../services/local_topic_storage.dart';
import '../services/local_module_storage.dart';
import '../services/local_study_log_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/courses_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../widgets/topic_options_sheet.dart';
import 'add_topic_screen.dart';
import 'session_setup_screen.dart';

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
    // 1. Immediately render local cached topics for zero-latency load
    final cached = await LocalTopicStorage.loadTopicsForModule(
      moduleId: widget.moduleId,
      fallbackTitle: widget.moduleTitle,
    );
    if (!mounted) return;
    if (cached.isNotEmpty) {
      final clean = _deduplicateTopics(cached);
      setState(() => _topics = clean);
      unawaited(_loadModuleStats());
      if (clean.every((t) => t.isCompleted)) {
        unawaited(_syncModuleCompletion());
      }
    }

    // 2. Real-time stream subscription from Firestore
    if (widget.moduleId.isNotEmpty && getIt.isRegistered<FirestoreService>()) {
      final firestore = getIt<FirestoreService>();
      if (firestore.isAvailable) {
        _topicsSubscription?.cancel();
        _topicsSubscription = firestore
            .streamTopics(moduleId: widget.moduleId)
            .listen((remoteTopics) async {
          if (!mounted) return;
          if (remoteTopics.isNotEmpty) {
            final merged = _mergeTopics(_topics, remoteTopics);
            setState(() => _topics = merged);
            unawaited(_loadModuleStats());
            final key = widget.moduleId.isNotEmpty
                ? widget.moduleId
                : widget.moduleTitle;
            await LocalTopicStorage.saveTopics(key, merged);
            if (merged.every((t) => t.isCompleted)) {
              await _syncModuleCompletion();
            }
            if (getIt.isRegistered<OngoingModulesController>()) {
              getIt<OngoingModulesController>().refresh();
            }
          }
        }, onError: (e) {
          debugPrint('Error streaming topics from Firestore: $e');
        });
      }
    }
  }

  Future<void> _loadModuleStats() async {
    try {
      DateTime? latestDate;
      int totalMinutes = 0;

      final topicIds = _topics.map((t) => t.id).toSet();
      final topicTitles = _topics.map((t) => t.title.toLowerCase().trim()).toSet();

      final logs = await LocalStudyLogStorage.loadAll();
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
        final allModules = await LocalModuleStorage.loadAllModules();
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

  void _handleBack() {
    Navigator.of(context).pop();
  }

  Future<void> _syncModuleCompletion() async {
    String courseId = widget.courseId;
    String moduleId = widget.moduleId;

    // Resolve courseId and moduleId from disk cache if either is empty
    if (courseId.isEmpty || moduleId.isEmpty) {
      final all = await LocalModuleStorage.loadAllModules();
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

    if (courseId.isEmpty) return;
    try {
      final modules = await LocalModuleStorage.loadModules(courseId);
      final idx = modules.indexWhere(
        (m) => (moduleId.isNotEmpty && m.id == moduleId) ||
               (widget.moduleTitle.isNotEmpty && m.title.toLowerCase() == widget.moduleTitle.toLowerCase()),
      );
      final allDone = _topics.isNotEmpty && _topics.every((t) => t.isCompleted);
      final newStatus = allDone ? 'completed' : 'active';
      final now = DateTime.now();

      final Module targetModule;
      if (idx != -1) {
        if (modules[idx].status.toLowerCase() != newStatus) {
          targetModule = modules[idx].copyWith(
            status: newStatus,
            updatedAt: now,
          );
          modules[idx] = targetModule;
          await LocalModuleStorage.saveModulesForCourse(courseId, modules);
          if (getIt.isRegistered<FirestoreService>()) {
            final fs = getIt<FirestoreService>();
            if (fs.isAvailable) {
              try {
                await fs.updateModule(targetModule).timeout(
                  const Duration(seconds: 4),
                  onTimeout: () {},
                );
              } catch (_) {}
            }
          }
        } else {
          targetModule = modules[idx];
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
        await LocalModuleStorage.saveModulesForCourse(courseId, modules);
        if (getIt.isRegistered<FirestoreService>()) {
          final fs = getIt<FirestoreService>();
          if (fs.isAvailable) {
            try {
              await fs.updateModule(targetModule).timeout(
                const Duration(seconds: 4),
                onTimeout: () {},
              );
            } catch (_) {}
          }
        }
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
      final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
      await LocalTopicStorage.saveTopics(key, merged);
      if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
        await LocalTopicStorage.saveTopics(widget.moduleTitle, merged);
      }
      await _syncModuleCompletion();
      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
    }
  }

  Future<void> _toggleTopicStatus(int index) async {
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

    final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
    await LocalTopicStorage.saveTopics(key, _topics);
    if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
      await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
    }
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
      await LocalStudyLogStorage.addLog(studyLog);
      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable) {
          unawaited(firestore.addStudyLog(studyLog));
        }
      }
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    } else {
      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    }

    if (getIt.isRegistered<FirestoreService>()) {
      final firestore = getIt<FirestoreService>();
      if (firestore.isAvailable && updated.id.isNotEmpty) {
        try {
          await firestore.updateTopic(updated).timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('Firestore updateTopic timed out, kept local state.');
            },
          );
        } catch (e) {
          debugPrint('Error updating topic in firestore: $e');
        }
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
      final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
      await LocalTopicStorage.saveTopics(key, _topics);
      if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
        await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
      }
      await _syncModuleCompletion();
      unawaited(_loadModuleStats());

      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable && sub.id.isNotEmpty) {
          try {
            await firestore.deleteTopic(sub.id).timeout(
              const Duration(seconds: 4),
              onTimeout: () {},
            );
          } catch (e) {
            debugPrint('Error deleting topic in firestore: $e');
          }
        }
      }

      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
      if (getIt.isRegistered<RevisionController>()) {
        await getIt<RevisionController>().reconcile();
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
      final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
      await LocalTopicStorage.saveTopics(key, _topics);
      if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
        await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
      }
      await _syncModuleCompletion();
      if (getIt.isRegistered<OngoingModulesController>()) {
        await getIt<OngoingModulesController>().refresh();
      }
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

    final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
    await LocalTopicStorage.saveTopics(key, _topics);
    if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
      await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
    }
    await _syncModuleCompletion();

    if (getIt.isRegistered<FirestoreService>()) {
      final firestore = getIt<FirestoreService>();
      if (firestore.isAvailable) {
        try {
          await firestore.addTopic(duplicated).timeout(
            const Duration(seconds: 4),
            onTimeout: () {},
          );
        } catch (e) {
          debugPrint('Error duplicating topic in firestore: $e');
        }
      }
    }

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

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      floatingActionButton: _topics.isNotEmpty
          ? FloatingActionButton(
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
                if (allDone && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showModuleCompletedDialog(isInRevision: result is Map && result['isRevision'] == true);
                    }
                  });
                }
              },
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: progress >= 1.0 ? 'Start Revision Session' : 'Start Study Session',
              child: const Icon(Icons.play_arrow_rounded, size: 28),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomAppBar(
              title: widget.courseTitle.isNotEmpty ? widget.courseTitle : 'MODULE',
              onBack: _handleBack,
              actions: [
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
                onToggle: _toggleTopicStatus,
                onEdit: _handleEditTopic,
                onDuplicate: _handleDuplicateTopic,
                onDelete: _handleDeleteTopic,
                onAddTopic: _openAddTopicScreen,
                bottomPadding: bottomSafe + 84,
              ),
            ),
          ],
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

  static final DateFormat _dateFormat = DateFormat('d MMM, yyyy');

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
    final percent = (progress * 100).round();
    final isComplete = totalCount > 0 && completedCount >= totalCount;
    final dateStr = _dateFormat.format(lastUpdatedAt);
    final hoursStr = _formatDuration(totalMinutesExpended);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModuleContextPill(
            moduleTitle: moduleTitle,
            courseId: courseId,
            courseTitle: courseTitle,
          ),
          const VGapXs(),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$completedCount/$totalCount topics',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppTheme.successColor.withValues(alpha: 0.12)
                      : AppTheme.pastelPurple(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isComplete
                        ? AppTheme.successColor.withValues(alpha: 0.25)
                        : AppTheme.pastelPurpleBorder(context),
                  ),
                ),
                child: Text(
                  isComplete ? 'Completed' : 'In Progress',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isComplete
                        ? AppTheme.successColor
                        : AppTheme.pastelPurpleText(context),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          ],
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
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDuplicate;
  final ValueChanged<int> onDelete;
  final VoidCallback onAddTopic;
  final double bottomPadding;

  const _TopicsListView({
    required this.topics,
    required this.moduleTitle,
    required this.courseTitle,
    required this.courseId,
    required this.moduleId,
    required this.onToggle,
    required this.onEdit,
    required this.onDuplicate,
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

    final isModuleCompleted = topics.isNotEmpty && topics.every((t) => t.isCompleted);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 0, bottom: bottomPadding),
      itemCount: topics.length + (isModuleCompleted ? 1 : 0),
      itemBuilder: (context, index) {
        // "Add to Revision" footer button for completed modules
        if (isModuleCompleted && index == topics.length) {
          return _AddToRevisionFooter(
            moduleTitle: moduleTitle,
            courseTitle: courseTitle,
            courseId: courseId,
            moduleId: moduleId,
          );
        }

        final item = topics[index];
        void openOptions() {
          TopicOptionsSheet.show(
            context,
            topic: item,
            moduleTitle: moduleTitle,
            onEdit: () => onEdit(index),
            onDuplicate: () => onDuplicate(index),
            onDelete: () => onDelete(index),
          );
        }

        return TopicListItem(
          topic: item,
          onCheckboxTap: () => onToggle(index),
          onTap: () => onToggle(index),
          onLongPress: openOptions,
          onOptionsTap: openOptions,
        );
      },
    );
  }
}

/// Footer button shown at the bottom of a completed module's topic list.
class _AddToRevisionFooter extends StatelessWidget {
  final String moduleTitle;
  final String courseTitle;
  final String courseId;
  final String moduleId;

  const _AddToRevisionFooter({
    required this.moduleTitle,
    required this.courseTitle,
    required this.courseId,
    required this.moduleId,
  });

  Future<void> _handleTap(BuildContext context, bool isInRevision) async {
    if (!getIt.isRegistered<RevisionController>()) return;
    final revisionCtrl = getIt<RevisionController>();
    if (isInRevision) {
      final rev = revisionCtrl.revisionForModule(moduleId, moduleTitle: moduleTitle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rev != null
                ? '"$moduleTitle" is in revision schedule (Level R${rev.currentLevel})'
                : '"$moduleTitle" is already in revision schedule',
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
        ),
      );
      return;
    }

    try {
      final rev = await revisionCtrl.createOrEnsureRevision(
        courseId: courseId,
        moduleId: moduleId,
        courseTitle: courseTitle,
        moduleTitle: moduleTitle,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$moduleTitle" added to revision schedule (Level R${rev.currentLevel})'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to revision: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final revisionCtrl = getIt.isRegistered<RevisionController>()
        ? getIt<RevisionController>()
        : null;

    if (revisionCtrl == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: revisionCtrl,
      builder: (context, _) {
        final existingRevision = revisionCtrl.revisionForModule(
          moduleId,
          moduleTitle: moduleTitle,
        );
        final isInRevision = existingRevision != null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _handleTap(context, isInRevision),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isInRevision
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isInRevision
                        ? AppTheme.successColor.withValues(alpha: 0.4)
                        : AppTheme.primaryColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isInRevision ? Icons.check_circle_rounded : Icons.replay_rounded,
                      color: isInRevision ? AppTheme.successColor : AppTheme.primaryColor,
                      size: 20,
                    ),
                    const HGapSm(),
                    Text(
                      isInRevision
                          ? 'In Revision Schedule (Level R${existingRevision.currentLevel})'
                          : 'Add to Revision',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isInRevision ? AppTheme.successColor : AppTheme.primaryColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


