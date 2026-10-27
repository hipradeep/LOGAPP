import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/sheet_action_widgets.dart';
import '../widgets/phone_lock_settings_sheet.dart';
import '../models/topic.dart';
import '../models/revision_topic.dart';
import 'session_timer_screen.dart';

enum LockPermissionChoice {
  cancel,
  onlyLock,
  pinAndLock,
}

/// Screen 2 & 7: Session Setup Screen
///
/// Prepares a focus session for studying or revising module topics.
/// Displays module metadata, session duration selector (default 15m),
/// start-with topic selector, multi-topic note, and a prominent Start Session button.
class SessionSetupScreen extends StatefulWidget {
  final String courseTitle;
  final String courseId;
  final String moduleTitle;
  final String moduleId;
  final List<Topic> topics;
  final List<RevisionTopic>? revisionTopics;
  final bool isRevision;
  final String? revisionId;

  const SessionSetupScreen({
    super.key,
    required this.courseTitle,
    required this.courseId,
    required this.moduleTitle,
    required this.moduleId,
    this.topics = const [],
    this.revisionTopics,
    this.isRevision = false,
    this.revisionId,
  });

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  int _selectedDurationMinutes = 15;
  int _selectedTopicIndex = -1; // -1 means "Next incomplete topic" / "Next topic in revision"

  // Session Preferences
  bool _trackSession = true;
  bool _allowPause = true;
  bool _allowReset = true;
  PhoneLockConfig _lockConfig = const PhoneLockConfig();

  @override
  void initState() {
    super.initState();
    // Default to the first incomplete topic index
    _selectedTopicIndex = _findNextIncompleteIndex();
  }

  int _findNextIncompleteIndex() {
    if (widget.isRevision && widget.revisionTopics != null) {
      for (int i = 0; i < widget.revisionTopics!.length; i++) {
        if (!widget.revisionTopics![i].isCompleted) return i;
      }
      return 0;
    } else {
      for (int i = 0; i < widget.topics.length; i++) {
        if (!widget.topics[i].isCompleted) return i;
      }
      return 0;
    }
  }

  String _getTopicTitleAtIndex(int index) {
    if (widget.isRevision && widget.revisionTopics != null) {
      if (index >= 0 && index < widget.revisionTopics!.length) {
        if (index < widget.topics.length && widget.topics[index].title.isNotEmpty) {
          return widget.topics[index].title;
        }
        final rt = widget.revisionTopics![index];
        final match = widget.topics.where((t) => t.id == rt.topicId).firstOrNull;
        if (match != null && match.title.isNotEmpty) return match.title;
        if (rt.title.isNotEmpty) return rt.title;
        return rt.topicId.isNotEmpty ? rt.topicId : 'Topic';
      }
    } else {
      if (index >= 0 && index < widget.topics.length) {
        return widget.topics[index].title;
      }
    }
    return '';
  }

  String get _startWithSubtitle {
    if (_selectedTopicIndex == -1) {
      return widget.isRevision ? 'Next topic in revision' : 'Next incomplete topic';
    }
    final title = _getTopicTitleAtIndex(_selectedTopicIndex);
    if (title.isNotEmpty) {
      return title;
    }
    return widget.isRevision ? 'Next topic in revision' : 'Next incomplete topic';
  }

