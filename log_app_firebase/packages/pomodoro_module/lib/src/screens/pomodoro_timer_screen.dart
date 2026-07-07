import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_services/core_services.dart';
import 'package:get_it/get_it.dart';
import '../services/pomodoro_manager.dart';


enum _Phase { countdown, focus }

class PomodoroTimerScreen extends StatefulWidget {
  static final ValueNotifier<bool> isTimerScreenActive = ValueNotifier<bool>(false);

  final Activity activity;
  final List<Activity> remainingQueue;
  final int? initialDurationMinutes;
  final int? initialSecondsRemaining;
  final bool? initialIsRunning;
  final Task? initialMilestoneTask;
  final bool trackSession;
  final bool followUpNext;
  final bool allowPause;
  final bool allowReset;
  final List<String>? focusedSubTaskIds;
  final bool isRestrictMode;

  const PomodoroTimerScreen({
    super.key,
    required this.activity,
    required this.remainingQueue,
    this.initialDurationMinutes,
    this.initialSecondsRemaining,
    this.initialIsRunning,
    this.initialMilestoneTask,
    this.trackSession = true,
    this.followUpNext = true,
    this.allowPause = true,
    this.allowReset = true,
    this.focusedSubTaskIds,
    this.isRestrictMode = true,
  });

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> {


  // ── Phase state ─────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.countdown;

  // ── Setup options ───────────────────────────────────────────────────────────
  bool _trackSession = true;
  bool _followUpNext = true;

  // ── Milestone Tasks for Countdown ───────────────────────────────────────────
  Task? _milestoneTask;
  List<String>? _focusedSubTaskIds;

  // ── Countdown ───────────────────────────────────────────────────────────────
  late final ValueNotifier<int> _countdownNotifier;
  Timer? _countdownTimer;

  late final int _totalSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PomodoroTimerScreen.isTimerScreenActive.value = true;
    });
    
    final manager = PomodoroManager.instance;
    final bool hasActiveSession = manager.activity != null;

    if (hasActiveSession) {
      _phase = _Phase.focus;
      _trackSession = manager.trackSession;
      _followUpNext = manager.followUpNext;
      _focusedSubTaskIds = manager.focusedSubTaskIds;
      _milestoneTask = manager.milestoneTask;
      _totalSeconds = manager.totalSeconds;
    } else {
      final durationMins = widget.initialDurationMinutes ?? widget.activity.focusDuration;
      _totalSeconds = durationMins * 60;
      _trackSession = widget.trackSession;
      _followUpNext = widget.followUpNext;
      _focusedSubTaskIds = widget.focusedSubTaskIds;
      _milestoneTask = widget.initialMilestoneTask;
      
      manager.init(
        activity: widget.activity,
        remainingQueue: widget.remainingQueue,
        totalSeconds: _totalSeconds,
        trackSession: _trackSession,
        followUpNext: _followUpNext,
        allowPause: widget.allowPause,
        isRestrictMode: widget.isRestrictMode,
        focusedSubTaskIds: _focusedSubTaskIds,
        milestoneTask: _milestoneTask,
        initialSecondsRemaining: widget.initialSecondsRemaining,
        initialIsRunning: widget.initialIsRunning ?? false,
      );
    }

    _countdownNotifier = ValueNotifier<int>(6);

    if (_milestoneTask == null) {
      if (widget.activity.trackingType == 'milestone') {
        GetIt.instance<ActivityService>().getActiveTaskForActivity(widget.activity.id).then((task) {
          if (mounted) {
            setState(() {
              _milestoneTask = task;
              if (!hasActiveSession) {
                manager.milestoneTask = task;
              }
            });
          }
        }).catchError((e) {
          debugPrint('Error fetching milestone task details in PomodoroTimerScreen: $e');
        });
      } else if (widget.activity.trackingType == 'multiple') {
        GetIt.instance<ActivityService>().getOrCreateTodayTaskForRoutine(widget.activity).then((task) {
          if (mounted) {
            setState(() {
              _milestoneTask = task;
              if (!hasActiveSession) {
                manager.milestoneTask = task;
              }
            });
          }
        }).catchError((e) {
          debugPrint('Error fetching/creating routine task details in PomodoroTimerScreen: $e');
        });
      }
    }

    manager.isRunningNotifier.addListener(_onManagerStatusChanged);
    manager.isCompletedNotifier.addListener(_onManagerStatusChanged);

    if (hasActiveSession) {
      // Already running globally
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await FlutterLocalNotificationsPlugin()
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        _startCountdown();
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownNotifier.dispose();
    final manager = PomodoroManager.instance;
    manager.isRunningNotifier.removeListener(_onManagerStatusChanged);
    manager.isCompletedNotifier.removeListener(_onManagerStatusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PomodoroTimerScreen.isTimerScreenActive.value = false;
    });
    super.dispose();
  }

  void _onManagerStatusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startCountdown({bool reset = true}) {
    setState(() {
      _phase = _Phase.countdown;
    });
    if (reset) {
      _countdownNotifier.value = 6;
    }
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdownNotifier.value > 1) {
        _countdownNotifier.value--;
      } else {
        t.cancel();
        _beginFocus();
      }
    });
  }

  void _beginFocus() {
    setState(() => _phase = _Phase.focus);
    PomodoroManager.instance.startFocusTimer();
  }

  void _handleReset() {
    PomodoroManager.instance.resetTimer();
  }

  void _handleNextActivity() {
    _countdownTimer?.cancel();
    PomodoroManager.instance.cancelTimer();
    if (_followUpNext && widget.remainingQueue.isNotEmpty) {
      final next = widget.remainingQueue.first;
      final nextQueue = widget.remainingQueue.sublist(1);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PomodoroTimerScreen(
            activity: next,
            remainingQueue: nextQueue,
            isRestrictMode: widget.isRestrictMode,
            allowPause: widget.allowPause,
            allowReset: widget.allowReset,
          ),
        ),
      );
    } else {
      AppToast.show(
        context: context,
        message: 'All Pomodoro sessions completed! 🎉',
        backgroundColor: AppTheme.successColor,
      );
      Navigator.pop(context);
    }
  }

  void _handleCancelSession() {
    _countdownTimer?.cancel();
    PomodoroManager.instance.cancelTimer();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final manager = PomodoroManager.instance;

    return PopScope(
      canPop: !widget.isRestrictMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // If backed out, active session keeps running in background
          return;
        }
        _countdownTimer?.cancel();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        child: switch (_phase) {
          _Phase.countdown => _CountdownScreen(
              key: const ValueKey('countdown'),
              countdownNotifier: _countdownNotifier,
              activityName: widget.activity.name,
              durationMinutes: _totalSeconds ~/ 60,
              onCancel: _handleCancelSession,
            ),
          _Phase.focus => _FocusScreen(
              key: const ValueKey('focus'),
              activity: widget.activity,
              totalSeconds: _totalSeconds,
              secondsRemainingNotifier: manager.secondsNotifier,
              isRunning: manager.isRunningNotifier.value,
              isCompleted: manager.isCompletedNotifier.value,
              hasMore: widget.remainingQueue.isNotEmpty,
              onStart: manager.startFocusTimer,
              onPause: manager.pauseTimer,
              onReset: _handleReset,
              onNext: _handleNextActivity,
              onCancel: _handleCancelSession,
              allowPause: widget.allowPause,
              allowReset: widget.allowReset,
              focusedSubTaskIds: _focusedSubTaskIds,
              milestoneTask: _milestoneTask,
              isRestrictMode: widget.isRestrictMode,
              nextActivity: widget.remainingQueue.isNotEmpty
                  ? widget.remainingQueue.first
                  : null,
            ),
        },
      ),
    );
  }
}

