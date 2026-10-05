import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../models/topic.dart';
import '../models/revision_topic.dart';
import '../models/study_log.dart';
import '../services/local_study_log_storage.dart';
import '../services/local_topic_storage.dart';
import '../services/local_revision_topic_storage.dart';
import '../services/firestore_service.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../widgets/sheet_action_widgets.dart';

/// Running Study / Revision Session screen adhering to Screens 3, 4, 5, 8, 9, 10
/// from the design specification.
///
/// Features:
/// - Circular countdown timer displaying current mm:ss and total duration (/ 25:00).
/// - Current topic card with progress counter (e.g. 2 / 5 topics) and progress bar.
/// - Tap to mark topic complete triggers the "Topic Complete / Revised" popup (Screens 4 & 9).
/// - "Stay Here" keeps current topic active; "Next Topic" advances seamlessly to the next topic (Screens 5 & 10).
/// - Pause / Resume and End Session controls.
/// - Persists completed topics and study session logs to local storage and Firestore.
class SessionTimerScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String courseId;
  final String courseTitle;
  final String moduleId;
  final String moduleTitle;
  final int durationMinutes;
  final bool isRevision;
  final String? revisionId;
  final List<Topic> topics;
  final List<RevisionTopic>? revisionTopics;
  final int initialTopicIndex;
  final bool trackSession;
  final bool allowPause;
  final bool isRestrictMode;
  final bool allowReset;

  const SessionTimerScreen({
    super.key,
    this.title = 'Study Session',
    this.subtitle,
    this.courseId = '',
    this.courseTitle = '',
    this.moduleId = '',
    this.moduleTitle = '',
    this.durationMinutes = 25,
    this.isRevision = false,
    this.revisionId,
    this.topics = const [],
    this.revisionTopics,
    this.initialTopicIndex = 0,
    this.trackSession = true,
    this.allowPause = true,
    this.isRestrictMode = false,
    this.allowReset = true,
  });

  @override
  State<SessionTimerScreen> createState() => _SessionTimerScreenState();
}

class _SessionTimerScreenState extends State<SessionTimerScreen> {
  late int _totalSeconds;
  late final ValueNotifier<int> _secondsRemainingNotifier;
  late final ValueNotifier<bool> _isRunningNotifier;
  late final ValueNotifier<bool> _isCompletedNotifier;

  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Active topics list
  late List<Topic> _topics;
  late List<RevisionTopic> _revisionTopics;
  late int _currentTopicIndex;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _secondsRemainingNotifier = ValueNotifier<int>(_totalSeconds);
    _isRunningNotifier = ValueNotifier<bool>(true);
    _isCompletedNotifier = ValueNotifier<bool>(false);

    _topics = List<Topic>.from(widget.topics);
    _revisionTopics = widget.revisionTopics != null
        ? List<RevisionTopic>.from(widget.revisionTopics!)
        : [];
    _currentTopicIndex = widget.initialTopicIndex.clamp(
      0,
      (widget.isRevision ? _revisionTopics.length : _topics.length) > 0
          ? (widget.isRevision ? _revisionTopics.length : _topics.length) - 1
          : 0,
    );

