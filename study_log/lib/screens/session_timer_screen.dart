import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../models/topic.dart';
import '../models/revision_topic.dart';
import '../models/study_log.dart';
import '../services/database_service.dart';
import '../services/service_locator.dart';
import '../controllers/ongoing_modules_controller.dart';
import '../controllers/revision_controller.dart';
import '../controllers/topic_revision_controller.dart';
import '../controllers/progress_controller.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/phone_lock_settings_sheet.dart';
import '../widgets/timed_lock_overlay_screen.dart';
import '../services/notification_service.dart';

/// Running Study / Revision Session screen adhering to Screens 3, 4, 5, 8, 9, 10
/// from the design specification.
///
/// Features:
/// - Circular countdown timer displaying current mm:ss and total duration (/ 15:00).
/// - Current topic card with progress counter (e.g. 2 / 5 topics) and progress bar.
/// - Tap to mark topic complete triggers the "Topic Complete / Revised" popup (Screens 4 & 9).
/// - "Stay Here" keeps current topic active; "Next Topic" advances seamlessly to the next topic (Screens 5 & 10).
/// - Pause / Resume and End Session controls.
/// - Persists completed topics and study session logs to local SQLite database.
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
  final bool allowReset;
  final PhoneLockConfig lockConfig;

  const SessionTimerScreen({
    super.key,
    this.title = 'Study Session',
    this.subtitle,
    this.courseId = '',
    this.courseTitle = '',
    this.moduleId = '',
    this.moduleTitle = '',
    this.durationMinutes = 15,
    this.isRevision = false,
    this.revisionId,
    this.topics = const [],
    this.revisionTopics,
    this.initialTopicIndex = 0,
    this.trackSession = true,
    this.allowPause = true,
    this.allowReset = true,
    this.lockConfig = const PhoneLockConfig(),
  });

  @override
  State<SessionTimerScreen> createState() => _SessionTimerScreenState();
}

class _SessionTimerScreenState extends State<SessionTimerScreen> with WidgetsBindingObserver {
  late int _totalSeconds;
  late final ValueNotifier<int> _secondsRemainingNotifier;
  late final ValueNotifier<bool> _isRunningNotifier;
  late final ValueNotifier<bool> _isCompletedNotifier;
  late final ValueNotifier<bool> _isLockOverlayActiveNotifier;

  Timer? _sessionTimer;
  int _elapsedSeconds = 0;
  DateTime? _backgroundEnterTime;
  StreamSubscription<String>? _actionSubscription;
  bool _isInBackground = false;

  // Active topics list
  late List<Topic> _topics;
  late List<RevisionTopic> _revisionTopics;
  late int _currentTopicIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _totalSeconds = widget.durationMinutes * 60;
    _secondsRemainingNotifier = ValueNotifier<int>(_totalSeconds);
    _isRunningNotifier = ValueNotifier<bool>(true);
    _isCompletedNotifier = ValueNotifier<bool>(false);
    _isLockOverlayActiveNotifier = ValueNotifier<bool>(widget.lockConfig.isLockModeEnabled);

    if (getIt.isRegistered<NotificationService>()) {
      _actionSubscription = getIt<NotificationService>().onActionTapped.listen(_handleNotificationAction);
    }

    _topics = List<Topic>.from(widget.topics);
    _revisionTopics = widget.revisionTopics != null
        ? List<RevisionTopic>.from(widget.revisionTopics!)
        : [];

