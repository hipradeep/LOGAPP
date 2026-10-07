import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import '../services/service_locator.dart';
import '../controllers/notification_controller.dart';

/// Full-screen Notification Settings page allowing users to configure
/// Revision Due, Course Due, Streak Saver, and Course Deadline reminders.
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListenableBuilder(
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
                const _SectionLabel(title: 'REMINDERS'),
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
                          iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          title: 'Revision Due',
                          value: controller.revisionDueEnabled,
                          onChanged: controller.setRevisionDue,
                        ),
                        const _TileDivider(),
                        _NotificationOptionTile(
                          icon: Icons.school_outlined,
                          iconColor: const Color(0xFF3B82F6),
                          iconBgColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          title: 'Study',
                          value: controller.courseDueEnabled,
                          onChanged: controller.setCourseDue,
                          child: controller.courseDueEnabled
                              ? _TimePickerRow(
                                  label: 'Alert time',
                                  time: controller.courseDueTime,
                                  onSelectTime: controller.setCourseDueTime,
                                )
                              : null,
                        ),
                        const _TileDivider(),
                        _NotificationOptionTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFF97316),
                          iconBgColor: const Color(0xFFF97316).withValues(alpha: 0.12),
                          title: 'Streak Saver',
                          value: controller.streakSaverEnabled,
                          onChanged: controller.setStreakSaver,
                        ),
                        const _TileDivider(),
                        _NotificationOptionTile(
                          icon: Icons.calendar_today_rounded,
                          iconColor: const Color(0xFF10B981),
                          iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                          title: 'Deadline Alerts',
                          value: controller.deadlineEnabled,
                          onChanged: controller.setDeadlineEnabled,
                        ),
                      ],
                    ),
                  ),
                ),
                const VGapMd(),
              ],
            );
          },
        ),
                    const VGapLg(),
                  ],
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
              color: isEnabled ? AppTheme.primaryColor : AppTheme.textMutedColor(context),
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
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _NotificationOptionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
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
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor(context),
                  ),
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
              content: Text('Notifications must start from 4:00 AM onwards. Adjusted to 4:00 AM.'),
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


