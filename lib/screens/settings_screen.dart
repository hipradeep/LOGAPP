import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/app_spacers.dart';
import '../widgets/edit_profile_sheet.dart';
import 'track_activities_screen.dart';
import 'manage_budget_screen.dart';
import '../services/activity_service.dart';
import '../services/note_service.dart';
import '../services/budget_service.dart';
import '../services/notification_service.dart';
import '../models/activity.dart';
import '../models/note_entity.dart';
import '../models/budget.dart';
import 'manage_quick_actions_screen.dart';
import '../controllers/settings_controller.dart';
import '../widgets/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showComingSoonSnackBar(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName option is coming soon in LOG Pro!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _showProUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius)),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Text('LOG Pro Beta', style: AppTheme.headingSmall),
          ],
        ),
        content: Text(
          'LOG Pro will unlock features like custom color themes, biometric app locks, automated cloud backups, and export options.\n\nAll premium features will be unlocked for early beta testers in the next build! Thank you for testing LOG.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got It', style: AppTheme.bodyMedium.copyWith(color: AppTheme.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, SettingsController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditProfileSheet(
        initialName: controller.userName,
        initialAvatar: controller.userAvatar,
        onSave: controller.updateProfile,
      ),
    );
  }

  Future<void> _resetCache(BuildContext context, SettingsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius)),
        title: Text('Reset Profile Settings', style: AppTheme.headingSmall),
        content: Text(
          'Are you sure you want to reset your profile details and toggle settings? This won\'t delete your activities or logs.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTheme.bodyMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.resetCache();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings cache cleared successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppProvider<SettingsController>(
      notifier: _controller,
      child: Builder(
        builder: (context) {
          final controller = AppProvider.watch<SettingsController>(context);

          if (controller.isLoading) {
            return const FullScreenPage(
              title: 'Settings',
              children: [
                Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              ],
            );
          }

          return FullScreenPage(
            title: 'Settings',
            isScrollable: true,
            backgroundWidgets: const [
              GlowBlob(
                top: -40,
                left: -40,
                size: 240,
                color: AppTheme.primaryColor,
                opacity: 0.1,
              ),
              GlowBlob(
                bottom: -60,
                right: -40,
                size: 260,
                color: AppTheme.secondaryColor,
                opacity: 0.06,
              ),
            ],
            children: [
              const VGapMd(),
              
              // 1. Profile card with stats
              _ProfileCard(
                userName: controller.userName,
                userAvatar: controller.userAvatar,
                onEditTap: () => _showEditProfileSheet(context, controller),
              ),
              
              const VGapLg(),

              // 2. Pro Upgrade Card
              _ProUpgradeCard(
                onTap: () => _showProUpgradeDialog(context),
              ),

              const VGapLg(),

              // 3. Tracking & Goals (static)
              const _GoalsTrackingSection(),

              const VGapLg(),

              // 4. Preferences & Security
              _PreferencesSecuritySection(
                dailyReminder: controller.dailyReminder,
                onReminderToggle: controller.toggleReminder,
                onComingSoon: (feature) => _showComingSoonSnackBar(context, feature),
              ),

              const VGapLg(),

              // 5. Data & Sync
              _DataSyncSection(
                onResetCache: () => _resetCache(context, controller),
                onComingSoon: (feature) => _showComingSoonSnackBar(context, feature),
              ),

              const VGapLg(),

              // 6. App Info (static)
              const _InfoSupportSection(),
              
              const VGapXxl(),
              const VGapXxl(),
            ],
          );
        }
      ),
    );
  }
}

// ==================== WIDGET COMPONENTS ====================

class _ProfileCard extends StatelessWidget {
  final String userName;
  final String userAvatar;
  final VoidCallback onEditTap;