  void _openDurationPicker() {
    showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final durations = [15, 20, 25, 30, 45, 60];
        return SheetContainer(
          children: [
            const SheetHandleBar(),
            const VGapSm(),
            const SheetHeader(
              title: 'Select Session Duration',
            ),
            const VGapSm(),
            ...durations.map((mins) {
              final isSelected = _selectedDurationMinutes == mins;
              final isDefault = mins == 15;
              return InkWell(
                onTap: () {
                  setState(() => _selectedDurationMinutes = mins);
                  Navigator.of(ctx).pop();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor(context),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondaryColor(context),
                          ),
                          const HGapSm(),
                          Text(
                            '$mins minutes${isDefault ? ' (Default)' : ''}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _openStartWithPicker() {
    final int total = widget.isRevision && widget.revisionTopics != null
        ? widget.revisionTopics!.length
        : widget.topics.length;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const VGapSm(),
                Text(
                  'Start With Topic',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const VGapXs(),
                Text(
                  'Select the topic to focus on first:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapSm(),
                Expanded(
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    children: [
                      // "Next incomplete / in revision" default option
                      InkWell(
                        onTap: () {
                          setState(() => _selectedTopicIndex = _findNextIncompleteIndex());
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedTopicIndex == -1
                                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _selectedTopicIndex == -1
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor(context),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.track_changes_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const HGapSm(),
                                  Text(
                                    widget.isRevision
                                        ? 'Next topic in revision'
                                        : 'Next incomplete topic',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: _selectedTopicIndex == -1
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: _selectedTopicIndex == -1
                                          ? AppTheme.primaryColor
                                          : AppTheme.textPrimaryColor(context),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedTopicIndex == -1)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 12),
                      // Specific topics list
                      for (int i = 0; i < total; i++) ...[
                        Builder(
                          builder: (context) {
                            final isCompleted = widget.isRevision && widget.revisionTopics != null
                                ? widget.revisionTopics![i].isCompleted
                                : widget.topics[i].isCompleted;
                            final title = _getTopicTitleAtIndex(i);
                            final isSelected = _selectedTopicIndex == i;

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedTopicIndex = i);
                                Navigator.of(ctx).pop();
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor(context),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Icon(
                                        isCompleted
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                        size: 16,
                                        color: isCompleted
                                            ? AppTheme.successColor
                                            : AppTheme.textSecondaryColor(context),
                                      ),
                                    ),
                                    const HGapSm(),
                                    Expanded(
                                      child: Text(
                                        '${i + 1}. $title',
                                        softWrap: true,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.25,
                                          fontWeight:
                                              isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.textPrimaryColor(context),
                                        ),
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const HGapSm(),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2.0),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: AppTheme.primaryColor,
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSessionSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SheetContainer(
              children: [
                const SheetHandleBar(),
                const VGapMd(),
                SheetHeader(
                  badge: SheetHeaderBadge(
                    backgroundColor: AppTheme.pastelIndigo(context),
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: 'Session Settings',
                  subtitle: 'Configure timer preferences and focus mode',
                ),
                const VGapLg(),
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Track session',
                  subtitle: 'Save completed session into study logs',
                  value: _trackSession,
                  onChanged: (val) {
                    setSheetState(() => _trackSession = val);
                    setState(() {});
                  },
                ),
                const VGapSm(),
                _buildLockModeSettingItem(
                  context: context,
                  config: _lockConfig,
                  onConfigure: () async {
                    final updated = await PhoneLockSettingsSheet.show(
                      context,
                      initialConfig: _lockConfig,
                    );
                    if (updated != null) {
                      setSheetState(() => _lockConfig = updated);
                      setState(() {});
                    }
                  },
                  onToggle: (enabled) {
                    setSheetState(() {
                      _lockConfig = _lockConfig.copyWith(isLockModeEnabled: enabled);
                    });
                    setState(() {});
                  },
                ),
                const VGapSm(),
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Allow pause',
                  subtitle: _lockConfig.isLockModeEnabled
                      ? 'Locked off in Lock mode'
                      : 'Enable pausing the timer during study',
                  value: _lockConfig.isLockModeEnabled ? false : _allowPause,
                  enabled: !_lockConfig.isLockModeEnabled,
                  onChanged: (val) {
                    setSheetState(() => _allowPause = val);
                    setState(() {});
                  },
                ),
                const VGapSm(),
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Allow reset',
                  subtitle: _lockConfig.isLockModeEnabled
                      ? 'Locked off in Lock mode'
                      : 'Enable resetting timer back to beginning',
                  value: _lockConfig.isLockModeEnabled ? false : _allowReset,
                  enabled: !_lockConfig.isLockModeEnabled,
                  onChanged: (val) {
                    setSheetState(() => _allowReset = val);
                    setState(() {});
                  },
                ),
                const VGapMd(),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSettingCheckboxItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    required ValueChanged<bool>? onChanged,
  }) {
    final alphaMultiplier = enabled ? 1.0 : 0.6;
    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primaryColor.withValues(alpha: 0.05 * alphaMultiplier)
              : AppTheme.surfaceVariant(context).withValues(alpha: 0.25 * alphaMultiplier),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value
                ? AppTheme.primaryColor.withValues(alpha: 0.3 * alphaMultiplier)
                : AppTheme.borderColor(context).withValues(alpha: alphaMultiplier),
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
              activeColor: AppTheme.primaryColor.withValues(alpha: alphaMultiplier),
              checkColor: Colors.white,
              side: BorderSide(
                color: value
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor(context).withValues(alpha: alphaMultiplier),
                width: 1.5,
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const HGapSm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context).withValues(alpha: alphaMultiplier),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondaryColor(context).withValues(alpha: alphaMultiplier),
                    ),
                  ),
                ],
              ),
            ),
            if (!enabled) ...[
              const HGapSm(),
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppTheme.textSecondaryColor(context).withValues(alpha: alphaMultiplier),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLockModeSettingItem({
    required BuildContext context,
    required PhoneLockConfig config,
    required VoidCallback onConfigure,
    required ValueChanged<bool> onToggle,
  }) {
    final isLocked = config.isLockModeEnabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLocked
            ? const Color(0xFFDC2626).withValues(alpha: 0.08)
            : AppTheme.surfaceVariant(context).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLocked
              ? const Color(0xFFDC2626).withValues(alpha: 0.35)
              : AppTheme.borderColor(context),
          width: isLocked ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isLocked,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: const Color(0xFFDC2626),
            checkColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const HGapSm(),
          Expanded(
            child: InkWell(
              onTap: onConfigure,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Lock mode',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLocked
                                ? const Color(0xFFDC2626)
                                : AppTheme.textPrimaryColor(context),
                          ),
                        ),
                        const HGapXs(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ZEN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const VGapXs(),
                    Text(
                      isLocked
                          ? 'Timed lock active (${config.gracePeriodSeconds}s grace) • Tap to configure'
                          : 'Lock My Phone style: full-screen timed lock • Tap to configure',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 18),
            color: isLocked ? const Color(0xFFDC2626) : AppTheme.textSecondaryColor(context),
            tooltip: 'Lock Mode Settings',
            visualDensity: VisualDensity.compact,
            onPressed: onConfigure,
          ),
        ],
      ),
    );
  }

  Future<LockPermissionChoice?> _showLockModePinPrompt(BuildContext context) {
    return showDialog<LockPermissionChoice>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.screen_lock_portrait_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const VGapMd(),
                  Text(
                    'Start Lock Mode',
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    'Choose lock intensity for this $_selectedDurationMinutes-minute session:\n\n• Only Lock: Timed full-screen lock overlay.\n• Pin & Lock: Native Android screen pinning blocks secondary apps completely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const VGapLg(),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(LockPermissionChoice.onlyLock),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppTheme.borderColor(context)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Only Lock',
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const HGapSm(),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(LockPermissionChoice.pinAndLock),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Pin & Lock',
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
            // Top right cross icon to cancel
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppTheme.textSecondaryColor(context),
                ),
                tooltip: 'Cancel',
                splashRadius: 18,
                onPressed: () => Navigator.of(ctx).pop(LockPermissionChoice.cancel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    final effectiveIndex = _selectedTopicIndex >= 0 ? _selectedTopicIndex : _findNextIncompleteIndex();

    // If Lock Mode is enabled, show explicit Pin Permission dialog before locking
    if (_lockConfig.isLockModeEnabled) {
      final choice = await _showLockModePinPrompt(context);
      if (choice == null || choice == LockPermissionChoice.cancel || !mounted) {
        return;
      }
      final enablePinning = (choice == LockPermissionChoice.pinAndLock);
      _lockConfig = _lockConfig.copyWith(enableScreenPinning: enablePinning);
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionTimerScreen(
          title: widget.isRevision ? 'Revision Session' : 'Study Session',
          subtitle: widget.courseTitle.isNotEmpty
              ? '${widget.courseTitle} > ${widget.moduleTitle}'
              : widget.moduleTitle,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          durationMinutes: _selectedDurationMinutes,
          isRevision: widget.isRevision,
          revisionId: widget.revisionId,
          topics: widget.topics,
          revisionTopics: widget.revisionTopics,
          initialTopicIndex: effectiveIndex,
          trackSession: _trackSession,
          allowPause: _allowPause,
          allowReset: _allowReset,
          lockConfig: _lockConfig,
        ),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final isRev = widget.isRevision;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(context),

            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Module Card
                    _buildModuleHeaderCard(context, isRev),

                    const VGapSm(),

                    // Settings Group (Duration + Start With)
                    _buildSettingsCard(context),

                    const VGapSm(),

                    // Info Callout
                    _buildInfoNote(context, isRev),
                  ],
                ),
              ),
            ),

            // Bottom Compact CTA Button with Quick Launch Lock Mode Checkbox
            Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, bottomSafe > 0 ? bottomSafe + 4 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Quick Launch Lock Mode Checkbox (Left-aligned)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _lockConfig = _lockConfig.copyWith(
                            isLockModeEnabled: !_lockConfig.isLockModeEnabled,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _lockConfig.isLockModeEnabled,
                                onChanged: (val) {
                                  setState(() {
                                    _lockConfig = _lockConfig.copyWith(
                                      isLockModeEnabled: val ?? false,
                                    );
                                  });
                                },
                                activeColor: const Color(0xFFDC2626),
                                checkColor: Colors.white,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const HGapSm(),
                            Text(
                              'Lock Mode',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _lockConfig.isLockModeEnabled
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: _lockConfig.isLockModeEnabled
                                    ? const Color(0xFFDC2626)
                                    : AppTheme.textSecondaryColor(context),
                              ),
                            ),
                            if (_lockConfig.isLockModeEnabled) ...[
                              const HGapXs(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'ZEN',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const VGapMd(),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _startSession,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Start Session',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lockConfig.isLockModeEnabled
                            ? const Color(0xFFDC2626)
                            : AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return CustomAppBar(
      title: widget.isRevision ? 'Revision Session' : 'Study Session',
      onBack: () => Navigator.of(context).pop(),
      actions: [
        if (_lockConfig.isLockModeEnabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
            ),
            child: const Text(
              'LOCK',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFFDC2626),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const HGapXs(),
        ],
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            size: 20,
            color: _lockConfig.isLockModeEnabled
                ? const Color(0xFFDC2626)
                : AppTheme.textSecondaryColor(context),
          ),
          onPressed: _openSessionSettingsSheet,
          tooltip: 'Session Settings',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildModuleHeaderCard(BuildContext context, bool isRev) {
    final iconColor = isRev ? AppTheme.successColor : AppTheme.primaryColor;
    final iconBg = isRev
        ? AppTheme.successColor.withValues(alpha: 0.12)
        : AppTheme.primaryColor.withValues(alpha: 0.12);

    final subtext = widget.courseTitle.isNotEmpty
        ? '${widget.courseTitle} • ${widget.moduleTitle}'
        : widget.moduleTitle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              isRev ? Icons.sync_rounded : Icons.article_outlined,
              color: iconColor,
              size: 20,
            ),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.moduleTitle,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const VGapXs(),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        children: [
          // Session duration tile
          InkWell(
            onTap: _openDurationPicker,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const HGapMd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session duration',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        const VGapXs(),
                        Text(
                          '$_selectedDurationMinutes minutes${_selectedDurationMinutes == 25 ? ' (Default)' : ''}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondaryColor(context),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: AppTheme.borderColor(context), indent: 52),

          // Start with topic tile
          InkWell(
            onTap: _openStartWithPicker,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.track_changes_rounded,
                      size: 16,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const HGapMd(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start with',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                        const VGapXs(),
                        Text(
                          _startWithSubtitle,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondaryColor(context),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote(BuildContext context, bool isRev) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppTheme.textSecondaryColor(context),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              isRev
                  ? 'You can revise multiple topics in this session.'
                  : 'You can complete multiple topics in this session.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondaryColor(context),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
