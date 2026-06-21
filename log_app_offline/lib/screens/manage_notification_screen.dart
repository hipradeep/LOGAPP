import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../controllers/settings_controller.dart';
import 'activity_reminder_screen.dart';

class ManageNotificationScreen extends StatelessWidget {
  final SettingsController controller;

  const ManageNotificationScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return FullScreenPage(
          title: 'Manage Notification',
          showBackButton: true,
          isScrollable: true,

          children: [
            const VGapMd(),
            _buildNotificationSection(context),
            const VGapXxl(),
          ],
        );
      },
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'NOTIFICATION SETTINGS',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor(context),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _MenuItem(
                icon: Icons.notifications_active_rounded,
                iconBgColor: AppTheme.secondaryColor,
                title: 'Activity Reminder',
                subtitle: 'Configure alarms, reminder times and schedules',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityReminderScreen(),
                    ),
                  );
                },
              ),
              const _Divider(),
              _SwitchItem(
                icon: Icons.notifications_active_outlined,
                iconBgColor: AppTheme.primaryColor,
                title: 'Daily note Reminder',
                subtitle: 'Receive a daily nudge to record your thoughts',
                value: controller.dailyReminder,
                onChanged: controller.toggleReminder,
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconBgColor.withValues(alpha: 0.8), size: 20),
            ),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondaryColor(context),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconBgColor.withValues(alpha: 0.8), size: 20),
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const VGapXs(),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.4),
            inactiveThumbColor: AppTheme.switchInactiveThumbColor(context),
            inactiveTrackColor: AppTheme.switchInactiveTrackColor(context),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppTheme.borderColor(context));
  }
}
