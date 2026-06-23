import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../theme/app_theme.dart';

import '../widgets/app_spacers.dart';
import '../widgets/app_toast.dart';
import '../models/activity.dart';
import '../services/note_service.dart';
import '../services/service_locator.dart';
import '../services/notification_service.dart';
import '../services/cache_service.dart';


// ─── Phase enum ───────────────────────────────────────────────────────────────
enum _Phase { countdown, focus }

class PomodoroTimerScreen extends StatefulWidget {
  static bool isTimerScreenActive = false;

  final Activity activity;
  final List<Activity> remainingQueue;
  final int? initialDurationMinutes;
  final int? initialSecondsRemaining;
  final bool? initialIsRunning;

  const PomodoroTimerScreen({
    super.key,
    required this.activity,
    required this.remainingQueue,
    this.initialDurationMinutes,
    this.initialSecondsRemaining,
    this.initialIsRunning,
  });

  @override
  State<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends State<PomodoroTimerScreen> with WidgetsBindingObserver {
  final NoteService _noteService = getIt<NoteService>();

  // ── Phase state ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.countdown;

  // ── Setup options ─────────────────────────────────────────────────────────
  bool _trackSession = true;
  bool _followUpNext = true;

  // ── Countdown ────────────────────────────────────────────────────────────
  int _countdown = 6;
  Timer? _countdownTimer;

  // ── Focus timer ──────────────────────────────────────────────────────────
  Timer? _sessionTimer;
  late final int _totalSeconds;
  int _secondsRemaining = 0;
  bool _isRunning = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    PomodoroTimerScreen.isTimerScreenActive = true;
    WidgetsBinding.instance.addObserver(this);
    final durationMins =
        widget.initialDurationMinutes ?? widget.activity.focusDuration;
    _totalSeconds = durationMins * 60;
    _secondsRemaining = widget.initialSecondsRemaining ?? _totalSeconds;
    
    if (widget.initialSecondsRemaining != null) {
      _phase = _Phase.focus;
      final startRunning = widget.initialIsRunning ?? true;
      if (startRunning) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startFocusTimer();
        });
      } else {
        _isRunning = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _saveSessionToCache();
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await NotificationService.requestPermissions();
        _startCountdown();
      });
    }
  }

  @override
  void dispose() {
    PomodoroTimerScreen.isTimerScreenActive = false;
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    _cancelBackgroundNotifications();
    super.dispose();
  }

  // ── Countdown → Focus ────────────────────────────────────────────────────
  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 6;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        t.cancel();
        _beginFocus();
      }
    });
  }

  void _beginFocus() {
    setState(() => _phase = _Phase.focus);
    _startFocusTimer();
  }

  // ── Focus timer ──────────────────────────────────────────────────────────
  void _saveSessionToCache() async {
    final endTimestamp = DateTime.now().millisecondsSinceEpoch + _secondsRemaining * 1000;
    final sessionData = {
      'activity': widget.activity.toJson(),
      'remainingQueue': widget.remainingQueue.map((a) => a.toJson()).toList(),
      'endTimestamp': endTimestamp,
      'initialDurationMinutes': widget.initialDurationMinutes,
      'trackSession': _trackSession,
      'followUpNext': _followUpNext,
      'isRunning': _isRunning,
      'secondsRemaining': _secondsRemaining,
    };
    await CacheService().saveActivePomodoroSession(sessionData);
  }

  // ── Focus timer ──────────────────────────────────────────────────────────
  void _startFocusTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _saveSessionToCache();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _handleSessionComplete();
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _sessionTimer?.cancel();
    _cancelBackgroundNotifications();
    setState(() => _isRunning = false);
    _saveSessionToCache();
  }

  void _resetTimer() {
    _sessionTimer?.cancel();
    _cancelBackgroundNotifications();
    setState(() {
      _secondsRemaining = _totalSeconds;
      _isRunning = false;
      _isCompleted = false;
    });
    CacheService().clearActivePomodoroSession();
  }

  void _handleSessionComplete() {
    _cancelBackgroundNotifications();
    setState(() {
      _isRunning = false;
      _isCompleted = true;
    });
    CacheService().clearActivePomodoroSession();
    if (!_trackSession) return;
    final minutes = _totalSeconds ~/ 60;
    _noteService
        .createEntry(
          'Completed Pomodoro Session',
          'Successfully completed a $minutes-minute Pomodoro focus session on "${widget.activity.name}".',
          widget.activity.symbolValue ?? '🎯',
          ['FocusSession', 'Pomodoro', widget.activity.name],
        )
        .then((_) {
      if (mounted) {
        AppToast.show(
          context: context,
          message: 'Session on "${widget.activity.name}" logged! 🎯',
          backgroundColor: AppTheme.successColor,
        );
      }
    });
  }

  void _handleNextActivity() {
    _sessionTimer?.cancel();
    _cancelBackgroundNotifications();
    CacheService().clearActivePomodoroSession();
    if (_followUpNext && widget.remainingQueue.isNotEmpty) {
      final next = widget.remainingQueue.first;
      final nextQueue = widget.remainingQueue.sublist(1);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PomodoroTimerScreen(
            activity: next,
            remainingQueue: nextQueue,
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
    _sessionTimer?.cancel();
    _cancelBackgroundNotifications();
    CacheService().clearActivePomodoroSession();
    Navigator.pop(context);
  }

  void _showBackgroundNotifications() async {
    if (!_isRunning || _secondsRemaining <= 0) return;

    final endTimestamp = DateTime.now().millisecondsSinceEpoch + _secondsRemaining * 1000;

    final androidDetails = AndroidNotificationDetails(
      'pomodoro_timer_channel_v3',
      'Pomodoro Active Timer',
      channelDescription: 'Real-time countdown for running Pomodoro sessions',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: true,
      when: endTimestamp,
      usesChronometer: true,
      chronometerCountDown: true,
      visibility: NotificationVisibility.public,
      icon: 'ic_timer',
      styleInformation: const MediaStyleInformation(),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'pause_pomodoro',
          'Pause',
          icon: DrawableResourceAndroidBitmap('ic_pause'),
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'cancel_pomodoro',
          'Cancel',
          icon: DrawableResourceAndroidBitmap('ic_cancel'),
          cancelNotification: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.show(
        8888,
        null,
        widget.activity.name,
        notificationDetails,
        payload: 'open_pomodoro',
      );

      // Schedule the one-shot completion notification at the exact completion time
      await NotificationService.scheduleOneShotNotification(
        id: 8889,
        title: 'Session Completed! 🎉',
        body: 'Successfully completed focus session on "${widget.activity.name}".',
        dateTime: DateTime.now().add(Duration(seconds: _secondsRemaining)),
        skipPermissionCheck: true,
      );
    } catch (e) {
      debugPrint('Error showing background notifications: $e');
    }
  }

  void _cancelBackgroundNotifications() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(8888);
      await flutterLocalNotificationsPlugin.cancel(8889);
    } catch (e) {
      debugPrint('Error cancelling background notifications: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_phase == _Phase.focus) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _showBackgroundNotifications();
      } else if (state == AppLifecycleState.resumed) {
        _cancelBackgroundNotifications();
        
        final activeSession = await CacheService().getActivePomodoroSession();
        if (activeSession != null) {
          final isRunning = activeSession['isRunning'] as bool? ?? false;
          final endTimestamp = activeSession['endTimestamp'] as int? ?? 0;
          final savedSeconds = activeSession['secondsRemaining'] as int? ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          setState(() {
            _isRunning = isRunning;
            if (_isRunning) {
              final remaining = ((endTimestamp - now) / 1000).round();
              _secondsRemaining = remaining;
              if (_secondsRemaining <= 0) {
                _secondsRemaining = 0;
                _isRunning = false;
                _sessionTimer?.cancel();
                _handleSessionComplete();
              } else {
                _sessionTimer?.cancel();
                _startFocusTimer();
              }
            } else {
              _secondsRemaining = savedSeconds;
              _sessionTimer?.cancel();
            }
          });
        } else {
          setState(() {
            _isRunning = false;
            _secondsRemaining = 0;
            _sessionTimer?.cancel();
          });
          if (mounted) {
            Navigator.pop(context);
          }
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _countdownTimer?.cancel();
        _sessionTimer?.cancel();
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
              count: _countdown,
              activityName: widget.activity.name,
              durationMinutes: _totalSeconds ~/ 60,
              hasQueue: widget.remainingQueue.isNotEmpty,
              trackSession: _trackSession,
              followUpNext: _followUpNext,
              onTrackSessionChanged: (v) => setState(() => _trackSession = v),
              onFollowUpNextChanged: (v) => setState(() => _followUpNext = v),
              onCancel: _handleCancelSession,
            ),
          _Phase.focus => _FocusScreen(
              key: const ValueKey('focus'),
              activity: widget.activity,
              totalSeconds: _totalSeconds,
              secondsRemaining: _secondsRemaining,
              isRunning: _isRunning,
              isCompleted: _isCompleted,
              hasMore: widget.remainingQueue.isNotEmpty,
              onStart: _startFocusTimer,
              onPause: _pauseTimer,
              onReset: _resetTimer,
              onNext: _handleNextActivity,
              onCancel: _handleCancelSession,
              nextActivity: widget.remainingQueue.isNotEmpty
                  ? widget.remainingQueue.first
                  : null,
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CountdownScreen extends StatelessWidget {
  final int count;
  final String activityName;
  final int durationMinutes;
  final bool hasQueue;
  final bool trackSession;
  final bool followUpNext;
  final ValueChanged<bool> onTrackSessionChanged;
  final ValueChanged<bool> onFollowUpNextChanged;
  final VoidCallback onCancel;

  const _CountdownScreen({
    super.key,
    required this.count,
    required this.activityName,
    required this.durationMinutes,
    required this.hasQueue,
    required this.trackSession,
    required this.followUpNext,
    required this.onTrackSessionChanged,
    required this.onFollowUpNextChanged,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = count / 6.0;
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
                // ── Top Bar (Back/Cancel button) ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
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
                  ],
                ),
                const VGapMd(),
                // ── Ready? label ───────────────────────────────────────────
                Text(
                  'Ready?',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const VGapSm(),
                // ── Activity Name ──────────────────────────────────────────
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
                // ── Duration ───────────────────────────────────────────────
                Text(
                  '$durationMinutes min',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const VGapLg(),

                // ── Checkboxes (above countdown circle) ─────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: trackSession,
                              onChanged: (v) => onTrackSessionChanged(v ?? false),
                              activeColor: AppTheme.primaryColor,
                              checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                              side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const HGapSm(),
                            GestureDetector(
                              onTap: () => onTrackSessionChanged(!trackSession),
                              child: Text(
                                'Track Session',
                                style: TextStyle(
                                  color: AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const VGapXs(),
                        Opacity(
                          opacity: hasQueue ? 1.0 : 0.5,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: followUpNext,
                                onChanged: hasQueue
                                    ? (v) => onFollowUpNextChanged(v ?? false)
                                    : null,
                                activeColor: AppTheme.primaryColor,
                                checkColor: AppTheme.isDarkMode(context) ? Colors.black : Colors.white,
                                side: BorderSide(color: AppTheme.textSecondaryColor(context), width: 1.5),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const HGapSm(),
                              GestureDetector(
                                onTap: hasQueue
                                    ? () => onFollowUpNextChanged(!followUpNext)
                                    : null,
                                child: Text(
                                  'Follow up next',
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // ── Circular countdown progress ────────────────────────────
                Stack(
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
                ),
                const Spacer(),
                // ── Cancel button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onCancel,
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
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Focus Screen (existing timer UI)
// ─────────────────────────────────────────────────────────────────────────────
class _FocusScreen extends StatefulWidget {
  final Activity activity;
  final int totalSeconds;
  final int secondsRemaining;
  final bool isRunning;
  final bool isCompleted;
  final bool hasMore;
  final Activity? nextActivity;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const _FocusScreen({
    super.key,
    required this.activity,
    required this.totalSeconds,
    required this.secondsRemaining,
    required this.isRunning,
    required this.isCompleted,
    required this.hasMore,
    required this.nextActivity,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onNext,
    required this.onCancel,
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
    final double progress = (widget.totalSeconds - widget.secondsRemaining) / widget.totalSeconds;
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
                // ── Top Bar (Back/Cancel button) ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (!widget.isCompleted)
                      GestureDetector(
                        onTap: _onExitTapped,
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
                      )
                    else
                      const SizedBox(height: 32),
                  ],
                ),
                const VGapMd(),
                
                // ── Activity Title ───────────────────────────────────────────
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
                
                const Spacer(),

                // ── Timer Circle ─────────────────────────────────────────────
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: widget.isCompleted ? 1.0 : progress,
                        strokeWidth: 3,
                        backgroundColor: AppTheme.borderColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryAccentColor(context)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isCompleted ? 'Finished' : 'Time remaining',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        const VGapSm(),
                        Text(
                          _formatTime(widget.secondsRemaining),
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryColor(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ── Controls & Actions ────────────────────────────────────────
                if (widget.isCompleted) ...[
                  Text(
                    'Session Completed! 🎉',
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
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.hasMore ? 'Next Activity' : 'Finish Flow',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ] else ...[
                  AnimatedOpacity(
                    opacity: _showCancel ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_showCancel,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: widget.onCancel,
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
                  ),
                ],

                const VGapMd(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
