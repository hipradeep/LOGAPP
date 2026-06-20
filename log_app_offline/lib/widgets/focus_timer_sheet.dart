import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/note_service.dart';
import 'app_spacers.dart';
import 'app_toast.dart';

class FocusTimerSheet extends StatefulWidget {
  const FocusTimerSheet({super.key});

  @override
  State<FocusTimerSheet> createState() => _FocusTimerSheetState();
}

class _FocusTimerSheetState extends State<FocusTimerSheet> {
  final NoteService _noteService = NoteService();
  final TextEditingController _topicController = TextEditingController(text: 'Focus Session');
  Timer? _sessionTimer;
  final int _totalSeconds = 25 * 60;
  int _secondsRemaining = 25 * 60;
  bool _isRunning = false;
  bool _isCompleted = false;

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _topicController.dispose();
    super.dispose();
  }

  String _formatTime(int secs) {
    final minutes = (secs / 60).floor();
    final seconds = secs % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRunning = false;
          _isCompleted = true;
        });
        
        // Log focus session in note
        final topic = _topicController.text.trim();
        _noteService.createEntry(
          'Completed Focus Session',
          'Successfully completed a 25-minute focus session on "$topic".',
          '🎯',
          ['FocusSession', topic],
        ).then((_) {
          if (mounted) {
            AppToast.show(
              context: context,
              message: 'Focus session completed! Logged 🎯',
              backgroundColor: AppTheme.successColor,
            );
          }
        });
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _sessionTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _sessionTimer?.cancel();
    setState(() {
      _secondsRemaining = _totalSeconds;
      _isRunning = false;
      _isCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _sessionTimer?.cancel();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.borderColor(context), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const VGapMd(),
              Text('Productivity Focus Timer ⏱️', style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold)),
              const VGapMd(),
              if (!_isRunning && _secondsRemaining == _totalSeconds && !_isCompleted) ...[
                Text('What are you focusing on?', style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                const VGapSm(),
                TextField(
                  controller: _topicController,
                  style: AppTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Study Chemistry, Workout',
                  ),
                ),
                const VGapLg(),
              ] else ...[
                Text(
                  _topicController.text.isNotEmpty ? _topicController.text : 'Focus Session',
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryAccentColor(context)),
                ),
                const VGapSm(),
              ],
              
              // Progress Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: _isCompleted ? 1.0 : (_totalSeconds - _secondsRemaining) / _totalSeconds,
                      strokeWidth: 10,
                      backgroundColor: AppTheme.subtleFillColor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
                  Text(
                    _formatTime(_secondsRemaining),
                    style: AppTheme.headingLarge.copyWith(fontSize: 32),
                  ),
                ],
              ),
              const VGapLg(),
              
              // Timer Controls
              if (_isCompleted) ...[
                const Text('Session Completed! Great Job! 🎉', style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                const VGapMd(),
                SizedBox(
                  width: double.infinity,
                  height: AppTheme.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Finish'),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_secondsRemaining < _totalSeconds)
                      ElevatedButton(
                        onPressed: _resetTimer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.subtleFillColor(context),
                          foregroundColor: AppTheme.textPrimaryColor(context),
                          minimumSize: const Size(100, 48),
                        ),
                        child: const Text('Reset'),
                      ),
                    ElevatedButton(
                      onPressed: _isRunning ? _pauseTimer : _startTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? AppTheme.warningColor : AppTheme.primaryColor,
                        minimumSize: const Size(120, 48),
                      ),
                      child: Text(_isRunning ? 'Pause' : 'Start'),
                    ),
                  ],
                ),
                const VGapMd(),
                TextButton(
                  onPressed: () {
                    _sessionTimer?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel Session', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
