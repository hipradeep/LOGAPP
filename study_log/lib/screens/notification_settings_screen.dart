import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/service_locator.dart';
import '../controllers/notification_controller.dart';

/// Full-screen Notification Settings page allowing users to configure
/// Morning Briefing, Daily Study Reminders with custom multi-slots,
/// Spaced Revision reminders, Streak Saver, and Course Deadlines.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = getIt<NotificationController>();
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Notifications',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomSafe + 32),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final isMasterEnabled = controller.enabled;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MasterToggleCard(
                          isEnabled: isMasterEnabled,
                          onChanged: controller.setMasterEnabled,
                        ),
                        const VGapMd(),
                        const _SectionLabel(title: 'DAILY ROUTINE'),
                        const VGapXs(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isMasterEnabled ? 1.0 : 0.4,
                          child: IgnorePointer(
                            ignoring: !isMasterEnabled,
                            child: _SettingsContainer(
                              children: [
                                _NotificationOptionTile(
                                  icon: Icons.wb_sunny_rounded,
                                  iconColor: const Color(0xFFF59E0B),
                                  iconBgColor:
                                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                  title: 'Morning Briefing',
                                  subtitle:
                                      'Daily digest of revisions and deadlines',
                                  value: controller.morningBriefingEnabled,
                                  onChanged: controller.setMorningBriefing,
                                  child: controller.morningBriefingEnabled
                                      ? _TimePickerRow(
                                          label: 'Briefing time',
                                          time: controller.morningBriefingTime,
                                          onSelectTime:
                                              controller.setMorningBriefingTime,
                                        )
                                      : null,
                                ),
                                const _TileDivider(),
                                _StudyRemindersAccordionTile(
                                  controller: controller,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const VGapMd(),
                        const _SectionLabel(title: 'REVISION & STREAKS'),
                        const VGapXs(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isMasterEnabled ? 1.0 : 0.4,
                          child: IgnorePointer(
                            ignoring: !isMasterEnabled,
                            child: _SettingsContainer(
                              children: [
                                _NotificationOptionTile(
                                  icon: Icons.replay_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  iconBgColor:
                                      const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                  title: 'Revision Reminders',
                                  subtitle:
                                      'Includes Topics & Modules due today (Morning & Midday)',
                                  value: controller.revisionDueEnabled,
                                  onChanged: controller.setRevisionDue,
                                ),
                                const _TileDivider(),
                                _NotificationOptionTile(
                                  icon: Icons.local_fire_department_rounded,
                                  iconColor: const Color(0xFFF97316),
                                  iconBgColor:
                                      const Color(0xFFF97316).withValues(alpha: 0.12),
                                  title: 'Streak Saver',
                                  subtitle:
                                      'Silences automatically once you study today',
                                  value: controller.streakSaverEnabled,
                                  onChanged: controller.setStreakSaver,
                                  child: controller.streakSaverEnabled
                                      ? _TimePickerRow(
                                          label: 'Alert time',
                                          time: controller.streakSaverTime,
                                          onSelectTime:
                                              controller.setStreakSaverTime,
                                        )
                                      : null,
                                ),
                                const _TileDivider(),
                                _NotificationOptionTile(
                                  icon: Icons.calendar_today_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  iconBgColor:
                                      const Color(0xFF10B981).withValues(alpha: 0.12),
                                  title: 'Course Deadlines',
                                  subtitle:
                                      'Alert when a target deadline is today',
                                  value: controller.deadlineEnabled,
                                  onChanged: controller.setDeadlineEnabled,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const VGapLg(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textMutedColor(context),
        ),
      ),
    );
  }
}

class _MasterToggleCard extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _MasterToggleCard({
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(
          color: isEnabled
              ? AppTheme.primaryColor.withValues(alpha: 0.35)
              : AppTheme.borderColor(context),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : AppTheme.borderColor(context).withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: isEnabled
                  ? AppTheme.primaryColor
                  : AppTheme.textMutedColor(context),
              size: 16,
            ),
          ),
          const HGapSm(),
          Expanded(
            child: Text(
              'Allow Notifications',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          ),
          _CompactSwitch(
            value: isEnabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsContainer extends StatelessWidget {
  final List<Widget> children;

  const _SettingsContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor(context),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _NotificationOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _NotificationOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const HGapSm(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const VGapXs(),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _CompactSwitch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
          if (child != null) ...[
            const VGapXs(),
            Padding(
              padding: const EdgeInsets.only(left: 36.0, top: 2.0),
              child: child!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Accordion tile allowing user to view, expand, configure, add, and delete multi-slot study times.
class _StudyRemindersAccordionTile extends StatefulWidget {
  final NotificationController controller;

  const _StudyRemindersAccordionTile({required this.controller});

  @override
  State<_StudyRemindersAccordionTile> createState() =>
      _StudyRemindersAccordionTileState();
}

class _StudyRemindersAccordionTileState
    extends State<_StudyRemindersAccordionTile> {
  bool _isExpanded = false;

  String _formatSlotTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
  }

  Future<void> _showAddSlotDialog() async {
    final textController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
              ),
              title: Text(
                'Add Study Reminder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Afternoon Focus Boost',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedColor(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: AppTheme.borderColor(context)),
                      ),
                    ),
                  ),
                  const VGapMd(),
                  Text(
                    'Time',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatSlotTime(selectedTime),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondaryColor(context)),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    final title = textController.text.trim();
                    widget.controller.addStudyReminderSlot(
                      title: title.isEmpty ? 'Study Reminder' : title,
                      time: selectedTime,
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteSlot(StudyReminderSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
          ),
          title: Text(
            'Delete Reminder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          content: Text(
            'Delete reminder for ${_formatSlotTime(slot.time)} ("${slot.title}")?',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.controller.deleteStudyReminderSlot(slot.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMasterStudyOn = widget.controller.courseDueEnabled;
    final slots = widget.controller.studyReminderSlots;
    final activeCount = slots.where((s) => s.isEnabled).length;
    final summaryText = '$activeCount of ${slots.length} active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: Color(0xFF3B82F6),
                  size: 15,
                ),
              ),
              const HGapSm(),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Daily Study Reminders',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          const HGapXs(),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppTheme.textMutedColor(context),
                          ),
                        ],
                      ),
                      const VGapXs(),
                      Text(
                        summaryText,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _CompactSwitch(
                value: isMasterStudyOn,
                onChanged: widget.controller.setCourseDue,
              ),
            ],
          ),
          if (_isExpanded && isMasterStudyOn) ...[
            const VGapMd(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.borderColor(context).withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final slot in slots) ...[
                    _SlotRowItem(
                      slot: slot,
                      formattedTime: _formatSlotTime(slot.time),
                      onToggle: (val) =>
                          widget.controller.toggleStudyReminderSlot(slot.id, val),
                      onTimeTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: slot.time,
                        );
                        if (picked != null) {
                          widget.controller.updateStudyReminderSlot(
                            slot.copyWith(time: picked),
                          );
                        }
                      },
                      onLongPress: () => _confirmDeleteSlot(slot),
                    ),
                    const VGapXs(),
                  ],
                  const VGapXs(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _showAddSlotDialog,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              HGapXs(),
                              Text(
                                'Add Study Time',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '💡 Long-press to delete',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotRowItem extends StatelessWidget {
  final StudyReminderSlot slot;
  final String formattedTime;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTimeTap;
  final VoidCallback onLongPress;

  const _SlotRowItem({
    required this.slot,
    required this.formattedTime,
    required this.onToggle,
    required this.onTimeTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = slot.isEnabled ? 1.0 : 0.45;

    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
          child: Row(
            children: [
              const Icon(
                Icons.alarm_rounded,
                size: 14,
                color: Color(0xFF3B82F6),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  slot.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const HGapSm(),
              InkWell(
                onTap: onTimeTap,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const HGapSm(),
              _SlotToggleChip(
                isEnabled: slot.isEnabled,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotToggleChip extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _SlotToggleChip({
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isEnabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppTheme.primaryColor
              : AppTheme.borderColor(context).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isEnabled ? 'ON' : 'OFF',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: isEnabled
                ? Colors.white
                : AppTheme.textMutedColor(context),
          ),
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CompactSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.primaryColor;
    final inactiveTrack = AppTheme.borderColor(context).withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: 34,
          height: 19,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: value ? activeColor : inactiveTrack,
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onSelectTime;

  const _TimePickerRow({
    required this.label,
    required this.time,
    required this.onSelectTime,
  });

  String _formatTime(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppTheme.primaryColor,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      if (picked.hour < 4) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Notifications must start from 4:00 AM onwards. Adjusted to 4:00 AM.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        onSelectTime(const TimeOfDay(hour: 4, minute: 0));
      } else {
        onSelectTime(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondaryColor(context),
            fontWeight: FontWeight.w400,
          ),
        ),
        InkWell(
          onTap: () => _pickTime(context),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: AppTheme.primaryColor,
                ),
                const HGapXs(),
                Text(
                  _formatTime(context),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 42,
      endIndent: 14,
      color: AppTheme.borderColor(context),
    );
  }
}
