import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import 'phone_lock_settings_sheet.dart';

/// Immersive Full-Screen Phone Lock Screen (Zen Mode)
///
/// Features:
/// - Adopts Session Timer visual design (circular progress ring, breadcrumbs, current topic)
/// - Edge-to-edge immersive lock screen (SystemUiMode.immersiveSticky)
/// - Grace period cancellation window (e.g. 10s countdown to abort before lock engages)
/// - Live circular lock countdown clock matching SessionTimerScreen
/// - Top-right emergency exit button protected by 3-second hold verification
/// - Emergency dialer / ICE trigger shortcut
/// - Anti-back navigation protection (PopScope blocks hardware and gesture back)
class TimedLockOverlayScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? breadcrumbs;
  final int currentTopicIndex;
  final String currentTopicTitle;
  final int completedTopicsCount;
  final int totalTopicsCount;
  final int durationSeconds;
  final ValueNotifier<int> secondsRemainingNotifier;
  final PhoneLockConfig lockConfig;
  final VoidCallback onEmergencyExit;
  final VoidCallback onSessionComplete;

  const TimedLockOverlayScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.breadcrumbs,
    this.currentTopicIndex = 0,
    this.currentTopicTitle = '',
    this.completedTopicsCount = 0,
    this.totalTopicsCount = 1,
    required this.durationSeconds,
    required this.secondsRemainingNotifier,
    required this.lockConfig,
    required this.onEmergencyExit,
    required this.onSessionComplete,
  });

  @override
  State<TimedLockOverlayScreen> createState() => _TimedLockOverlayScreenState();
}

class _TimedLockOverlayScreenState extends State<TimedLockOverlayScreen> {
  late int _graceRemaining;
  Timer? _graceTimer;
  bool _gracePeriodActive = false;