    _startTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _secondsRemainingNotifier.dispose();
    _isRunningNotifier.dispose();
    _isCompletedNotifier.dispose();
    super.dispose();
  }

  void _startTimer() {
    _sessionTimer?.cancel();
    _isRunningNotifier.value = true;
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _elapsedSeconds++;
      if (_secondsRemainingNotifier.value > 0) {
        _secondsRemainingNotifier.value--;
      } else {
        timer.cancel();
        _isRunningNotifier.value = false;
        _isCompletedNotifier.value = true;
        _onSessionFinished();
      }
    });
  }

  void _pauseTimer() {
    _sessionTimer?.cancel();
    _isRunningNotifier.value = false;
  }

  void _togglePauseResume() {
    if (_isRunningNotifier.value) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  bool get _canPause => widget.allowPause && !widget.isRestrictMode;
  bool get _canReset => widget.allowReset && !widget.isRestrictMode;

  int get _totalTopicsCount {
    return widget.isRevision ? _revisionTopics.length : _topics.length;
  }

  int get _completedTopicsCount {
    if (widget.isRevision) {
      return _revisionTopics.where((t) => t.isCompleted).length;
    }
    return _topics.where((t) => t.isCompleted).length;
  }

  String get _currentTopicTitle {
    if (widget.isRevision) {
      if (_currentTopicIndex < _revisionTopics.length) {
        if (_currentTopicIndex < _topics.length && _topics[_currentTopicIndex].title.isNotEmpty) {
          return _topics[_currentTopicIndex].title;
        }
        final rt = _revisionTopics[_currentTopicIndex];
        final match = _topics.where((t) => t.id == rt.topicId).firstOrNull;
        if (match != null && match.title.isNotEmpty) return match.title;
        return rt.topicId.isNotEmpty ? rt.topicId : 'Topic';
      }
    } else {
      if (_currentTopicIndex < _topics.length) {
        return _topics[_currentTopicIndex].title;
      }
    }
    return 'Topic';
  }

  bool get _isCurrentTopicCompleted {
    if (widget.isRevision) {
      if (_currentTopicIndex < _revisionTopics.length) {
        return _revisionTopics[_currentTopicIndex].isCompleted;
      }
    } else {
      if (_currentTopicIndex < _topics.length) {
        return _topics[_currentTopicIndex].isCompleted;
      }
    }
    return false;
  }

  Future<void> _handleCompleteCurrentTopic() async {
    final now = DateTime.now();

    if (widget.isRevision) {
      if (_currentTopicIndex >= _revisionTopics.length) return;
      final current = _revisionTopics[_currentTopicIndex];
      final updated = current.copyWith(
        status: TopicStatus.completed,
        completedAt: now,
        updatedAt: now,
      );

      setState(() {
        _revisionTopics[_currentTopicIndex] = updated;
      });

      if (widget.revisionId != null && widget.revisionId!.isNotEmpty) {
        await LocalRevisionTopicStorage.saveTopics(widget.revisionId!, _revisionTopics);
      }

      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable && updated.id.isNotEmpty) {
          unawaited(firestore.updateRevisionTopic(updated));
        }
      }

      // Log to StudyLog
      final studyLog = StudyLog(
        id: '${updated.id}_${now.millisecondsSinceEpoch}',
        type: StudyLogType.revisionCompleted,
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        moduleId: widget.moduleId,
        moduleTitle: widget.moduleTitle,
        topicId: updated.topicId.isNotEmpty ? updated.topicId : updated.id,
        topicTitle: _currentTopicTitle,
        timestamp: now,
        createdAt: now,
      );
      await LocalStudyLogStorage.addLog(studyLog);
      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable) {
          unawaited(firestore.addStudyLog(studyLog));
        }
      }
    } else {
      if (_currentTopicIndex >= _topics.length) return;
      final current = _topics[_currentTopicIndex];
      final updated = current.copyWith(
        status: TopicStatus.completed,
        completedAt: now,
      );

      setState(() {
        _topics[_currentTopicIndex] = updated;
      });

      final key = widget.moduleId.isNotEmpty ? widget.moduleId : widget.moduleTitle;
      await LocalTopicStorage.saveTopics(key, _topics);
      if (widget.moduleTitle.isNotEmpty && widget.moduleTitle != key) {
        await LocalTopicStorage.saveTopics(widget.moduleTitle, _topics);
      }

      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable && updated.id.isNotEmpty) {
          unawaited(firestore.updateTopic(updated));
        }
      }

      // Log to StudyLog
      final studyLog = StudyLog(
        id: '${updated.id}_${now.millisecondsSinceEpoch}',
        type: StudyLogType.topicCompleted,
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        moduleId: widget.moduleId,
        moduleTitle: widget.moduleTitle,
        topicId: updated.id,
        topicTitle: updated.title,
        timestamp: now,
        createdAt: now,
      );
      await LocalStudyLogStorage.addLog(studyLog);
      if (getIt.isRegistered<FirestoreService>()) {
        final firestore = getIt<FirestoreService>();
        if (firestore.isAvailable) {
          unawaited(firestore.addStudyLog(studyLog));
        }
      }
    }

    if (getIt.isRegistered<OngoingModulesController>()) {
      unawaited(getIt<OngoingModulesController>().refresh());
    }
    if (getIt.isRegistered<RevisionController>()) {
      unawaited(getIt<RevisionController>().reconcile());
    }
    if (getIt.isRegistered<ProgressController>()) {
      unawaited(getIt<ProgressController>().refresh());
    }

    if (!mounted) return;

    // Show Screens 4 / 9: Topic Complete / Revised Popup
    _showTopicCompletePopup();
  }

  void _showTopicCompletePopup() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 310),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact green checkmark badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const VGapMd(),
                Text(
                  widget.isRevision ? 'Topic revised!' : 'Topic completed!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const VGapXs(),
                Text(
                  _currentTopicTitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapSm(),
                Text(
                  'Move to next topic?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapMd(),
                Row(
                  children: [
                    // Stay Here button (matching app pastel secondary button)
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.pastelIndigo(context),
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'Stay Here',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const HGapSm(),
                    // Next Topic button (matching app primary button)
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _advanceToNextTopic();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text(
                            'Next Topic',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _advanceToNextTopic() {
    int nextIndex = -1;
    final total = _totalTopicsCount;

    // Look for the next incomplete topic after current index
    for (int i = _currentTopicIndex + 1; i < total; i++) {
      final isComp = widget.isRevision
          ? _revisionTopics[i].isCompleted
          : _topics[i].isCompleted;
      if (!isComp) {
        nextIndex = i;
        break;
      }
    }

    // Wrap around if needed
    if (nextIndex == -1) {
      for (int i = 0; i < _currentTopicIndex; i++) {
        final isComp = widget.isRevision
            ? _revisionTopics[i].isCompleted
            : _topics[i].isCompleted;
        if (!isComp) {
          nextIndex = i;
          break;
        }
      }
    }

    if (nextIndex != -1) {
      setState(() {
        _currentTopicIndex = nextIndex;
      });
    } else {
      // All topics completed!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All topics in this module are now completed! 🎉'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _onSessionFinished() async {
    final now = DateTime.now();
    final elapsedMinutes = (_elapsedSeconds / 60).ceil().clamp(1, widget.durationMinutes);

    if (widget.trackSession) {
      final studyLog = StudyLog(
        id: 'session_${now.millisecondsSinceEpoch}',
        type: StudyLogType.studySession,
        courseId: widget.courseId,
        courseTitle: widget.courseTitle,
        moduleId: widget.moduleId,
        moduleTitle: widget.moduleTitle,
        topicId: widget.isRevision
            ? (_currentTopicIndex < _revisionTopics.length ? _revisionTopics[_currentTopicIndex].id : null)
            : (_currentTopicIndex < _topics.length ? _topics[_currentTopicIndex].id : null),
        topicTitle: _currentTopicTitle,
        durationMinutes: elapsedMinutes,
        timestamp: now,
        createdAt: now,
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
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.title} completed ($elapsedMinutes mins)! 🎉'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleExitSession() async {
    _pauseTimer();

    final isStrict = widget.isRestrictMode;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: !isStrict,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStrict
                    ? Icons.lock_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                size: 38,
                color: isStrict ? AppTheme.pastelOrangeText(context) : AppTheme.primaryColor,
              ),
              const VGapMd(),
              Text(
                isStrict ? 'Strict Mode Active' : 'Exit Session?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const VGapXs(),
              Text(
                isStrict
                    ? 'Strict focus discipline is active. Are you sure you want to break focus and quit the session early?'
                    : 'End this session?\nCompleted progress will be saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor(context),
                  height: 1.35,
                ),
              ),
              const VGapMd(),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop(false);
                          _startTimer();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isStrict
                              ? AppTheme.primaryColor
                              : AppTheme.pastelIndigo(context),
                          foregroundColor: isStrict ? Colors.white : AppTheme.primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          isStrict ? 'Keep Focusing' : 'Resume',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isStrict
                              ? AppTheme.surfaceVariant(context)
                              : AppTheme.primaryColor,
                          foregroundColor: isStrict
                              ? AppTheme.errorColor
                              : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          isStrict ? 'Quit Session' : 'End & Exit',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      if (_elapsedSeconds >= 60 && widget.trackSession) {
        await _onSessionFinished();
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (confirm != true && mounted) {
      _startTimer();
    }
  }

  static String _formatTime(int secs) {
    final m = (secs / 60).floor();
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalTopicsCount;
    final completed = _completedTopicsCount;
    final ratio = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleExitSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Top App Bar: Exit | Title | Settings
                _buildTopBar(context),

                const Spacer(flex: 1),

                // RepaintBoundary isolates 1-second countdown repaints from rest of UI
                RepaintBoundary(
                  child: _buildCircularTimer(context),
                ),

                const Spacer(flex: 1),

                // Current Topic Card
                _buildCurrentTopicCard(context, completed, total, ratio),

                const Spacer(flex: 1),

                // Bottom Action Controls: Pause & End Session
                _buildBottomControls(context),

                const VGapSm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addTime(int minutes) {
    final addedSeconds = minutes * 60;
    setState(() {
      _totalSeconds += addedSeconds;
    });
    _secondsRemainingNotifier.value += addedSeconds;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added +$minutes minutes to session'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetTimer() {
    _pauseTimer();
    _secondsRemainingNotifier.value = _totalSeconds;
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Timer reset to initial duration'),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openSessionOptionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SheetContainer(
          children: [
            const SheetHandleBar(),
            const VGapMd(),
            SheetHeader(
              badge: SheetHeaderBadge(
                backgroundColor: widget.isRestrictMode
                    ? AppTheme.pastelOrange(context)
                    : AppTheme.pastelIndigo(context),
                child: Icon(
                  widget.isRestrictMode
                      ? Icons.shield_outlined
                      : (widget.isRevision ? Icons.sync_rounded : Icons.timer_outlined),
                  color: widget.isRestrictMode
                      ? AppTheme.pastelOrangeText(context)
                      : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              title: widget.isRevision ? 'Revision Session Options' : 'Study Session Options',
              subtitle: '${widget.moduleTitle} • ${_formatTime(_secondsRemainingNotifier.value)} remaining',
            ),
            const VGapMd(),
            if (widget.isRestrictMode) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.pastelOrange(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.pastelOrangeBorder(context)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: AppTheme.pastelOrangeText(context),
                    ),
                    const HGapSm(),
                    Expanded(
                      child: Text(
                        'Strict Mode active: pause & reset are locked.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.pastelOrangeText(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SheetActionRow(
              icon: Icons.add_alarm_rounded,
              title: 'Add +5 Minutes',
              onTap: () {
                Navigator.pop(sheetCtx);
                _addTime(5);
              },
            ),
            SheetActionRow(
              icon: Icons.more_time_rounded,
              title: 'Add +10 Minutes',
              onTap: () {
                Navigator.pop(sheetCtx);
                _addTime(10);
              },
            ),
            SheetActionRow(
              icon: Icons.skip_next_rounded,
              title: 'Skip to Next Topic',
              onTap: () {
                Navigator.pop(sheetCtx);
                _advanceToNextTopic();
              },
            ),
            if (_canReset) ...[
              SheetActionRow(
                icon: Icons.restart_alt_rounded,
                title: 'Reset Timer',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _resetTimer();
                },
              ),
            ],
            const VGapSm(),
            SheetCancelButton(
              onTap: () => Navigator.pop(sheetCtx),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Exit button matching existing pill style
        Material(
          color: widget.isRestrictMode
              ? AppTheme.pastelOrange(context)
              : AppTheme.pastelIndigo(context),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: _handleExitSession,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isRestrictMode
                      ? AppTheme.pastelOrangeBorder(context)
                      : AppTheme.pastelIndigoBorder(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isRestrictMode ? Icons.lock_outline_rounded : Icons.close_rounded,
                    size: 13,
                    color: widget.isRestrictMode
                        ? AppTheme.pastelOrangeText(context)
                        : AppTheme.primaryColor,
                  ),
                  const HGapXs(),
                  Text(
                    'Exit',
                    style: TextStyle(
                      color: widget.isRestrictMode
                          ? AppTheme.pastelOrangeText(context)
                          : AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Session Title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isRevision ? 'Revision Session' : 'Study Session',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            if (widget.isRestrictMode) ...[
              const HGapXs(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.pastelOrange(context),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'STRICT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.pastelOrangeText(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Gear Options Button
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: widget.isRestrictMode
                ? AppTheme.pastelOrangeText(context)
                : AppTheme.textSecondaryColor(context),
            size: 20,
          ),
          onPressed: _openSessionOptionsSheet,
          tooltip: 'Session Options',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _handleTimerTap() {
    if (_canPause) {
      _togglePauseResume();
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                widget.isRestrictMode ? Icons.lock_outline_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  widget.isRestrictMode
                      ? 'Strict Mode: Continuous focus active (pause locked)'
                      : 'Pause is disabled for this session',
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: widget.isRestrictMode ? const Color(0xFFC2410C) : AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildCircularTimer(BuildContext context) {
    return GestureDetector(
      onTap: _handleTimerTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular Progress Indicator Ring
          ValueListenableBuilder<int>(
            valueListenable: _secondsRemainingNotifier,
            builder: (context, secondsRemaining, _) {
              final double progress = (_totalSeconds - secondsRemaining) / _totalSeconds;
              return SizedBox(
                width: 195,
                height: 195,
                child: CircularProgressIndicator(
                  value: _isCompletedNotifier.value ? 1.0 : progress,
                  strokeWidth: 4.0,
                  backgroundColor: AppTheme.borderColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isCompletedNotifier.value
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                ),
              );
            },
          ),

          // Center Time Display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _secondsRemainingNotifier,
                builder: (context, secondsRemaining, _) {
                  return Text(
                    _formatTime(secondsRemaining),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const VGapXs(),
              Text(
                '/ ${_formatTime(_totalSeconds)}',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTopicCard(
    BuildContext context,
    int completed,
    int total,
    double ratio,
  ) {
    final isRev = widget.isRevision;
    final iconColor = isRev ? AppTheme.successColor : AppTheme.primaryColor;
    final iconBg = isRev
        ? AppTheme.successColor.withValues(alpha: 0.12)
        : AppTheme.primaryColor.withValues(alpha: 0.12);

    final breadcrumbs = widget.courseTitle.isNotEmpty
        ? '${widget.moduleTitle} • ${widget.courseTitle}'
        : widget.moduleTitle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon Box
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isRev ? Icons.sync_rounded : Icons.article_outlined,
                  color: iconColor,
                  size: 18,
                ),
              ),
              const HGapMd(),
              // Title & Breadcrumb
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Topic',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      '${_currentTopicIndex + 1}. $_currentTopicTitle',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      breadcrumbs,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const HGapSm(),
              // Mark Complete Pill Button matching AddPillButton style
              Material(
                color: _isCurrentTopicCompleted
                    ? AppTheme.pastelGreen(context)
                    : AppTheme.pastelIndigo(context),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _isCurrentTopicCompleted ? null : _handleCompleteCurrentTopic,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCurrentTopicCompleted
                            ? AppTheme.pastelGreenBorder(context)
                            : AppTheme.pastelIndigoBorder(context),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCurrentTopicCompleted
                              ? Icons.check_circle_rounded
                              : Icons.check_rounded,
                          size: 13,
                          color: _isCurrentTopicCompleted
                              ? AppTheme.pastelGreenText(context)
                              : AppTheme.primaryColor,
                        ),
                        const HGapXs(),
                        Text(
                          _isCurrentTopicCompleted ? 'Done' : 'Complete',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _isCurrentTopicCompleted
                                ? AppTheme.pastelGreenText(context)
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const VGapSm(),

          // Progress text & bar
          Text(
            '$completed / $total topics',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapXs(),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: AppTheme.borderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Pause / Resume Control
        ValueListenableBuilder<bool>(
          valueListenable: _isRunningNotifier,
          builder: (context, isRunning, _) {
            final canPause = _canPause;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _handleTimerTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: canPause
                          ? AppTheme.surface(context)
                          : AppTheme.surfaceVariant(context).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.isRestrictMode
                            ? AppTheme.pastelOrangeBorder(context)
                            : AppTheme.borderColor(context),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      !canPause
                          ? Icons.lock_outline_rounded
                          : (isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      size: 21,
                      color: !canPause
                          ? (widget.isRestrictMode
                              ? AppTheme.pastelOrangeText(context)
                              : AppTheme.textSecondaryColor(context))
                          : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                const VGapXs(),
                Text(
                  !canPause
                      ? (widget.isRestrictMode ? 'Strict' : 'Locked')
                      : (isRunning ? 'Pause' : 'Resume'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.isRestrictMode && !canPause
                        ? AppTheme.pastelOrangeText(context)
                        : AppTheme.textSecondaryColor(context),
                  ),
                ),
              ],
            );
          },
        ),

        // End Session Control
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _handleExitSession,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimaryColor(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),
            const VGapXs(),
            Text(
              'End',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
