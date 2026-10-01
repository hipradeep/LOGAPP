import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/sheet_action_widgets.dart';
import '../models/topic.dart';
import '../models/revision_topic.dart';
import 'session_timer_screen.dart';

/// Screen 2 & 7: Session Setup Screen
///
/// Prepares a focus session for studying or revising module topics.
/// Displays module metadata, session duration selector (default 25m),
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
  int _selectedDurationMinutes = 25;
  int _selectedTopicIndex = -1; // -1 means "Next incomplete topic" / "Next topic in revision"

  // Session Preferences
  bool _trackSession = true;
  bool _allowPause = true;
  bool _isRestrictMode = false;
  bool _allowReset = true;

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
        return widget.revisionTopics![index].title;
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
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                  'Select Session Duration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
                const VGapSm(),
                ...durations.map((mins) {
                  final isSelected = _selectedDurationMinutes == mins;
                  final isDefault = mins == 25;
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
            ),
          ),
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
                    physics: const BouncingScrollPhysics(),
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
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Allow pause',
                  subtitle: _isRestrictMode
                      ? 'Locked off in Restrict mode'
                      : 'Enable pausing the timer during study',
                  value: _isRestrictMode ? false : _allowPause,
                  enabled: !_isRestrictMode,
                  onChanged: (val) {
                    setSheetState(() => _allowPause = val);
                    setState(() {});
                  },
                ),
                const VGapSm(),
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Restrict mode',
                  subtitle: 'Strict focus: disables pause, guards exit & blocks resets',
                  value: _isRestrictMode,
                  onChanged: (val) {
                    setSheetState(() => _isRestrictMode = val);
                    setState(() {});
                  },
                ),
                const VGapSm(),
                _buildSettingCheckboxItem(
                  context: context,
                  title: 'Allow reset',
                  subtitle: _isRestrictMode
                      ? 'Locked off in Restrict mode'
                      : 'Enable resetting timer back to beginning',
                  value: _isRestrictMode ? false : _allowReset,
                  enabled: !_isRestrictMode,
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
    return InkWell(
      onTap: enabled && onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: value
                ? AppTheme.primaryColor.withValues(alpha: 0.05)
                : AppTheme.surfaceVariant(context).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.white,
                side: BorderSide(
                  color: value ? AppTheme.primaryColor : AppTheme.borderColor(context),
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
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryColor(context),
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
                  color: AppTheme.textSecondaryColor(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _startSession() {
    final effectiveIndex = _selectedTopicIndex >= 0 ? _selectedTopicIndex : _findNextIncompleteIndex();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionTimerScreen(
          title: widget.isRevision ? 'Revision Session' : 'Study Session',
          subtitle: '${widget.moduleTitle} • ${widget.courseTitle.isNotEmpty ? widget.courseTitle : 'C1'}',
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
          isRestrictMode: _isRestrictMode,
          allowReset: _allowReset,
        ),
      ),
    );
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
                physics: const BouncingScrollPhysics(),
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

            // Bottom Compact CTA Button
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, bottomSafe > 0 ? bottomSafe + 4 : 10),
              child: SizedBox(
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
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppTheme.textPrimaryColor(context),
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
          ),
          Text(
            widget.isRevision ? 'Revision Session' : 'Study Session',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRestrictMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelOrange(context),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.pastelOrangeBorder(context)),
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
                const HGapXs(),
              ],
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  size: 20,
                  color: _isRestrictMode
                      ? AppTheme.pastelOrangeText(context)
                      : AppTheme.textSecondaryColor(context),
                ),
                onPressed: _openSessionSettingsSheet,
                tooltip: 'Session Settings',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
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