    if (widget.isRevision) {
      if (_revisionTopics.isNotEmpty && _revisionTopics.every((t) => t.isCompleted)) {
        // If all revision topics already completed, restart from first and reset status
        final now = DateTime.now();
        _revisionTopics = _revisionTopics.map((t) => t.copyWith(
          status: TopicStatus.notStarted,
          clearCompletedAt: true,
          updatedAt: now,
        )).toList();
        _currentTopicIndex = 0;

        if (widget.revisionId != null && widget.revisionId!.isNotEmpty) {
          unawaited(DatabaseService.instance.saveRevisionTopics(widget.revisionId!, _revisionTopics));
        }
      } else {
        _currentTopicIndex = widget.initialTopicIndex.clamp(
          0,
          (_revisionTopics.isNotEmpty ? _revisionTopics.length : _topics.length) > 0
              ? (_revisionTopics.isNotEmpty ? _revisionTopics.length : _topics.length) - 1
              : 0,
        );
      }
    } else {
      _currentTopicIndex = widget.initialTopicIndex.clamp(
        0,
        _topics.isNotEmpty ? _topics.length - 1 : 0,
      );
    }

    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionSubscription?.cancel();
    if (getIt.isRegistered<NotificationService>()) {
      unawaited(getIt<NotificationService>().dismissSessionTimerNotification());
    }
    _sessionTimer?.cancel();
    _secondsRemainingNotifier.dispose();
    _isRunningNotifier.dispose();
    _isCompletedNotifier.dispose();
    _isLockOverlayActiveNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isInBackground = true;
      _backgroundEnterTime = DateTime.now();
      if (!_isCompletedNotifier.value) {
        _showBackgroundNotification();
      }
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      if (_backgroundEnterTime != null && _isRunningNotifier.value && !_isCompletedNotifier.value) {
        final elapsedInBackground = DateTime.now().difference(_backgroundEnterTime!).inSeconds;
        _backgroundEnterTime = null;
        if (elapsedInBackground > 0) {
          _elapsedSeconds += elapsedInBackground;
          final remaining = _secondsRemainingNotifier.value - elapsedInBackground;
          if (remaining <= 0) {
            _secondsRemainingNotifier.value = 0;
            _sessionTimer?.cancel();
            _isRunningNotifier.value = false;
            _isCompletedNotifier.value = true;
            _onSessionFinished();
          } else {
            _secondsRemainingNotifier.value = remaining;
          }
        }
      } else {
        _backgroundEnterTime = null;
      }
      if (getIt.isRegistered<NotificationService>()) {
        unawaited(getIt<NotificationService>().dismissSessionTimerNotification());
      }
    }
  }

  void _handleNotificationAction(String action) {
    if (!mounted || _isCompletedNotifier.value) return;
    if (action == 'pause_session') {
      _pauseTimer();
      _showBackgroundNotification();
    } else if (action == 'resume_session') {
      _startTimer();
      _showBackgroundNotification();
    } else if (action == 'stop_session') {
      _sessionTimer?.cancel();
      _isRunningNotifier.value = false;
      _isCompletedNotifier.value = true;
      if (getIt.isRegistered<NotificationService>()) {
        unawaited(getIt<NotificationService>().dismissSessionTimerNotification());
      }
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _showBackgroundNotification() {
    if (!getIt.isRegistered<NotificationService>() || _isCompletedNotifier.value) return;
    final notifService = getIt<NotificationService>();
    final prefix = widget.isRevision ? 'Revision' : 'Study';
    final rawTopic = _currentTopicTitle.trim();
    final topicName = rawTopic.isNotEmpty
        ? rawTopic
        : (widget.moduleTitle.trim().isNotEmpty ? widget.moduleTitle.trim() : 'Session');
    final displayTitle = '$prefix: $topicName';

    if (_isRunningNotifier.value && _secondsRemainingNotifier.value > 0) {
      unawaited(notifService.showSessionTimerNotification(
        title: displayTitle,
        subtitle: '',
        remainingSeconds: _secondsRemainingNotifier.value,
        targetId: widget.moduleId,
      ));
    } else {
      unawaited(notifService.showSessionPausedNotification(
        title: displayTitle,
        subtitle: '',
        remainingSeconds: _secondsRemainingNotifier.value,
        targetId: widget.moduleId,
      ));
    }
  }

  void _minimizeSession() {
    _showBackgroundNotification();
    const MethodChannel('com.logapp.studylog/share').invokeMethod('sendToBackground');
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
    if (_isInBackground) {
      _showBackgroundNotification();
    }
  }

  void _togglePauseResume() {
    if (_isRunningNotifier.value) {
      _pauseTimer();
    } else {
      _startTimer();
    }
    if (_isInBackground) {
      _showBackgroundNotification();
    }
  }

  bool get _isLockModeActive =>
      widget.lockConfig.isLockModeEnabled && _isLockOverlayActiveNotifier.value;

  bool get _canPause => widget.allowPause && !_isLockModeActive;
  bool get _canReset => widget.allowReset && !_isLockModeActive;

  int get _totalTopicsCount {
    return (widget.isRevision && _revisionTopics.isNotEmpty)
        ? _revisionTopics.length
        : _topics.length;
  }

  int get _completedTopicsCount {
    if (widget.isRevision && _revisionTopics.isNotEmpty) {
      return _revisionTopics.where((t) => t.isCompleted).length;
    }
    return _topics.where((t) => t.isCompleted).length;
  }

  String _getTopicTitleAt(int index) {
    if (widget.isRevision && _revisionTopics.isNotEmpty) {
      if (index < _revisionTopics.length) {
        if (index < _topics.length && _topics[index].title.isNotEmpty) {
          return _topics[index].title;
        }
        final rt = _revisionTopics[index];
        final match = _topics.where((t) => t.id == rt.topicId).firstOrNull;
        if (match != null && match.title.isNotEmpty) return match.title;
        return rt.topicId.isNotEmpty ? rt.topicId : 'Topic ${index + 1}';
      }
    } else {
      if (index < _topics.length) {
        return _topics[index].title;
      }
    }
    return 'Topic ${index + 1}';
  }

  bool _isTopicCompletedAt(int index) {
    if (widget.isRevision && _revisionTopics.isNotEmpty) {
      if (index < _revisionTopics.length) {
        return _revisionTopics[index].isCompleted;
      }
    } else {
      if (index < _topics.length) {
        return _topics[index].isCompleted;
      }
    }
    return false;
  }

  String get _currentTopicTitle => _getTopicTitleAt(_currentTopicIndex);

  bool get _isCurrentTopicCompleted => _isTopicCompletedAt(_currentTopicIndex);

  void _switchToTopic(int index) {
    if (index >= 0 && index < _totalTopicsCount && index != _currentTopicIndex) {
      setState(() {
        _currentTopicIndex = index;
      });
    }
  }

  Future<void> _handleDoneAndNext() async {
    final now = DateTime.now();

    if (widget.isRevision && _revisionTopics.isNotEmpty) {
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
        await DatabaseService.instance.saveRevisionTopics(widget.revisionId!, _revisionTopics);
      }

      final elapsedMinutes = (_elapsedSeconds / 60).ceil().clamp(1, widget.durationMinutes);
      final targetTopicId = updated.topicId.isNotEmpty ? updated.topicId : updated.id;

      // Advance individual topic revision in TopicRevisionController (Single Source of Truth)
      if (getIt.isRegistered<TopicRevisionController>()) {
        final trc = getIt<TopicRevisionController>();
        final rev = trc.topicRevisionFor(targetTopicId) ??
            (widget.revisionId != null
                ? trc.topicRevisions.where((r) => r.id == widget.revisionId).firstOrNull
                : null);
        if (rev != null) {
          await trc.completeCurrentLevel(rev.id, at: now, durationMinutes: elapsedMinutes);
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
        topicId: targetTopicId,
        topicTitle: _currentTopicTitle,
        durationMinutes: elapsedMinutes,
        timestamp: now,
        createdAt: now,
      );
      await DatabaseService.instance.addStudyLog(studyLog);
      // 2) Save study session for this topic
      if (widget.trackSession) {
        final sessionLog = StudyLog(
          id: 'session_${now.millisecondsSinceEpoch}',
          type: StudyLogType.studySession,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          topicId: updated.topicId.isNotEmpty ? updated.topicId : updated.id,
          topicTitle: _currentTopicTitle,
          revisionLevel: 1,
          durationMinutes: elapsedMinutes,
          timestamp: now,
          createdAt: now,
        );
        await DatabaseService.instance.addStudyLog(sessionLog);
      }
    } else if (widget.isRevision) {
      // Individual topic revision session
      if (_currentTopicIndex >= _topics.length) return;
      final current = _topics[_currentTopicIndex];
      final updated = current.copyWith(
        status: TopicStatus.completed,
        completedAt: current.completedAt ?? now,
      );

      setState(() {
        _topics[_currentTopicIndex] = updated;
      });

      await DatabaseService.instance.updateTopic(updated);

      final elapsedMinutes = (_elapsedSeconds / 60).ceil().clamp(1, widget.durationMinutes);

      // Advance individual topic revision in TopicRevisionController
      if (getIt.isRegistered<TopicRevisionController>()) {
        final trc = getIt<TopicRevisionController>();
        final rev = widget.revisionId != null
            ? trc.topicRevisions.where((r) => r.id == widget.revisionId).firstOrNull
            : trc.topicRevisionFor(current.id);
        if (rev != null) {
          await trc.completeCurrentLevel(rev.id, at: now, durationMinutes: elapsedMinutes);
        } else {
          final studyLog = StudyLog(
            id: 'rev_topic_${current.id}_${now.millisecondsSinceEpoch}',
            type: StudyLogType.revisionCompleted,
            courseId: widget.courseId,
            courseTitle: widget.courseTitle,
            moduleId: widget.moduleId,
            moduleTitle: widget.moduleTitle,
            topicId: current.id,
            topicTitle: current.title,
            revisionLevel: 1,
            durationMinutes: elapsedMinutes,
            timestamp: now,
            createdAt: now,
          );
          await DatabaseService.instance.addStudyLog(studyLog);
        }
      }

      if (widget.trackSession) {
        final sessionLog = StudyLog(
          id: 'session_${now.millisecondsSinceEpoch}',
          type: StudyLogType.studySession,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          topicId: current.id,
          topicTitle: current.title,
          revisionLevel: 1,
          durationMinutes: elapsedMinutes,
          timestamp: now,
          createdAt: now,
        );
        await DatabaseService.instance.addStudyLog(sessionLog);
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

      await DatabaseService.instance.updateTopic(updated);

      final elapsedMinutes = (_elapsedSeconds / 60).ceil().clamp(1, widget.durationMinutes);

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
        durationMinutes: elapsedMinutes,
        timestamp: now,
        createdAt: now,
      );
      await DatabaseService.instance.addStudyLog(studyLog);

      // 2) Save study session for this topic
      if (widget.trackSession) {
        final sessionLog = StudyLog(
          id: 'session_${now.millisecondsSinceEpoch}',
          type: StudyLogType.studySession,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          topicId: updated.id,
          topicTitle: updated.title,
          durationMinutes: elapsedMinutes,
          timestamp: now,
          createdAt: now,
        );
        await DatabaseService.instance.addStudyLog(sessionLog);
      }
    }

    if (getIt.isRegistered<TopicRevisionController>()) {
      unawaited(getIt<TopicRevisionController>().refresh());
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

    // Reset timer to default duration for the next topic
    _elapsedSeconds = 0;
    _totalSeconds = widget.durationMinutes * 60;
    _secondsRemainingNotifier.value = _totalSeconds;
    _isCompletedNotifier.value = false;
    _startTimer();

    if (!mounted) return;

    // Check if ALL topics in this module/session are completed
    final allCompleted = (widget.isRevision && _revisionTopics.isNotEmpty)
        ? _revisionTopics.every((t) => t.isCompleted)
        : _topics.every((t) => t.isCompleted);

    if (allCompleted) {
      _sessionTimer?.cancel();
      _isRunningNotifier.value = false;
      Navigator.of(context).pop<Map<String, dynamic>>({
        'allCompleted': true,
        'isRevision': widget.isRevision,
        'moduleId': widget.moduleId,
        'revisionId': widget.revisionId,
      });
      return;
    }

    // Advance directly to the next topic
    _advanceToNextTopic();
  }

  void _advanceToNextTopic() {
    int nextIndex = -1;
    final total = _totalTopicsCount;

    // Look for the next incomplete topic after current index
    for (int i = _currentTopicIndex + 1; i < total; i++) {
      final isComp = (widget.isRevision && _revisionTopics.isNotEmpty)
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
        final isComp = (widget.isRevision && _revisionTopics.isNotEmpty)
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
      // All topics completed! Close timer and return to module page
      _sessionTimer?.cancel();
      _isRunningNotifier.value = false;
      if (mounted) {
        Navigator.of(context).pop<Map<String, dynamic>>({
          'allCompleted': true,
          'isRevision': widget.isRevision,
          'moduleId': widget.moduleId,
          'revisionId': widget.revisionId,
        });
      }
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
            ? (_currentTopicIndex < _revisionTopics.length
                ? (_revisionTopics[_currentTopicIndex].topicId.isNotEmpty
                    ? _revisionTopics[_currentTopicIndex].topicId
                    : _revisionTopics[_currentTopicIndex].id)
                : null)
            : (_currentTopicIndex < _topics.length ? _topics[_currentTopicIndex].id : null),
        topicTitle: _currentTopicTitle,
        revisionLevel: widget.isRevision ? 1 : null,
        durationMinutes: elapsedMinutes,
        timestamp: now,
        createdAt: now,
      );

      await DatabaseService.instance.addStudyLog(studyLog);

      if (getIt.isRegistered<ProgressController>()) {
        unawaited(getIt<ProgressController>().refresh());
      }
    }

    if (getIt.isRegistered<NotificationService>()) {
      unawaited(getIt<NotificationService>().dismissSessionTimerNotification());
      if (_isInBackground) {
        unawaited(getIt<NotificationService>().showSessionCompleteNotification(
          title: '${widget.title} Completed! 🎉',
          body: 'You focused for $elapsedMinutes mins on $_currentTopicTitle.',
        ));
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

  Future<void> _handleEmergencyLockExit() async {
    await _handleExitSession();
  }

  Future<void> _handleExitSession() async {
    _pauseTimer();

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
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
                Icons.pause_circle_outline_rounded,
                size: 38,
                color: AppTheme.primaryColor,
              ),
              const VGapMd(),
              Text(
                'Exit Session?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const VGapXs(),
              Text(
                'End this session?\nCompleted progress will be saved.',
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
                          backgroundColor: AppTheme.pastelIndigo(context),
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'Resume',
                          style: TextStyle(
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
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text(
                          'End & Exit',
                          style: TextStyle(
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
      _isLockOverlayActiveNotifier.value = false;
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

  String get _breadcrumbs {
    if (widget.courseTitle.isNotEmpty && widget.moduleTitle.isNotEmpty) {
      return '${widget.courseTitle} > ${widget.moduleTitle}';
    } else if (widget.courseTitle.isNotEmpty) {
      return widget.courseTitle;
    } else {
      return widget.moduleTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalTopicsCount;
    final completed = _completedTopicsCount;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (widget.lockConfig.isLockModeEnabled) {
            // Silently consume back button in Lock Mode without alert
            return;
          }
          _handleExitSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background(context),
        body: SafeArea(
          child: Stack(
            children: [
              // Layer 1: Timer Layer (Z-index: Center, lifted slightly for optical balance)
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -45),
                    child: RepaintBoundary(
                      child: _buildCircularTimer(context, completed, total),
                    ),
                  ),
                ),
              ),

              // Layer 2: Top Header Layer (App Bar, Breadcrumbs, Current Topic)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopBar(context),
                    if (_breadcrumbs.isNotEmpty) ...[
                      const VGapXs(),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _breadcrumbs,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              color: AppTheme.textSecondaryColor(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const VGapSm(),
                    _buildCurrentTopicCard(context),
                  ],
                ),
              ),

              // Layer 3: Bottom Controls Layer (End, Next & Save / Save)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _buildBottomControls(context),
              ),

              // Layer 4: Zen Lock Mode Overlay (Full-screen timed phone lock)
              if (widget.lockConfig.isLockModeEnabled)
                ValueListenableBuilder<bool>(
                  valueListenable: _isLockOverlayActiveNotifier,
                  builder: (context, isLocked, _) {
                    if (!isLocked) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: TimedLockOverlayScreen(
                        title: widget.isRevision ? 'Revision Session' : 'Study Session',
                        subtitle: _currentTopicTitle,
                        breadcrumbs: _breadcrumbs,
                        currentTopicIndex: _currentTopicIndex,
                        currentTopicTitle: _currentTopicTitle,
                        completedTopicsCount: _completedTopicsCount,
                        totalTopicsCount: _totalTopicsCount,
                        durationSeconds: _totalSeconds,
                        secondsRemainingNotifier: _secondsRemainingNotifier,
                        lockConfig: widget.lockConfig,
                        onEmergencyExit: _handleEmergencyLockExit,
                        onSessionComplete: () {
                          _isLockOverlayActiveNotifier.value = false;
                        },
                      ),
                    );
                  },
                ),
            ],
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
  }

  void _resetTimer() {
    _pauseTimer();
    _secondsRemainingNotifier.value = _totalSeconds;
    _startTimer();
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
                backgroundColor: widget.lockConfig.isLockModeEnabled
                    ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                    : AppTheme.pastelIndigo(context),
                child: Icon(
                  widget.lockConfig.isLockModeEnabled
                      ? Icons.lock_clock_rounded
                      : (widget.isRevision ? Icons.sync_rounded : Icons.timer_outlined),
                  color: widget.lockConfig.isLockModeEnabled
                      ? const Color(0xFFDC2626)
                      : AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              title: widget.isRevision ? 'Revision Session Options' : 'Study Session Options',
              subtitle: '${widget.moduleTitle} • ${_formatTime(_secondsRemainingNotifier.value)} remaining',
            ),
            const VGapMd(),
            if (widget.lockConfig.isLockModeEnabled) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.screen_lock_portrait_rounded,
                      size: 15,
                      color: Color(0xFFDC2626),
                    ),
                    HGapSm(),
                    Expanded(
                      child: Text(
                        'Lock Mode active: device is locked & navigation pinned.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
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

  void _openTopicsReadModeSheet() {
    final total = _totalTopicsCount;
    final completed = _completedTopicsCount;

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
                backgroundColor: AppTheme.pastelIndigo(sheetCtx),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              title: 'Session Topics',
              subtitle: '${widget.moduleTitle.isNotEmpty ? widget.moduleTitle : widget.title} • $completed of $total completed',
            ),
            const VGapMd(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.52,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: total,
                separatorBuilder: (_, _) => const VGapXs(),
                itemBuilder: (ctx, index) {
                  final isCurrent = index == _currentTopicIndex;
                  final isDone = _isTopicCompletedAt(index);
                  final title = _getTopicTitleAt(index);

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        if (index != _currentTopicIndex) {
                          _switchToTopic(index);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.pastelIndigo(sheetCtx)
                              : (isDone
                                  ? AppTheme.pastelGreen(sheetCtx).withValues(alpha: 0.35)
                                  : AppTheme.surfaceVariant(sheetCtx).withValues(alpha: 0.45)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent
                                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                : (isDone
                                    ? AppTheme.pastelGreenBorder(sheetCtx)
                                    : AppTheme.borderColor(sheetCtx)),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCurrent
                                    ? AppTheme.primaryColor
                                    : (isDone
                                        ? AppTheme.pastelGreenText(sheetCtx)
                                        : AppTheme.surfaceVariant(sheetCtx)),
                              ),
                              alignment: Alignment.center,
                              child: isDone
                                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrent
                                            ? Colors.white
                                            : AppTheme.textSecondaryColor(sheetCtx),
                                      ),
                                    ),
                            ),
                            const HGapSm(),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isDone
                                      ? AppTheme.textSecondaryColor(sheetCtx)
                                      : AppTheme.textPrimaryColor(sheetCtx),
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  decorationColor: AppTheme.textMutedColor(sheetCtx),
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const VGapMd(),
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
        // Minimize Button to send to background and show custom notification
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 26,
          ),
          color: widget.lockConfig.isLockModeEnabled
              ? const Color(0xFFDC2626)
              : AppTheme.textSecondaryColor(context),
          tooltip: 'Minimize Session',
          visualDensity: VisualDensity.compact,
          onPressed: _minimizeSession,
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
            if (widget.lockConfig.isLockModeEnabled) ...[
              const HGapSm(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppTheme.pastelIndigo(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: AppTheme.primaryColor,
                    ),
                    HGapXs(),
                    Text(
                      'Lock',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        // Gear Options Button
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: widget.lockConfig.isLockModeEnabled
                ? const Color(0xFFDC2626)
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
    }
  }

  Widget _buildCircularTimer(BuildContext context, int completed, int total) {
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
              // Total countdown duration placed above running timer
              Text(
                _formatTime(_totalSeconds),
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const VGapXs(),
              // Running countdown timer
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
              // 0/1 topics counter placed where total countdown duration was
              Text(
                '$completed / $total topics',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const VGapXs(),
              // Pause / Play icon below 0/1
              ValueListenableBuilder<bool>(
                valueListenable: _isRunningNotifier,
                builder: (context, isRunning, _) {
                  final canPause = _canPause;
                  return Icon(
                    !canPause
                        ? Icons.lock_outline_rounded
                        : (isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    size: 20,
                    color: !canPause
                        ? (_isLockModeActive
                            ? const Color(0xFFDC2626)
                            : AppTheme.textMutedColor(context))
                        : AppTheme.textSecondaryColor(context),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTopicCard(BuildContext context) {
    return GestureDetector(
      onTap: _openTopicsReadModeSheet,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
              // Topic title with ^ icon at end
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${_currentTopicIndex + 1}. $_currentTopicTitle',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                  ),
                  const HGapXs(),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 19,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final total = _totalTopicsCount;
    final completed = _completedTopicsCount;
    final allDone = _isCurrentTopicCompleted && completed >= total;
    final isAlreadyDone = _isCurrentTopicCompleted && !allDone;
    final remainingTopics = total - completed;

    final VoidCallback onNextAndSave = allDone
        ? () {
            _sessionTimer?.cancel();
            _isRunningNotifier.value = false;
            Navigator.of(context).pop<Map<String, dynamic>>({
              'allCompleted': true,
              'isRevision': widget.isRevision,
              'moduleId': widget.moduleId,
              'revisionId': widget.revisionId,
            });
          }
        : (isAlreadyDone ? _advanceToNextTopic : _handleDoneAndNext);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Left: End Session Control (replacing Pause)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: widget.lockConfig.isLockModeEnabled
                  ? _handleEmergencyLockExit
                  : _handleExitSession,
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

        // Right: Next and Save Control (replacing End)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onNextAndSave,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: allDone
                      ? AppTheme.pastelGreen(context)
                      : AppTheme.surface(context),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: allDone
                        ? AppTheme.pastelGreenBorder(context)
                        : AppTheme.primaryColor.withValues(alpha: 0.35),
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
                  allDone
                      ? Icons.check_circle_rounded
                      : (isAlreadyDone ? Icons.arrow_forward_rounded : Icons.check_rounded),
                  size: 21,
                  color: allDone ? AppTheme.pastelGreenText(context) : AppTheme.primaryColor,
                ),
              ),
            ),
            const VGapXs(),
            Text(
              allDone
                  ? 'All Done'
                  : (isAlreadyDone
                      ? 'Next Topic'
                      : (remainingTopics <= 1 ? 'Save' : 'Next & Save')),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: allDone
                    ? AppTheme.pastelGreenText(context)
                    : AppTheme.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