  @override
  void initState() {
    super.initState();

    // Enable sticky immersive mode (hides system navigation and status bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Engage native Kotlin Zen lock mode (Lock Task pinning if enabled, keep screen on, onUserLeaveHint protection)
    const MethodChannel('com.logapp.studylog/share').invokeMethod('startNativeLockMode', {
      'enablePinning': widget.lockConfig.enableScreenPinning,
    });

    _graceRemaining = widget.lockConfig.gracePeriodSeconds;
    if (_graceRemaining > 0) {
      _gracePeriodActive = true;
      _graceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_graceRemaining > 1) {
          setState(() {
            _graceRemaining--;
          });
        } else {
          timer.cancel();
          setState(() {
            _graceRemaining = 0;
            _gracePeriodActive = false;
          });
          HapticFeedback.heavyImpact();
        }
      });
    }

    widget.secondsRemainingNotifier.addListener(_checkCompletion);
  }

  void _checkCompletion() {
    if (widget.secondsRemainingNotifier.value <= 0) {
      widget.onSessionComplete();
    }
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    widget.secondsRemainingNotifier.removeListener(_checkCompletion);
    // Release native Kotlin lock mode
    const MethodChannel('com.logapp.studylog/share').invokeMethod('stopNativeLockMode');
    // Restore normal system UI overlays
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatClock(int totalSecs) {
    final m = (totalSecs / 60).floor();
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmEmergencyExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _HoldToExitDialog(
        onConfirmed: () {
          Navigator.of(ctx).pop(true);
        },
      ),
    );

    if (confirmed == true && mounted) {
      widget.onEmergencyExit();
    }
  }

  void _openEmergencyDialer() {
    try {
      const MethodChannel('com.logapp.studylog/share').invokeMethod('openUrl', {
        'url': 'tel:112',
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppTheme.background(context);
    final textPrimary = AppTheme.textPrimaryColor(context);
    final textSecondary = AppTheme.textSecondaryColor(context);
    final textMuted = AppTheme.textMutedColor(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Silently consume back button press in lock mode with zero alerts or snackbars
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Layer 1: Center Circular Timer (Matching Session Screen)
              Positioned.fill(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -45),
                    child: ValueListenableBuilder<int>(
                      valueListenable: widget.secondsRemainingNotifier,
                      builder: (context, secondsRemaining, _) {
                        final double progress = widget.durationSeconds > 0
                            ? (widget.durationSeconds - secondsRemaining) / widget.durationSeconds
                            : 0.0;
                        return SizedBox(
                          width: 195,
                          height: 195,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 195,
                                height: 195,
                                child: CircularProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  strokeWidth: 4.0,
                                  backgroundColor: AppTheme.borderColor(context),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatClock(widget.durationSeconds),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const VGapXs(),
                                  Text(
                                    _formatClock(secondsRemaining),
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                      letterSpacing: -0.5,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const VGapXs(),
                                  Text(
                                    '${widget.completedTopicsCount} / ${widget.totalTopicsCount} topics',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const VGapXs(),
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 20,
                                    color: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Layer 2: Top Header Layer (Lock Badge, Title, Exit Icon, Breadcrumbs, Current Topic)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left spacer to optically center the title against the right exit button
                        const SizedBox(width: 48, height: 48),

                        // Title with [icon] Lock on right side
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
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
                        ),

                        // Exit button icon
                        IconButton(
                          icon: Icon(
                            Icons.exit_to_app_rounded,
                            color: textSecondary,
                            size: 22,
                          ),
                          tooltip: 'Exit Lock Mode',
                          onPressed: _confirmEmergencyExit,
                        ),
                      ],
                    ),

                    if (widget.breadcrumbs != null && widget.breadcrumbs!.isNotEmpty) ...[
                      const VGapXs(),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            widget.breadcrumbs!,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const VGapSm(),

                    // Current Topic Card (Locked view)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Topic',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const VGapXs(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.currentTopicTitle.isNotEmpty
                                      ? '${widget.currentTopicIndex + 1}. ${widget.currentTopicTitle}'
                                      : widget.subtitle,
                                  softWrap: true,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const HGapXs(),
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 17,
                                color: textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Layer 3: Bottom Area (Grace Period, Emergency Call, Lock Status Info)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grace period notice banner if active
                    if (_gracePeriodActive) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.warningColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: AppTheme.warningColor,
                            ),
                            const HGapSm(),
                            Text(
                              'Grace Period: ${_graceRemaining}s to cancel',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.warningColor,
                              ),
                            ),
                            const HGapSm(),
                            GestureDetector(
                              onTap: widget.onEmergencyExit,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Abort',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (widget.lockConfig.showEmergencyBypass) ...[
                      TextButton.icon(
                        onPressed: _openEmergencyDialer,
                        icon: Icon(
                          Icons.emergency_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                        label: Text(
                          'Emergency Call',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                      ),
                      const VGapXs(),
                    ],

                    Text(
                      'Phone is locked until session timer ends',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      'Timed Lock prevents distractions during your study session',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: textMuted,
                      ),
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

/// Professional Hold-to-Exit verification dialog.
/// Requires the user to hold down the button for 3 seconds with a radial progress ring.
class _HoldToExitDialog extends StatefulWidget {
  final VoidCallback onConfirmed;

  const _HoldToExitDialog({required this.onConfirmed});

  @override
  State<_HoldToExitDialog> createState() => _HoldToExitDialogState();
}

class _HoldToExitDialogState extends State<_HoldToExitDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onConfirmed();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _onHoldStart(TapDownDetails _) {
    HapticFeedback.selectionClick();
    _holdController.forward();
  }

  void _onHoldEnd([dynamic _]) {
    if (_holdController.status != AnimationStatus.completed) {
      _holdController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = AppTheme.surface(context);
    final surfaceVariant = AppTheme.surfaceVariant(context);
    final borderColor = AppTheme.borderColor(context);
    final textPrimary = AppTheme.textPrimaryColor(context);
    final textSecondary = AppTheme.textSecondaryColor(context);

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: borderColor,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: AppTheme.errorColor,
                size: 24,
              ),
            ),
            const VGapMd(),
            Text(
              'Exit Lock Mode?',
              style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const VGapXs(),
            Text(
              'Lock Mode protects your focus discipline. To prevent impulsive unlocks, press and hold the button below for 3 seconds to exit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const VGapLg(),

            // Hold-to-exit button with progress fill and spinner
            AnimatedBuilder(
              animation: _holdController,
              builder: (context, _) {
                final progress = _holdController.value;
                return GestureDetector(
                  onTapDown: _onHoldStart,
                  onTapUp: _onHoldEnd,
                  onTapCancel: _onHoldEnd,
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: progress > 0
                            ? AppTheme.errorColor
                            : borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Single clean progress fill across the button
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Button Text & Icon (Text uses textPrimary for 100% theme contrast)
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.touch_app_rounded,
                                size: 18,
                                color: AppTheme.errorColor,
                              ),
                              const HGapSm(),
                              Text(
                                progress > 0
                                    ? 'Holding... (${(3 - (progress * 3)).toStringAsFixed(1)}s)'
                                    : 'Hold 3s to Unlock',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const VGapMd(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel & Keep Studying',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