  const _ProfileCard({
    required this.userName,
    required this.userAvatar,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final activityService = ActivityService();
    final noteService = NoteService();
    final budgetService = BudgetService();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar emoji inside glowing circle
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.backgroundColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(userAvatar, style: const TextStyle(fontSize: 32)),
                  ),
                ),
                const HGapMd(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: AppTheme.headingSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const VGapXs(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'LOG Member',
                          style: TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  color: AppTheme.primaryLight,
                  onPressed: onEditTap,
                  tooltip: 'Edit Profile',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          
          // Stats Row
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stat 1: Habits
                Expanded(
                  child: StreamBuilder<List<Activity>>(
                    stream: activityService.getActiveActivitiesStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Habits', count.toString(), Icons.check_circle_outline_rounded, AppTheme.primaryLight);
                    },
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                // Stat 2: Logs
                Expanded(
                  child: StreamBuilder<List<NoteEntity>>(
                    stream: noteService.getNotesStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Logs', count.toString(), Icons.history_rounded, Colors.tealAccent);
                    },
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                // Stat 3: Budgets
                Expanded(
                  child: StreamBuilder<List<Budget>>(
                    stream: budgetService.getBudgetsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStatColumn('Budgets', count.toString(), Icons.account_balance_wallet_outlined, AppTheme.successColor);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTheme.headingSmall.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProUpgradeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ProUpgradeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.15),
            Colors.amber.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 22),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to LOG Pro',
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                    const VGapXs(),
                    Text(
                      'Unlock advanced cloud sync, app locks, and themes.',
                      style: AppTheme.bodySmall.copyWith(fontSize: 11, color: Colors.amber.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
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
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.trailing,
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
            if (trailing != null) ...[
              trailing!,
            ] else ...[
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textSecondary, size: 14),
            ],
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
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppTheme.primaryLight,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.05),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _GoalsTrackingSection extends StatelessWidget {
  const _GoalsTrackingSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Goals & Tracking',
      children: [
        _MenuItem(
          icon: Icons.check_circle_outline_rounded,
          iconBgColor: AppTheme.primaryColor,
          title: 'Track Activities',
          subtitle: 'Select habits and attendance items to track',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TrackActivitiesScreen(),
              ),
            );
          },
        ),
        const _Divider(),
        _MenuItem(
          icon: Icons.account_balance_wallet_outlined,
          iconBgColor: AppTheme.successColor,
          title: 'Manage Budget',
          subtitle: 'Set salary, item limits, and track savings',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageBudgetScreen(),
              ),
            );
          },
        ),
        const _Divider(),
        _MenuItem(
          icon: Icons.bolt_rounded,
          iconBgColor: AppTheme.secondaryColor,
          title: 'Manage Quick Actions',
          subtitle: 'Select which shortcut panels appear on Dashboard',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageQuickActionsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PreferencesSecuritySection extends StatelessWidget {
  final bool dailyReminder;
  final ValueChanged<bool> onReminderToggle;
  final ValueChanged<String> onComingSoon;

  const _PreferencesSecuritySection({
    required this.dailyReminder,
    required this.onReminderToggle,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Preferences & Security',
      children: [
        _SwitchItem(
          icon: Icons.notifications_active_outlined,
          iconBgColor: AppTheme.primaryColor,
          title: 'Daily note Reminder',
          subtitle: 'Receive a daily nudge to record your thoughts',
          value: dailyReminder,
          onChanged: onReminderToggle,
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
        const _Divider(),
        _MenuItem(
          icon: Icons.lock_outline_rounded,
          iconBgColor: Colors.blueAccent,
          title: 'App Lock & PIN',
          subtitle: 'Secure your note entries with a passcode',
          trailing: const _ComingSoonBadge(),
          onTap: () => onComingSoon('App Lock'),
        ),
        const _Divider(),
        _MenuItem(
          icon: Icons.palette_outlined,
          iconBgColor: Colors.pinkAccent,
          title: 'Custom Themes',
          subtitle: 'Tailor the application accent and gradients',
          trailing: const _ComingSoonBadge(),
          onTap: () => onComingSoon('Custom Themes'),
        ),
      ],
    );
  }
}

class _DataSyncSection extends StatelessWidget {
  final VoidCallback onResetCache;
  final ValueChanged<String> onComingSoon;

  const _DataSyncSection({
    required this.onResetCache,
    required this.onComingSoon,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Data & Sync',
      children: [
        _MenuItem(
          icon: Icons.cloud_sync_outlined,
          iconBgColor: Colors.teal,
          title: 'Cloud Backup & Sync',
          subtitle: 'Save and synchronize settings and logs',
          trailing: const _ComingSoonBadge(),
          onTap: () => onComingSoon('Cloud Backup'),
        ),
        const _Divider(),
        _MenuItem(
          icon: Icons.delete_outline_rounded,
          iconBgColor: AppTheme.errorColor,
          title: 'Clear Cache & Reset',
          subtitle: 'Restore local settings, username, and toggles',
          onTap: onResetCache,
        ),
      ],
    );
  }
}

class _InfoSupportSection extends StatelessWidget {
  const _InfoSupportSection();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Info & Support',
      children: [
        _MenuItem(
          icon: Icons.star_outline_rounded,
          iconBgColor: Colors.amber,
          title: 'Review LOG App',
          subtitle: 'Share feedback or rate us on Play Store',
          onTap: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for testing LOG! Custom review link coming soon.'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          },
        ),
        const _Divider(),
        _MenuItem(
          icon: Icons.info_outline_rounded,
          iconBgColor: AppTheme.textSecondary,
          title: 'About LOG',
          subtitle: 'Learn more about LOG developers',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'LOG',
              applicationVersion: '1.1.0',
              applicationIcon: const Text('🚀', style: TextStyle(fontSize: 32)),
              children: const [
                Text('A premium daily note and activity tracker for Android.'),
              ],
            );
          },
        ),
      ],
    );
  }
}
