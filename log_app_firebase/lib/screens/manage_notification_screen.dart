import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../controllers/settings_controller.dart';
import '../services/notification_service.dart';
import '../services/notification_transaction_service.dart';

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
              _SwitchItem(
                icon: Icons.notifications_active_outlined,
                iconBgColor: AppTheme.primaryColor,
                title: 'Daily note Reminder',
                subtitle: 'Receive a daily nudge to record your thoughts',
                value: controller.dailyReminder,
                onChanged: controller.toggleReminder,
              ),
              const _Divider(),
              _SwitchItem(
                icon: Icons.receipt_long_outlined,
                iconBgColor: AppTheme.successColor,
                title: 'Notification Scanner',
                subtitle: 'Auto-track payments from active screen notifications (requires persistent banner)',
                value: controller.notificationScannerEnabled,
                onChanged: (val) => _handleNotificationScannerToggle(context, val),
              ),
              const _Divider(),
              _MenuItem(
                icon: Icons.notifications_active_rounded,
                iconBgColor: AppTheme.secondaryColor,
                title: 'Trigger Test Notification',
                subtitle: 'Test banner notifications immediately (instant trigger)',
                onTap: () async {
                  await NotificationService.showInstantNotification(
                    id: 9999,
                    title: 'Test Notification 🔔',
                    body: 'If you see this, your reminders are working perfectly!',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification triggered instantly!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
              ),
              const _Divider(),
              _MenuItem(
                icon: Icons.receipt_long_rounded,
                iconBgColor: AppTheme.successColor,
                title: 'Trigger Dummy Transaction',
                subtitle: 'Simulate a ₹1,250 spent SMS notification to test budget capture',
                onTap: () async {
                  final hasScannerPermission = await NotificationTransactionService.isPermissionGranted();
                  if (hasScannerPermission) {
                    await NotificationTransactionService.startService();
                  }
                  await NotificationService.showInstantNotification(
                    id: 9991,
                    title: 'HDFC Bank',
                    body: 'Alert: Rs. 1,250.00 spent on HDFC Credit Card XX1234 at Swiggy. Info: ₹1250',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Dummy transaction SMS notification triggered!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
              ),
              const _Divider(),
              _MenuItem(
                icon: Icons.timer_rounded,
                iconBgColor: AppTheme.primaryColor,
                title: 'Test Scheduled Notification (10s)',
                subtitle: 'Schedule a test notification to trigger in 10 seconds',
                onTap: () async {
                  final triggerTime = DateTime.now().add(const Duration(seconds: 10));
                  await NotificationService.scheduleOneShotNotification(
                    id: 889,
                    title: 'Scheduled Test ⏰',
                    body: 'If you see this, scheduled alarms are working!',
                    dateTime: triggerTime,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification scheduled for 10 seconds from now!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleNotificationScannerToggle(BuildContext context, bool val) async {
    if (val) {
      final hasPermission = await NotificationTransactionService.isPermissionGranted();
      if (!context.mounted) return;
      if (!hasPermission) {
        final confirmed = await _showNotificationScannerSetupDialog(context);
        if (!confirmed) return;
        await NotificationTransactionService.requestPermission();
        final statusAfter = await NotificationTransactionService.isPermissionGranted();
        if (!statusAfter) return;
      }
    }
    await controller.toggleNotificationScanner(val);
  }


  Future<bool> _showNotificationScannerSetupDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Notification Scanner Access',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'LOG requires Notification Access to automatically scan and import transaction alerts from active notifications in real time. Your messages are parsed completely offline and locally on your device.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Enable Access',
              style: TextStyle(
                color: AppTheme.primaryAccentColor(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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