// 
// 
class _CountdownScreen extends StatelessWidget {
  final ValueNotifier<int> countdownNotifier;
  final String activityName;
  final int durationMinutes;
  final VoidCallback onCancel;

  const _CountdownScreen({
    super.key,
    required this.countdownNotifier,
    required this.activityName,
    required this.durationMinutes,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.resolvedBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                _CountdownHeader(onCancel: onCancel),
                const Spacer(),
                Text(
                  activityName,
                  style: TextStyle(
                    fontSize: 32,
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapXs(),
                Text(
                  '$durationMinutes min',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const VGapLg(),
                _CountdownIndicator(countdownNotifier: countdownNotifier),
                const Spacer(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownHeader extends StatelessWidget {
  final VoidCallback onCancel;
  const _CountdownHeader({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: onCancel,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimaryColor(context),
                  size: 16,
                ),
              ),
            ),
          ),
          Text(
            'Ready?',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownIndicator extends StatelessWidget {
  final ValueNotifier<int> countdownNotifier;
  const _CountdownIndicator({required this.countdownNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: countdownNotifier,
      builder: (context, count, _) {
        final double progress = count / 6.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 3,
                backgroundColor: AppTheme.borderColor(context),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccentColor(context)),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                count > 1 ? '$count' : 'Go!',
                key: ValueKey(count),
                style: TextStyle(
                  fontSize: count > 1 ? 84 : 64,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Focus Screen (existing timer UI0
class _FocusScreen extends StatefulWidget {
  final Activity activity;
  final int totalSeconds;
  final ValueNotifier<int> secondsRemainingNotifier;
  final bool isRunning;
  final bool isCompleted;
  final bool hasMore;
  final Activity? nextActivity;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final bool allowPause;
  final bool allowReset;
  final List<String>? focusedSubTaskIds;
  final Task? milestoneTask;
  final bool isRestrictMode;

  const _FocusScreen({
    super.key,
    required this.activity,
    required this.totalSeconds,
    required this.secondsRemainingNotifier,
    required this.isRunning,
    required this.isCompleted,
    required this.hasMore,
    required this.nextActivity,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onNext,
    required this.onCancel,
    required this.allowPause,
    this.allowReset = true,
    this.focusedSubTaskIds,
    this.milestoneTask,
    required this.isRestrictMode,
  });

  @override
  State<_FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<_FocusScreen> {
  bool _showCancel = false;
  Timer? _cancelHideTimer;

  @override
  void dispose() {
    _cancelHideTimer?.cancel();
    super.dispose();
  }

  void _onExitTapped() {
    _cancelHideTimer?.cancel();
    setState(() {
      _showCancel = !_showCancel;
    });

    if (_showCancel) {
      _cancelHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showCancel = false;
          });
        }
      });
    }
  }

  void _handleCircleTapped() {
    if (widget.isCompleted) return;
    if (widget.isRunning) {
      if (widget.allowPause) {
        widget.onPause();
      } else {
        AppToast.show(
          context: context,
          message: 'Pausing is disabled for this session',
        );
      }
    } else {
      widget.onStart();
    }
  }

  void _handleReset() {
    _cancelHideTimer?.cancel();
    setState(() {
      _showCancel = false;
    });
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSubTasks = widget.milestoneTask?.subTasks
            .where((st) => widget.focusedSubTaskIds?.contains(st.id) ?? false)
            .toList() ?? [];

    SubTask? currentSubTask;
    List<SubTask> remainingSubTasks = [];

    if (selectedSubTasks.isNotEmpty) {
      int currentIndex = selectedSubTasks.indexWhere((st) => !st.checked);
      if (currentIndex == -1) {
        currentIndex = 0;
      }
      currentSubTask = selectedSubTasks[currentIndex];
      remainingSubTasks = List<SubTask>.from(selectedSubTasks)..removeAt(currentIndex);
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppTheme.resolvedBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                if (!widget.isCompleted)
                  _FocusHeader(
                    onBackTapped: _onExitTapped,
                  )
                else
                  const SizedBox(height: 32),
                
                const VGapMd(),
                
                Text(
                  widget.activity.name,
                  style: TextStyle(
                    fontSize: 32,
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentSubTask != null) ...[
                  const VGapSm(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const HGapXs(),
                      Text(
                        currentSubTask.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
                
                const Spacer(),

                _FocusTimerIndicator(
                  totalSeconds: widget.totalSeconds,
                  secondsRemainingNotifier: widget.secondsRemainingNotifier,
                  isRunning: widget.isRunning,
                  isCompleted: widget.isCompleted,
                  allowPause: widget.allowPause,
                  onTap: _handleCircleTapped,
                ),
                if (remainingSubTasks.isNotEmpty) ...[
                  const VGapMd(),
                  _RemainingTasksDropdown(remainingTasks: remainingSubTasks),
                ],

                const Spacer(),

                _FocusControls(
                  isCompleted: widget.isCompleted,
                  hasMore: widget.hasMore,
                  showCancel: _showCancel,
                  allowReset: widget.allowReset,
                  onNext: widget.onNext,
                  onCancel: widget.onCancel,
                  onReset: _handleReset,
                ),

                const VGapMd(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusHeader extends StatelessWidget {
  final VoidCallback onBackTapped;

  const _FocusHeader({
    required this.onBackTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: onBackTapped,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimaryColor(context),
              size: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _FocusTimerIndicator extends StatelessWidget {
  final int totalSeconds;
  final ValueNotifier<int> secondsRemainingNotifier;
  final bool isRunning;
  final bool isCompleted;
  final bool allowPause;
  final VoidCallback onTap;

  const _FocusTimerIndicator({
    required this.totalSeconds,
    required this.secondsRemainingNotifier,
    required this.isRunning,
    required this.isCompleted,
    required this.allowPause,
    required this.onTap,
  });

  String _formatTime(int secs) {
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).floor();
    final s = secs % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    } else {
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: secondsRemainingNotifier,
            builder: (context, seconds, _) {
              final double progress = (totalSeconds - seconds) / totalSeconds;
              return SizedBox(
                width: 250,
                height: 250,
                child: CircularProgressIndicator(
                  value: isCompleted ? 1.0 : progress,
                  strokeWidth: 3,
                  backgroundColor: AppTheme.borderColor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccentColor(context)),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCompleted ? 'Finished' : 'Time remaining',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
              const VGapSm(),
              ValueListenableBuilder<int>(
                valueListenable: secondsRemainingNotifier,
                builder: (context, seconds, _) {
                  return Text(
                    _formatTime(seconds),
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                      letterSpacing: 0.5,
                    ),
                  );
                },
              ),
              if (!isCompleted) ...[
                const VGapXs(),
                Icon(
                  isRunning
                      ? (allowPause ? Icons.pause_rounded : Icons.lock_outline_rounded)
                      : Icons.play_arrow_rounded,
                  color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FocusControls extends StatelessWidget {
  final bool isCompleted;
  final bool hasMore;
  final bool showCancel;
  final bool allowReset;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final VoidCallback onReset;

  const _FocusControls({
    required this.isCompleted,
    required this.hasMore,
    required this.showCancel,
    this.allowReset = true,
    required this.onNext,
    required this.onCancel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompleted) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Session Completed! Ã°Å¸Å½â€°',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const VGapMd(),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 2,
              ),
              child: Text(
                hasMore ? 'Next Activity' : 'Finish Flow',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      );
    } else {
      return AnimatedOpacity(
        opacity: showCancel ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: !showCancel,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor.withValues(alpha: 0.12),
                      foregroundColor: AppTheme.errorColor,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      side: const BorderSide(
                        color: AppTheme.errorColor,
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              if (allowReset) ...[ 
                const HGapSm(),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onReset,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface(context).withValues(alpha: AppTheme.isDarkMode(context) ? 0.12 : 0.8),
                        foregroundColor: AppTheme.textPrimaryColor(context),
                        elevation: 0,
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: AppTheme.borderColor(context),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}

class _RemainingTasksDropdown extends StatelessWidget {
  final List<SubTask> remainingTasks;
  const _RemainingTasksDropdown({required this.remainingTasks});

  @override
  Widget build(BuildContext context) {
    if (remainingTasks.isEmpty) return const SizedBox.shrink();

    final nextTask = remainingTasks.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Upcoming Task',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.6),
          ),
        ),
        const VGapXs(),
        PopupMenuButton<String>(
          tooltip: 'Remaining Tasks',
          offset: const Offset(0, 40),
          color: AppTheme.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.borderColor(context), width: 1),
          ),
          onSelected: (_) {}, // read-only
          itemBuilder: (context) {
            return remainingTasks.map((st) {
              return PopupMenuItem<String>(
                value: st.id,
                child: Text(
                  st.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor(context).withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextTask.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const HGapXs(),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondaryColor(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


